-- Conversão DDA por CNPJ; cadastros compartilhados e dívidas preservados.
begin;
create or replace function hsn_private.dda_tax_key(value text) returns text
language sql immutable parallel safe set search_path='' as $$select regexp_replace(coalesce(value,''),'[^0-9]','','g')$$;
create or replace function hsn_private.dda_barcode_key(value text) returns text
language sql immutable parallel safe set search_path='' as $$
 select case length(n)
 when 44 then n
 when 47 then substr(n,1,4)||substr(n,33,1)||substr(n,34,14)||substr(n,5,5)||substr(n,11,10)||substr(n,22,10)
 when 48 then substr(n,1,11)||substr(n,13,11)||substr(n,25,11)||substr(n,37,11)
 else '' end from (select regexp_replace(coalesce(value,''),'[^0-9]','','g') n) x
$$;
revoke all on function hsn_private.dda_tax_key(text),hsn_private.dda_barcode_key(text) from public,anon;
grant execute on function hsn_private.dda_tax_key(text),hsn_private.dda_barcode_key(text) to authenticated,service_role;
-- Não altera nem mescla cadastros; duplicidades antigas precisam ser conferidas antes da instalação.
create unique index if not exists hsn_supplier_tax_unique on public.suppliers(owner_id,hsn_private.dda_tax_key(tax_id)) where hsn_private.dda_tax_key(tax_id)<>'';
create unique index if not exists hsn_payable_barcode_unique on public.payables(owner_id,hsn_private.dda_barcode_key(barcode)) where hsn_private.dda_barcode_key(barcode)<>'';
create index if not exists hsn_dda_barcode_lookup on public.dda_charges(owner_id,hsn_private.dda_barcode_key(barcode)) where hsn_private.dda_barcode_key(barcode)<>'';

create or replace function public.hsn_dda_save_supplier(p_id uuid,p_name text,p_tax_id text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); charge public.dda_charges; vendor public.suppliers; tax text:=hsn_private.dda_tax_key(p_tax_id); n integer; name text:=trim(coalesce(p_name,''));
begin
 if uid is null or not hsn_private.is_owner() then raise exception 'Acesso negado';end if;
 select * into charge from public.dda_charges where id=p_id and owner_id=uid for update;
 if not found or charge.archived or charge.converted_payable_id is not null or (to_jsonb(charge)->>'linked_payable_id') is not null then raise exception 'DDA indisponível para cadastro de fornecedor.';end if;
 if length(name)<1 or length(name)>180 then raise exception 'Informe o nome do fornecedor, até 180 caracteres.';end if;
 if length(tax) not in (11,14) or tax ~ '^([0-9])\1+$' then raise exception 'Informe CPF com 11 dígitos ou CNPJ com 14 dígitos.';end if;
 if hsn_private.dda_tax_key(charge.tax_id)<>'' and hsn_private.dda_tax_key(charge.tax_id)<>tax then raise exception 'O CPF/CNPJ informado difere do título DDA. Confira ou corrija o título antes de cadastrar.';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||':supplier:'||tax,0));
 select count(*) into n from public.suppliers where owner_id=uid and hsn_private.dda_tax_key(tax_id)=tax;
 if n>1 then raise exception 'Mais de um fornecedor possui este CPF/CNPJ. Confira os cadastros.';end if;
 if n=1 then select * into vendor from public.suppliers where owner_id=uid and hsn_private.dda_tax_key(tax_id)=tax;
 else
  select count(*) into n from public.suppliers where owner_id=uid and hsn_private.dda_tax_key(tax_id)='' and (lower(trim(legal_name))=lower(name) or lower(trim(trade_name))=lower(name));
  if n>1 then raise exception 'Há cadastros sem CPF/CNPJ com este nome. Confira antes de criar outro fornecedor.';end if;
  if n=1 then
   update public.suppliers set tax_id=tax where owner_id=uid and hsn_private.dda_tax_key(tax_id)='' and (lower(trim(legal_name))=lower(name) or lower(trim(trade_name))=lower(name)) returning * into vendor;
  else
   insert into public.suppliers(owner_id,legal_name,tax_id) values(uid,name,tax) returning * into vendor;
  end if;
 end if;
 update public.dda_charges set supplier_id=vendor.id where id=charge.id and owner_id=uid returning * into charge;
 return jsonb_build_object('supplier',to_jsonb(vendor),'charge',jsonb_build_object('id',charge.id,'supplier_id',charge.supplier_id,'updated_at',charge.updated_at));
end $$;
revoke all on function public.hsn_dda_save_supplier(uuid,text,text) from public,anon;
grant execute on function public.hsn_dda_save_supplier(uuid,text,text) to authenticated,service_role;

create or replace function public.convert_dda_to_payable(p_id uuid,p_expected_updated_at timestamptz,p_supplier_id uuid,p_type_id uuid,p_competence date,p_due_rule text)
returns uuid language plpgsql security invoker set search_path='' as $$
declare uid uuid:=auth.uid(); charge public.dda_charges; vendor public.suppliers; prior public.payables; result uuid; tax text; n integer;
begin
 if uid is null or not hsn_private.is_owner() then raise exception 'Acesso negado';end if;
 select * into charge from public.dda_charges where id=p_id and owner_id=uid for update;
 if not found then raise exception 'Cobrança não encontrada';end if;
 tax:=hsn_private.dda_tax_key(charge.tax_id);
 if tax<>'' then
  select count(*) into n from public.suppliers where owner_id=uid and hsn_private.dda_tax_key(tax_id)=tax;
  if n>1 then raise exception 'CPF/CNPJ com mais de um fornecedor. Confira os cadastros.';end if;
  if n=1 then select * into vendor from public.suppliers where owner_id=uid and hsn_private.dda_tax_key(tax_id)=tax;end if;
 end if;
 if vendor.id is null then select * into vendor from public.suppliers where id=p_supplier_id and owner_id=uid;end if;
 if vendor.id is null then raise exception 'Cadastre ou selecione o fornecedor na própria conversão.';end if;
 if tax<>'' and hsn_private.dda_tax_key(vendor.tax_id)<>tax then raise exception 'Fornecedor selecionado não corresponde ao CPF/CNPJ do título DDA.';end if;
 if not exists(select 1 from public.account_types where id=p_type_id and owner_id=uid) then raise exception 'Selecione a categoria da despesa (plano de contas).';end if;
 if charge.converted_payable_id is not null then
  select * into prior from public.payables where id=charge.converted_payable_id and owner_id=uid;
  if prior.id is not null and prior.supplier_id=vendor.id and prior.type_id=p_type_id and prior.competence=p_competence and prior.due_rule=p_due_rule then return prior.id;end if;
  raise exception 'DDA já convertido. Abra a conta existente; nenhuma nova dívida foi criada.';
 end if;
 if (to_jsonb(charge)->>'linked_payable_id') is not null then raise exception 'DDA já vinculado a uma conta. Abra o lançamento existente.';end if;
 if charge.updated_at is distinct from p_expected_updated_at then raise exception 'Cobrança mudou. Atualize antes de converter';end if;
 if charge.archived then raise exception 'Restaure a cobrança antes de converter';end if;
 if not charge.reviewed then raise exception 'Confira o DDA antes de converter';end if;
 if charge.amount<=0 then raise exception 'Informe um valor positivo para o DDA.';end if;
 if p_competence is null or extract(day from p_competence)<>1 then raise exception 'Competência inválida';end if;
 if p_due_rule not in ('keep','before','after') or p_due_rule is null then raise exception 'Regra de vencimento inválida';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||'payables',0));
 if hsn_private.dda_barcode_key(charge.barcode)<>'' and exists(select 1 from public.payables where owner_id=uid and hsn_private.dda_barcode_key(barcode)=hsn_private.dda_barcode_key(charge.barcode)) then raise exception 'Este boleto já possui conta cadastrada, inclusive se arquivada ou cancelada. Abra a conta existente.';end if;
 insert into public.payables(owner_id,supplier_id,type_id,title,competence,original_due_date,due_date,due_rule,estimated_amount,actual_amount,document_number,barcode,notes,required_documents)
 values(uid,vendor.id,p_type_id,charge.title,p_competence,charge.due_date,hsn_private.adjust_due(charge.due_date,p_due_rule),p_due_rule,charge.amount,charge.amount,charge.document_number,charge.barcode,
 'Convertida do DDA '||charge.id::text||case when charge.notes<>'' then E'\n'||charge.notes else '' end,'{}'::text[]) returning id into result;
 update public.dda_charges set supplier_id=vendor.id,converted_payable_id=result where id=charge.id and owner_id=uid;
 return result;
end $$;

-- Reimportação aceita o mesmo boleto em código de barras ou linha digitável.
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
       (coalesce(d->>'barcode','')<>'' and hsn_private.dda_barcode_key(barcode)=hsn_private.dda_barcode_key(d->>'barcode')) or
       (supplier_id=(d->>'supplier_id')::uuid and ((coalesce(d->>'document_number','')<>'' and document_number=d->>'document_number' and due_date=dt) or
       (due_date=dt and coalesce(actual_amount,estimated_amount)=amt and coalesce(document_number,'')=coalesce(d->>'document_number','') and title=d->>'title')))) limit 1;
      if oldrow is null then
       insert into public.payables(owner_id,title,supplier_id,type_id,competence,original_due_date,due_date,due_rule,estimated_amount,actual_amount,document_number,barcode,notes,payment_status,workflow_status,workflow_note,bank_scheduled_date,required_documents)
        values(uid,d->>'title',(d->>'supplier_id')::uuid,(d->>'type_id')::uuid,(d->>'competence')::date,coalesce(nullif(d->>'original_due_date','')::date,dt),dt,coalesce(d->>'due_rule','keep'),coalesce((d->>'estimated_amount')::numeric,amt),(d->>'actual_amount')::numeric,coalesce(d->>'document_number',''),coalesce(d->>'barcode',''),coalesce(d->>'notes',''),'open',coalesce(d->>'workflow_status','pending'),coalesce(d->>'workflow_note',''),nullif(d->>'bank_scheduled_date','')::date,(jsonb_populate_record(null::public.payables,jsonb_build_object('required_documents',coalesce(d->'required_documents','["boleto"]'::jsonb)))).required_documents) returning id into rid;
       status:='imported';msg:='Conta importada sem baixa.';
      end if;
     else
      select to_jsonb(c) into oldrow from public.dda_charges c where owner_id=uid and ((coalesce(d->>'barcode','')<>'' and hsn_private.dda_barcode_key(barcode)=hsn_private.dda_barcode_key(d->>'barcode')) or (due_date=dt and amount=amt and lower(trim(supplier_name))=lower(trim(d->>'supplier_name')) and coalesce(document_number,'')=coalesce(d->>'document_number',''))) limit 1;
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

commit;
