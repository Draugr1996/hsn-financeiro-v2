-- SOMENTE CONSULTA: antes/depois da migração. Não apaga nem corrige registros.
-- Confira resultados com extratos, NF e vouchers, em acesso administrativo.
select 'Referências Sicoob repetidas' as conferencia,owner_id,lower(trim(reference)) as referencia,
 count(*) as quantidade,array_agg(id) as ids from public.sicoob_collections
 group by owner_id,lower(trim(reference)) having count(*)>1;
select id,company,reference,amount,status,to_jsonb(s)->>'paid_date' as data_registrada
 from public.sicoob_collections s where status='paid' and nullif(to_jsonb(s)->>'paid_date','') is null;
select id,title,actual_amount,estimated_amount,payment_status,due_date,archived
 from public.payables p where (archived and payment_status<>'paid' and coalesce(to_jsonb(p)->>'workflow_status','')<>'cancelled')
 or (payment_status='paid' and (actual_amount is null or paid_date is null));
select owner_id,supplier_id,due_date,coalesce(actual_amount,estimated_amount) as valor,
 coalesce(document_number,'') as documento,count(*) as quantidade,array_agg(id) as ids
 from public.payables group by owner_id,supplier_id,due_date,coalesce(actual_amount,estimated_amount),coalesce(document_number,'')
 having count(*)>1;
select proname as rotina_instalada from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and (proname like 'hsn10_%' or proname in ('hsn_send_claim','hsn_send_finish'));
select table_name,column_name,data_type,udt_name from information_schema.columns
 where table_schema='public' and table_name in ('payables','sicoob_collections','dda_charges')
 and column_name in ('paid_amount','paid_date','workflow_status','required_documents','billing_documents');
