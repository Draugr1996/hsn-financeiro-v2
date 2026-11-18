-- Anexos opcionais: preserva documentos, exigências antigas e registros financeiros.
begin;
alter table public.payables alter column required_documents set default '{}'::text[];
alter table public.recurring_models alter column required_documents set default '{}'::text[];
alter table public.sicoob_collections alter column required_billing_docs set default '[]'::jsonb;

create or replace function public.hsn10_mark_billing_sent(p_id uuid,p_expected_updated_at timestamptz,p_reference text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.sicoob_collections;
begin
 select * into r from public.sicoob_collections where id=p_id and owner_id=auth.uid() for update;
 if not found or r.updated_at is distinct from p_expected_updated_at or r.cancelled_at is not null then raise exception 'Título indisponível/alterado.';end if;
 if length(trim(r.guest_name))=0 or length(trim(r.stay_reference))=0 or r.check_in is null or r.check_out is null or length(trim(coalesce(p_reference,'')))<8 then raise exception 'Complete hospedagem e referência do envio confirmado.';end if;
 -- O operador confirma um envio já realizado; anexo não comprova envio nem pagamento.
 update public.sicoob_collections set billing_sent_at=now(),billing_send_reference=p_reference where id=p_id and owner_id=auth.uid();
end $$;
commit;
