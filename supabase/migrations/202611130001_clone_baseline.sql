-- Estrutura recuperada do banco real em 13/11/2026. Sem dados de clientes ou credenciais.

-- Executar exclusivamente em projeto novo, vazio. Inclui a integridade financeira da versão 10.

set check_function_bodies = off;

do $guard$ begin if to_regclass('public.payables') is not null then raise exception 'Este instalador exige um projeto vazio. Nenhuma tabela existente foi substituída.'; end if; end $guard$;

create schema if not exists hsn_private;

revoke all on schema hsn_private from public, anon;

grant usage on schema hsn_private to authenticated, service_role;

create table hsn_private."app_owner" (
 "singleton" boolean default true not null,
 "user_id" uuid not null
);

create table hsn_private."push_run_guard" (
 "owner_id" uuid not null,
 "kind" text not null,
 "token" uuid not null,
 "started_at" timestamp with time zone not null,
 "lease_until" timestamp with time zone not null
);

create table public."account_types" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "name" text not null,
 "color" text default '#2563eb'::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."audit_log" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "table_name" text not null,
 "record_id" uuid not null,
 "action" text not null,
 "changed_fields" text[] default '{}'::text[] not null,
 "old_data" jsonb,
 "new_data" jsonb,
 "actor_id" uuid,
 "created_at" timestamp with time zone default now() not null
);

create table public."backup_settings" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "weekly_enabled" boolean default true not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."backup_snapshots" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "kind" text not null,
 "week_start" date not null,
 "payload" jsonb not null,
 "record_count" bigint not null,
 "document_count" bigint not null,
 "created_at" timestamp with time zone default now() not null
);

create table public."commission_alert_settings" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "lead_days" integer[] default ARRAY[7, 3, 1, 0] not null,
 "daily_summary" boolean default true not null,
 "monthly_reminder" boolean default true not null,
 "review_day" integer default 5 not null,
 "checklist_template" text[] default ARRAY['Conferir reservas e competências'::text, 'Conferir percentuais e bases de cálculo'::text, 'Conferir cancelamentos e no-shows'::text, 'Conferir divergências com a agência'::text, 'Registrar conclusão da conferência'::text] not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."commission_reviews" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "competence" date not null,
 "checklist" jsonb not null,
 "review_status" text default 'open'::text not null,
 "completed_date" date,
 "notes" text default ''::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."commissions" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "title" text not null,
 "agency_name" text not null,
 "supplier_id" uuid,
 "competence" date not null,
 "due_date" date not null,
 "amount" numeric(14,2) default 0 not null,
 "document_number" text default ''::text not null,
 "review_status" text default 'pending'::text not null,
 "confirmed_date" date,
 "notes" text default ''::text not null,
 "archived" boolean default false not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."dda_charges" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "title" text not null,
 "supplier_name" text not null,
 "tax_id" text default ''::text not null,
 "supplier_id" uuid,
 "amount" numeric(14,2) not null,
 "due_date" date not null,
 "document_number" text default ''::text not null,
 "barcode" text default ''::text not null,
 "reviewed" boolean default false not null,
 "reviewed_date" date,
 "converted_payable_id" uuid,
 "source_file" text default ''::text not null,
 "notes" text default ''::text not null,
 "archived" boolean default false not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null,
 "source_status" text,
 "source_status_date" date
);

create table public."hsn10_audit" (
 "id" bigint generated always as identity not null,
 "owner_id" uuid not null,
 "table_name" text not null,
 "record_id" uuid not null,
 "action" text not null,
 "before_data" jsonb,
 "after_data" jsonb,
 "actor_id" uuid,
 "created_at" timestamp with time zone default now() not null
);

create table public."hsn10_backup" (
 "table_name" text not null,
 "record_id" text not null,
 "owner_id" uuid,
 "data" jsonb not null,
 "captured_at" timestamp with time zone default now() not null
);

create table public."hsn10_bank_transactions" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "account" text not null,
 "bank_reference" text not null,
 "transaction_date" date not null,
 "amount" numeric(14,2) not null,
 "description" text not null,
 "settled" boolean default false not null,
 "source_file" text not null,
 "payment_id" uuid,
 "created_at" timestamp with time zone default now() not null
);

create table public."hsn10_events" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "kind" text not null,
 "target_id" uuid not null,
 "amount" numeric(14,2) not null,
 "payment_date" date,
 "reference" text not null,
 "reason" text not null,
 "request_id" uuid not null,
 "bank_id" uuid,
 "reverses_id" uuid,
 "legacy" boolean default false not null,
 "created_at" timestamp with time zone default now() not null,
 "actor_id" uuid
);

create table public."hsn10_import_batches" (
 "id" uuid not null,
 "owner_id" uuid not null,
 "kind" text not null,
 "filename" text not null,
 "file_hash" text not null,
 "results" jsonb not null,
 "created_at" timestamp with time zone default now() not null
);

create table public."hsn10_migrations" (
 "version" integer not null,
 "applied_at" timestamp with time zone default now() not null
);

create table public."hsn_billing_dispatches" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "request_id" uuid not null,
 "company" text not null,
 "reference" text not null,
 "to_emails" text not null,
 "cc_emails" text default ''::text not null,
 "subject" text not null,
 "file_names" jsonb default '[]'::jsonb not null,
 "status" text not null,
 "message_id" text,
 "error_detail" text,
 "created_at" timestamp with time zone default now() not null,
 "sent_at" timestamp with time zone
);

create table public."hsn_billing_recipients" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "company" text not null,
 "to_emails" text not null,
 "cc_emails" text default ''::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."hsn_communication_followups" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "company" text not null,
 "email" text default ''::text not null,
 "subject" text default ''::text not null,
 "note" text not null,
 "status" text default 'pending'::text not null,
 "source" text default 'manual'::text not null,
 "zoho_message_id" text,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."hsn_communication_links" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "billing_dispatch_id" uuid not null,
 "sicoob_collection_id" uuid not null,
 "note" text default ''::text not null,
 "created_at" timestamp with time zone default now() not null
);

create table public."hsn_send_attempts" (
 "id" uuid default gen_random_uuid() not null,
 "job_id" uuid not null,
 "owner_id" uuid not null,
 "status" text not null,
 "detail" text default ''::text not null,
 "created_at" timestamp with time zone default now() not null
);

create table public."hsn_send_contacts" (
 "owner_id" uuid not null,
 "email" text not null,
 "display_name" text default ''::text not null,
 "companies" text[] default '{}'::text[] not null
);

create table public."hsn_send_jobs" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "kind" text not null,
 "fingerprint" text not null,
 "status" text default 'prepared'::text not null,
 "snapshot" jsonb not null,
 "legacy_ids" jsonb default '[]'::jsonb not null,
 "attempts" integer default 0 not null,
 "message_id" text,
 "error_detail" text,
 "retry_after" timestamp with time zone,
 "created_at" timestamp with time zone default now() not null,
 "sent_at" timestamp with time zone
);

create table public."hsn_send_locks" (
 "owner_id" uuid not null,
 "resource" text not null,
 "job_id" uuid not null
);

create table public."hsn_send_templates" (
 "owner_id" uuid not null,
 "code" text not null,
 "title" text not null,
 "subject" text not null,
 "body" text not null
);

create table public."hsn_send_throttle" (
 "owner_id" uuid not null,
 "next_at" timestamp with time zone not null
);

create table public."local_holidays" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "name" text not null,
 "holiday_date" date not null,
 "annually" boolean default false not null,
 "scope" text default 'municipal'::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."message_templates" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "title" text not null,
 "body" text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."payable_alert_settings" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "lead_days" integer[] default ARRAY[7, 3, 1, 0] not null,
 "variation_percent" numeric(6,2) default 30 not null,
 "daily_summary" boolean default true not null,
 "missing_documents" boolean default true not null,
 "missing_bill" boolean default true not null,
 "waiting_approval" boolean default true not null,
 "variation_alert" boolean default true not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."payable_documents" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "payable_id" uuid not null,
 "competence" date not null,
 "document_type" text not null,
 "storage_path" text not null,
 "original_name" text not null,
 "mime_type" text not null,
 "size_bytes" bigint not null,
 "created_at" timestamp with time zone default now() not null
);

create table public."payables" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "model_id" uuid,
 "supplier_id" uuid not null,
 "type_id" uuid not null,
 "title" text not null,
 "competence" date not null,
 "original_due_date" date not null,
 "due_date" date not null,
 "due_rule" text default 'keep'::text not null,
 "estimated_amount" numeric(14,2) default 0 not null,
 "actual_amount" numeric(14,2),
 "payment_status" text default 'open'::text not null,
 "paid_date" date,
 "archived" boolean default false not null,
 "required_documents" text[] default ARRAY['boleto'::text] not null,
 "arrival_day" integer,
 "barcode" text default ''::text not null,
 "issuing_bank" text default ''::text not null,
 "document_number" text default ''::text not null,
 "approval_status" text default 'not_required'::text not null,
 "approval_note" text default ''::text not null,
 "notes" text default ''::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null,
 "workflow_status" text default 'pending'::text not null,
 "workflow_note" text default ''::text not null,
 "bank_scheduled_date" date,
 "workflow_updated_at" timestamp with time zone,
 "paid_amount" numeric(14,2) default 0 not null
);

create table public."push_deliveries" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "subscription_id" uuid not null,
 "module" text not null,
 "kind" text not null,
 "send_date" date not null,
 "dedupe_key" text not null,
 "state" text default 'sending'::text not null,
 "attempts" integer default 1 not null,
 "lease_token" uuid default gen_random_uuid() not null,
 "lease_until" timestamp with time zone default (now() + '00:03:00'::interval) not null,
 "next_retry_at" timestamp with time zone,
 "status_code" integer,
 "error_note" text default ''::text not null,
 "accepted_at" timestamp with time zone,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."push_settings" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "module" text not null,
 "enabled" boolean default false not null,
 "send_hour" integer default 8 not null,
 "send_minute" integer default 0 not null,
 "include_week" boolean default true not null,
 "notify_empty" boolean default false not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."push_subscriptions" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "endpoint" text not null,
 "p256dh" text not null,
 "auth_key" text not null,
 "vapid_public_key" text not null,
 "device_name" text not null,
 "enabled" boolean default true not null,
 "payables" boolean default true not null,
 "commissions" boolean default true not null,
 "dda" boolean default true not null,
 "last_accepted_at" timestamp with time zone,
 "last_failure" text default ''::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."recurring_models" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "title" text not null,
 "supplier_id" uuid not null,
 "type_id" uuid not null,
 "due_day" integer not null,
 "estimated_amount" numeric(14,2) default 0 not null,
 "due_rule" text default 'keep'::text not null,
 "first_month" date not null,
 "last_month" date,
 "arrival_day" integer,
 "required_documents" text[] default ARRAY['boleto'::text] not null,
 "active" boolean default true not null,
 "notes" text default ''::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null,
 "contract_adjustment_date" date,
 "contract_notice_days" integer default 30 not null
);

create table public."sicoob_collection_dispatches" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "collection_id" uuid not null,
 "status" text default 'processing'::text not null,
 "recipient_email" text not null,
 "sent_at" timestamp with time zone,
 "created_at" timestamp with time zone default now() not null
);

create table public."sicoob_collections" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "company" text not null,
 "reference" text not null,
 "external_reference" text,
 "due_date" date not null,
 "amount" numeric(12,2) not null,
 "status" text default 'pending'::text not null,
 "sent_at" timestamp with time zone,
 "created_at" timestamp with time zone default now() not null,
 "paid_amount" numeric(14,2) default 0 not null,
 "paid_date" date,
 "updated_at" timestamp with time zone default now() not null,
 "cancelled_at" timestamp with time zone,
 "cancellation_reason" text,
 "guest_name" text default ''::text not null,
 "stay_reference" text default ''::text not null,
 "check_in" date,
 "check_out" date,
 "nf_number" text default ''::text not null,
 "billing_documents" jsonb default '{}'::jsonb not null,
 "required_billing_docs" jsonb default '["extrato", "voucher", "nota_fiscal", "boleto"]'::jsonb not null,
 "billing_sent_at" timestamp with time zone,
 "billing_send_reference" text
);

create table public."sicoob_contacts" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid not null,
 "company" text not null,
 "email" text not null
);

create table public."suppliers" (
 "id" uuid default gen_random_uuid() not null,
 "owner_id" uuid default auth.uid() not null,
 "legal_name" text not null,
 "trade_name" text default ''::text not null,
 "tax_id" text default ''::text not null,
 "service_type" text default ''::text not null,
 "contacts" jsonb default '[]'::jsonb not null,
 "postal_code" text default ''::text not null,
 "street" text default ''::text not null,
 "address_number" text default ''::text not null,
 "complement" text default ''::text not null,
 "neighborhood" text default ''::text not null,
 "city" text default ''::text not null,
 "state" text default ''::text not null,
 "bank" text default ''::text not null,
 "bank_branch" text default ''::text not null,
 "bank_account" text default ''::text not null,
 "pix_key" text default ''::text not null,
 "notes" text default ''::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."ui_preferences" (
 "owner_id" uuid default auth.uid() not null,
 "theme" text default 'system'::text not null,
 "created_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."zoho_mail_tokens" (
 "user_id" uuid not null,
 "refresh_token" text not null,
 "account_id" text,
 "connected_at" timestamp with time zone default now() not null,
 "updated_at" timestamp with time zone default now() not null
);

create table public."zoho_oauth_states" (
 "state_hash" text not null,
 "user_id" uuid not null,
 "expires_at" timestamp with time zone not null,
 "used_at" timestamp with time zone,
 "created_at" timestamp with time zone default now() not null
);

CREATE OR REPLACE FUNCTION hsn_private.validate_dda_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin
 if old.converted_payable_id is not null and
 (to_jsonb(new)-'archived'-'updated_at')<>(to_jsonb(old)-'archived'-'updated_at')
 then raise exception 'DDA já convertido. Edite a conta a pagar vinculada';end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.validate_monthly_review()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin
 if new.review_status='completed' and exists(select 1 from jsonb_array_elements(new.checklist) item where item->>'checked'<>'true')
 then raise exception 'Marque todos os itens antes de concluir a conferência';end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.valid_lead_days(days integer[])
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 select days is not null and cardinality(days) between 1 and 20
 and not exists(select 1 from unnest(days) d where d is null or d<0 or d>365);
$function$;

CREATE OR REPLACE FUNCTION hsn_private.valid_checklist(items jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$ declare item jsonb; begin
 if items is null or jsonb_typeof(items)<>'array' then return false;end if;
 if jsonb_array_length(items)<1 or jsonb_array_length(items)>30 then return false;end if;
 for item in select value from jsonb_array_elements(items) loop
 if jsonb_typeof(item)<>'object' or jsonb_typeof(item->'text') is distinct from 'string'
 or length(trim(item->>'text')) not between 1 and 250
 or jsonb_typeof(item->'checked') is distinct from 'boolean' then return false;end if;
 end loop;return true;
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.is_owner()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from hsn_private.app_owner
    where user_id = (select auth.uid())
  );
$function$;

CREATE OR REPLACE FUNCTION hsn_private.touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION hsn_private.validate_document()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin
 if not exists(select 1 from public.payables p where p.id=new.payable_id and p.owner_id=new.owner_id and p.competence=new.competence)
 then raise exception 'Competência do documento diferente da conta'; end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='hsn-documentos' and o.name=new.storage_path)
 then raise exception 'Envie o arquivo ao Storage antes de registrar o documento'; end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.easter(y integer)
 RETURNS date
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare a integer; b integer; c integer; d integer; e integer; f integer; g integer; h integer; i integer; k integer; l integer; m integer; mm integer; dd integer;
begin
 a:=y%19;b:=y/100;c:=y%100;d:=b/4;e:=b%4;f:=(b+8)/25;g:=(b-f+1)/3;
 h:=(19*a+b-d-g+15)%30;i:=c/4;k:=c%4;l:=(32+2*e+2*i-h-k)%7;m:=(a+11*h+22*l)/451;
 mm:=(h+l-7*m+114)/31;dd:=((h+l-7*m+114)%31)+1;
 return make_date(y,mm,dd);
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.is_business_day(d date)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select extract(isodow from d)<6
 and to_char(d,'MM-DD') not in ('01-01','04-21','05-01','09-07','10-12','11-02','11-15','12-25')
 and not (extract(year from d)>=2024 and to_char(d,'MM-DD')='11-20')
 and d not in (hsn_private.easter(extract(year from d)::integer)-48,hsn_private.easter(extract(year from d)::integer)-47,hsn_private.easter(extract(year from d)::integer)-2,hsn_private.easter(extract(year from d)::integer)+60)
 and not exists(select 1 from public.local_holidays h where h.owner_id=(select auth.uid()) and
  (h.holiday_date=d or (h.annually and to_char(h.holiday_date,'MM-DD')=to_char(d,'MM-DD'))));
$function$;

CREATE OR REPLACE FUNCTION hsn_private.adjust_due(d date, rule text)
 RETURNS date
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare result date:=d; steps integer:=0;
begin
 if rule='keep' then return d; end if;
 if rule not in ('before','after') then raise exception 'Regra inválida'; end if;
 while not hsn_private.is_business_day(result) loop
 result:=result+case when rule='before' then -1 else 1 end;steps:=steps+1;
 if steps>370 then raise exception 'Não foi possível encontrar dia útil';end if;
 end loop;return result;
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.validate_payable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN

  -- Impede alterar a competência de contas com anexos
  IF TG_OP = 'UPDATE'
     AND NEW.competence <> OLD.competence
     AND EXISTS (
       SELECT 1
       FROM public.payable_documents
       WHERE payable_id = OLD.id
     )
  THEN
    RAISE EXCEPTION
      'Conta com anexos não pode mudar de competência';
  END IF;

  -- Comprovante passa a ser opcional
  RETURN NEW;

END;
$function$;

CREATE OR REPLACE FUNCTION hsn_private.audit_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare before_row jsonb;after_row jsonb;row_owner uuid;row_id uuid;changed text[];
begin
 if TG_OP<>'INSERT' then before_row=to_jsonb(old);end if;
 if TG_OP<>'DELETE' then after_row=to_jsonb(new);end if;
 row_owner=coalesce(after_row->>'owner_id',before_row->>'owner_id')::uuid;
 row_id=coalesce(after_row->>'id',before_row->>'id',after_row->>'owner_id',before_row->>'owner_id')::uuid;
 if TG_OP='UPDATE' then
  select coalesce(array_agg(k order by k),'{}'::text[]) into changed
  from (select jsonb_object_keys(before_row||after_row) as k) keys
  where k<>'updated_at' and before_row->k is distinct from after_row->k;
  if cardinality(changed)=0 then return new;end if;
 else
  select array_agg(k order by k) into changed from jsonb_object_keys(coalesce(after_row,before_row)) k;
 end if;
 insert into public.audit_log(owner_id,table_name,record_id,action,changed_fields,old_data,new_data,actor_id)
 values(row_owner,TG_TABLE_NAME,row_id,TG_OP,changed,before_row,after_row,auth.uid());
 if TG_OP='DELETE' then return old;else return new;end if;
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.weekly_backup()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare o uuid;begin
 for o in select b.owner_id from public.backup_settings b join hsn_private.app_owner a on a.user_id=b.owner_id where b.weekly_enabled loop
 perform hsn_private.take_backup(o,'weekly');
 end loop;
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.take_backup(p_owner uuid, p_kind text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t text;parts text[]='{}';q text;document jsonb;result uuid;wk date;
begin
 if p_owner is null or not exists(select 1 from hsn_private.app_owner where user_id=p_owner)
 then raise exception 'Proprietário inválido';end if;
 if p_kind not in ('manual','weekly') or p_kind is null then raise exception 'Tipo de backup inválido';end if;
 -- Serializa geração entre aparelhos e o cron para este proprietário.
 perform pg_advisory_xact_lock(hashtextextended(p_owner::text,5));
 wk=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
 if p_kind='weekly' then
  select id into result from public.backup_snapshots where owner_id=p_owner and kind='weekly' and week_start=wk;
  if found then return result;end if;
 end if;
 foreach t in array array['account_types','suppliers','message_templates','local_holidays','recurring_models','payables','payable_documents','payable_alert_settings','commission_alert_settings','commissions','commission_reviews','ui_preferences','dda_charges','backup_settings','push_settings','audit_log'] loop
 parts=array_append(parts,format('%L, (select coalesce(jsonb_agg(to_jsonb(r)),''[]''::jsonb) from public.%I r where owner_id=$1)',t,t));
 end loop;
 q='select jsonb_build_object(''format'',''financeiro-hsn-backup'',''schema_version'',6,''owner_id'',$1,''created_at'',now(),''timezone'',''America/Sao_Paulo'',''date_fields'',''YYYY-MM-DD, sem horário'',''tables'',jsonb_build_object('||array_to_string(parts,',')||'),''storage_objects'',(select coalesce(jsonb_agg(jsonb_build_object(''path'',name,''size_bytes'',coalesce((metadata->>''size'')::bigint,0),''mime_type'',metadata->>''mimetype'',''created_at'',created_at)),''[]''::jsonb) from storage.objects where bucket_id=''hsn-documentos'' and split_part(name,''/'',1)=$1::text))';
 execute q into document using p_owner;
 insert into public.backup_snapshots(owner_id,kind,week_start,payload,record_count,document_count)
 values(p_owner,p_kind,wk,document,
 (select coalesce(sum(jsonb_array_length(value)),0) from jsonb_each(document->'tables')),
 jsonb_array_length(document->'storage_objects')) returning id into result;
 return result;
end $function$;

CREATE OR REPLACE FUNCTION hsn_private.request_push_run()
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare credential text;request_id bigint;begin
 select decrypted_secret into credential from vault.decrypted_secrets where name='hsn_push_cron_key' order by created_at desc limit 1;
 if credential is null or length(credential)<40 then raise exception 'Segredo do agendamento não configurado';end if;
 select net.http_post(
 url:=(select value from hsn_private.clone_configuration where key='supabase_url')||'/functions/v1/hsn-push',
 headers:=jsonb_build_object('Content-Type','application/json','x-hsn-cron-key',credential),
 body:='{"action":"scheduled"}'::jsonb,timeout_milliseconds:=60000) into request_id;
 return request_id;
end $function$;

CREATE OR REPLACE FUNCTION public.convert_dda_to_payable(p_id uuid, p_expected_updated_at timestamp with time zone, p_supplier_id uuid, p_type_id uuid, p_competence date, p_due_rule text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare charge public.dda_charges; result uuid;
begin
 if not hsn_private.is_owner() then raise exception 'Acesso negado';end if;
 select * into charge from public.dda_charges where id=p_id for update;
 if not found then raise exception 'Cobrança não encontrada';end if;
 if charge.updated_at is distinct from p_expected_updated_at then raise exception 'Cobrança mudou. Atualize antes de converter';end if;
 if charge.archived then raise exception 'Restaure a cobrança antes de converter';end if;
 if not charge.reviewed then raise exception 'Confira o DDA antes de converter';end if;
 if charge.converted_payable_id is not null then raise exception 'Cobrança já convertida';end if;
 if p_competence is null or extract(day from p_competence)<>1 then raise exception 'Competência inválida';end if;
 if p_supplier_id is null or p_type_id is null then raise exception 'Informe fornecedor e tipo';end if;
 if p_due_rule not in ('keep','before','after') or p_due_rule is null then raise exception 'Regra de vencimento inválida';end if;
 insert into public.payables(owner_id,supplier_id,type_id,title,competence,original_due_date,due_date,due_rule,estimated_amount,actual_amount,document_number,barcode,notes)
 values((select auth.uid()),p_supplier_id,p_type_id,charge.title,p_competence,charge.due_date,hsn_private.adjust_due(charge.due_date,p_due_rule),p_due_rule,charge.amount,charge.amount,charge.document_number,charge.barcode,
 'Convertida do DDA '||charge.id::text||case when charge.notes<>'' then E'\n'||charge.notes else '' end)
 returning id into result;
 update public.dda_charges set supplier_id=p_supplier_id,converted_payable_id=result where id=charge.id;
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.create_hsn_backup()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ begin
 if not hsn_private.is_owner() then raise exception 'Acesso negado';end if;
 return hsn_private.take_backup(auth.uid(),'manual');
end $function$;

CREATE OR REPLACE FUNCTION public.generate_recurring_month(p_month date, p_preview jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ declare total integer; current_preview jsonb; expected_preview jsonb;
begin
 if not hsn_private.is_owner() then raise exception 'Acesso negado';end if;
 if p_month is null or extract(day from p_month)<>1 then raise exception 'Use o primeiro dia da competência';end if;
 if p_preview is null or jsonb_typeof(p_preview)<>'array' then raise exception 'Prévia obrigatória';end if;
 -- Impede alteração concorrente entre a conferência e a geração.
 lock table public.local_holidays,public.recurring_models,public.payables in share row exclusive mode;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.model_id::text),'[]'::jsonb)
 into current_preview from public.preview_recurring_month(p_month) r;
 select coalesce(jsonb_agg(value order by value->>'model_id'),'[]'::jsonb)
 into expected_preview from jsonb_array_elements(p_preview);
 if current_preview<>expected_preview then raise exception 'A prévia mudou. Confira novamente antes de confirmar';end if;
 insert into public.payables(owner_id,model_id,supplier_id,type_id,title,competence,original_due_date,due_date,estimated_amount,required_documents,arrival_day,due_rule)
 select (select auth.uid()),r.model_id,r.supplier_id,r.type_id,r.title,r.competence,r.original_due_date,r.due_date,r.estimated_amount,r.required_documents,r.arrival_day,r.due_rule
 from public.preview_recurring_month(p_month) r
 on conflict(model_id,competence) do nothing;
 get diagnostics total=row_count; return total;
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_audit_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare j jsonb; begin
 j:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 insert into public.hsn10_audit(owner_id,table_name,record_id,action,before_data,after_data,actor_id)
 values((j->>'owner_id')::uuid,tg_table_name,(j->>'id')::uuid,tg_op,
 case when tg_op<>'INSERT' then to_jsonb(old) end,case when tg_op<>'DELETE' then to_jsonb(new) end,auth.uid());
 return coalesce(new,old);
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_cancel_receivable(p_id uuid, p_expected_updated_at timestamp with time zone, p_reason text, p_restore boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
 if auth.uid() is null or length(trim(coalesce(p_reason,'')))<8 then raise exception 'Informe motivo com pelo menos 8 caracteres.';end if;
 update public.sicoob_collections set cancelled_at=case when p_restore then null else now() end,cancellation_reason=p_reason
 where id=p_id and owner_id=auth.uid() and updated_at=p_expected_updated_at and paid_amount=0;
 if not found then raise exception 'Título alterado ou com recebimentos. Atualize/estorne antes de cancelar.';end if;
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_commit_import(p_batch_id uuid, p_kind text, p_filename text, p_file_hash text, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_export_backup()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_guard_title()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_mark_billing_sent(p_id uuid, p_expected_updated_at timestamp with time zone, p_reference text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare r public.sicoob_collections; doc text;
begin
 select * into r from public.sicoob_collections where id=p_id and owner_id=auth.uid() for update;
 if not found or r.updated_at is distinct from p_expected_updated_at or r.cancelled_at is not null then raise exception 'Título indisponível/alterado.';end if;
 if length(trim(r.guest_name))=0 or length(trim(r.stay_reference))=0 or r.check_in is null or r.check_out is null or length(trim(coalesce(p_reference,'')))<8 then raise exception 'Complete hospedagem e referência do envio confirmado.';end if;
 for doc in select jsonb_array_elements_text(r.required_billing_docs) loop
  if length(trim(coalesce(r.billing_documents->>doc,'')))=0 then raise exception 'Documento faltante: %',doc;end if;
 end loop;
 update public.sicoob_collections set billing_sent_at=now(),billing_send_reference=p_reference where id=p_id and owner_id=auth.uid();
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_post_payment(p_kind text, p_target_id uuid, p_amount numeric, p_date date, p_reference text, p_request_id uuid, p_reason text, p_bank_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_reverse_payment(p_event_id uuid, p_date date, p_reason text, p_request_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.hsn10_save_receivable(p_id uuid, p_expected_updated_at timestamp with time zone, p_data jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.hsn_backup_schedule_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare active_job boolean=false;begin
 if not hsn_private.is_owner() then raise exception 'Acesso negado';end if;
 if to_regclass('cron.job') is not null then
 execute 'select coalesce(bool_or(active and schedule=''0 7 * * 0''),false) from cron.job where jobname=''hsn-weekly-backup''' into active_job;
 end if;
 active_job=active_job and coalesce(current_setting('cron.timezone',true),'GMT') in ('GMT','UTC','Etc/UTC');
 return jsonb_build_object('installed',active_job,'schedule','Domingo, 04:00 (America/Sao_Paulo; 07:00 UTC)');
end $function$;

CREATE OR REPLACE FUNCTION public.hsn_collection_send_claim(p_owner uuid, p_job uuid, p_snapshot jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 v_job public.hsn_send_jobs%rowtype;
 v_title jsonb;
 v_row public.sicoob_collections%rowtype;
 v_result jsonb;
 v_source text;
begin
 -- Uma trava por operador serializa a reserva de títulos em jobs sobrepostos.
 perform pg_advisory_xact_lock(hashtextextended('hsn-collection:'||p_owner::text,0));
 select * into strict v_job from public.hsn_send_jobs where id=p_job and owner_id=p_owner for update;
 if v_job.kind<>'collection' or v_job.snapshot is distinct from p_snapshot then
  raise exception 'Prévia alterada ou operação inválida';
 end if;
 for v_title in select value from jsonb_array_elements(p_snapshot->'titles') loop
  select * into strict v_row from public.sicoob_collections
   where id=(v_title->>'id')::uuid and owner_id=p_owner for update;
  if v_row.status not in ('pending','sent') then raise exception 'Título pago ou cancelado'; end if;
  if exists(select 1 from public.hsn_send_jobs j
   where j.owner_id=p_owner and j.kind='collection' and j.id<>p_job
    and j.status in ('processing','review')
    and j.snapshot->'titles' @> jsonb_build_array(jsonb_build_object('id',v_title->>'id'))) then
   raise exception 'Existe tentativa em processamento ou a conferir';
  end if;
  select j.id::text into v_source from public.hsn_send_jobs j
   where j.owner_id=p_owner and j.kind='collection' and j.status='sent'
    and j.snapshot->'titles' @> jsonb_build_array(jsonb_build_object('id',v_title->>'id'))
   order by j.created_at desc limit 1;
  if v_source is not null and v_source is distinct from p_snapshot->>'resend_of' then
   raise exception 'Houve um novo envio; refaça a prévia';
  end if;
 end loop;
 select public.hsn_send_claim(p_owner,p_job,p_snapshot) into v_result;
 return v_result;
end $function$;

CREATE OR REPLACE FUNCTION public.hsn_communication_validate_link()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.owner_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Usuário da vinculação não autorizado';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.hsn_billing_dispatches b
    WHERE b.id = NEW.billing_dispatch_id AND b.owner_id = NEW.owner_id AND b.status = 'sent'
  ) THEN RAISE EXCEPTION 'Faturamento enviado não localizado para este usuário'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.sicoob_collections s
    WHERE s.id = NEW.sicoob_collection_id AND s.owner_id = NEW.owner_id
  ) THEN RAISE EXCEPTION 'Título Sicoob não localizado para este usuário'; END IF;
  RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION public.hsn_push_begin(p_owner uuid, p_kind text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare r uuid;begin
 if p_kind not in ('test','scheduled') or not exists(select 1 from hsn_private.app_owner where user_id=p_owner)
 then raise exception 'Solicitação inválida';end if;
 insert into hsn_private.push_run_guard(owner_id,kind,token,started_at,lease_until)
 values(p_owner,p_kind,gen_random_uuid(),now(),now()+interval '2 minutes')
 on conflict(owner_id,kind) do update set token=excluded.token,started_at=excluded.started_at,lease_until=excluded.lease_until
 where hsn_private.push_run_guard.started_at<now()-interval '30 seconds' and hsn_private.push_run_guard.lease_until<now()
 returning token into r;return r;
end $function$;

CREATE OR REPLACE FUNCTION public.hsn_push_claim(p_subscription uuid, p_module text, p_kind text, p_key text, p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare u uuid;r public.push_deliveries;begin
 if p_module not in ('payables','commissions','dda') or p_kind not in ('daily','test')
 or p_key is null or length(p_key) not between 1 and 100 then raise exception 'Dados de envio inválidos';end if;
 select owner_id into u from public.push_subscriptions s where id=p_subscription and enabled
 and case p_module when 'payables' then s.payables when 'commissions' then s.commissions else s.dda end;
 if not found then return null;end if;
 if p_kind='daily' and not exists(select 1 from public.push_settings where owner_id=u and module=p_module and enabled) then return null;end if;
 insert into public.push_deliveries(owner_id,subscription_id,module,kind,send_date,dedupe_key)
 values(u,p_subscription,p_module,p_kind,p_date,p_key)
 on conflict(subscription_id,module,kind,dedupe_key) do update set state='sending',attempts=public.push_deliveries.attempts+1,
 lease_token=gen_random_uuid(),lease_until=now()+interval '3 minutes',updated_at=now()
 where public.push_deliveries.attempts<3 and
 ((public.push_deliveries.state='failed' and public.push_deliveries.next_retry_at<=now()) or
 (public.push_deliveries.state='sending' and public.push_deliveries.lease_until<now()))
 returning * into r;
 if r.id is null then return null;end if;
 return jsonb_build_object('id',r.id,'token',r.lease_token);
end $function$;

CREATE OR REPLACE FUNCTION public.hsn_push_context(p_owner uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object('settings',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.push_settings r where owner_id=p_owner),
 'subscriptions',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.push_subscriptions r where owner_id=p_owner and enabled),
 'payables',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.payables r where owner_id=p_owner),
 'documents',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.payable_documents r where owner_id=p_owner),
 'payable_settings',(select to_jsonb(r) from public.payable_alert_settings r where owner_id=p_owner),
 'commissions',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.commissions r where owner_id=p_owner),
 'reviews',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.commission_reviews r where owner_id=p_owner),
 'commission_settings',(select to_jsonb(r) from public.commission_alert_settings r where owner_id=p_owner),
 'models',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.recurring_models r where owner_id=p_owner),
 'dda',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.dda_charges r where owner_id=p_owner));
$function$;

CREATE OR REPLACE FUNCTION public.hsn_push_end(p_token uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 update hsn_private.push_run_guard set lease_until=now() where token=p_token;
$function$;

CREATE OR REPLACE FUNCTION public.hsn_push_finish(p_id uuid, p_token uuid, p_status integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare r public.push_deliveries;accepted boolean;expired boolean;note text;begin
 accepted=p_status between 200 and 299;expired=p_status in (404,410,409);
 accepted=coalesce(accepted,false);expired=coalesce(expired,false);
 note=case when accepted then '' when p_status=409 then 'Chave alterada. Reative este aparelho.' when expired then 'Inscrição expirada. Reative este aparelho.' when p_status=0 then 'Falha de rede ou tempo excedido.' else 'Serviço push retornou HTTP '||coalesce(p_status::text,'desconhecido') end;
 update public.push_deliveries set state=case when accepted then 'accepted' when expired then 'expired' else 'failed' end,
 status_code=p_status,error_note=note,accepted_at=case when accepted then now() end,
 next_retry_at=case when not accepted and not expired then now()+interval '5 minutes' end,updated_at=now()
 where id=p_id and lease_token=p_token and state='sending' returning * into r;
 if r.id is null then return false;end if;
 update public.push_subscriptions set enabled=case when expired then false else enabled end,
 last_accepted_at=case when accepted then now() else last_accepted_at end,last_failure=note where id=r.subscription_id;
 return true;
end $function$;

CREATE OR REPLACE FUNCTION public.hsn_push_owner()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select user_id from hsn_private.app_owner limit 1;
$function$;

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
   IF NOT FOUND OR title.status<>'pending' OR title.due_date::date>=day_br OR
     title.company IS DISTINCT FROM r->>'company' OR title.amount::numeric IS DISTINCT FROM (r->>'amount')::numeric OR
     title.external_reference IS DISTINCT FROM r->>'external_reference' OR title.due_date::text IS DISTINCT FROM r->>'due_date'
   THEN RAISE EXCEPTION 'Título pago, alterado, ausente ou não vencido. Refaça a conferência.'; END IF;
   IF EXISTS(SELECT 1 FROM public.sicoob_collection_dispatches WHERE collection_id=title.id
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
 INSERT INTO public.hsn_send_attempts(job_id,owner_id,status,detail) VALUES(p_job,p_owner,p_status,left(p_detail,1500));
 IF p_status='failed' THEN DELETE FROM public.hsn_send_locks WHERE job_id=p_job AND owner_id=p_owner; END IF;
END $function$;

CREATE OR REPLACE FUNCTION public.preview_recurring_month(p_month date)
 RETURNS TABLE(model_id uuid, supplier_id uuid, type_id uuid, title text, competence date, original_due_date date, due_date date, estimated_amount numeric, required_documents text[], arrival_day integer, due_rule text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select m.id,m.supplier_id,m.type_id,m.title,p_month,
 p_month+(least(m.due_day,extract(day from (p_month+interval '1 month - 1 day'))::integer)-1),
 hsn_private.adjust_due(p_month+(least(m.due_day,extract(day from (p_month+interval '1 month - 1 day'))::integer)-1),m.due_rule),
 coalesce((select round(avg(h.actual_amount),2) from
  (select p.actual_amount from public.payables p where p.model_id=m.id and p.payment_status='paid'
   and not p.archived and p.competence<p_month order by p.competence desc limit 3) h),m.estimated_amount),
 m.required_documents,m.arrival_day,m.due_rule
 from public.recurring_models m
 where hsn_private.is_owner() and extract(day from p_month)=1 and m.active
 and m.first_month<=p_month and (m.last_month is null or m.last_month>=p_month)
 and not exists(select 1 from public.payables p where p.model_id=m.id and p.competence=p_month);
$function$;

CREATE OR REPLACE FUNCTION public.register_hsn_push(p_endpoint text, p_p256dh text, p_auth text, p_vapid text, p_device_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare r uuid;u uuid=auth.uid();begin
 if not hsn_private.is_owner() then raise exception 'Acesso negado';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,6));
 if not exists(select 1 from public.push_subscriptions where endpoint=p_endpoint and owner_id=u and enabled)
 and (select count(*) from public.push_subscriptions where owner_id=u and enabled)>=5
 then raise exception 'Limite de 5 aparelhos ativos. Desative um antes de cadastrar outro';end if;
 insert into public.push_subscriptions(owner_id,endpoint,p256dh,auth_key,vapid_public_key,device_name)
 values(u,p_endpoint,p_p256dh,p_auth,p_vapid,trim(p_device_name))
 on conflict(endpoint) do update set p256dh=excluded.p256dh,auth_key=excluded.auth_key,vapid_public_key=excluded.vapid_public_key,
 device_name=excluded.device_name,enabled=true,last_failure=''
 where public.push_subscriptions.owner_id=u returning id into r;
 if r is null then raise exception 'Inscrição não pertence ao proprietário';end if;
 return r;
end $function$;

CREATE OR REPLACE FUNCTION public.set_hsn_push_device(p_id uuid, p_enabled boolean, p_payables boolean, p_commissions boolean, p_dda boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare u uuid=auth.uid();begin
 if not hsn_private.is_owner() then raise exception 'Acesso negado';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,6));
 if p_enabled is null or p_payables is null or p_commissions is null or p_dda is null then raise exception 'Preferências inválidas';end if;
 if p_enabled and not exists(select 1 from public.push_subscriptions where id=p_id and owner_id=u and enabled)
 and (select count(*) from public.push_subscriptions where owner_id=u and enabled)>=5
 then raise exception 'Limite de 5 aparelhos ativos';end if;
 update public.push_subscriptions set enabled=p_enabled,payables=p_payables,commissions=p_commissions,dda=p_dda
 where id=p_id and owner_id=u;
 if not found then raise exception 'Aparelho não encontrado';end if;
end $function$;

create table hsn_private.clone_configuration(key text primary key, value text not null);

alter table hsn_private.clone_configuration enable row level security;

revoke all on hsn_private.clone_configuration from public, anon, authenticated;

alter table hsn_private."app_owner" add constraint "app_owner_pkey" PRIMARY KEY (singleton);

alter table hsn_private."push_run_guard" add constraint "push_run_guard_pkey" PRIMARY KEY (owner_id, kind);

alter table public."account_types" add constraint "account_types_pkey" PRIMARY KEY (id);

alter table public."audit_log" add constraint "audit_log_pkey" PRIMARY KEY (id);

alter table public."backup_settings" add constraint "backup_settings_pkey" PRIMARY KEY (id);

alter table public."backup_snapshots" add constraint "backup_snapshots_pkey" PRIMARY KEY (id);

alter table public."commission_alert_settings" add constraint "commission_alert_settings_pkey" PRIMARY KEY (id);

alter table public."commission_reviews" add constraint "commission_reviews_pkey" PRIMARY KEY (id);

alter table public."commissions" add constraint "commissions_pkey" PRIMARY KEY (id);

alter table public."dda_charges" add constraint "dda_charges_pkey" PRIMARY KEY (id);

alter table public."hsn10_audit" add constraint "hsn10_audit_pkey" PRIMARY KEY (id);

alter table public."hsn10_backup" add constraint "hsn10_backup_pkey" PRIMARY KEY (table_name, record_id);

alter table public."hsn10_bank_transactions" add constraint "hsn10_bank_transactions_pkey" PRIMARY KEY (id);

alter table public."hsn10_events" add constraint "hsn10_events_pkey" PRIMARY KEY (id);

alter table public."hsn10_import_batches" add constraint "hsn10_import_batches_pkey" PRIMARY KEY (id);

alter table public."hsn10_migrations" add constraint "hsn10_migrations_pkey" PRIMARY KEY (version);

alter table public."hsn_billing_dispatches" add constraint "hsn_billing_dispatches_pkey" PRIMARY KEY (id);

alter table public."hsn_billing_recipients" add constraint "hsn_billing_recipients_pkey" PRIMARY KEY (id);

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_pkey" PRIMARY KEY (id);

alter table public."hsn_communication_links" add constraint "hsn_communication_links_pkey" PRIMARY KEY (id);

alter table public."hsn_send_attempts" add constraint "hsn_send_attempts_pkey" PRIMARY KEY (id);

alter table public."hsn_send_contacts" add constraint "hsn_send_contacts_pkey" PRIMARY KEY (owner_id, email);

alter table public."hsn_send_jobs" add constraint "hsn_send_jobs_pkey" PRIMARY KEY (id);

alter table public."hsn_send_locks" add constraint "hsn_send_locks_pkey" PRIMARY KEY (owner_id, resource);

alter table public."hsn_send_templates" add constraint "hsn_send_templates_pkey" PRIMARY KEY (owner_id, code);

alter table public."hsn_send_throttle" add constraint "hsn_send_throttle_pkey" PRIMARY KEY (owner_id);

alter table public."local_holidays" add constraint "local_holidays_pkey" PRIMARY KEY (id);

alter table public."message_templates" add constraint "message_templates_pkey" PRIMARY KEY (id);

alter table public."payable_alert_settings" add constraint "payable_alert_settings_pkey" PRIMARY KEY (id);

alter table public."payable_documents" add constraint "payable_documents_pkey" PRIMARY KEY (id);

alter table public."payables" add constraint "payables_pkey" PRIMARY KEY (id);

alter table public."push_deliveries" add constraint "push_deliveries_pkey" PRIMARY KEY (id);

alter table public."push_settings" add constraint "push_settings_pkey" PRIMARY KEY (id);

alter table public."push_subscriptions" add constraint "push_subscriptions_pkey" PRIMARY KEY (id);

alter table public."recurring_models" add constraint "recurring_models_pkey" PRIMARY KEY (id);

alter table public."sicoob_collection_dispatches" add constraint "sicoob_collection_dispatches_pkey" PRIMARY KEY (id);

alter table public."sicoob_collections" add constraint "sicoob_collections_pkey" PRIMARY KEY (id);

alter table public."sicoob_contacts" add constraint "sicoob_contacts_pkey" PRIMARY KEY (id);

alter table public."suppliers" add constraint "suppliers_pkey" PRIMARY KEY (id);

alter table public."ui_preferences" add constraint "ui_preferences_pkey" PRIMARY KEY (owner_id);

alter table public."zoho_mail_tokens" add constraint "zoho_mail_tokens_pkey" PRIMARY KEY (user_id);

alter table public."zoho_oauth_states" add constraint "zoho_oauth_states_pkey" PRIMARY KEY (state_hash);

alter table hsn_private."app_owner" add constraint "app_owner_user_id_key" UNIQUE (user_id);

alter table public."account_types" add constraint "account_types_id_owner_id_key" UNIQUE (id, owner_id);

alter table public."backup_settings" add constraint "backup_settings_owner_id_key" UNIQUE (owner_id);

alter table public."commission_alert_settings" add constraint "commission_alert_settings_owner_id_key" UNIQUE (owner_id);

alter table public."commission_reviews" add constraint "commission_reviews_owner_id_competence_key" UNIQUE (owner_id, competence);

alter table public."dda_charges" add constraint "dda_charges_converted_payable_id_key" UNIQUE (converted_payable_id);

alter table public."hsn10_bank_transactions" add constraint "hsn10_bank_transactions_owner_id_account_bank_reference_key" UNIQUE (owner_id, account, bank_reference);

alter table public."hsn10_events" add constraint "hsn10_events_owner_id_request_id_key" UNIQUE (owner_id, request_id);

alter table public."hsn10_events" add constraint "hsn10_events_reverses_id_key" UNIQUE (reverses_id);

alter table public."hsn_billing_dispatches" add constraint "hsn_billing_dispatches_owner_id_request_id_key" UNIQUE (owner_id, request_id);

alter table public."hsn_billing_recipients" add constraint "hsn_billing_recipients_owner_id_company_key" UNIQUE (owner_id, company);

alter table public."hsn_communication_links" add constraint "hsn_communication_links_owner_id_billing_dispatch_id_sicoob_key" UNIQUE (owner_id, billing_dispatch_id, sicoob_collection_id);

alter table public."hsn_send_jobs" add constraint "hsn_send_jobs_owner_id_kind_fingerprint_key" UNIQUE (owner_id, kind, fingerprint);

alter table public."payable_alert_settings" add constraint "payable_alert_settings_owner_id_key" UNIQUE (owner_id);

alter table public."payable_documents" add constraint "payable_documents_storage_path_key" UNIQUE (storage_path);

alter table public."payables" add constraint "payables_id_owner_id_key" UNIQUE (id, owner_id);

alter table public."payables" add constraint "payables_model_id_competence_key" UNIQUE (model_id, competence);

alter table public."push_deliveries" add constraint "push_deliveries_subscription_id_module_kind_dedupe_key_key" UNIQUE (subscription_id, module, kind, dedupe_key);

alter table public."push_settings" add constraint "push_settings_owner_id_module_key" UNIQUE (owner_id, module);

alter table public."push_subscriptions" add constraint "push_subscriptions_endpoint_key" UNIQUE (endpoint);

alter table public."push_subscriptions" add constraint "push_subscriptions_id_owner_id_key" UNIQUE (id, owner_id);

alter table public."recurring_models" add constraint "recurring_models_id_owner_id_key" UNIQUE (id, owner_id);

alter table public."sicoob_collection_dispatches" add constraint "sicoob_collection_dispatches_collection_id_key" UNIQUE (collection_id);

alter table public."sicoob_collections" add constraint "sicoob_collections_owner_id_reference_due_date_key" UNIQUE (owner_id, reference, due_date);

alter table public."sicoob_contacts" add constraint "sicoob_contacts_owner_id_company_key" UNIQUE (owner_id, company);

alter table public."suppliers" add constraint "suppliers_id_owner_id_key" UNIQUE (id, owner_id);

alter table hsn_private."app_owner" add constraint "app_owner_singleton_check" CHECK (singleton);

alter table hsn_private."push_run_guard" add constraint "push_run_guard_kind_check" CHECK (kind = ANY (ARRAY['test'::text, 'scheduled'::text]));

alter table public."account_types" add constraint "account_types_color_check" CHECK (color ~ '^#[0-9a-fA-F]{6}$'::text);

alter table public."account_types" add constraint "account_types_name_check" CHECK (length(TRIM(BOTH FROM name)) >= 1 AND length(TRIM(BOTH FROM name)) <= 80);

alter table public."audit_log" add constraint "audit_log_action_check" CHECK (action = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text]));

alter table public."backup_snapshots" add constraint "backup_snapshots_kind_check" CHECK (kind = ANY (ARRAY['manual'::text, 'weekly'::text]));

alter table public."commission_alert_settings" add constraint "commission_alert_settings_checklist_template_check" CHECK (cardinality(checklist_template) >= 1 AND cardinality(checklist_template) <= 30 AND array_position(checklist_template, NULL::text) IS NULL);

alter table public."commission_alert_settings" add constraint "commission_alert_settings_lead_days_check" CHECK (hsn_private.valid_lead_days(lead_days));

alter table public."commission_alert_settings" add constraint "commission_alert_settings_review_day_check" CHECK (review_day >= 1 AND review_day <= 31);

alter table public."commission_reviews" add constraint "commission_reviews_check" CHECK (review_status = 'completed'::text AND completed_date IS NOT NULL OR review_status = 'open'::text AND completed_date IS NULL);

alter table public."commission_reviews" add constraint "commission_reviews_checklist_check" CHECK (hsn_private.valid_checklist(checklist));

alter table public."commission_reviews" add constraint "commission_reviews_competence_check" CHECK (EXTRACT(day FROM competence) = 1::numeric);

alter table public."commission_reviews" add constraint "commission_reviews_review_status_check" CHECK (review_status = ANY (ARRAY['open'::text, 'completed'::text]));

alter table public."commissions" add constraint "commissions_agency_name_check" CHECK (length(TRIM(BOTH FROM agency_name)) >= 1 AND length(TRIM(BOTH FROM agency_name)) <= 180);

alter table public."commissions" add constraint "commissions_amount_check" CHECK (amount >= 0::numeric);

alter table public."commissions" add constraint "commissions_check" CHECK (review_status = 'confirmed'::text AND confirmed_date IS NOT NULL OR review_status <> 'confirmed'::text AND confirmed_date IS NULL);

alter table public."commissions" add constraint "commissions_competence_check" CHECK (EXTRACT(day FROM competence) = 1::numeric);

alter table public."commissions" add constraint "commissions_review_status_check" CHECK (review_status = ANY (ARRAY['pending'::text, 'in_review'::text, 'confirmed'::text]));

alter table public."commissions" add constraint "commissions_title_check" CHECK (length(TRIM(BOTH FROM title)) >= 1 AND length(TRIM(BOTH FROM title)) <= 180);

alter table public."dda_charges" add constraint "dda_charges_amount_check" CHECK (amount >= 0::numeric);

alter table public."dda_charges" add constraint "dda_charges_barcode_check" CHECK (barcode = ''::text OR barcode ~ '^([0-9]{44}|[0-9]{47}|[0-9]{48})$'::text);

alter table public."dda_charges" add constraint "dda_charges_check" CHECK (reviewed AND reviewed_date IS NOT NULL OR NOT reviewed AND reviewed_date IS NULL);

alter table public."dda_charges" add constraint "dda_charges_check1" CHECK (converted_payable_id IS NULL OR reviewed);

alter table public."dda_charges" add constraint "dda_charges_supplier_name_check" CHECK (length(TRIM(BOTH FROM supplier_name)) >= 1 AND length(TRIM(BOTH FROM supplier_name)) <= 180);

alter table public."dda_charges" add constraint "dda_charges_title_check" CHECK (length(TRIM(BOTH FROM title)) >= 1 AND length(TRIM(BOTH FROM title)) <= 180);

alter table public."hsn10_bank_transactions" add constraint "hsn10_bank_transactions_amount_check" CHECK (amount <> 0::numeric);

alter table public."hsn10_events" add constraint "hsn10_events_amount_check" CHECK (amount > 0::numeric);

alter table public."hsn10_events" add constraint "hsn10_events_kind_check" CHECK (kind = ANY (ARRAY['payable'::text, 'receivable'::text]));

alter table public."hsn_billing_dispatches" add constraint "hsn_billing_dispatches_status_check" CHECK (status = ANY (ARRAY['processing'::text, 'sent'::text, 'review'::text, 'failed'::text]));

alter table public."hsn_billing_recipients" add constraint "hsn_billing_recipients_company_check" CHECK (char_length(btrim(company)) >= 2 AND char_length(btrim(company)) <= 120);

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_company_check" CHECK (length(btrim(company)) >= 2 AND length(btrim(company)) <= 160);

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_email_check" CHECK (length(email) <= 320);

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_note_check" CHECK (length(btrim(note)) >= 1 AND length(btrim(note)) <= 2000);

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_source_check" CHECK (source = ANY (ARRAY['manual'::text, 'zoho'::text]));

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'resolved'::text]));

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_subject_check" CHECK (length(subject) <= 250);

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_zoho_message_id_check" CHECK (length(zoho_message_id) <= 120);

alter table public."hsn_communication_links" add constraint "hsn_communication_links_note_check" CHECK (length(note) <= 1200);

alter table public."hsn_send_contacts" add constraint "hsn_send_contacts_email_check" CHECK (email = lower(email));

alter table public."hsn_send_jobs" add constraint "hsn_send_jobs_kind_check" CHECK (kind = ANY (ARRAY['billing'::text, 'collection'::text]));

alter table public."hsn_send_jobs" add constraint "hsn_send_jobs_status_check" CHECK (status = ANY (ARRAY['prepared'::text, 'processing'::text, 'sent'::text, 'failed'::text, 'review'::text]));

alter table public."hsn_send_templates" add constraint "hsn_send_templates_body_check" CHECK (length(body) >= 5 AND length(body) <= 10000);

alter table public."hsn_send_templates" add constraint "hsn_send_templates_subject_check" CHECK (length(subject) >= 2 AND length(subject) <= 180);

alter table public."local_holidays" add constraint "local_holidays_name_check" CHECK (length(TRIM(BOTH FROM name)) >= 1 AND length(TRIM(BOTH FROM name)) <= 120);

alter table public."local_holidays" add constraint "local_holidays_scope_check" CHECK (scope = ANY (ARRAY['municipal'::text, 'estadual'::text]));

alter table public."message_templates" add constraint "message_templates_body_check" CHECK (length(TRIM(BOTH FROM body)) >= 1 AND length(TRIM(BOTH FROM body)) <= 2000);

alter table public."message_templates" add constraint "message_templates_title_check" CHECK (length(TRIM(BOTH FROM title)) >= 1 AND length(TRIM(BOTH FROM title)) <= 100);

alter table public."payable_alert_settings" add constraint "payable_alert_settings_lead_days_check" CHECK (hsn_private.valid_lead_days(lead_days));

alter table public."payable_alert_settings" add constraint "payable_alert_settings_variation_percent_check" CHECK (variation_percent >= 0::numeric AND variation_percent <= 1000::numeric);

alter table public."payable_documents" add constraint "payable_documents_check" CHECK (storage_path ~~ (((((((owner_id::text || '/'::text) || payable_id::text) || '/'::text) || to_char(competence::timestamp with time zone, 'YYYY-MM'::text)) || '/'::text) || document_type) || '/%'::text));

alter table public."payable_documents" add constraint "payable_documents_competence_check" CHECK (EXTRACT(day FROM competence) = 1::numeric);

alter table public."payable_documents" add constraint "payable_documents_document_type_check" CHECK (document_type = ANY (ARRAY['boleto'::text, 'nota_fiscal'::text, 'comprovante'::text, 'outros'::text]));

alter table public."payable_documents" add constraint "payable_documents_mime_type_check" CHECK (mime_type = ANY (ARRAY['application/pdf'::text, 'image/jpeg'::text, 'image/png'::text]));

alter table public."payable_documents" add constraint "payable_documents_original_name_check" CHECK (length(original_name) >= 1 AND length(original_name) <= 255);

alter table public."payable_documents" add constraint "payable_documents_size_bytes_check" CHECK (size_bytes >= 1 AND size_bytes <= 20971520);

alter table public."payables" add constraint "payables_actual_amount_check" CHECK (actual_amount IS NULL OR actual_amount >= 0::numeric);

alter table public."payables" add constraint "payables_approval_status_check" CHECK (approval_status = ANY (ARRAY['not_required'::text, 'waiting'::text, 'received'::text]));

alter table public."payables" add constraint "payables_arrival_day_check" CHECK (arrival_day >= 1 AND arrival_day <= 31);

alter table public."payables" add constraint "payables_barcode_check" CHECK (barcode = ''::text OR barcode ~ '^([0-9]{44}|[0-9]{47}|[0-9]{48})$'::text);

alter table public."payables" add constraint "payables_check" CHECK (payment_status = 'open'::text AND paid_date IS NULL OR payment_status = 'paid'::text AND paid_date IS NOT NULL AND actual_amount IS NOT NULL);

alter table public."payables" add constraint "payables_competence_check" CHECK (EXTRACT(day FROM competence) = 1::numeric);

alter table public."payables" add constraint "payables_due_rule_check" CHECK (due_rule = ANY (ARRAY['keep'::text, 'before'::text, 'after'::text]));

alter table public."payables" add constraint "payables_estimated_amount_check" CHECK (estimated_amount >= 0::numeric);

alter table public."payables" add constraint "payables_payment_status_check" CHECK (payment_status = ANY (ARRAY['open'::text, 'paid'::text]));

alter table public."payables" add constraint "payables_required_documents_check" CHECK (required_documents <@ ARRAY['boleto'::text, 'nota_fiscal'::text, 'comprovante'::text, 'outros'::text]);

alter table public."payables" add constraint "payables_title_check" CHECK (length(TRIM(BOTH FROM title)) >= 1 AND length(TRIM(BOTH FROM title)) <= 180);

alter table public."payables" add constraint "payables_workflow_status_check" CHECK (workflow_status = ANY (ARRAY['pending'::text, 'awaiting_signature'::text, 'scheduled_signature'::text, 'scheduled'::text, 'approved'::text, 'cancelled'::text]));

alter table public."push_deliveries" add constraint "push_deliveries_attempts_check" CHECK (attempts >= 1 AND attempts <= 3);

alter table public."push_deliveries" add constraint "push_deliveries_kind_check" CHECK (kind = ANY (ARRAY['daily'::text, 'test'::text]));

alter table public."push_deliveries" add constraint "push_deliveries_module_check" CHECK (module = ANY (ARRAY['payables'::text, 'commissions'::text, 'dda'::text]));

alter table public."push_deliveries" add constraint "push_deliveries_state_check" CHECK (state = ANY (ARRAY['sending'::text, 'accepted'::text, 'failed'::text, 'expired'::text]));

alter table public."push_settings" add constraint "push_settings_module_check" CHECK (module = ANY (ARRAY['payables'::text, 'commissions'::text, 'dda'::text]));

alter table public."push_settings" add constraint "push_settings_send_hour_check" CHECK (send_hour >= 0 AND send_hour <= 23);

alter table public."push_settings" add constraint "push_settings_send_minute_check" CHECK (send_minute = ANY (ARRAY[0, 15, 30, 45]));

alter table public."push_subscriptions" add constraint "push_subscriptions_auth_key_check" CHECK (auth_key ~ '^[A-Za-z0-9_-]{22}$'::text);

alter table public."push_subscriptions" add constraint "push_subscriptions_device_name_check" CHECK (length(TRIM(BOTH FROM device_name)) >= 1 AND length(TRIM(BOTH FROM device_name)) <= 80);

alter table public."push_subscriptions" add constraint "push_subscriptions_endpoint_check" CHECK (length(endpoint) <= 4000 AND endpoint ~ '^https://(fcm\.googleapis\.com/(fcm/send/|wp/)|updates\.push\.services\.mozilla\.com/wpush/|web\.push\.apple\.com/)[A-Za-z0-9_./=:-]+$'::text);

alter table public."push_subscriptions" add constraint "push_subscriptions_p256dh_check" CHECK (p256dh ~ '^[A-Za-z0-9_-]{87}$'::text);

alter table public."push_subscriptions" add constraint "push_subscriptions_vapid_public_key_check" CHECK (vapid_public_key ~ '^[A-Za-z0-9_-]{87}$'::text);

alter table public."recurring_models" add constraint "recurring_models_arrival_day_check" CHECK (arrival_day >= 1 AND arrival_day <= 31);

alter table public."recurring_models" add constraint "recurring_models_check" CHECK (last_month IS NULL OR EXTRACT(day FROM last_month) = 1::numeric AND last_month >= first_month);

alter table public."recurring_models" add constraint "recurring_models_contract_notice_days_check" CHECK (contract_notice_days >= 0 AND contract_notice_days <= 365);

alter table public."recurring_models" add constraint "recurring_models_due_day_check" CHECK (due_day >= 1 AND due_day <= 31);

alter table public."recurring_models" add constraint "recurring_models_due_rule_check" CHECK (due_rule = ANY (ARRAY['keep'::text, 'before'::text, 'after'::text]));

alter table public."recurring_models" add constraint "recurring_models_estimated_amount_check" CHECK (estimated_amount >= 0::numeric);

alter table public."recurring_models" add constraint "recurring_models_first_month_check" CHECK (EXTRACT(day FROM first_month) = 1::numeric);

alter table public."recurring_models" add constraint "recurring_models_required_documents_check" CHECK (required_documents <@ ARRAY['boleto'::text, 'nota_fiscal'::text, 'comprovante'::text, 'outros'::text]);

alter table public."recurring_models" add constraint "recurring_models_title_check" CHECK (length(TRIM(BOTH FROM title)) >= 1 AND length(TRIM(BOTH FROM title)) <= 180);

alter table public."sicoob_collection_dispatches" add constraint "sicoob_collection_dispatches_status_check" CHECK (status = ANY (ARRAY['processing'::text, 'sent'::text, 'failed'::text]));

alter table public."sicoob_collections" add constraint "sicoob_collections_amount_check" CHECK (amount > 0::numeric);

alter table public."sicoob_collections" add constraint "sicoob_collections_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'paid'::text, 'sent'::text]));

alter table public."suppliers" add constraint "suppliers_contacts_check" CHECK (jsonb_typeof(contacts) = 'array'::text);

alter table public."suppliers" add constraint "suppliers_legal_name_check" CHECK (length(TRIM(BOTH FROM legal_name)) >= 1 AND length(TRIM(BOTH FROM legal_name)) <= 180);

alter table public."suppliers" add constraint "suppliers_tax_id_check" CHECK (tax_id = ''::text OR tax_id ~ '^([0-9]{11}|[0-9]{14})$'::text);

alter table public."ui_preferences" add constraint "ui_preferences_theme_check" CHECK (theme = ANY (ARRAY['light'::text, 'dark'::text, 'system'::text]));

alter table hsn_private."app_owner" add constraint "app_owner_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id);

alter table hsn_private."push_run_guard" add constraint "push_run_guard_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."account_types" add constraint "account_types_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."audit_log" add constraint "audit_log_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."backup_settings" add constraint "backup_settings_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."backup_snapshots" add constraint "backup_snapshots_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."commission_alert_settings" add constraint "commission_alert_settings_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."commission_reviews" add constraint "commission_reviews_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."commissions" add constraint "commissions_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."commissions" add constraint "commissions_supplier_id_owner_id_fkey" FOREIGN KEY (supplier_id, owner_id) REFERENCES suppliers(id, owner_id);

alter table public."dda_charges" add constraint "dda_charges_converted_payable_id_owner_id_fkey" FOREIGN KEY (converted_payable_id, owner_id) REFERENCES payables(id, owner_id);

alter table public."dda_charges" add constraint "dda_charges_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."dda_charges" add constraint "dda_charges_supplier_id_owner_id_fkey" FOREIGN KEY (supplier_id, owner_id) REFERENCES suppliers(id, owner_id);

alter table public."hsn10_bank_transactions" add constraint "hsn10_bank_transactions_payment_id_fkey" FOREIGN KEY (payment_id) REFERENCES hsn10_events(id);

alter table public."hsn10_events" add constraint "hsn10_events_reverses_id_fkey" FOREIGN KEY (reverses_id) REFERENCES hsn10_events(id);

alter table public."hsn_billing_dispatches" add constraint "hsn_billing_dispatches_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."hsn_billing_recipients" add constraint "hsn_billing_recipients_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."hsn_communication_followups" add constraint "hsn_communication_followups_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."hsn_communication_links" add constraint "hsn_communication_links_billing_dispatch_id_fkey" FOREIGN KEY (billing_dispatch_id) REFERENCES hsn_billing_dispatches(id) ON DELETE CASCADE;

alter table public."hsn_communication_links" add constraint "hsn_communication_links_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."hsn_communication_links" add constraint "hsn_communication_links_sicoob_collection_id_fkey" FOREIGN KEY (sicoob_collection_id) REFERENCES sicoob_collections(id) ON DELETE CASCADE;

alter table public."hsn_send_attempts" add constraint "hsn_send_attempts_job_id_fkey" FOREIGN KEY (job_id) REFERENCES hsn_send_jobs(id);

alter table public."hsn_send_attempts" add constraint "hsn_send_attempts_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."hsn_send_contacts" add constraint "hsn_send_contacts_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."hsn_send_jobs" add constraint "hsn_send_jobs_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."hsn_send_locks" add constraint "hsn_send_locks_job_id_fkey" FOREIGN KEY (job_id) REFERENCES hsn_send_jobs(id);

alter table public."hsn_send_locks" add constraint "hsn_send_locks_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."hsn_send_templates" add constraint "hsn_send_templates_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."hsn_send_throttle" add constraint "hsn_send_throttle_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."local_holidays" add constraint "local_holidays_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."message_templates" add constraint "message_templates_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."payable_alert_settings" add constraint "payable_alert_settings_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."payable_documents" add constraint "payable_documents_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."payable_documents" add constraint "payable_documents_payable_id_owner_id_fkey" FOREIGN KEY (payable_id, owner_id) REFERENCES payables(id, owner_id);

alter table public."payables" add constraint "payables_model_id_owner_id_fkey" FOREIGN KEY (model_id, owner_id) REFERENCES recurring_models(id, owner_id);

alter table public."payables" add constraint "payables_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."payables" add constraint "payables_supplier_id_owner_id_fkey" FOREIGN KEY (supplier_id, owner_id) REFERENCES suppliers(id, owner_id);

alter table public."payables" add constraint "payables_type_id_owner_id_fkey" FOREIGN KEY (type_id, owner_id) REFERENCES account_types(id, owner_id);

alter table public."push_deliveries" add constraint "push_deliveries_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."push_deliveries" add constraint "push_deliveries_subscription_id_owner_id_fkey" FOREIGN KEY (subscription_id, owner_id) REFERENCES push_subscriptions(id, owner_id);

alter table public."push_settings" add constraint "push_settings_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."push_subscriptions" add constraint "push_subscriptions_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."recurring_models" add constraint "recurring_models_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."recurring_models" add constraint "recurring_models_supplier_id_owner_id_fkey" FOREIGN KEY (supplier_id, owner_id) REFERENCES suppliers(id, owner_id);

alter table public."recurring_models" add constraint "recurring_models_type_id_owner_id_fkey" FOREIGN KEY (type_id, owner_id) REFERENCES account_types(id, owner_id);

alter table public."sicoob_collection_dispatches" add constraint "sicoob_collection_dispatches_collection_id_fkey" FOREIGN KEY (collection_id) REFERENCES sicoob_collections(id);

alter table public."sicoob_collection_dispatches" add constraint "sicoob_collection_dispatches_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."sicoob_collections" add constraint "sicoob_collections_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."sicoob_contacts" add constraint "sicoob_contacts_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."suppliers" add constraint "suppliers_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."ui_preferences" add constraint "ui_preferences_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id);

alter table public."zoho_mail_tokens" add constraint "zoho_mail_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."zoho_oauth_states" add constraint "zoho_oauth_states_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX account_types_name_unique ON public.account_types USING btree (owner_id, lower(TRIM(BOTH FROM name)));

CREATE INDEX audit_owner_time ON public.audit_log USING btree (owner_id, created_at DESC, id);

CREATE INDEX audit_record ON public.audit_log USING btree (owner_id, table_name, record_id, created_at DESC);

CREATE UNIQUE INDEX backup_one_week ON public.backup_snapshots USING btree (owner_id, week_start) WHERE (kind = 'weekly'::text);

CREATE INDEX backup_owner_time ON public.backup_snapshots USING btree (owner_id, created_at DESC, id);

CREATE INDEX commissions_owner_due ON public.commissions USING btree (owner_id, due_date) WHERE (NOT archived);

CREATE INDEX commissions_owner_month ON public.commissions USING btree (owner_id, competence);

CREATE INDEX dda_owner_due ON public.dda_charges USING btree (owner_id, due_date) WHERE (NOT archived);

CREATE INDEX dda_owner_tax ON public.dda_charges USING btree (owner_id, tax_id) WHERE (tax_id <> ''::text);

CREATE INDEX hsn10_events_target ON public.hsn10_events USING btree (owner_id, kind, target_id);

CREATE UNIQUE INDEX hsn10_one_opening ON public.hsn10_events USING btree (kind, target_id) WHERE legacy;

CREATE INDEX hsn_billing_dispatches_owner_created ON public.hsn_billing_dispatches USING btree (owner_id, created_at DESC);

CREATE INDEX hsn_comm_followups_owner ON public.hsn_communication_followups USING btree (owner_id, status, created_at DESC);

CREATE INDEX hsn_comm_links_owner ON public.hsn_communication_links USING btree (owner_id, created_at DESC);

CREATE INDEX hsn_send_jobs_owner_date ON public.hsn_send_jobs USING btree (owner_id, created_at DESC);

CREATE INDEX idx_payables_workflow_status ON public.payables USING btree (owner_id, workflow_status);

CREATE INDEX local_holidays_owner_date ON public.local_holidays USING btree (owner_id, holiday_date);

CREATE INDEX message_templates_owner ON public.message_templates USING btree (owner_id);

CREATE INDEX payable_documents_account ON public.payable_documents USING btree (owner_id, payable_id, created_at DESC);

CREATE INDEX payables_model_paid ON public.payables USING btree (model_id, competence DESC) WHERE (payment_status = 'paid'::text);

CREATE INDEX payables_owner_due ON public.payables USING btree (owner_id, due_date) WHERE (NOT archived);

CREATE INDEX payables_owner_month ON public.payables USING btree (owner_id, competence);

CREATE INDEX push_deliveries_owner_time ON public.push_deliveries USING btree (owner_id, created_at DESC);

CREATE INDEX recurring_models_owner_active ON public.recurring_models USING btree (owner_id, active);

CREATE INDEX suppliers_owner_name ON public.suppliers USING btree (owner_id, legal_name);

CREATE INDEX suppliers_tax_id ON public.suppliers USING btree (owner_id, tax_id) WHERE (tax_id <> ''::text);

CREATE TRIGGER hsn10_audit AFTER INSERT OR DELETE OR UPDATE ON account_types FOR EACH ROW EXECUTE FUNCTION hsn10_audit_change();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON account_types FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON account_types FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON backup_settings FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON backup_settings FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON commission_alert_settings FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON commission_alert_settings FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON commission_reviews FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON commission_reviews FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER validate_monthly_review BEFORE INSERT OR UPDATE ON commission_reviews FOR EACH ROW EXECUTE FUNCTION hsn_private.validate_monthly_review();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON commissions FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON commissions FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn10_audit AFTER INSERT OR DELETE OR UPDATE ON dda_charges FOR EACH ROW EXECUTE FUNCTION hsn10_audit_change();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON dda_charges FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON dda_charges FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER validate_dda_update BEFORE UPDATE ON dda_charges FOR EACH ROW EXECUTE FUNCTION hsn_private.validate_dda_update();

CREATE TRIGGER hsn_communication_validate_link_trg BEFORE INSERT OR UPDATE ON hsn_communication_links FOR EACH ROW EXECUTE FUNCTION hsn_communication_validate_link();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON local_holidays FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON local_holidays FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON message_templates FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON message_templates FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON payable_alert_settings FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON payable_alert_settings FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn10_audit AFTER INSERT OR DELETE OR UPDATE ON payable_documents FOR EACH ROW EXECUTE FUNCTION hsn10_audit_change();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON payable_documents FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER validate_document BEFORE INSERT ON payable_documents FOR EACH ROW EXECUTE FUNCTION hsn_private.validate_document();

CREATE TRIGGER hsn10_audit AFTER INSERT OR DELETE OR UPDATE ON payables FOR EACH ROW EXECUTE FUNCTION hsn10_audit_change();

CREATE TRIGGER hsn10_guard BEFORE INSERT OR DELETE OR UPDATE ON payables FOR EACH ROW EXECUTE FUNCTION hsn10_guard_title();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON payables FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON payables FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER validate_payable BEFORE INSERT OR UPDATE ON payables FOR EACH ROW EXECUTE FUNCTION hsn_private.validate_payable();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON push_settings FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON push_settings FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON push_subscriptions FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON recurring_models FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON recurring_models FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn10_audit AFTER INSERT OR DELETE OR UPDATE ON sicoob_collections FOR EACH ROW EXECUTE FUNCTION hsn10_audit_change();

CREATE TRIGGER hsn10_guard BEFORE INSERT OR DELETE OR UPDATE ON sicoob_collections FOR EACH ROW EXECUTE FUNCTION hsn10_guard_title();

CREATE TRIGGER hsn10_audit AFTER INSERT OR DELETE OR UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION hsn10_audit_change();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

CREATE TRIGGER hsn_audit AFTER INSERT OR DELETE OR UPDATE ON ui_preferences FOR EACH ROW EXECUTE FUNCTION hsn_private.audit_change();

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON ui_preferences FOR EACH ROW EXECUTE FUNCTION hsn_private.touch_updated_at();

alter table hsn_private."app_owner" enable row level security;

alter table hsn_private."push_run_guard" enable row level security;

alter table public."account_types" enable row level security;

alter table public."audit_log" enable row level security;

alter table public."backup_settings" enable row level security;

alter table public."backup_snapshots" enable row level security;

alter table public."commission_alert_settings" enable row level security;

alter table public."commission_reviews" enable row level security;

alter table public."commissions" enable row level security;

alter table public."dda_charges" enable row level security;

alter table public."hsn10_audit" enable row level security;

alter table public."hsn10_backup" enable row level security;

alter table public."hsn10_bank_transactions" enable row level security;

alter table public."hsn10_events" enable row level security;

alter table public."hsn10_import_batches" enable row level security;

alter table public."hsn10_migrations" enable row level security;

alter table public."hsn_billing_dispatches" enable row level security;

alter table public."hsn_billing_recipients" enable row level security;

alter table public."hsn_communication_followups" enable row level security;

alter table public."hsn_communication_links" enable row level security;

alter table public."hsn_send_attempts" enable row level security;

alter table public."hsn_send_contacts" enable row level security;

alter table public."hsn_send_jobs" enable row level security;

alter table public."hsn_send_locks" enable row level security;

alter table public."hsn_send_templates" enable row level security;

alter table public."hsn_send_throttle" enable row level security;

alter table public."local_holidays" enable row level security;

alter table public."message_templates" enable row level security;

alter table public."payable_alert_settings" enable row level security;

alter table public."payable_documents" enable row level security;

alter table public."payables" enable row level security;

alter table public."push_deliveries" enable row level security;

alter table public."push_settings" enable row level security;

alter table public."push_subscriptions" enable row level security;

alter table public."recurring_models" enable row level security;

alter table public."sicoob_collection_dispatches" enable row level security;

alter table public."sicoob_collections" enable row level security;

alter table public."sicoob_contacts" enable row level security;

alter table public."suppliers" enable row level security;

alter table public."ui_preferences" enable row level security;

alter table public."zoho_mail_tokens" enable row level security;

alter table public."zoho_oauth_states" enable row level security;

create policy "hsn_owner_only" on "public"."account_types" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."suppliers" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."message_templates" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_documents_read" on "storage"."objects" as PERMISSIVE for SELECT to "authenticated" using (((bucket_id = 'hsn-documentos'::text) AND hsn_private.is_owner() AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

create policy "hsn_billing_recipients_insert" on "public"."hsn_billing_recipients" as PERMISSIVE for INSERT to "authenticated" with check ((owner_id = auth.uid()));

create policy "hsn_documents_insert" on "storage"."objects" as PERMISSIVE for INSERT to "authenticated" with check (((bucket_id = 'hsn-documentos'::text) AND hsn_private.is_owner() AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

create policy "hsn_owner_only" on "public"."local_holidays" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."recurring_models" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."payables" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_documents_metadata_read" on "public"."payable_documents" as PERMISSIVE for SELECT to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_documents_metadata_insert" on "public"."payable_documents" as PERMISSIVE for INSERT to "authenticated" with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."payable_alert_settings" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."commission_alert_settings" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."commissions" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."commission_reviews" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."ui_preferences" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."dda_charges" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_read" on "public"."audit_log" as PERMISSIVE for SELECT to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_only" on "public"."backup_settings" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_read" on "public"."backup_snapshots" as PERMISSIVE for SELECT to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "Usuarios consultam seus proprios envios" on "public"."sicoob_collection_dispatches" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = ( SELECT auth.uid() AS uid)));

create policy "hsn_owner_only" on "public"."push_settings" as PERMISSIVE for ALL to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid)))) with check ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_read" on "public"."push_subscriptions" as PERMISSIVE for SELECT to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "hsn_owner_read" on "public"."push_deliveries" as PERMISSIVE for SELECT to "authenticated" using ((hsn_private.is_owner() AND (owner_id = ( SELECT auth.uid() AS uid))));

create policy "sicoob contacts owner" on "public"."sicoob_contacts" as PERMISSIVE for ALL to "authenticated" using ((owner_id = auth.uid())) with check ((owner_id = auth.uid()));

create policy "sicoob collections owner" on "public"."sicoob_collections" as PERMISSIVE for ALL to "authenticated" using ((owner_id = auth.uid())) with check ((owner_id = auth.uid()));

create policy "hsn_billing_recipients_select" on "public"."hsn_billing_recipients" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn_billing_recipients_update" on "public"."hsn_billing_recipients" as PERMISSIVE for UPDATE to "authenticated" using ((owner_id = auth.uid())) with check ((owner_id = auth.uid()));

create policy "hsn_billing_dispatches_select" on "public"."hsn_billing_dispatches" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn_comm_links_select" on "public"."hsn_communication_links" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn_comm_links_insert" on "public"."hsn_communication_links" as PERMISSIVE for INSERT to "authenticated" with check ((owner_id = auth.uid()));

create policy "hsn_comm_links_delete" on "public"."hsn_communication_links" as PERMISSIVE for DELETE to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn_comm_followups_select" on "public"."hsn_communication_followups" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn_comm_followups_insert" on "public"."hsn_communication_followups" as PERMISSIVE for INSERT to "authenticated" with check ((owner_id = auth.uid()));

create policy "hsn_comm_followups_update" on "public"."hsn_communication_followups" as PERMISSIVE for UPDATE to "authenticated" using ((owner_id = auth.uid())) with check ((owner_id = auth.uid()));

create policy "hsn_comm_followups_delete" on "public"."hsn_communication_followups" as PERMISSIVE for DELETE to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn_contacts_own" on "public"."hsn_send_contacts" as PERMISSIVE for ALL to "authenticated" using ((owner_id = auth.uid())) with check ((owner_id = auth.uid()));

create policy "hsn_jobs_read" on "public"."hsn_send_jobs" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn_attempts_read" on "public"."hsn_send_attempts" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn_templates_own" on "public"."hsn_send_templates" as PERMISSIVE for ALL to "authenticated" using ((owner_id = auth.uid())) with check ((owner_id = auth.uid()));

create policy "hsn10_owner_read" on "public"."hsn10_backup" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn10_owner_read" on "public"."hsn10_events" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn10_owner_read" on "public"."hsn10_audit" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn10_owner_read" on "public"."hsn10_import_batches" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

create policy "hsn10_owner_read" on "public"."hsn10_bank_transactions" as PERMISSIVE for SELECT to "authenticated" using ((owner_id = auth.uid()));

revoke all on all tables in schema public from anon;

revoke all on all tables in schema hsn_private from public, anon, authenticated;

grant all on all tables in schema public, hsn_private to service_role;

grant usage, select on all sequences in schema public to authenticated, service_role;

grant INSERT on public."sicoob_collections" to authenticated;

grant SELECT on public."sicoob_collections" to authenticated;

grant UPDATE on public."sicoob_collections" to authenticated;

grant DELETE on public."sicoob_collections" to authenticated;

grant TRUNCATE on public."sicoob_collections" to authenticated;

grant REFERENCES on public."sicoob_collections" to authenticated;

grant TRIGGER on public."sicoob_collections" to authenticated;

grant SELECT on public."hsn10_backup" to authenticated;

grant SELECT on public."hsn10_events" to authenticated;

grant SELECT on public."hsn10_audit" to authenticated;

grant SELECT on public."hsn10_import_batches" to authenticated;

grant SELECT on public."hsn10_bank_transactions" to authenticated;

grant INSERT on public."account_types" to authenticated;

grant SELECT on public."account_types" to authenticated;

grant UPDATE on public."account_types" to authenticated;

grant DELETE on public."account_types" to authenticated;

grant INSERT on public."suppliers" to authenticated;

grant SELECT on public."suppliers" to authenticated;

grant UPDATE on public."suppliers" to authenticated;

grant DELETE on public."suppliers" to authenticated;

grant INSERT on public."message_templates" to authenticated;

grant SELECT on public."message_templates" to authenticated;

grant UPDATE on public."message_templates" to authenticated;

grant DELETE on public."message_templates" to authenticated;

grant INSERT on public."payables" to authenticated;

grant SELECT on public."payables" to authenticated;

grant UPDATE on public."payables" to authenticated;

grant INSERT on public."local_holidays" to authenticated;

grant SELECT on public."local_holidays" to authenticated;

grant UPDATE on public."local_holidays" to authenticated;

grant DELETE on public."local_holidays" to authenticated;

grant INSERT on public."recurring_models" to authenticated;

grant SELECT on public."recurring_models" to authenticated;

grant UPDATE on public."recurring_models" to authenticated;

grant DELETE on public."recurring_models" to authenticated;

grant INSERT on public."payable_documents" to authenticated;

grant SELECT on public."payable_documents" to authenticated;

grant SELECT on public."audit_log" to authenticated;

grant INSERT on public."payable_alert_settings" to authenticated;

grant SELECT on public."payable_alert_settings" to authenticated;

grant UPDATE on public."payable_alert_settings" to authenticated;

grant INSERT on public."commission_alert_settings" to authenticated;

grant SELECT on public."commission_alert_settings" to authenticated;

grant UPDATE on public."commission_alert_settings" to authenticated;

grant INSERT on public."commissions" to authenticated;

grant SELECT on public."commissions" to authenticated;

grant UPDATE on public."commissions" to authenticated;

grant INSERT on public."commission_reviews" to authenticated;

grant SELECT on public."commission_reviews" to authenticated;

grant UPDATE on public."commission_reviews" to authenticated;

grant INSERT on public."ui_preferences" to authenticated;

grant SELECT on public."ui_preferences" to authenticated;

grant UPDATE on public."ui_preferences" to authenticated;

grant INSERT on public."dda_charges" to authenticated;

grant SELECT on public."dda_charges" to authenticated;

grant UPDATE on public."dda_charges" to authenticated;

grant SELECT on public."backup_settings" to authenticated;

grant UPDATE on public."backup_settings" to authenticated;

grant SELECT on public."backup_snapshots" to authenticated;

grant SELECT on public."push_subscriptions" to authenticated;

grant SELECT on public."push_settings" to authenticated;

grant SELECT on public."sicoob_collection_dispatches" to authenticated;

grant SELECT on public."push_deliveries" to authenticated;

grant INSERT on public."sicoob_contacts" to authenticated;

grant SELECT on public."sicoob_contacts" to authenticated;

grant UPDATE on public."sicoob_contacts" to authenticated;

grant DELETE on public."sicoob_contacts" to authenticated;

grant TRUNCATE on public."sicoob_contacts" to authenticated;

grant REFERENCES on public."sicoob_contacts" to authenticated;

grant TRIGGER on public."sicoob_contacts" to authenticated;

grant INSERT on public."hsn_billing_recipients" to authenticated;

grant SELECT on public."hsn_billing_recipients" to authenticated;

grant UPDATE on public."hsn_billing_recipients" to authenticated;

grant DELETE on public."hsn_billing_recipients" to authenticated;

grant TRUNCATE on public."hsn_billing_recipients" to authenticated;

grant REFERENCES on public."hsn_billing_recipients" to authenticated;

grant TRIGGER on public."hsn_billing_recipients" to authenticated;

grant SELECT on public."hsn_billing_dispatches" to authenticated;

grant INSERT on public."hsn_communication_links" to authenticated;

grant SELECT on public."hsn_communication_links" to authenticated;

grant UPDATE on public."hsn_communication_links" to authenticated;

grant DELETE on public."hsn_communication_links" to authenticated;

grant TRUNCATE on public."hsn_communication_links" to authenticated;

grant REFERENCES on public."hsn_communication_links" to authenticated;

grant TRIGGER on public."hsn_communication_links" to authenticated;

grant INSERT on public."hsn_communication_followups" to authenticated;

grant SELECT on public."hsn_communication_followups" to authenticated;

grant UPDATE on public."hsn_communication_followups" to authenticated;

grant DELETE on public."hsn_communication_followups" to authenticated;

grant TRUNCATE on public."hsn_communication_followups" to authenticated;

grant REFERENCES on public."hsn_communication_followups" to authenticated;

grant TRIGGER on public."hsn_communication_followups" to authenticated;

grant INSERT on public."hsn_send_contacts" to authenticated;

grant SELECT on public."hsn_send_contacts" to authenticated;

grant UPDATE on public."hsn_send_contacts" to authenticated;

grant SELECT on public."hsn_send_jobs" to authenticated;

grant SELECT on public."hsn_send_attempts" to authenticated;

grant INSERT on public."hsn_send_templates" to authenticated;

grant SELECT on public."hsn_send_templates" to authenticated;

grant UPDATE on public."hsn_send_templates" to authenticated;

grant DELETE on public."hsn_send_templates" to authenticated;

revoke all on function hsn_private.validate_dda_update() from public, anon, authenticated, service_role;

revoke all on function hsn_private.validate_monthly_review() from public, anon, authenticated, service_role;

revoke all on function hsn_private.valid_lead_days(integer[]) from public, anon, authenticated, service_role;

grant execute on function hsn_private.valid_lead_days(integer[]) to authenticated;

revoke all on function hsn_private.valid_checklist(jsonb) from public, anon, authenticated, service_role;

grant execute on function hsn_private.valid_checklist(jsonb) to authenticated;

revoke all on function hsn_private.is_owner() from public, anon, authenticated, service_role;

grant execute on function hsn_private.is_owner() to authenticated;

revoke all on function hsn_private.touch_updated_at() from public, anon, authenticated, service_role;

revoke all on function hsn_private.validate_document() from public, anon, authenticated, service_role;

revoke all on function hsn_private.easter(integer) from public, anon, authenticated, service_role;

grant execute on function hsn_private.easter(integer) to authenticated;

revoke all on function hsn_private.is_business_day(date) from public, anon, authenticated, service_role;

grant execute on function hsn_private.is_business_day(date) to authenticated;

revoke all on function hsn_private.adjust_due(date,text) from public, anon, authenticated, service_role;

grant execute on function hsn_private.adjust_due(date,text) to authenticated;

revoke all on function hsn_private.validate_payable() from public, anon, authenticated, service_role;

revoke all on function hsn_private.audit_change() from public, anon, authenticated, service_role;

revoke all on function hsn_private.weekly_backup() from public, anon, authenticated, service_role;

revoke all on function hsn_private.take_backup(uuid,text) from public, anon, authenticated, service_role;

revoke all on function hsn_private.request_push_run() from public, anon, authenticated, service_role;

revoke all on function public.convert_dda_to_payable(uuid,timestamp with time zone,uuid,uuid,date,text) from public, anon, authenticated, service_role;

grant execute on function public.convert_dda_to_payable(uuid,timestamp with time zone,uuid,uuid,date,text) to authenticated;

grant execute on function public.convert_dda_to_payable(uuid,timestamp with time zone,uuid,uuid,date,text) to service_role;

revoke all on function public.create_hsn_backup() from public, anon, authenticated, service_role;

grant execute on function public.create_hsn_backup() to service_role;

grant execute on function public.create_hsn_backup() to authenticated;

revoke all on function public.generate_recurring_month(date,jsonb) from public, anon, authenticated, service_role;

grant execute on function public.generate_recurring_month(date,jsonb) to authenticated;

grant execute on function public.generate_recurring_month(date,jsonb) to service_role;

revoke all on function public.hsn10_audit_change() from public, anon, authenticated, service_role;

grant execute on function public.hsn10_audit_change() to service_role;

revoke all on function public.hsn10_cancel_receivable(uuid,timestamp with time zone,text,boolean) from public, anon, authenticated, service_role;

grant execute on function public.hsn10_cancel_receivable(uuid,timestamp with time zone,text,boolean) to authenticated;

grant execute on function public.hsn10_cancel_receivable(uuid,timestamp with time zone,text,boolean) to service_role;

revoke all on function public.hsn10_commit_import(uuid,text,text,text,jsonb) from public, anon, authenticated, service_role;

grant execute on function public.hsn10_commit_import(uuid,text,text,text,jsonb) to authenticated;

grant execute on function public.hsn10_commit_import(uuid,text,text,text,jsonb) to service_role;

revoke all on function public.hsn10_export_backup() from public, anon, authenticated, service_role;

grant execute on function public.hsn10_export_backup() to authenticated;

grant execute on function public.hsn10_export_backup() to service_role;

revoke all on function public.hsn10_guard_title() from public, anon, authenticated, service_role;

grant execute on function public.hsn10_guard_title() to service_role;

revoke all on function public.hsn10_mark_billing_sent(uuid,timestamp with time zone,text) from public, anon, authenticated, service_role;

grant execute on function public.hsn10_mark_billing_sent(uuid,timestamp with time zone,text) to authenticated;

grant execute on function public.hsn10_mark_billing_sent(uuid,timestamp with time zone,text) to service_role;

revoke all on function public.hsn10_post_payment(text,uuid,numeric,date,text,uuid,text,uuid) from public, anon, authenticated, service_role;

grant execute on function public.hsn10_post_payment(text,uuid,numeric,date,text,uuid,text,uuid) to authenticated;

grant execute on function public.hsn10_post_payment(text,uuid,numeric,date,text,uuid,text,uuid) to service_role;

revoke all on function public.hsn10_reverse_payment(uuid,date,text,uuid) from public, anon, authenticated, service_role;

grant execute on function public.hsn10_reverse_payment(uuid,date,text,uuid) to authenticated;

grant execute on function public.hsn10_reverse_payment(uuid,date,text,uuid) to service_role;

revoke all on function public.hsn10_save_receivable(uuid,timestamp with time zone,jsonb) from public, anon, authenticated, service_role;

grant execute on function public.hsn10_save_receivable(uuid,timestamp with time zone,jsonb) to authenticated;

grant execute on function public.hsn10_save_receivable(uuid,timestamp with time zone,jsonb) to service_role;

revoke all on function public.hsn_backup_schedule_status() from public, anon, authenticated, service_role;

grant execute on function public.hsn_backup_schedule_status() to service_role;

grant execute on function public.hsn_backup_schedule_status() to authenticated;

revoke all on function public.hsn_collection_send_claim(uuid,uuid,jsonb) from public, anon, authenticated, service_role;

grant execute on function public.hsn_collection_send_claim(uuid,uuid,jsonb) to service_role;

revoke all on function public.hsn_communication_validate_link() from public, anon, authenticated, service_role;

grant execute on function public.hsn_communication_validate_link() to authenticated;

grant execute on function public.hsn_communication_validate_link() to service_role;

revoke all on function public.hsn_push_begin(uuid,text) from public, anon, authenticated, service_role;

grant execute on function public.hsn_push_begin(uuid,text) to service_role;

revoke all on function public.hsn_push_claim(uuid,text,text,text,date) from public, anon, authenticated, service_role;

grant execute on function public.hsn_push_claim(uuid,text,text,text,date) to service_role;

revoke all on function public.hsn_push_context(uuid) from public, anon, authenticated, service_role;

grant execute on function public.hsn_push_context(uuid) to service_role;

revoke all on function public.hsn_push_end(uuid) from public, anon, authenticated, service_role;

grant execute on function public.hsn_push_end(uuid) to service_role;

revoke all on function public.hsn_push_finish(uuid,uuid,integer) from public, anon, authenticated, service_role;

grant execute on function public.hsn_push_finish(uuid,uuid,integer) to service_role;

revoke all on function public.hsn_push_owner() from public, anon, authenticated, service_role;

grant execute on function public.hsn_push_owner() to service_role;

revoke all on function public.hsn_send_claim(uuid,uuid,jsonb) from public, anon, authenticated, service_role;

grant execute on function public.hsn_send_claim(uuid,uuid,jsonb) to service_role;

revoke all on function public.hsn_send_finish(uuid,uuid,text,text,text,integer) from public, anon, authenticated, service_role;

grant execute on function public.hsn_send_finish(uuid,uuid,text,text,text,integer) to service_role;

revoke all on function public.preview_recurring_month(date) from public, anon, authenticated, service_role;

grant execute on function public.preview_recurring_month(date) to authenticated;

grant execute on function public.preview_recurring_month(date) to service_role;

revoke all on function public.register_hsn_push(text,text,text,text,text) from public, anon, authenticated, service_role;

grant execute on function public.register_hsn_push(text,text,text,text,text) to service_role;

grant execute on function public.register_hsn_push(text,text,text,text,text) to authenticated;

revoke all on function public.set_hsn_push_device(uuid,boolean,boolean,boolean,boolean) from public, anon, authenticated, service_role;

grant execute on function public.set_hsn_push_device(uuid,boolean,boolean,boolean,boolean) to service_role;

grant execute on function public.set_hsn_push_device(uuid,boolean,boolean,boolean,boolean) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('hsn-documentos','hsn-documentos',false,20971520,array['application/pdf','image/jpeg','image/png']::text[]);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('hsn-send-private','hsn-send-private',false,10485760,null);

insert into public.hsn10_migrations(version) values(10);

insert into hsn_private.clone_configuration(key,value) values('supabase_url','https://qbowrzgpmkvlmmckvwaz.supabase.co');

set check_function_bodies = on;
