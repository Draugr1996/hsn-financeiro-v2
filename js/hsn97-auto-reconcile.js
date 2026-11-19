/* HSN 9.7 — triagem conservadora: DDA + conta a pagar + extrato liquidado.
 * Somente débito bancário com referência estável e identificação documental
 * suficiente pode ir para baixa automática, após autorização explícita.
 * Não deduz pagamento de DDA, valor/data iguais ou agendamento.
 */
(function(root){'use strict';
 const digits=v=>String(v??'').replace(/\D/g,'');
 const normalize=v=>String(v??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
 const cents=v=>Math.round(Number(v)*100);
 const validAmount=v=>Number.isFinite(Number(v))&&Number(v)>0;
 const payableAmount=p=>p?.actual_amount==null?null:Number(p.actual_amount)-Number(p.paid_amount||0);
 const dayDiff=(a,b)=>{const x=Date.parse(String(a||'')+'T00:00:00Z'),y=Date.parse(String(b||'')+'T00:00:00Z');return Number.isFinite(x)&&Number.isFinite(y)?Math.round((x-y)/86400000):Infinity;};
 const accountStatus=p=>p.payment_status==='paid'?'paid':(['scheduled','scheduled_signature'].includes(p.workflow_status)?'scheduled':'open');
 function matchesSupplier(d,p,s){
  const supplier=(s instanceof Map?s.get(p.supplier_id):s.find(x=>x.id===p.supplier_id))||{};
  const a=digits(d.tax_id),b=digits(supplier.tax_id);
  if(a&&b)return a===b;
  const dn=normalize(d.supplier_name),names=[supplier.legal_name,supplier.trade_name].map(normalize).filter(Boolean);
  return dn.length>=7&&names.includes(dn);
 }
 function strongDdaAccount(d,p,s){
  if(d.archived||p.archived||p.workflow_status==='cancelled'||!validAmount(d.amount))return false;
  if(cents(d.amount)!==cents(payableAmount(p)))return false;
  const db=digits(d.barcode),pb=digits(p.barcode);
  const barcode=db.length>=30&&db===pb;
  const doc=normalize(d.document_number).replace(/\s/g,''),pdoc=normalize(p.document_number).replace(/\s/g,'');
  const document=doc.length>=6&&doc===pdoc&&matchesSupplier(d,p,s);
  return barcode||document;
 }
 function accountCandidates(d,accounts,s){
  const directId=d.converted_payable_id||d.linked_payable_id;
  if(directId){const p=accounts.find(x=>x.id===directId);return p&&cents(d.amount)===cents(payableAmount(p))?[p]:[];}
  return accounts.filter(p=>strongDdaAccount(d,p,s));
 }
 // Compara identificadores completos: um número de documento não pode ser um trecho do CNPJ.
 const containsDigits=(text,ident)=>ident.length>=6&&(String(text||'').match(/\d(?:[\d.\s/\-]*\d)?/g)||[]).some(token=>digits(token)===ident);
 function hasBankIdentity(tx,d,p,s){
  const bankText=[tx.description,tx.reference].join(' '),supplier=(s instanceof Map?s.get(p.supplier_id):s.find(x=>x.id===p.supplier_id))||{};
  const barcode=digits(d.barcode),document=digits(d.document_number),tax=digits(d.tax_id);
  if(barcode.length>=30&&containsDigits(bankText,barcode))return 'Código de barras confirmado no extrato';
  const supplierTax=digits(supplier.tax_id);
  const bankTax=(tax.length===11||tax.length===14)&&tax===supplierTax&&containsDigits(bankText,tax);
  const bankDoc=document.length>=6&&containsDigits(bankText,document);
  // Documento do DDA e identidade do fornecedor precisam aparecer no EXTRATO.
  // O número interno da transação (FITID) sozinho não identifica o beneficiário.
  if(bankDoc&&bankTax)return 'Documento e CPF/CNPJ identificados no extrato';
  return '';
 }
 function referenceIsStable(tx){
  const ref=String(tx.bankReference||tx.reference||'').trim();
  return !!tx.stableReference&&ref.length>=6&&!/^(?:linha\s*\d+|\d{1,5})$/i.test(ref);
 }
 function transactionIdentity(tx){
  const ref=String(tx.bankReference||tx.reference||'').trim();
  const source=tx.sourceType==='ofx'?'ofx':'csv';
  return source+'|'+String(tx.bankAccount||'')+'|'+ref+'|'+tx.date+'|'+cents(Math.abs(Number(tx.amount)))+'|'+normalize(tx.description);
 }
 function reconcile(bankRows,dda,accounts,suppliers,options={}){
  const payables=accounts||[],charges=(dda||[]).filter(x=>!x.archived),vendors=suppliers||[];
  const index=new Map(),duplicateCounts=new Map(),rows=[];
  const byAccountId=new Map(payables.map(x=>[x.id,x])),byAmount=new Map(),bySupplierId=new Map(vendors.map(x=>[x.id,x]));
  // Indexacao O(titulos + contas + transacoes): nao procura TODAS as contas para cada debito.
  for(const p of payables){if(p.actual_amount==null)continue;const key=cents(p.actual_amount),arr=byAmount.get(key)||[];arr.push(p);byAmount.set(key,arr);}
  const matchedPayables=new Map();
  for(const d of charges){if(!validAmount(d.amount))continue;const k=cents(d.amount),arr=index.get(k)||[];arr.push(d);index.set(k,arr);
   const linkedId=d.converted_payable_id||d.linked_payable_id;
   const possibilities=linkedId?[byAccountId.get(linkedId)].filter(Boolean):(byAmount.get(k)||[]).filter(p=>strongDdaAccount(d,p,bySupplierId));
   matchedPayables.set(d.id,possibilities.filter(p=>cents(payableAmount(p))===k));
  }
  for(const tx of bankRows||[]){const key=transactionIdentity(tx);duplicateCounts.set(key,(duplicateCounts.get(key)||0)+1);}
  for(const tx of bankRows||[]){
   const result={tx,status:'review',reason:'Movimento sem identificação bancária suficiente.',dda:null,payable:null,evidence:'',transactionIdentity:transactionIdentity(tx)};
   rows.push(result);
   if(!(Number(tx.amount)<0)){result.status='ignored';result.reason='Crédito não é pagamento de boleto.';continue;}
   if(!tx.date||!Number.isFinite(Number(tx.amount))){result.status='review';result.reason='Data ou valor inválidos.';continue;}
   if(duplicateCounts.get(result.transactionIdentity)>1){result.reason='Possível movimento repetido neste extrato; sem baixa automática.';result.status='duplicate';continue;}
   const dList=index.get(cents(-Number(tx.amount)))||[];
   if(!dList.length){result.status='no_dda';result.reason='Não há DDA do mesmo valor. Conferir manualmente.';continue;}
   const possibilities=[];
   for(const d of dList){
    const ps=matchedPayables.get(d.id)||[];
    for(const p of ps){
     if(!p||cents(payableAmount(p))!==cents(-Number(tx.amount)))continue;
     const diff=dayDiff(tx.date,p.bank_scheduled_date||d.due_date||p.due_date);
     const evidence=hasBankIdentity(tx,d,p,bySupplierId);
     possibilities.push({d,p,evidence,diff});
    }
   }
   const strong=possibilities.filter(x=>x.evidence&&x.diff>=-10&&x.diff<=90);
   // Não usar desempate arbitrário: uma transação deve identificar UM título e UMA conta.
   const uniqueDda=new Set(strong.map(x=>x.d.id)),uniquePayable=new Set(strong.map(x=>x.p.id));
   if(strong.length===1&&uniqueDda.size===1&&uniquePayable.size===1){
    const x=strong[0];result.dda=x.d;result.payable=x.p;result.evidence=x.evidence;
    if(x.p.payment_status==='paid'){result.status='paid';result.reason='A conta já está paga no HSN; não repetir baixa.';}
    else if(x.p.archived||x.p.workflow_status==='cancelled'||['awaiting_signature','scheduled_signature'].includes(x.p.workflow_status)||x.p.approval_status==='waiting'){
     result.status='blocked';result.reason='Conta bloqueada, cancelada ou aguardando autorização.';
    }else if(tx.settledProof!==true){
     result.status='review';result.reason='Arquivo não comprova lançamento efetivado. Para CSV, exija saldo do extrato ou situação liquidada.';
   }else if(!referenceIsStable(tx)){
     result.status='review';result.reason='Sem referência bancária estável (FITID/identificador do movimento).';
    }else if((options.today||new Date().toISOString().slice(0,10))<tx.date){
     result.status='review';result.reason='Lançamento com data futura não comprova liquidação.';
    }else{result.status='auto';result.reason='DDA, conta e débito bancário identificados de forma única.';}
   }else if(strong.length>1){result.status='review';result.reason='Mais de um DDA/conta tem identificação bancária compatível.';}
   else if(possibilities.length){
    const uniqueP=new Set(possibilities.map(x=>x.p.id));
    const p=uniqueP.size===1?possibilities[0].p:null;
    result.payable=p;result.dda=possibilities.length===1?possibilities[0].d:null;
    result.status=p?.payment_status==='paid'?'paid':p&&accountStatus(p)==='scheduled'?'scheduled':'review';
    result.reason='Valor encontrado, mas o extrato não identifica documento e beneficiário; conferir manualmente.';
   }else{result.status='no_account';result.reason='Existe DDA pelo valor, mas não foi encontrada conta vinculada com documento compatível.';}
  }
  const auto=rows.filter(x=>x.status==='auto'), accountCount=new Map();
  for(const r of auto)accountCount.set(r.payable.id,(accountCount.get(r.payable.id)||0)+1);
  for(const r of auto)if(accountCount.get(r.payable.id)>1){r.status='review';r.reason='A mesma conta aparece em vários débitos; conferir duplicidade.';}
  return rows;
 }
 // Conciliação integrada: usa os movimentos persistidos e o saldo do livro de baixas.
 // Sugestão é apenas seleção inicial para conferência; não registra pagamento.
 function persistedMatches(bankRows,dda,accounts,suppliers,day){
  const byId=new Map((accounts||[]).map(p=>[p.id,p])),vendors=new Map((suppliers||[]).map(s=>[s.id,s]));
  const charges=(dda||[]).filter(d=>!d.archived),pairs=[];
  for(const d of charges){
   const linked=d.converted_payable_id||d.linked_payable_id;
   const candidates=linked?[byId.get(linked)].filter(Boolean):(accounts||[]).filter(p=>strongDdaAccount(d,{...p,paid_amount:0},vendors));
   for(const p of candidates)pairs.push({d,p});
  }
  const out=new Map();
  for(const bank of bankRows||[]){
   if(!(Number(bank.amount)<0))continue;
   const tx={date:bank.transaction_date,description:bank.description,reference:bank.bank_reference};
   const found=pairs.map(x=>({...x,evidence:hasBankIdentity(tx,x.d,x.p,vendors)})).filter(x=>x.evidence);
   let r={key:'review',label:'Conferir manualmente',reason:'O extrato não identifica o documento e o beneficiário. Coincidência de valor não confirma o vínculo.',payable:null,dda:null};
   if(found.length>1)r={...r,label:'Vínculo ambíguo',reason:'Mais de um DDA/conta tem identificação compatível. Nenhuma conta foi selecionada.'};
   else if(found.length===1){
    const x=found[0],p=x.p,b=root.HSN_MONEY.balance(p),scheduled=['scheduled','scheduled_signature'].includes(p.workflow_status);
    r={...r,payable:p,dda:x.d,evidence:x.evidence};
    if(b.cancelled||p.archived||['awaiting_signature','scheduled_signature'].includes(p.workflow_status)||p.approval_status==='waiting')r={...r,key:'blocked',label:scheduled?'Programado · assinatura pendente':'Conta bloqueada',reason:'Confirme a autorização bancária antes de registrar pagamento.'};
    else if(b.pending===0&&b.total>0)r={...r,key:'paid',label:'Conta já paga no HSN',reason:'A conta está quitada. Confira o histórico para não registrar o mesmo pagamento novamente.'};
    else if(!bank.settled||bank.transaction_date>day)r={...r,key:scheduled?'scheduled':'review',label:scheduled?'Programado no HSN · sem liquidação confirmada':'Sem liquidação comprovada',reason:'Programação ou data futura não comprova pagamento.'};
    else if(b.estimated||!validAmount(bank.amount*-1)||cents(Math.abs(bank.amount))!==cents(b.pending))r={...r,key:'divergence',label:'Divergência de valor',reason:'Valor bancário '+Math.abs(Number(bank.amount)).toLocaleString('pt-BR',{style:'currency',currency:'BRL'})+'; saldo da conta '+b.pending.toLocaleString('pt-BR',{style:'currency',currency:'BRL'})+'. Confira pagamento parcial, juros ou desconto.'};
    else if(cents(x.d.amount)!==cents(b.total))r={...r,key:'divergence',label:'DDA e conta com valores diferentes',reason:'Confira o valor original do título e da conta antes de conciliar.'};
    else if(dayDiff(bank.transaction_date,p.bank_scheduled_date||x.d.due_date||p.due_date)<-10||dayDiff(bank.transaction_date,p.bank_scheduled_date||x.d.due_date||p.due_date)>90)r={...r,key:'divergence',label:'Data fora do período esperado',reason:'Documento compatível, mas a data exige conferência manual.'};
    else r={...r,key:'suggested',label:'DDA e conta identificados',reason:x.evidence+'. Valor e saldo conferem. Revise e confirme a baixa.'};
   }else{
    const unmatched=charges.filter(d=>!d.converted_payable_id&&!d.linked_payable_id&&hasBankIdentity(tx,d,{supplier_id:null},vendors));
    if(unmatched.length===1)r={...r,key:'no_account',label:'DDA ainda sem conta identificada',dda:unmatched[0],reason:'Confira ou converta este DDA antes de registrar o pagamento.'};
   }
   out.set(bank.id,r);
  }
  const suggestions=[...out.values()].filter(r=>r.key==='suggested'),counts=new Map();
  for(const r of suggestions)counts.set(r.payable.id,(counts.get(r.payable.id)||0)+1);
  for(const r of suggestions)if(counts.get(r.payable.id)>1)Object.assign(r,{key:'review',label:'Conta em mais de um débito',reason:'Confira repetição ou pagamentos parciais. Nenhuma sugestão foi selecionada.'});
  return out;
 }

 root.HSN97={persistedMatches,reconcile,transactionIdentity,strongDdaAccount,hasBankIdentity,referenceIsStable};
})(window);
