-- HSN 10.0.1 — correção de legados pagos com valor zero/ausente.
-- Execute TODO este arquivo no SQL Editor DEPOIS de exportar o banco/Storage.
-- Migração aditiva, transacional e repetível; não elimina títulos/documentos.
begin;
do $$ begin
 if to_regclass('public.payables') is null or to_regclass('public.sicoob_collections') is null then
  raise exception 'Instale o esquema original do hotel antes da HSN 10.';
 end if;
end $$;
create table if not exists public.hsn10_migrations(version integer primary key, applied_at timestamptz not null default now());
revoke all on public.hsn10_migrations from public,anon,authenticated;
create table if not exists public.hsn10_backup (
 table_name text not null, record_id text not null, owner_id uuid, data jsonb not null,
 captured_at timestamptz not null default now(), primary key(table_name,record_id)
);
-- Cópia ANTES de qualquer alteração, inclusive contas já pagas sem data.
do $$ declare t text; begin
 if exists(select 1 from public.hsn10_migrations where version=10) then return;end if;
 foreach t in array array['payables','sicoob_collections','dda_charges','payable_documents','sicoob_collection_dispatches','hsn_billing_dispatches','suppliers','account_types'] loop
  if to_regclass('public.'||t) is not null then
   execute format('insert into public.hsn10_backup(table_name,record_id,owner_id,data) select %L,id::text,owner_id,to_jsonb(t) from public.%I t on conflict do nothing',t,t);
  end if;
 end loop;
end $$;
alter table public.dda_charges add column if not exists source_status text;
alter table public.dda_charges add column if not exists source_status_date date;
alter table public.payables add column if not exists paid_amount numeric(14,2);
alter table public.sicoob_collections add column if not exists paid_amount numeric(14,2);
alter table public.sicoob_collections add column if not exists paid_date date;
alter table public.sicoob_collections add column if not exists updated_at timestamptz not null default now();
alter table public.sicoob_collections add column if not exists cancelled_at timestamptz;
alter table public.sicoob_collections add column if not exists cancellation_reason text;
alter table public.sicoob_collections add column if not exists guest_name text not null default '';
alter table public.sicoob_collections add column if not exists stay_reference text not null default '';
alter table public.sicoob_collections add column if not exists check_in date;
alter table public.sicoob_collections add column if not exists check_out date;
alter table public.sicoob_collections add column if not exists nf_number text not null default '';
alter table public.sicoob_collections add column if not exists billing_documents jsonb not null default '{}';
alter table public.sicoob_collections add column if not exists required_billing_docs jsonb not null default '["extrato","voucher","nota_fiscal","boleto"]';
alter table public.sicoob_collections add column if not exists billing_sent_at timestamptz;
alter table public.sicoob_collections add column if not exists billing_send_reference text;
-- Não inventa data de pagamentos antigos. Sem data, ficam fora do caixa por período.
update public.payables set paid_amount=case when payment_status='paid' then coalesce(actual_amount,estimated_amount,0) else 0 end where paid_amount is null;
update public.sicoob_collections set paid_amount=case when status='paid' then amount else 0 end where paid_amount is null;
alter table public.payables alter column paid_amount set default 0;
alter table public.payables alter column paid_amount set not null;
alter table public.sicoob_collections alter column paid_amount set default 0;
alter table public.sicoob_collections alter column paid_amount set not null;
create table if not exists public.hsn10_events (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null,
 kind text not null check(kind in ('payable','receivable')), target_id uuid not null,
 amount numeric(14,2) not null check(amount>0), payment_date date,
 reference text not null, reason text not null, request_id uuid not null,
 bank_id uuid, reverses_id uuid references public.hsn10_events(id), legacy boolean not null default false,
 created_at timestamptz not null default now(), actor_id uuid,
 unique(owner_id,request_id), unique(reverses_id)
);
create index if not exists hsn10_events_target on public.hsn10_events(owner_id,kind,target_id);
create table if not exists public.hsn10_audit (
 id bigint generated always as identity primary key, owner_id uuid not null,
 table_name text not null, record_id uuid not null, action text not null,
 before_data jsonb, after_data jsonb, actor_id uuid, created_at timestamptz not null default now()
);
create table if not exists public.hsn10_import_batches (
 id uuid primary key, owner_id uuid not null, kind text not null, filename text not null,
 file_hash text not null, results jsonb not null, created_at timestamptz not null default now()
);
create table if not exists public.hsn10_bank_transactions (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null,
 account text not null, bank_reference text not null, transaction_date date not null,
 amount numeric(14,2) not null check(amount<>0), description text not null,
 settled boolean not null default false, source_file text not null,
 payment_id uuid references public.hsn10_events(id), created_at timestamptz not null default now(),
 unique(owner_id,account,bank_reference)
);
-- Importações antigas não passam a ser novos recebimentos. Uma abertura por título.
-- R$ 0,00 informado é preservado: não substituir por estimativa nem permitir baixa zero.
-- Legados sem valor positivo ficam no backup e em aviso de auditoria para conferência.
with opening as (
 select b.owner_id,b.table_name,b.record_id,b.data,
 case when b.table_name='payables' then 'payable' else 'receivable' end as kind,
 coalesce((b.data->>'paid_amount')::numeric,
   case when b.table_name='payables' then coalesce((b.data->>'actual_amount')::numeric,(b.data->>'estimated_amount')::numeric)
   else (b.data->>'amount')::numeric end) as opening_amount
 from public.hsn10_backup b where b.table_name in ('payables','sicoob_collections')
 and (b.data->>'payment_status'='paid' or b.data->>'status'='paid' or coalesce((b.data->>'paid_amount')::numeric,0)>0)
), migrated as (
 insert into public.hsn10_events(owner_id,kind,target_id,amount,payment_date,reference,reason,request_id,legacy)
 select o.owner_id,o.kind,o.record_id::uuid,o.opening_amount,
 nullif(o.data->>'paid_date','')::date,'Saldo anterior HSN 10','Baixa legada; conferir documentação e data original',gen_random_uuid(),true
 from opening o where o.opening_amount>0
 and not exists(select 1 from public.hsn10_events e where e.kind=o.kind and e.target_id=o.record_id::uuid and e.legacy)
 returning id
)
insert into public.hsn10_audit(owner_id,table_name,record_id,action,before_data,after_data,actor_id)
 select o.owner_id,o.table_name,o.record_id::uuid,'MIGRATION_REVIEW',o.data,o.data,auth.uid()
 from opening o where (o.opening_amount is null or o.opening_amount<=0)
 and not exists(select 1 from public.hsn10_audit a where a.owner_id=o.owner_id
   and a.table_name=o.table_name and a.record_id=o.record_id::uuid and a.action='MIGRATION_REVIEW');
create unique index if not exists hsn10_one_opening on public.hsn10_events(kind,target_id) where legacy;

-- RLS: browser lê somente os próprios registros. Escritas financeiras somente por RPC.
do $$ declare t text; begin
 foreach t in array array['hsn10_backup','hsn10_events','hsn10_audit','hsn10_import_batches','hsn10_bank_transactions'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon, authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('drop policy if exists hsn10_owner_read on public.%I',t);
  execute format('create policy hsn10_owner_read on public.%I for select to authenticated using(owner_id=auth.uid())',t);
 end loop;
end $$;

create or replace function public.hsn10_audit_change() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare j jsonb; begin
 j:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 insert into public.hsn10_audit(owner_id,table_name,record_id,action,before_data,after_data,actor_id)
 values((j->>'owner_id')::uuid,tg_table_name,(j->>'id')::uuid,tg_op,
 case when tg_op<>'INSERT' then to_jsonb(old) end,case when tg_op<>'DELETE' then to_jsonb(new) end,auth.uid());
 return coalesce(new,old);
end $$;
-- Protege também clientes antigos e funções existentes de baixa total.
create or replace function public.hsn10_guard_title() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare j jsonb; prev jsonb; total numeric; paid numeric; oldpaid numeric; ispaid boolean; cancelled boolean; k text; statekey text;
begin
 if tg_op='DELETE' then raise exception 'Preserve o histórico: cancele ou arquive o título.'; end if;
 j:=to_jsonb(new);prev:=case when tg_op='UPDATE' then to_jsonb(old) else '{}'::jsonb end;
 k:=case when tg_table_name='payables' then 'payable' else 'receivable' end;
 statekey:=case when k='payable' then 'payment_status' else 'status' end;
 total:=case when k='payable' then coalesce((j->>'actual_amount')::numeric,(j->>'estimated_amount')::numeric) else (j->>'amount')::numeric end;
 paid:=coalesce((j->>'paid_amount')::numeric,0);oldpaid:=coalesce((prev->>'paid_amount')::numeric,0);
 ispaid:=j->>statekey='paid';cancelled:=coalesce(j->>'workflow_status','')='cancelled' or j->>'cancelled_at' is not null;
 if total is null or total<0 or total>999999999999.99 then raise exception 'Valor total inválido.'; end if;
 if tg_op='UPDATE' and (j->>'owner_id' is distinct from prev->>'owner_id' or j->>'id' is distinct from prev->>'id') then raise exception 'Identidade do título não pode mudar.'; end if;
 if current_setting('hsn10.payment',true) is distinct from 'on' then
  if paid<>oldpaid and tg_op='UPDATE' then raise exception 'Use Registrar pagamento/recebimento ou Estornar no histórico.'; end if;
  if tg_op='INSERT' and paid<>0 then raise exception 'Cadastre o título antes de registrar recebimentos.'; end if;
  if tg_op='UPDATE' and oldpaid>0 and (j->>'actual_amount' is distinct from prev->>'actual_amount' or j->>'amount' is distinct from prev->>'amount' or j->>statekey is distinct from prev->>statekey and j->>statekey<>'sent') then
   raise exception 'Título com baixa: use estorno antes de mudar valor ou reabrir.';
  end if;
  if ispaid and (tg_op='INSERT' or prev->>statekey is distinct from 'paid') then
   if total<=0 or (j->>'paid_date') is null or (j->>'paid_date')::date>(now() at time zone 'America/Sao_Paulo')::date then raise exception 'Baixa exige valor positivo e data efetiva válida.'; end if;
   if k='payable' and tg_op='UPDATE' and (j->>'actual_amount') is distinct from (prev->>'actual_amount') then raise exception 'Não substitua a dívida pelo valor pago. Use pagamento parcial.'; end if;
   paid:=total;j:=j||jsonb_build_object('paid_amount',paid);
   insert into public.hsn10_events(owner_id,kind,target_id,amount,payment_date,reference,reason,request_id,actor_id)
   values((j->>'owner_id')::uuid,k,(j->>'id')::uuid,total-oldpaid,(j->>'paid_date')::date,'Baixa pelo módulo existente','Baixa total confirmada no módulo existente',gen_random_uuid(),auth.uid());
  end if;
 end if;
 if paid>0 and paid=total then j:=j||jsonb_build_object(statekey,'paid');end if;
 if paid<0 or paid>total then raise exception 'Pagamento excede o saldo ou cria saldo negativo.'; end if;
 if cancelled and paid>0 then raise exception 'Estorne os pagamentos antes de cancelar.'; end if;
 if k='receivable' then
  if tg_op='UPDATE' and prev->>'billing_sent_at' is not null and (j->'billing_documents' is distinct from prev->'billing_documents' or j->>'company' is distinct from prev->>'company' or j->>'guest_name' is distinct from prev->>'guest_name' or j->>'stay_reference' is distinct from prev->>'stay_reference' or j->>'check_in' is distinct from prev->>'check_in' or j->>'check_out' is distinct from prev->>'check_out' or j->>'nf_number' is distinct from prev->>'nf_number' or j->>'amount' is distinct from prev->>'amount') then
   j:=j||jsonb_build_object('billing_sent_at',null,'billing_send_reference',null);
  end if;
  if cancelled and j->>'status'='sent' and (tg_op='INSERT' or prev->>'status' is distinct from 'sent') then raise exception 'Título cancelado não pode ser cobrado.';end if;
  if tg_op='UPDATE' and oldpaid>0 and j->>'status'='sent' and prev->>'status' is distinct from 'sent' then raise exception 'Recebimento parcial/total: reenvio do valor original bloqueado.';end if;
  if j->>'check_in' is not null and j->>'check_out' is not null and (j->>'check_out')::date<(j->>'check_in')::date then raise exception 'Check-out anterior ao check-in.'; end if;
  if jsonb_typeof(j->'billing_documents')<>'object' or jsonb_typeof(j->'required_billing_docs')<>'array' then raise exception 'Documentos de faturamento inválidos.'; end if;
 end if;
 if tg_op='INSERT' then
  perform pg_advisory_xact_lock(hashtextextended((j->>'owner_id')||tg_table_name,0));
  if k='receivable' and exists(select 1 from public.sicoob_collections s where s.owner_id=(j->>'owner_id')::uuid and lower(trim(s.reference))=lower(trim(j->>'reference'))) then raise exception 'Referência já cadastrada, inclusive cancelada.';end if;
  if k='payable' and exists(select 1 from public.payables p where p.owner_id=(j->>'owner_id')::uuid and ((coalesce(j->>'barcode','')<>'' and p.barcode=j->>'barcode') or
   (p.supplier_id=(j->>'supplier_id')::uuid and p.due_date=(j->>'due_date')::date and coalesce(p.actual_amount,p.estimated_amount)=total and coalesce(p.document_number,'')=coalesce(j->>'document_number','')))) then raise exception 'Conta já cadastrada; confira fornecedor, documento, valor e vencimento.';end if;
 end if;
 if tg_op='UPDATE' then j:=j||jsonb_build_object('updated_at',clock_timestamp());end if;
 new:=jsonb_populate_record(new,j);return new;
end $$;

do $$ declare t text; begin
 foreach t in array array['payables','sicoob_collections'] loop
  execute format('drop trigger if exists hsn10_guard on public.%I',t);
  execute format('create trigger hsn10_guard before insert or update or delete on public.%I for each row execute function public.hsn10_guard_title()',t);
  execute format('drop trigger if exists hsn10_audit on public.%I',t);
  execute format('create trigger hsn10_audit after insert or update or delete on public.%I for each row execute function public.hsn10_audit_change()',t);
 end loop;
end $$;

do $$ declare t text; begin
 foreach t in array array['dda_charges','payable_documents','suppliers','account_types'] loop
  if to_regclass('public.'||t) is not null then
   execute format('drop trigger if exists hsn10_audit on public.%I',t);
   execute format('create trigger hsn10_audit after insert or update or delete on public.%I for each row execute function public.hsn10_audit_change()',t);
  end if;
 end loop;
end $$;

create or replace function public.hsn10_post_payment(p_kind text,p_target_id uuid,p_amount numeric,p_date date,p_reference text,p_request_id uuid,p_reason text,p_bank_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); t text; j jsonb; total numeric; paid numeric; eventid uuid; bank public.hsn10_bank_transactions; oldevent public.hsn10_events;
begin
 if uid is null then raise exception 'Autenticação necessária.';end if;
 if p_kind not in ('payable','receivable') then raise exception 'Tipo inválido.';end if;
 t:=case when p_kind='payable' then 'payables' else 'sicoob_collections' end;
 -- Serializa reenvios de uma mesma solicitação antes de ler a chave idempotente.
 perform pg_advisory_xact_lock(hashtextextended(uid::text||p_request_id::text,0));
 select * into oldevent from public.hsn10_events where owner_id=uid and request_id=p_request_id;
 if found then
  if oldevent.kind<>p_kind or oldevent.target_id<>p_target_id or oldevent.amount<>p_amount or oldevent.payment_date is distinct from p_date or oldevent.bank_id is distinct from p_bank_id then raise exception 'Solicitação já utilizada com dados diferentes.';end if;
  return oldevent.id;
 end if;
 if p_amount is null or p_amount<=0 or round(p_amount,2)<>p_amount or p_date is null or p_date>(now() at time zone 'America/Sao_Paulo')::date then raise exception 'Informe valor positivo com até 2 decimais e data efetiva até hoje.';end if;
 if length(trim(coalesce(p_reference,'')))<3 or length(trim(coalesce(p_reason,'')))<8 then raise exception 'Informe referência e motivo da confirmação.';end if;
 -- Ordem de locks: banco, depois título. Estorno segue a mesma ordem.
 if p_bank_id is not null then
  select * into bank from public.hsn10_bank_transactions where id=p_bank_id and owner_id=uid for update;
  if not found or bank.payment_id is not null or not bank.settled then raise exception 'Movimento indisponível, já conciliado ou sem liquidação confirmada.';end if;
  if (p_kind='receivable' and bank.amount<=0) or (p_kind='payable' and bank.amount>=0) or abs(bank.amount)<>p_amount or bank.transaction_date<>p_date then raise exception 'Direção, data ou valor divergente do extrato.';end if;
 end if;
 execute format('select to_jsonb(t) from public.%I t where id=$1 and owner_id=$2 for update',t) into j using p_target_id,uid;
 if j is null then raise exception 'Título não encontrado.';end if;
 if j->>'cancelled_at' is not null or j->>'workflow_status'='cancelled' or (j->>'archived')::boolean or j->>'workflow_status' in ('awaiting_signature','scheduled_signature') or j->>'approval_status'='waiting' then raise exception 'Título cancelado, arquivado ou aguardando autorização.';end if;
 total:=case when p_kind='payable' then (j->>'actual_amount')::numeric else (j->>'amount')::numeric end;
 paid:=(j->>'paid_amount')::numeric;
 if total is null then raise exception 'Confirme o valor real da conta antes da baixa.';end if;
 if exists(select 1 from public.hsn10_events e where e.owner_id=uid and e.kind=p_kind and e.target_id=p_target_id and e.reference=trim(p_reference) and e.payment_date=p_date and e.amount=p_amount and e.reverses_id is null and not exists(select 1 from public.hsn10_events x where x.reverses_id=e.id)) then raise exception 'Baixa com a mesma referência, data e valor já registrada. Confira o histórico.';end if;
 if p_amount>total-paid then raise exception 'Valor superior ao saldo pendente. Confira juros, descontos ou duplicidade.';end if;
 insert into public.hsn10_events(owner_id,kind,target_id,amount,payment_date,reference,reason,request_id,bank_id,actor_id)
 values(uid,p_kind,p_target_id,p_amount,p_date,trim(p_reference),trim(p_reason),p_request_id,p_bank_id,uid) returning id into eventid;
 perform set_config('hsn10.payment','on',true);
 if p_kind='payable' then
  update public.payables set paid_amount=paid+p_amount,payment_status=case when paid+p_amount=total then 'paid' else 'open' end,paid_date=case when paid+p_amount=total then p_date else null end where id=p_target_id and owner_id=uid;
 else
  update public.sicoob_collections set paid_amount=paid+p_amount,status=case when paid+p_amount=total then 'paid' else case when status='paid' then 'pending' else status end end,paid_date=case when paid+p_amount=total then p_date else null end where id=p_target_id and owner_id=uid;
 end if;
 perform set_config('hsn10.payment','off',true);
 if p_bank_id is not null then update public.hsn10_bank_transactions set payment_id=eventid where id=p_bank_id;end if;
 return eventid;
end $$;

create or replace function public.hsn10_reverse_payment(p_event_id uuid,p_date date,p_reason text,p_request_id uuid)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); e public.hsn10_events; oldevent public.hsn10_events; rid uuid; t text; j jsonb; remaining numeric;
begin
 if uid is null then raise exception 'Autenticação necessária.';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||p_request_id::text,0));
 select * into oldevent from public.hsn10_events where owner_id=uid and request_id=p_request_id;
 if found then if oldevent.reverses_id is distinct from p_event_id or oldevent.payment_date is distinct from p_date then raise exception 'Solicitação já utilizada.';end if;return oldevent.id;end if;
 select * into e from public.hsn10_events where id=p_event_id and owner_id=uid;
 if not found or e.reverses_id is not null then raise exception 'Pagamento não localizado.';end if;
 if p_date is null or p_date<e.payment_date or p_date>(now() at time zone 'America/Sao_Paulo')::date or length(trim(coalesce(p_reason,'')))<8 then raise exception 'Informe data válida e motivo do estorno (mínimo 8 caracteres).';end if;
 if e.bank_id is not null then perform 1 from public.hsn10_bank_transactions where id=e.bank_id and owner_id=uid for update;end if;
 t:=case when e.kind='payable' then 'payables' else 'sicoob_collections' end;
 execute format('select to_jsonb(t) from public.%I t where id=$1 and owner_id=$2 for update',t) into j using e.target_id,uid;
 if j is null or exists(select 1 from public.hsn10_events where reverses_id=e.id) then raise exception 'Baixa já estornada ou título ausente.';end if;
 remaining:=(j->>'paid_amount')::numeric-e.amount;if remaining<0 then raise exception 'Saldo inconsistente; confira histórico antes do estorno.';end if;
 insert into public.hsn10_events(owner_id,kind,target_id,amount,payment_date,reference,reason,request_id,reverses_id,actor_id)
 values(uid,e.kind,e.target_id,e.amount,p_date,e.reference,trim(p_reason),p_request_id,e.id,uid) returning id into rid;
 perform set_config('hsn10.payment','on',true);
 if e.kind='payable' then update public.payables set paid_amount=remaining,payment_status='open',paid_date=null where id=e.target_id and owner_id=uid;
 else update public.sicoob_collections set paid_amount=remaining,status=case when sent_at is not null then 'sent' else 'pending' end,paid_date=null where id=e.target_id and owner_id=uid;end if;
 perform set_config('hsn10.payment','off',true);
 if e.bank_id is not null then update public.hsn10_bank_transactions set payment_id=null where id=e.bank_id and owner_id=uid;end if;
 return rid;
end $$;

-- Escrita do título e hospedagem em um só registro; Sicoob continua a fonte da dívida.
create or replace function public.hsn10_save_receivable(p_id uuid,p_expected_updated_at timestamptz,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); j jsonb; new_id uuid; v numeric;
begin
 if uid is null then raise exception 'Autenticação necessária.';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||'receivables',0));
 if length(trim(coalesce(p_data->>'company','')))=0 or length(trim(coalesce(p_data->>'reference','')))=0 then raise exception 'Informe empresa/hóspede e referência única.';end if;
 v:=(p_data->>'amount')::numeric;
 if v is null or v<=0 or v<>round(v,2) or nullif(p_data->>'due_date','')::date is null then raise exception 'Informe valor positivo e vencimento.';end if;
 if exists(select 1 from public.sicoob_collections where owner_id=uid and lower(trim(reference))=lower(trim(p_data->>'reference')) and (p_id is null or id<>p_id)) then raise exception 'Referência já cadastrada. Abra a cobrança existente.';end if;
 if p_id is not null then
  select to_jsonb(s) into j from public.sicoob_collections s where id=p_id and owner_id=uid for update;
  if j is null or (j->>'updated_at')::timestamptz is distinct from p_expected_updated_at then raise exception 'Título alterado em outro aparelho. Atualize antes de salvar.';end if;
  if (j->>'paid_amount')::numeric>0 and v<>(j->>'amount')::numeric then raise exception 'Estorne as baixas antes de mudar o valor original.';end if;
  update public.sicoob_collections set company=trim(p_data->>'company'),reference=trim(p_data->>'reference'),external_reference=coalesce(p_data->>'external_reference',''),amount=v,due_date=(p_data->>'due_date')::date,
   guest_name=coalesce(p_data->>'guest_name',''),stay_reference=coalesce(p_data->>'stay_reference',''),check_in=nullif(p_data->>'check_in','')::date,check_out=nullif(p_data->>'check_out','')::date,
   nf_number=coalesce(p_data->>'nf_number',''),billing_documents=coalesce(p_data->'billing_documents','{}'::jsonb)
   where id=p_id and owner_id=uid;return p_id;
 else
  insert into public.sicoob_collections(owner_id,company,reference,external_reference,amount,due_date,status,guest_name,stay_reference,check_in,check_out,nf_number,billing_documents)
   values(uid,trim(p_data->>'company'),trim(p_data->>'reference'),coalesce(p_data->>'external_reference',''),v,(p_data->>'due_date')::date,'pending',coalesce(p_data->>'guest_name',''),coalesce(p_data->>'stay_reference',''),nullif(p_data->>'check_in','')::date,nullif(p_data->>'check_out','')::date,coalesce(p_data->>'nf_number',''),coalesce(p_data->'billing_documents','{}'::jsonb)) returning id into new_id;
  return new_id;
 end if;
end $$;
create or replace function public.hsn10_cancel_receivable(p_id uuid,p_expected_updated_at timestamptz,p_reason text,p_restore boolean default false)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or length(trim(coalesce(p_reason,'')))<8 then raise exception 'Informe motivo com pelo menos 8 caracteres.';end if;
 update public.sicoob_collections set cancelled_at=case when p_restore then null else now() end,cancellation_reason=p_reason
 where id=p_id and owner_id=auth.uid() and updated_at=p_expected_updated_at and paid_amount=0;
 if not found then raise exception 'Título alterado ou com recebimentos. Atualize/estorne antes de cancelar.';end if;
end $$;

create or replace function public.hsn10_mark_billing_sent(p_id uuid,p_expected_updated_at timestamptz,p_reference text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.sicoob_collections; doc text;
begin
 select * into r from public.sicoob_collections where id=p_id and owner_id=auth.uid() for update;
 if not found or r.updated_at is distinct from p_expected_updated_at or r.cancelled_at is not null then raise exception 'Título indisponível/alterado.';end if;
 if length(trim(r.guest_name))=0 or length(trim(r.stay_reference))=0 or r.check_in is null or r.check_out is null or length(trim(coalesce(p_reference,'')))<8 then raise exception 'Complete hospedagem e referência do envio confirmado.';end if;
 for doc in select jsonb_array_elements_text(r.required_billing_docs) loop
  if length(trim(coalesce(r.billing_documents->>doc,'')))=0 then raise exception 'Documento faltante: %',doc;end if;
 end loop;
 update public.sicoob_collections set billing_sent_at=now(),billing_send_reference=p_reference where id=p_id and owner_id=auth.uid();
end $$;

-- Lote com resultado persistente por linha; chaves de negócio serializadas por dono.
create or replace function public.hsn10_commit_import(p_batch_id uuid,p_kind text,p_filename text,p_file_hash text,p_rows jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); prior public.hsn10_import_batches; r jsonb; d jsonb; results jsonb:='[]'; status text; msg text; rid uuid; oldrow jsonb; countrows integer; ref text; amt numeric; dt date;
begin
 if uid is null then raise exception 'Autenticação necessária.';end if;
 if p_kind not in ('receivable','payable','dda','bank') then raise exception 'Destino inválido.';end if;
 if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>2000 then raise exception 'Lote inválido ou acima de 2000 linhas.';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||'imports',0));
 select * into prior from public.hsn10_import_batches where id=p_batch_id and owner_id=uid;
 if found then if prior.file_hash<>p_file_hash or prior.kind<>p_kind then raise exception 'Lote já utilizado com outro arquivo.';end if;return prior.results;end if;
 for r in select value from jsonb_array_elements(p_rows) loop
  rid:=null;status:='ignored';msg:=coalesce(r->>'message','Não selecionada na conferência.');d:=r->'payload';
  begin
   if coalesce((r->>'selected')::boolean,false) then
    if d is null or jsonb_typeof(d)<>'object' then raise exception 'Linha sem dados válidos.';end if;
    if p_kind='receivable' then
     ref:=trim(d->>'reference');
     select count(*) into countrows from public.sicoob_collections where owner_id=uid and lower(trim(reference))=lower(ref);
     if countrows>0 then
      select to_jsonb(s) into oldrow from public.sicoob_collections s where owner_id=uid and lower(trim(reference))=lower(ref) limit 1;
      if countrows<>1 or (oldrow->>'amount')::numeric<>(d->>'amount')::numeric or oldrow->>'due_date'<>d->>'due_date' or lower(trim(oldrow->>'company'))<>lower(trim(d->>'company')) or coalesce(oldrow->>'external_reference','')<>coalesce(d->>'external_reference','') then raise exception 'Referência existente com dados divergentes. Edite o título existente.';end if;
      rid:=(oldrow->>'id')::uuid;msg:='Já existente; preservado.';
     else rid:=public.hsn10_save_receivable(null,null,d);status:='imported';msg:='Título importado como pendente; não confirma recebimento.';end if;
    elsif p_kind='bank' then
     ref:=trim(d->>'bank_reference');amt:=(d->>'amount')::numeric;dt:=(d->>'transaction_date')::date;
     if length(trim(coalesce(d->>'account','')))<3 or length(coalesce(ref,''))<3 or amt is null or amt=0 or amt<>round(amt,2) or dt is null then raise exception 'Conta, referência bancária estável, data e valor são obrigatórios.';end if;
     select to_jsonb(b) into oldrow from public.hsn10_bank_transactions b where owner_id=uid and account=d->>'account' and bank_reference=ref;
     if oldrow is not null then
      if (oldrow->>'amount')::numeric<>amt or oldrow->>'transaction_date'<>dt::text then raise exception 'Referência bancária existente com valor/data divergente.';end if;
      rid:=(oldrow->>'id')::uuid;msg:='Movimento já importado.';
     else
      insert into public.hsn10_bank_transactions(owner_id,account,bank_reference,transaction_date,amount,description,settled,source_file)
       values(uid,trim(d->>'account'),ref,dt,amt,coalesce(d->>'description',''),coalesce((d->>'settled')::boolean,false),p_filename) returning id into rid;
      status:='imported';msg:='Movimento importado; sem baixa automática.';
     end if;
    else
     -- Payloads já mapeados pelos importadores existentes. Pagamentos só no livro de baixas.
     if coalesce(d->>'payment_status','open')<>'open' then raise exception 'Importe a obrigação e registre a baixa separadamente.';end if;
     amt:=coalesce((d->>'actual_amount')::numeric,(d->>'amount')::numeric,(d->>'estimated_amount')::numeric);dt:=(d->>'due_date')::date;
     if amt is null or amt<=0 or amt<>round(amt,2) or dt is null then raise exception 'Valor/data inválidos.';end if;
     if p_kind='payable' then
      select to_jsonb(p) into oldrow from public.payables p where owner_id=uid and (
       (coalesce(d->>'barcode','')<>'' and barcode=d->>'barcode') or
       (supplier_id=(d->>'supplier_id')::uuid and ((coalesce(d->>'document_number','')<>'' and document_number=d->>'document_number' and due_date=dt) or
       (due_date=dt and coalesce(actual_amount,estimated_amount)=amt and coalesce(document_number,'')=coalesce(d->>'document_number','') and title=d->>'title')))) limit 1;
      if oldrow is null then
       insert into public.payables(owner_id,title,supplier_id,type_id,competence,original_due_date,due_date,due_rule,estimated_amount,actual_amount,document_number,barcode,notes,payment_status,workflow_status,workflow_note,bank_scheduled_date,required_documents)
        values(uid,d->>'title',(d->>'supplier_id')::uuid,(d->>'type_id')::uuid,(d->>'competence')::date,coalesce(nullif(d->>'original_due_date','')::date,dt),dt,coalesce(d->>'due_rule','keep'),coalesce((d->>'estimated_amount')::numeric,amt),(d->>'actual_amount')::numeric,coalesce(d->>'document_number',''),coalesce(d->>'barcode',''),coalesce(d->>'notes',''),'open',coalesce(d->>'workflow_status','pending'),coalesce(d->>'workflow_note',''),nullif(d->>'bank_scheduled_date','')::date,(jsonb_populate_record(null::public.payables,jsonb_build_object('required_documents',coalesce(d->'required_documents','["boleto"]'::jsonb)))).required_documents) returning id into rid;
       status:='imported';msg:='Conta importada sem baixa.';
      end if;
     else
      select to_jsonb(c) into oldrow from public.dda_charges c where owner_id=uid and ((coalesce(d->>'barcode','')<>'' and barcode=d->>'barcode') or (due_date=dt and amount=amt and lower(trim(supplier_name))=lower(trim(d->>'supplier_name')) and coalesce(document_number,'')=coalesce(d->>'document_number',''))) limit 1;
      if oldrow is null then
       insert into public.dda_charges(owner_id,title,supplier_name,tax_id,amount,due_date,document_number,barcode,notes,source_file)
        values(uid,d->>'title',d->>'supplier_name',coalesce(d->>'tax_id',''),amt,dt,coalesce(d->>'document_number',''),coalesce(d->>'barcode',''),coalesce(d->>'notes',''),p_filename) returning id into rid;
       if d->>'source_status' in ('paid','scheduled','open') then update public.dda_charges set source_status=d->>'source_status',source_status_date=nullif(d->>'source_status_date','')::date where id=rid and owner_id=uid;end if;
       status:='imported';msg:='DDA importado sem baixa.';
      end if;
     end if;
     if oldrow is not null then
      rid:=(oldrow->>'id')::uuid;msg:='Registro já existente, inclusive arquivado/cancelado; preservado.';
      if p_kind='dda' and d->>'source_status' in ('paid','scheduled','open') then
       update public.dda_charges set source_status=d->>'source_status',source_status_date=nullif(d->>'source_status_date','')::date,source_file=p_filename where id=rid and owner_id=uid;
       msg:='DDA existente: situação de origem atualizada; sem baixa financeira.';
      end if;
     end if;
    end if;
   elsif r->>'outcome'='error' then status:='error';end if;
  exception when others then status:='error';msg:=sqlerrm;
  end;
  results:=results||jsonb_build_array(jsonb_build_object('line',r->'line','status',status,'message',msg,'id',rid));
 end loop;
 insert into public.hsn10_import_batches(id,owner_id,kind,filename,file_hash,results) values(p_batch_id,uid,p_kind,p_filename,p_file_hash,results);
 return results;
end $$;

-- Exportação integral dos dados financeiros do proprietário, incluindo o novo livro.
-- Conteúdo dos PDFs/imagens deve ser exportado pelo fluxo de documentos existente.
create or replace function public.hsn10_export_backup() returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); tables jsonb:='{}'; rows jsonb; t text;
begin
 if uid is null then raise exception 'Autenticação necessária.';end if;
 foreach t in array array['payables','recurring_models','suppliers','account_types','local_holidays','payable_documents','message_templates','commissions','commission_reviews','dda_charges','sicoob_collections','sicoob_contacts','sicoob_collection_dispatches','hsn_billing_recipients','hsn_billing_dispatches','hsn_send_jobs','hsn10_events','hsn10_audit','hsn10_import_batches','hsn10_bank_transactions','hsn10_backup'] loop
  if to_regclass('public.'||t) is not null then
   execute format('select coalesce(jsonb_agg(to_jsonb(t)),''[]''::jsonb) from public.%I t where owner_id=$1',t) into rows using uid;
   tables:=tables||jsonb_build_object(t,rows);
  end if;
 end loop;
 return jsonb_build_object('version',10,'exported_at',now(),'owner_id',uid,'tables',tables,'documents_note','Metadados incluídos; exporte também os arquivos do bucket privado hsn-documentos.');
end $$;
revoke all on function public.hsn10_export_backup() from public,anon;
grant execute on function public.hsn10_export_backup() to authenticated;

-- Funcões SECURITY DEFINER não ficam disponíveis ao papel público.
revoke all on function public.hsn10_audit_change(),public.hsn10_guard_title() from public,anon,authenticated;
revoke all on function public.hsn10_post_payment(text,uuid,numeric,date,text,uuid,text,uuid),public.hsn10_reverse_payment(uuid,date,text,uuid),public.hsn10_save_receivable(uuid,timestamptz,jsonb),public.hsn10_cancel_receivable(uuid,timestamptz,text,boolean),public.hsn10_mark_billing_sent(uuid,timestamptz,text),public.hsn10_commit_import(uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.hsn10_post_payment(text,uuid,numeric,date,text,uuid,text,uuid),public.hsn10_reverse_payment(uuid,date,text,uuid),public.hsn10_save_receivable(uuid,timestamptz,jsonb),public.hsn10_cancel_receivable(uuid,timestamptz,text,boolean),public.hsn10_mark_billing_sent(uuid,timestamptz,text),public.hsn10_commit_import(uuid,text,text,text,jsonb) to authenticated;
insert into public.hsn10_migrations(version) values(10) on conflict do nothing;
commit;

-- Resultado de conferência, sem excluir ou alterar os valores da conta de origem.
select table_name as tabela,record_id as registro,
 before_data->>'title' as descricao,before_data->>'company' as empresa,
 coalesce(before_data->>'actual_amount',before_data->>'amount',before_data->>'estimated_amount') as valor_original,
 before_data->>'paid_amount' as valor_baixado_anterior,
 'Legado marcado como pago sem valor positivo. Dados preservados; nenhuma baixa criada. Conferir documentos.' as orientacao
 from public.hsn10_audit where action='MIGRATION_REVIEW'
 order by table_name,record_id;
