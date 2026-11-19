const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ctx={window:{},Intl,Date};vm.createContext(ctx);for(const f of ['financial-core','hsn96-dda-intel','hsn97-auto-reconcile'])vm.runInContext(fs.readFileSync('js/'+f+'.js','utf8'),ctx);
const H=ctx.window.HSN97,ownerSupplier={id:'s',legal_name:'Fornecedor Teste',tax_id:'12345678000195'};
const payable={id:'p',supplier_id:'s',actual_amount:1000,paid_amount:0,payment_status:'open',due_date:'2026-11-10',workflow_status:'pending',document_number:'DOC123456'};
const dda={id:'d',converted_payable_id:'p',supplier_name:'Fornecedor Teste',tax_id:'12345678000195',amount:1000,document_number:'123456',due_date:'2026-11-10'};
const tx={id:'tx',amount:-1000,transaction_date:'2026-11-10',settled:true,description:'Pagamento boleto doc 123456 CNPJ 12345678000195',bank_reference:'BANK-123456789'};
function match(t=tx,d=dda,p=payable){return H.persistedMatches([t],[d],[p],[ownerSupplier],'2026-11-19').get(t.id);}
test('DDA, conta e extrato identificados sugerem conta sem registrar baixa',()=>{const result=match();assert.equal(result.key,'suggested');assert.equal(result.payable.id,'p');assert.equal(payable.paid_amount,0);});
test('Valor igual sem documento e beneficiário não seleciona conta',()=>{assert.equal(match({...tx,description:'Pagamento boleto',bank_reference:'BANK-111111111'}).key,'review');});
test('Pagamento parcial usa saldo sem alterar o valor original do DDA',()=>{assert.equal(match({...tx,amount:-700},dda,{...payable,paid_amount:300}).key,'suggested');assert.equal(dda.amount,1000);});
test('Conta já quitada é reconhecida sem sugerir segunda baixa',()=>{assert.equal(match(tx,dda,{...payable,paid_amount:1000,payment_status:'paid'}).key,'paid');});
test('Juros ou descontos ficam como divergência',()=>{assert.equal(match({...tx,amount:-1005}).key,'divergence');assert.equal(match({...tx,amount:-995}).key,'divergence');});
test('Agendamento sem liquidação e assinatura pendente não viram pagamento',()=>{assert.equal(match({...tx,settled:false},dda,{...payable,workflow_status:'scheduled'}).key,'scheduled');assert.equal(match(tx,dda,{...payable,workflow_status:'scheduled_signature'}).key,'blocked');assert.equal(match({...tx,transaction_date:'2026-11-20'}).key,'review');});
test('DDA e conta com valores originais diferentes exigem revisão',()=>{assert.equal(match(tx,{...dda,amount:900}).key,'divergence');});
test('Dois documentos compatíveis ou dois débitos para a mesma conta não desempata por valor',()=>{let all=H.persistedMatches([tx],[dda,{...dda,id:'d2'}],[payable],[ownerSupplier],'2026-11-19');assert.equal(all.get('tx').key,'review');all=H.persistedMatches([tx,{...tx,id:'tx2'}],[dda],[payable],[ownerSupplier],'2026-11-19');assert.equal(all.get('tx').key,'review');assert.equal(all.get('tx2').key,'review');});
test('Situação paga no arquivo continua revisão até vincular baixa no HSN',()=>{const result=ctx.window.HSN_DDA96.classify({...dda,converted_payable_id:null,source_status:'paid'},{payables:[],suppliers:[]});assert.equal(result.key,'review');});

test('Documento que coincide com parte do CNPJ não identifica o boleto',()=>{assert.equal(match({...tx,description:'Pagamento documento 555555 CNPJ 12.345.678/0001-95',bank_reference:'BANK-555555-2026'}).key,'review');});

test('Fornecedor é identificado pelo CNPJ, com máscara e nome diferente',()=>{const r=ctx.window.HSN_DDA96.resolveSupplier({tax_id:'12.345.678/0001-95',supplier_name:'Nome no banco',supplier_id:'errado'},[ownerSupplier]);assert.equal(r.key,'matched');assert.equal(r.id,'s');});
test('CNPJ ausente ou duplicado não usa fornecedor homônimo automaticamente',()=>{const resolve=ctx.window.HSN_DDA96.resolveSupplier;assert.equal(resolve({tax_id:'98765432000199',supplier_name:ownerSupplier.legal_name},[ownerSupplier]).id,'');assert.equal(resolve({tax_id:ownerSupplier.tax_id},[ownerSupplier,{...ownerSupplier,id:'s2'}]).key,'ambiguous');assert.equal(resolve({tax_id:'00000000000000'},[ownerSupplier]).key,'invalid');});
