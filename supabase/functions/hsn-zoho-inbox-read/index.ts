// HSN 9.3 — Consulta SOMENTE-LEITURA de mensagens da pasta Entrada do Zoho.
// Permissões requeridas na conexão OAuth: ZohoMail.messages.READ, ZohoMail.folders.READ.
// Não altera mensagens, não envia e-mails, não grava conteúdos no banco.
import { createClient } from 'npm:@supabase/supabase-js@2.119.0';
const ALLOWED_ORIGIN=new URL(Deno.env.get('HSN_APP_URL')||'http://localhost:8080/').origin;
const EMAIL_RE=/^[^\s@;,]+@[^\s@;,]+\.[^\s@;,]+$/;
function bytes(v:string):Uint8Array{const b=atob(v);return Uint8Array.from(b,c=>c.charCodeAt(0));}
async function decrypt(value:string,keyB64:string){const [iv,payload]=value.split('.');if(!iv||!payload)throw Error('Token Zoho armazenado em formato inválido.');const key=await crypto.subtle.importKey('raw',bytes(keyB64),{name:'AES-GCM'},false,['decrypt']);const plaintext=await crypto.subtle.decrypt({name:'AES-GCM',iv:bytes(iv)},key,bytes(payload));return new TextDecoder().decode(plaintext);}
const env=(name:string)=>{const v=Deno.env.get(name);if(!v)throw Error('Configuração ausente: '+name);return v;};
function safeText(x:unknown,max=250){return String(x??'').replace(/[\u0000-\u001f]/g,' ').slice(0,max);}
async function json(r:Response){return await r.json().catch(()=>null);}
function msToISO(v:unknown){const t=Number(v);if(!Number.isFinite(t)||t<1000000000000)return null;const d=new Date(t);return Number.isNaN(d.getTime())?null:d.toISOString();}
serveIsolated(async request=>{
 const origin=request.headers.get('origin')||'';
 const allowed=origin===ALLOWED_ORIGIN||/^http:\/\/(?:localhost|127\.0\.0\.1)(?::\d+)?$/.test(origin);
 const cors={'Access-Control-Allow-Origin':allowed?origin:ALLOWED_ORIGIN,'Vary':'Origin','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
 const respond=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,'Content-Type':'application/json'}});
 if(request.method==='OPTIONS')return new Response(null,{status:allowed?204:403,headers:cors});
 if(!allowed)return respond({error:'Origem não autorizada'},403);
 if(request.method!=='POST')return respond({error:'Método não permitido'},405);
 const bearer=request.headers.get('authorization')||'';
 if(!bearer.startsWith('Bearer '))return respond({error:'Faça login para consultar o Zoho'},401);
 try{
  const params=await request.json().catch(()=>({}));const requested=Math.max(1,Math.min(30,Number(params.limit)||30));
  const url=env('SUPABASE_URL');const anon=hsnApiKey('SUPABASE_ANON_KEY')||env('SB_PUBLISHABLE_KEY');
  const client=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:authenticated,error:authError}=await client.auth.getUser(bearer.slice(7));
  if(authError||!authenticated?.user?.id)return respond({error:'Sessão expirada; entre novamente.'},401);
  const admin=createClient(url,env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:zoho,error:zohoError}=await admin.from('zoho_mail_tokens').select('refresh_token,account_id').eq('user_id',authenticated.user.id).maybeSingle();
  if(zohoError||!zoho?.refresh_token||!zoho?.account_id)return respond({error:'A conta Zoho não está conectada para este usuário.'},409);
  const refresh=await decrypt(zoho.refresh_token,env('ZOHO_TOKEN_ENCRYPTION_KEY'));
  const tokenResponse=await fetch('https://accounts.zoho.com/oauth/v2/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'refresh_token',client_id:env('ZOHO_CLIENT_ID'),client_secret:env('ZOHO_CLIENT_SECRET'),refresh_token:refresh})});
  const tokens=await json(tokenResponse);if(!tokenResponse.ok||!tokens?.access_token)return respond({error:'Não foi possível renovar a autorização Zoho. Reconecte a conta.'},409);
  const headers={Authorization:'Zoho-oauthtoken '+tokens.access_token,Accept:'application/json'};
  const base='https://mail.zoho.com/api/accounts/'+encodeURIComponent(String(zoho.account_id));
  const folderResponse=await fetch(base+'/folders',{headers});const folders=await json(folderResponse);
  if(!folderResponse.ok||Number(folders?.status?.code)!==200||!Array.isArray(folders?.data))return respond({error:'Não foi possível ler pastas do Zoho. Reautorize a conexão com ZohoMail.folders.READ e ZohoMail.messages.READ.'},403);
  const inbox=(folders.data as any[]).find(f=>String(f.folderType||f.folderName||'').toLowerCase()==='inbox');
  if(!inbox?.folderId)return respond({error:'Pasta de entrada não encontrada no Zoho.'},404);
  const endpoint=base+'/messages/view?'+new URLSearchParams({folderId:String(inbox.folderId),limit:String(requested),start:'1',status:'all',sortBy:'date',sortorder:'false'});
  const mailResponse=await fetch(endpoint,{headers});const mail=await json(mailResponse);
  if(!mailResponse.ok||Number(mail?.status?.code)!==200||!Array.isArray(mail?.data))return respond({error:'A conexão atual não tem permissão para ler mensagens. Reautorize com ZohoMail.messages.READ (e ZohoMail.folders.READ).'},403);
  const messages=mail.data.slice(0,requested).map((m:any)=>({
   message_id:safeText(m.messageId,120),subject:safeText(m.subject||'Sem assunto',250),
   from:EMAIL_RE.test(String(m.fromAddress||'').trim())?String(m.fromAddress).trim():'',
   received_at:msToISO(m.receivedTime||m.sentDateInGMT),summary:safeText(m.summary,240)
  }));
  return respond({success:true,messages,read_only:true});
 }catch(error){console.error('Zoho inbox read error:',error instanceof Error?error.message:'erro desconhecido');return respond({error:'Falha ao consultar a caixa de entrada. Confira as permissões OAuth e os logs da função.'},500);}
});

// Clone: valida sessão e proprietário no servidor antes de executar integrações.
function serveIsolated(handler: (request: Request) => Response | Promise<Response>){
 Deno.serve(async request=>{
  const origin=new URL(Deno.env.get('HSN_APP_URL')||'http://localhost:8080/').origin;
  const reply=(message:string,status:number)=>new Response(JSON.stringify({error:message}),{status,headers:{'Content-Type':'application/json','Access-Control-Allow-Origin':origin,'Vary':'Origin'}});
  if(request.method!=='OPTIONS'){
   const authorization=request.headers.get('Authorization')||'';
   if(!authorization.startsWith('Bearer '))return reply('Entre no aplicativo para continuar.',401);
   const admin=createClient(Deno.env.get('SUPABASE_URL')||'',hsnApiKey('SUPABASE_SERVICE_ROLE_KEY')||'',{auth:{persistSession:false,autoRefreshToken:false}});
   const {data,error}=await admin.auth.getUser(authorization.slice(7));
   if(error||!data.user)return reply('Sessão inválida.',401);
   const owner=await admin.rpc('hsn_push_owner');
   if(owner.error||!owner.data||owner.data!==data.user.id)return reply('Acesso restrito ao proprietário configurado.',403);
  }
  return handler(request);
 });
}

function hsnApiKey(name:string):string|undefined{
 const mapping=name==='SUPABASE_SERVICE_ROLE_KEY'?'SUPABASE_SECRET_KEYS':'SUPABASE_PUBLISHABLE_KEYS';
 try{const keys=JSON.parse(Deno.env.get(mapping)||'{}');if(typeof keys.default==='string'&&keys.default)return keys.default;}catch{}
 return Deno.env.get(name);
}
