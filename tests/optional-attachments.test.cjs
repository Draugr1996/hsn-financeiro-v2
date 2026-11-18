const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
const {webcrypto}=require('node:crypto');
function setup(){
 const saved=[],calls=[],env={SUPABASE_URL:'https://test.supabase.co',SUPABASE_ANON_KEY:'test-public',SUPABASE_SERVICE_ROLE_KEY:'test-private',HSN_APP_URL:'http://localhost:8080/',HSN_ENABLE_EMAIL:'true'};
 const owner='11111111-1111-4111-8111-111111111111';
 class Query{
  constructor(table){this.table=table;this.op='select';}
  select(){return this;}eq(){return this;}in(){return this;}order(){return this;}limit(){return this;}
  insert(row){this.op='insert';this.row=row;return this;}
  maybeSingle(){return Promise.resolve({data:null,error:null});}
  single(){if(this.op==='insert')saved.push(this.row);return Promise.resolve({data:null,error:null});}
  then(resolve,reject){if(this.op==='insert')saved.push(this.row);return Promise.resolve({data:this.op==='insert'?null:[],error:null}).then(resolve,reject);}
 }
 const client={auth:{getUser:async()=>({data:{user:{id:owner}},error:null})},from:table=>new Query(table),rpc:async(name)=>{calls.push(name);return{data:owner,error:null}}};
 const context={createClient:()=>client,Deno:{env:{get:k=>env[k]},serve:f=>{context.outer=f;}},crypto:webcrypto,TextEncoder,TextDecoder,URL,URLSearchParams,Request,Response,Headers,FormData,File,Blob,Uint8Array,Map,Set,ArrayBuffer,Buffer,atob,btoa,AbortSignal,fetch:()=>{throw Error('Rede externa proibida no teste');},console};
 vm.createContext(context);let code=fs.readFileSync('supabase/functions/zoho-billing-mail/index.ts','utf8').replace(/^import[^\n]*\n/,'');code=stripTypeScriptTypes(code);vm.runInContext(code,context);context.prepare=vm.runInContext('handler',context);return {context,saved,calls};
}
const body={action:'prepare',kind:'billing',company:'Empresa Teste',nf:'',to:'teste@example.com',cc:'',subject:'Faturamento sem anexos',content:'Conferência de faturamento sem documentos.',amount:null,confirm_documents:true};
async function prepare(t,payload=body,files=[]){const form=new FormData();form.append('payload',JSON.stringify(payload));for(const file of files)form.append('files',file);return t.context.prepare(new Request('http://localhost:8080/',{method:'POST',headers:{Origin:'http://localhost:8080',Authorization:'Bearer teste'},body:form}));}
test('Servidor prepara faturamento sem arquivos, sem enviar e-mail',async()=>{const t=setup(),reply=await prepare(t),r=await reply.json();assert.equal(reply.status,200,JSON.stringify(r));assert.equal(r.snapshot.files.length,0);assert.ok(r.approval);assert.equal(t.saved.length,1);assert.equal(t.calls.filter(n=>n==='hsn_send_claim').length,0);});
test('Mensagens distintas sem anexos não têm a mesma identidade de envio',async()=>{const t=setup();await prepare(t);await prepare(t,{...body,content:'Outro faturamento com referência diferente.'});assert.notEqual(t.saved[0].fingerprint,t.saved[1].fingerprint);});
test('Arquivos continuam sujeitos a tamanho, tipo e confirmação',async()=>{const t=setup();let reply=await prepare(t,{...body,confirm_documents:false});assert.notEqual(reply.status,200);reply=await prepare(t,body,[new File(['arquivo inválido'],'arquivo.exe',{type:'application/octet-stream'})]);assert.notEqual(reply.status,200);assert.equal(t.saved.length,0);});
test('Anexos opcionais não dispensam login',async()=>{const t=setup(),reply=await t.context.outer(new Request('http://localhost:8080/',{method:'POST'}));assert.equal(reply.status,401);assert.equal(t.saved.length,0);});
