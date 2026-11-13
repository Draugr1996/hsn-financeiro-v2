-- Complemento do clone: uma linha por tentativa, início/fim e reenvio do mesmo título.

alter table public.hsn_send_attempts add column started_at timestamptz not null default now(), add column finished_at timestamptz, add column updated_at timestamptz not null default now();

create unique index hsn_attempt_one_processing_job on public.hsn_send_attempts(job_id) where status='processing';

create trigger hsn_attempt_audit after insert or update on public.hsn_send_attempts for each row execute function hsn_private.audit_change();

CREATE OR REPLACE FUNCTION public.hsn_send_claim(p_owner uuid, p_job uuid, p_snapshot jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE j public.hsn_send_jobs; next_send timestamptz; r jsonb; title public.sicoob_collections; day_br date; log_id uuid; mirror jsonb:='[]';
BEGIN
 INSERT INTO public.hsn_send_throttle(owner_id,next_at) VALUES(p_owner,now()) ON CONFLICT DO NOTHING;
 SELECT next_at INTO next_send FROM public.hsn_send_throttle WHERE owner_id=p_owner FOR UPDATE;
 SELECT * INTO j FROM public.hsn_send_jobs WHERE id=p_job AND owner_id=p_owner FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Envio não localizado'; END IF;
 IF j.snapshot IS DISTINCT FROM p_snapshot THEN RAISE EXCEPTION 'Prévia alterada. Refaça a conferência.'; END IF;
 IF j.status NOT IN ('prepared','failed') THEN RAISE EXCEPTION 'Envio já iniciado ou resultado incerto'; END IF;
 IF j.retry_after>now() OR next_send>now() THEN RAISE EXCEPTION 'Aguarde o intervalo de envio antes de tentar'; END IF;
 day_br:=(now() AT TIME ZONE 'America/Sao_Paulo')::date;
 IF j.kind='collection' THEN
  FOR r IN SELECT value FROM jsonb_array_elements(j.snapshot->'titles') ORDER BY value->>'id' LOOP
   SELECT * INTO title FROM public.sicoob_collections WHERE id=(r->>'id')::uuid AND owner_id=p_owner FOR UPDATE;
   IF NOT FOUND OR (title.status not in ('pending','sent') or coalesce(title.paid_amount,0)>0 or title.cancelled_at is not null or (title.status='sent' and nullif(j.snapshot->>'resend_of','') is null)) OR title.due_date::date>=day_br OR
     title.company IS DISTINCT FROM r->>'company' OR title.amount::numeric IS DISTINCT FROM (r->>'amount')::numeric OR
     title.external_reference IS DISTINCT FROM r->>'external_reference' OR title.due_date::text IS DISTINCT FROM r->>'due_date'
   THEN RAISE EXCEPTION 'Título pago, alterado, ausente ou não vencido. Refaça a conferência.'; END IF;
   IF nullif(j.snapshot->>'resend_of','') is null AND EXISTS(SELECT 1 FROM public.sicoob_collection_dispatches WHERE collection_id=title.id
     AND NOT id::text IN (SELECT jsonb_array_elements_text(j.legacy_ids))) THEN
    RAISE EXCEPTION 'Há tentativa no histórico anterior. Verifique antes de cobrar.'; END IF;
   INSERT INTO public.hsn_send_locks(owner_id,resource,job_id) VALUES(p_owner,'collection:'||title.id,p_job);
   SELECT id INTO log_id FROM public.sicoob_collection_dispatches WHERE collection_id=title.id AND owner_id=p_owner;
   IF log_id IS NULL THEN
    INSERT INTO public.sicoob_collection_dispatches(owner_id,collection_id,status,recipient_email)
     VALUES(p_owner,title.id,'processing',j.snapshot->'to'->>0) RETURNING id INTO log_id;
   ELSE UPDATE public.sicoob_collection_dispatches SET status='processing' WHERE id=log_id AND owner_id=p_owner; END IF;
   mirror:=mirror||jsonb_build_array(log_id);
  END LOOP;
 ELSE
  INSERT INTO public.hsn_send_locks(owner_id,resource,job_id) VALUES(p_owner,'billing:'||j.fingerprint,p_job);
  IF jsonb_array_length(j.legacy_ids)=0 THEN
   INSERT INTO public.hsn_billing_dispatches(owner_id,request_id,company,reference,to_emails,cc_emails,subject,file_names,status)
   VALUES(p_owner,p_job,j.snapshot->>'company',j.fingerprint,
    array_to_string(ARRAY(SELECT jsonb_array_elements_text(j.snapshot->'to')),';'),
    array_to_string(ARRAY(SELECT jsonb_array_elements_text(j.snapshot->'cc')),';'),j.snapshot->>'subject',
    (SELECT jsonb_agg(jsonb_build_object('nome',value->>'name','tamanho',value->'size','tipo','documento')) FROM jsonb_array_elements(j.snapshot->'files')),'processing') RETURNING id INTO log_id;
   mirror:=jsonb_build_array(log_id);
  ELSE
   mirror:=j.legacy_ids;
   UPDATE public.hsn_billing_dispatches SET status='processing',subject=j.snapshot->>'subject',
    to_emails=array_to_string(ARRAY(SELECT jsonb_array_elements_text(j.snapshot->'to')),';'),
    cc_emails=array_to_string(ARRAY(SELECT jsonb_array_elements_text(j.snapshot->'cc')),';'),
    file_names=(SELECT jsonb_agg(jsonb_build_object('nome',value->>'name','tamanho',value->'size','tipo','documento')) FROM jsonb_array_elements(j.snapshot->'files'))
    WHERE owner_id=p_owner AND id::text IN (SELECT jsonb_array_elements_text(mirror));
  END IF;
 END IF;
 UPDATE public.hsn_send_jobs SET status='processing',legacy_ids=mirror,attempts=attempts+1,error_detail=NULL WHERE id=p_job;
 INSERT INTO public.hsn_send_attempts(job_id,owner_id,status) VALUES(p_job,p_owner,'processing');
 -- 6 segundos é o piso conservador; limites variam por conta/API.
 UPDATE public.hsn_send_throttle SET next_at=now()+interval '6 seconds' WHERE owner_id=p_owner;
 RETURN j.snapshot;
END $function$;

CREATE OR REPLACE FUNCTION public.hsn_send_finish(p_owner uuid, p_job uuid, p_status text, p_detail text, p_message text DEFAULT NULL::text, p_retry integer DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE j public.hsn_send_jobs;
BEGIN
 IF p_status NOT IN ('sent','failed','review') THEN RAISE EXCEPTION 'Situação inválida'; END IF;
 UPDATE public.hsn_send_jobs SET status=p_status,error_detail=left(p_detail,1500),message_id=p_message,
  sent_at=CASE WHEN p_status='sent' THEN now() ELSE NULL END,
  retry_after=CASE WHEN p_retry>0 THEN now()+make_interval(secs=>least(p_retry,86400)) ELSE NULL END
 WHERE id=p_job AND owner_id=p_owner AND status='processing';
 IF NOT FOUND THEN RAISE EXCEPTION 'Reserva não localizada'; END IF;
 SELECT * INTO j FROM public.hsn_send_jobs WHERE id=p_job AND owner_id=p_owner;
 IF j.kind='billing' THEN
  UPDATE public.hsn_billing_dispatches SET status=p_status,message_id=p_message,
   sent_at=CASE WHEN p_status='sent' THEN now() ELSE NULL END,error_detail=left(p_detail,1000)
   WHERE owner_id=p_owner AND id::text IN(SELECT jsonb_array_elements_text(j.legacy_ids));
 ELSE
  UPDATE public.sicoob_collection_dispatches SET status=CASE WHEN p_status='review' THEN 'failed' ELSE p_status END,
   sent_at=CASE WHEN p_status='sent' THEN now() ELSE NULL END
   WHERE owner_id=p_owner AND id::text IN(SELECT jsonb_array_elements_text(j.legacy_ids));
  IF p_status='sent' THEN
   UPDATE public.sicoob_collections SET status='sent',sent_at=now()
    WHERE owner_id=p_owner AND status='pending' AND id::text IN
     (SELECT value->>'id' FROM jsonb_array_elements(j.snapshot->'titles'));
  END IF;
 END IF;
 UPDATE public.hsn_send_attempts SET status=p_status,detail=left(p_detail,1500),finished_at=now(),updated_at=now() WHERE job_id=p_job AND owner_id=p_owner AND status='processing';
 IF NOT FOUND THEN RAISE EXCEPTION 'Tentativa em andamento não localizada'; END IF;
 IF p_status in ('sent','failed') THEN DELETE FROM public.hsn_send_locks WHERE job_id=p_job AND owner_id=p_owner; END IF;
END $function$;

revoke all on function public.hsn_send_claim(uuid,uuid,jsonb), public.hsn_send_finish(uuid,uuid,text,text,text,integer) from public,anon,authenticated;

grant execute on function public.hsn_send_claim(uuid,uuid,jsonb), public.hsn_send_finish(uuid,uuid,text,text,text,integer) to service_role;

create or replace function hsn_private.initialize_clone(p_owner uuid) returns void language plpgsql set search_path='' as $init$
begin
 if current_user<>'postgres' then raise exception 'Inicialize pelo SQL Editor como administrador';end if;
 if not exists(select 1 from auth.users where id=p_owner) then raise exception 'Crie primeiro o usuário em Authentication > Users';end if;
 if exists(select 1 from hsn_private.app_owner where user_id<>p_owner) then raise exception 'Outro proprietário já configurado; não substituído';end if;
 insert into hsn_private.app_owner(singleton,user_id) values(true,p_owner) on conflict(singleton) do nothing;
 insert into public.payable_alert_settings(owner_id) values(p_owner) on conflict(owner_id) do nothing;
 insert into public.commission_alert_settings(owner_id) values(p_owner) on conflict(owner_id) do nothing;
 insert into public.backup_settings(owner_id,weekly_enabled) values(p_owner,false) on conflict(owner_id) do nothing;
 insert into public.push_settings(owner_id,module) values(p_owner,'payables'),(p_owner,'commissions'),(p_owner,'dda') on conflict(owner_id,module) do nothing;
 insert into public.ui_preferences(owner_id) values(p_owner) on conflict(owner_id) do nothing;
end $init$;
revoke all on function hsn_private.initialize_clone(uuid) from public,anon,authenticated,service_role;
