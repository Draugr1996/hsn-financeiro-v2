import {createClient} from 'npm:@supabase/supabase-js@2.119.0';
// Pure validation shared by the Edge Function and offline tests.
const SENDER='faturamento@hotelserranegra.com.br';
const SIGNATURE_URL=(Deno.env.get('HSN_APP_URL')||'http://localhost:8080/').replace(/\/?$/,'/')+'icons/assinatura-faturamento-v2.png';
const emailOK=(s:string)=>/^[^\s@;,]+@[^\s@;,]+\.[^\s@;,]+$/.test(s);
const addresses=(s:unknown)=>Array.isArray(s)?s.map(String):String(s||'').split(/[;,\n]+/).map(x=>x.trim()).filter(Boolean);
function validateRecipients(to:unknown,cc:unknown){const a=addresses(to),b=addresses(cc);
 if(!a.length||a.length>8||b.length>8||[...a,...b].some(x=>!emailOK(x))||new Set([...a,...b].map(x=>x.toLowerCase())).size!==a.length+b.length)throw Error('Destinatários inválidos ou repetidos (até 8 em Para e 8 em CC).');return {to:a,cc:b};}
function validateMessage(subject:unknown,content:unknown){const s=String(subject||'').trim(),c=String(content||'').trim();if(s.length<2||s.length>180||/[\r\n]/.test(s)||c.length<5||c.length>10000||/\{\{[^}]+\}\}/.test(s+c))throw Error('Confira assunto, mensagem e variáveis não preenchidas.');return {subject:s,content:c};}
const escapeHTML=(s:string)=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]||c));
const hash=async(v:BufferSource|string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',typeof v==='string'?new TextEncoder().encode(v):v)),x=>x.toString(16).padStart(2,'0')).join('');
function canonical(value:any):string{const normalize=(v:any):any=>Array.isArray(v)?v.map(normalize):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,normalize(v[k])])):v;return JSON.stringify(normalize(value));}
async function approval(id:string,owner:string,snapshot:unknown,secret:string,expires=Date.now()+900000){const body=JSON.stringify({id,owner,hash:await hash(canonical(snapshot)),expires});const k=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);return {body,signature:Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',k,new TextEncoder().encode(body))),x=>x.toString(16).padStart(2,'0')).join('')};}
async function verifyApproval(token:any,id:string,owner:string,snapshot:unknown,secret:string){try{const p=JSON.parse(token.body);if(p.id!==id||p.owner!==owner||p.expires<Date.now()||p.expires>Date.now()+900000)return false;const expected=await approval(id,owner,snapshot,secret,p.expires);return expected.body===token.body&&expected.signature===token.signature;}catch{return false;}}
function titleSnapshot(r:any){return {id:r.id,company:r.company,external_reference:r.external_reference,due_date:r.due_date,amount:Number(r.amount)};}
function validateTitles(rows:any[],ids:string[],_today:string){if(rows.length!==ids.length||!rows.length||rows.length>50||new Set(ids).size!==ids.length||new Set(rows.map(x=>x.company)).size!==1||rows.some(r=>!['pending','sent'].includes(String(r.status))||!r.external_reference||!Number.isFinite(Number(r.amount))||Number(r.amount)<=0))throw Error('Selecione somente títulos em aberto ou já cobrados, da mesma empresa e com dados válidos. Títulos pagos ou cancelados não podem receber nova cobrança.');return rows.map(titleSnapshot).sort((a,b)=>a.id.localeCompare(b.id));}
function sameTitles(rows:any[],snapshot:any[]){return canonical(rows.map(titleSnapshot).sort((a,b)=>a.id.localeCompare(b.id)))===canonical(snapshot);}
async function validateFile(f:File){if(!f.size||f.size>10485760||f.name.length>150||/[\\/\x00-\x1f]/.test(f.name)||! /\.(pdf|xml|png|jpe?g)$/i.test(f.name))throw Error('Anexo inválido: '+f.name);
 const b=new Uint8Array(await f.slice(0,200).arrayBuffer()),n=f.name.toLowerCase();
 if(n.endsWith('.pdf')&&String.fromCharCode(...b.slice(0,5))!=='%PDF-')throw Error('PDF inválido.');
 if(n.endsWith('.png')&&!(b[0]===137&&b[1]===80&&b[2]===78&&b[3]===71))throw Error('PNG inválido.');
 if(/\.jpe?g$/.test(n)&&!(b[0]===255&&b[1]===216))throw Error('JPEG inválido.');
 if(n.endsWith('.xml')&&!new TextDecoder().decode(b).replace(/^\uFEFF/,'').trimStart().startsWith('<'))throw Error('XML inválido.');
}

const env=(k:string)=>{const v=Deno.env.get(k);if(!v)throw Error('Configuração ausente: '+k);return v;};
const bucket='hsn-send-private';
const tokenCache=new Map<string,{expires:number,value:any}>();
const ok=(r:any)=>{if(r.error)throw Error(r.error.message);return r.data;};
const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
async function decrypt(value:string){const [iv,data]=value.split('.');const bytes=(s:string)=>Uint8Array.from(atob(s),x=>x.charCodeAt(0));const k=await crypto.subtle.importKey('raw',bytes(env('ZOHO_TOKEN_ENCRYPTION_KEY')),{name:'AES-GCM'},false,['decrypt']);return new TextDecoder().decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:bytes(iv)},k,bytes(data)));}
async function zohoAuth(admin:any,owner:string){const cached=tokenCache.get(owner);if(cached&&cached.expires>Date.now())return cached.value;const t=ok(await admin.from('zoho_mail_tokens').select('refresh_token,account_id').eq('user_id',owner).single());if(!t.account_id)throw Error('Configure a conta Zoho.');const r=await fetch('https://accounts.zoho.com/oauth/v2/token',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'refresh_token',client_id:env('ZOHO_CLIENT_ID'),client_secret:env('ZOHO_CLIENT_SECRET'),refresh_token:await decrypt(t.refresh_token)})});const a=await r.json();if(!r.ok||!a.access_token){const error:any=Error('Falha na autorização Zoho.');if(r.status===429)error.retry_after=Math.max(60,Number(r.headers.get('Retry-After'))||60);throw error;}const value={endpoint:'https://mail.zoho.com/api/accounts/'+encodeURIComponent(t.account_id)+'/messages',headers:{Authorization:'Zoho-oauthtoken '+a.access_token,Accept:'application/json'}};tokenCache.set(owner,{expires:Date.now()+Math.max(60,(Number(a.expires_in)||3600)-60)*1000,value});return value;}
async function titles(admin:any,owner:string,ids:string[]){return ok(await admin.from('sicoob_collections').select('id,owner_id,company,external_reference,due_date,amount,status').eq('owner_id',owner).in('id',ids));}
async function latestCollectionResendSource(admin:any,owner:string,collectionId:string){
 const jobs=ok(await admin.from('hsn_send_jobs').select('id,status,kind,snapshot,created_at').eq('owner_id',owner).eq('kind','collection').order('created_at',{ascending:false}).limit(1001));
 if(jobs.length>1000)throw Error('Histórico muito extenso para validar automaticamente. Confira o histórico antes de cobrar novamente.');
 const matching=jobs.filter((j:any)=>(j.snapshot?.titles||[]).some((t:any)=>t.id===collectionId));
 if(matching.some((j:any)=>!['sent','prepared','failed'].includes(String(j.status))))throw Error('A última tentativa está em processamento ou com resultado incerto. Confira o Zoho antes de uma nova cobrança.');
 const sent=matching.find((j:any)=>j.status==='sent');
 if(sent)return sent.id;
 const legacy=ok(await admin.from('sicoob_collection_dispatches').select('id,status').eq('owner_id',owner).eq('collection_id',collectionId).maybeSingle());
 if(legacy){
  if(legacy.status==='sent')return 'legacy:'+legacy.id;
  throw Error('Existe tentativa anterior no histórico antigo ('+legacy.status+'). Confira o Zoho antes de cobrar novamente.');
 }
 return null;
}
async function legacyCheck(admin:any,owner:string,s:any,ownIds:string[]=[]){if(s.resend_of)return;
 if(s.kind==='collection'){const r=ok(await admin.from('sicoob_collection_dispatches').select('id').eq('owner_id',owner).in('collection_id',s.titles.map((x:any)=>x.id)).limit(1));if(r.some((x:any)=>!ownIds.includes(x.id)))throw Error('Há tentativa no histórico anterior. Confira no Zoho; este título não será repetido.');}
 else {const all=ok(await admin.from('hsn_billing_dispatches').select('id,subject,file_names').eq('owner_id',owner).eq('subject',s.subject).in('status',['processing','sent','review']).order('created_at',{ascending:false}).limit(1001));if(all.length>1000)throw Error('Há mais de 1000 registros com este assunto. Confira o histórico antes de preparar.');
 const names=s.files.map((x:any)=>x.name).sort().join('|');if(all.some((x:any)=>{if(ownIds.includes(x.id))return false;const old=(x.file_names||[]).map((f:any)=>typeof f==='string'?f:f.nome||f.name).sort().join('|');return old===names&&x.subject===s.subject;}))throw Error('Documentos e assunto já constam do histórico anterior. Use segunda via após conferência.');}
}
async function handler(request:Request){const origin=request.headers.get('origin')||'',allowed=origin===new URL(Deno.env.get('HSN_APP_URL')||'http://localhost:8080/').origin||/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
 const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':allowed?origin:new URL(Deno.env.get('HSN_APP_URL')||'http://localhost:8080/').origin,'Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS','Vary':'Origin'};
 const respond=(data:any,status=200)=>new Response(JSON.stringify(data),{status,headers});
 if(request.method==='OPTIONS')return new Response(null,{status:allowed?204:403,headers});
 if(!allowed||request.method!=='POST')return respond({error:'Origem ou método não autorizado.'},403);
 let admin:any=null,owner='',job:any=null,claimed=false,submitted=false,confirmed=false,retry=0;
 try{const auth=request.headers.get('Authorization')||'';if(!auth.startsWith('Bearer '))return respond({error:'Login obrigatório.'},401);
 const client=createClient(env('SUPABASE_URL'),hsnApiKey('SUPABASE_ANON_KEY')||env('SB_PUBLISHABLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
 const u=await client.auth.getUser(auth.slice(7));if(u.error||!u.data.user)return respond({error:'Sessão inválida.'},401);owner=u.data.user.id;
 admin=createClient(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
 const multipart=(request.headers.get('content-type')||'').includes('multipart/form-data');let form:FormData|null=null;let body:any;
 if(multipart){form=await request.formData();body=JSON.parse(String(form.get('payload')||'{}'));}else body=await request.json();
 if(body.action==='capabilities'){ok(await admin.from('hsn_send_jobs').select('id').eq('owner_id',owner).limit(1));return respond({success:true,version:'9.9',max_files:3,max_titles:50,interval_seconds:6,signature_url:SIGNATURE_URL,manual_collection_resend:true,collection_due_date_restriction:false});}
 if(body.action==='attachment'){const j=ok(await admin.from('hsn_send_jobs').select('snapshot').eq('id',body.id).eq('owner_id',owner).single());const f=j.snapshot.files?.[Number(body.index)];if(!f||!f.path.startsWith(owner+'/'))throw Error('Anexo não localizado.');const signed=ok(await admin.storage.from(bucket).createSignedUrl(f.path,60,{download:f.name}));return respond({success:true,url:signed.signedUrl});}
 if(body.action==='prepare'){
  if(body.confirm_documents!==true)throw Error('Confirme a empresa e os documentos antes de preparar.');
  const kind=body.kind;if(!['billing','collection'].includes(kind))throw Error('Tipo inválido.');
  const rec=validateRecipients(body.to,body.cc),msg=validateMessage(body.subject,body.content);
  let s:any={kind,company:String(body.company||'').trim(),nf:String(body.nf||'').trim(),amount:body.amount==null||body.amount===''?null:Number(body.amount),due_date:String(body.due_date||''),...rec,...msg,files:[],titles:[]};
  if(s.company.length<2||s.company.length>120||kind==='billing'&&s.nf.length>35||s.amount!==null&&(!Number.isFinite(s.amount)||s.amount<0))throw Error('Confira a empresa e os dados do documento.');
  let picked:File[]=[];
  if(kind==='billing'){
   picked=Array.from(form?.getAll('files')||[]) as File[];if(!picked.length||picked.length>3||picked.reduce((v,f)=>v+f.size,0)>26214400)throw Error('Selecione 1 a 3 anexos, até 10 MB cada e 25 MB no total.');
   for(const f of picked){if(!(f instanceof File))throw Error('Anexo inválido.');await validateFile(f);s.files.push({name:f.name,size:f.size,type:f.type,hash:await hash(await f.arrayBuffer())});}
   if(new Set(s.files.map((x:any)=>x.hash)).size!==s.files.length)throw Error('Documento anexado duas vezes.');
  }else{
   const ids=body.collection_ids;if(!Array.isArray(ids)||!ids.every((x:any)=>typeof x==='string'))throw Error('Títulos inválidos.');
   s.titles=validateTitles(await titles(admin,owner,ids),ids,today());s.company=s.titles[0].company;s.amount=Math.round(s.titles.reduce((n:number,x:any)=>n+x.amount,0)*100)/100;
  }
  if(kind==='collection'){
   const sources=await Promise.all(s.titles.map((t:any)=>latestCollectionResendSource(admin,owner,t.id)));
   if(sources.some(Boolean)&&!body.resend_of)throw Error('Prepare um reenvio a partir do último envio confirmado.');
  }
  let resend='';
  if(body.resend_of){
   const reason=String(body.resend_reason||'').trim();
   if(reason.length<10)throw Error('Informe o motivo da nova cobrança (mínimo de 10 caracteres).');
   const sourceId=String(body.resend_of);
   const legacy=sourceId.startsWith('legacy:');
   const id=legacy?sourceId.slice(7):sourceId;
   if(kind==='billing'){
    const source=legacy?'hsn_billing_dispatches':'hsn_send_jobs';
    const prior=ok(await admin.from(source).select('*').eq('id',id).eq('owner_id',owner).single());
    if(prior.status!=='sent'||(!legacy&&prior.kind!=='billing')||(legacy?prior.company:prior.snapshot?.company)!==s.company)throw Error('Segunda via exige faturamento anterior confirmado da mesma empresa.');
   }else{
    const currentIds=s.titles.map((x:any)=>x.id).sort();
    if(legacy){
     const prior=ok(await admin.from('sicoob_collection_dispatches').select('id,owner_id,collection_id,status').eq('id',id).eq('owner_id',owner).single());
     if(prior.status!=='sent'||!currentIds.includes(prior.collection_id))throw Error('Nova cobrança exige uma tentativa anterior confirmada para o mesmo título.');
    }else{
     const prior=ok(await admin.from('hsn_send_jobs').select('id,owner_id,kind,status,snapshot').eq('id',id).eq('owner_id',owner).single());
     const priorIds=(prior.snapshot?.titles||[]).map((x:any)=>x.id).sort();
     if(prior.status!=='sent'||prior.kind!=='collection'||canonical(priorIds)!==canonical(currentIds))throw Error('Nova cobrança exige um envio anterior confirmado para os mesmos títulos.');
    }
   }
   s.resend_of=sourceId;
   s.resend_reason=reason.slice(0,500);
   resend=sourceId+':'+s.resend_reason;
  }
  const collectionIds=s.titles.map((x:any)=>x.id).sort();
  const fingerprint=await hash(JSON.stringify(kind==='billing'?[s.company.toLocaleLowerCase(),s.files.map((x:any)=>x.hash).sort(),resend]:(s.resend_of?[collectionIds,'manual-resend',resend]:collectionIds)));
  const prior=ok(await admin.from('hsn_send_jobs').select('*').eq('owner_id',owner).eq('kind',kind).eq('fingerprint',fingerprint).maybeSingle());
  await legacyCheck(admin,owner,s,prior?.legacy_ids||[]);
  if(prior&&!['prepared','failed'].includes(prior.status))return respond({error:'Envio já iniciado, confirmado ou incerto. Não será duplicado.',status:prior.status,id:prior.id},409);
  const id=prior?.id||crypto.randomUUID();
  for(let i=0;i<picked.length;i++){const f=s.files[i];f.path=owner+'/'+id+'/'+f.hash;ok(await admin.storage.from(bucket).upload(f.path,picked[i],{contentType:picked[i].type||'application/octet-stream',upsert:true}));}
  // Snapshot is replaced only before a claim. Unique fingerprint handles competing prepares.
  if(prior)ok(await admin.from('hsn_send_jobs').update({snapshot:s,status:'prepared',error_detail:null}).eq('id',id).eq('owner_id',owner).in('status',['prepared','failed']).select('id').single());
  else ok(await admin.from('hsn_send_jobs').insert({id,owner_id:owner,kind,fingerprint,snapshot:s}).select('id').single());
  return respond({success:true,id,snapshot:s,approval:await approval(id,owner,s,env('SUPABASE_SERVICE_ROLE_KEY'))});
 }
 if(body.action==='send'){
  if(body.confirm!=='ENVIAR_APROVADOS')throw Error('Confirmação obrigatória.');
  job=ok(await admin.from('hsn_send_jobs').select('*').eq('id',body.id).eq('owner_id',owner).single());
  if(!await verifyApproval(body.approval,job.id,owner,job.snapshot,env('SUPABASE_SERVICE_ROLE_KEY')))return respond({error:'Prévia expirada ou alterada. Confira novamente.'},409);
  await legacyCheck(admin,owner,job.snapshot,job.legacy_ids||[]);
  const s=ok(await admin.rpc(job.kind==='collection'?'hsn_collection_send_claim':'hsn_send_claim',{p_owner:owner,p_job:job.id,p_snapshot:job.snapshot}));claimed=true;
  const z=await zohoAuth(admin,owner);const attachments=[];
  for(const f of s.files||[]){if(!f.path.startsWith(owner+'/'))throw Error('Anexo de outro proprietário.');const data=ok(await admin.storage.from(bucket).download(f.path));const bytes=await data.arrayBuffer();if(await hash(bytes)!==f.hash)throw Error('Anexo alterado após a conferência.');
   const response=await fetch(z.endpoint+'/attachments?fileName='+encodeURIComponent(f.name)+'&isInline=false',{method:'POST',signal:AbortSignal.timeout(30000),headers:{...z.headers,'Content-Type':'application/octet-stream'},body:bytes});const result=await response.json().catch(()=>null);
   if(response.status===429)retry=Math.max(60,Number(response.headers.get('Retry-After'))||60);
   if(!response.ok||Number(result?.status?.code)!==200||!result.data?.attachmentPath||!result.data?.storeName||!result.data?.attachmentName)throw Error('Falha ao carregar anexo no Zoho; nenhum e-mail solicitado.');
   attachments.push({storeName:result.data.storeName,attachmentName:result.data.attachmentName,attachmentPath:result.data.attachmentPath});
  }
  const image=await fetch(SIGNATURE_URL,{signal:AbortSignal.timeout(10000)});if(!image.ok||!(image.headers.get('content-type')||'').includes('image/png'))throw Error('Assinatura institucional indisponível.');const bytes=new Uint8Array(await image.arrayBuffer());if(bytes.length>768000||bytes[0]!==137||bytes[1]!==80||bytes[2]!==78||bytes[3]!==71)throw Error('Assinatura institucional inválida.');
  // Recheck payments and snapshots immediately before requesting a message.
  if(s.kind==='collection'){const current=await titles(admin,owner,s.titles.map((x:any)=>x.id));validateTitles(current,s.titles.map((x:any)=>x.id),today());if(!sameTitles(current,s.titles))throw Error('Título alterado; nenhum e-mail solicitado.');}
  const html='<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.65">'+escapeHTML(s.content).replace(/\n/g,'<br>')+'<br><img src="'+SIGNATURE_URL+'" alt="Hotel Serra Negra — Vanderson Santos" width="520" style="max-width:100%;height:auto"></div>';
  submitted=true;
  const r=await fetch(z.endpoint,{method:'POST',signal:AbortSignal.timeout(30000),headers:{...z.headers,'Content-Type':'application/json'},body:JSON.stringify({fromAddress:SENDER,toAddress:s.to.join(','),ccAddress:s.cc.join(','),subject:s.subject,content:html,mailFormat:'html',attachments})});
  const result=await r.json().catch(()=>null);
  if(!r.ok||Number(result?.status?.code)!==200){if([400,401,403,413,429].includes(r.status)){submitted=false;if(r.status===401)tokenCache.delete(owner);if(r.status===429)retry=Math.max(60,Number(r.headers.get('Retry-After'))||60);}throw Error(submitted?'Zoho não confirmou; confira Enviados.':'Zoho rejeitou a solicitação (HTTP '+r.status+').');}
  confirmed=true;const message=String(result?.data?.messageId||result?.data?.messageDetails?.messageId||'').slice(0,150);
  ok(await admin.rpc('hsn_send_finish',{p_owner:owner,p_job:job.id,p_status:'sent',p_detail:'Aceito pelo Zoho',p_message:message||null}));
  // Atualiza a situação de cobrança sem sobrescrever títulos que tenham sido pagos/cancelados.
  if(s.kind==='collection'){
   const sentAt=new Date().toISOString();
   const updated=await admin.from('sicoob_collections').update({status:'sent',sent_at:sentAt}).eq('owner_id',owner).in('id',s.titles.map((x:any)=>x.id)).in('status',['pending','sent']).select('id');
   if(updated.error)return respond({success:true,status:'sent',id:job.id,message_id:message||null,warning:'E-mail aceito pelo Zoho, mas não foi possível atualizar a situação do título. Confira o registro sem reenviar.'});
   if((updated.data||[]).length!==s.titles.length)return respond({success:true,status:'sent',id:job.id,message_id:message||null,warning:'E-mail aceito pelo Zoho. Um ou mais títulos mudaram de situação durante o envio; confira o cadastro antes de qualquer nova cobrança.'});
  }
  // New history remains authoritative; preserve all legacy rows, never rewrite them.
  return respond({success:true,status:'sent',id:job.id,message_id:message||null});
 }
 return respond({error:'Operação inválida.'},400);
 }catch(e){retry=Math.max(retry,Number((e as any).retry_after)||0);let state=claimed?(submitted||confirmed?'review':'failed'):undefined;
 if(claimed&&job){try{ok(await admin.rpc('hsn_send_finish',{p_owner:owner,p_job:job.id,p_status:state,p_detail:state==='review'?'Resultado incerto: confira Enviados antes de qualquer ação.':String((e as Error).message),p_retry:retry}));}catch{state='review';}}
 return respond({success:false,status:state,error:state==='review'?'Resultado incerto. Confira o Zoho e o histórico. Reenvio bloqueado.':String((e as Error).message||'Falha na operação.'),retry_after:retry},state==='review'?502:409);
 }
}


const sendHandler=handler;
(()=>{

const REMETENTE = "faturamento@hotelserranegra.com.br";

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(
    binary,
    (char) => char.charCodeAt(0),
  );
}

async function decryptToken(
  encrypted: string,
  keyBase64: string,
): Promise<string> {
  const [ivBase64, dataBase64] = encrypted.split(".");

  if (!ivBase64 || !dataBase64) {
    throw new Error("Invalid encrypted token");
  }

  const key = await crypto.subtle.importKey(
    "raw",
    fromBase64(keyBase64),
    { name: "AES-GCM" },
    false,
    ["decrypt"],
  );

  const decrypted = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: fromBase64(ivBase64),
    },
    key,
    fromBase64(dataBase64),
  );

  return new TextDecoder().decode(decrypted);
}

function validEmail(email: string): boolean {
  return /^[^\s@;,]+@[^\s@;,]+\.[^\s@;,]+$/.test(email);
}

function formatDate(value: string): string {
  const parts = value.split("-");

  if (parts.length !== 3) {
    return value;
  }

  return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

function formatMoney(value: number): string {
  return Number(value).toLocaleString("pt-BR", {
    style: "currency",
    currency: "BRL",
  });
}

serveIsolated(async (request: Request) => {
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin":
      new URL(Deno.env.get("HSN_APP_URL")||"http://localhost:8080/").origin,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };

  const respond = (data: object, status = 200) => {
    return new Response(JSON.stringify(data), {
      status,
      headers,
    });
  };

  if (request.method === "OPTIONS") {
    return new Response(null, { headers });
  }

  if (request.method !== "POST") {
    return respond(
      { error: "Method not allowed" },
      405,
    );
  }

  try {
    // ============================================
    // 1. AUTENTICAÇÃO
    // ============================================

    const authorization =
      request.headers.get("Authorization");

    if (!authorization?.startsWith("Bearer ")) {
      return respond(
        { error: "Login required" },
        401,
      );
    }

    const supabaseUrl =
      Deno.env.get("SUPABASE_URL");

    const anonKey =
      hsnApiKey("SUPABASE_ANON_KEY") ??
      Deno.env.get("SB_PUBLISHABLE_KEY");

    const serviceKey =
      hsnApiKey("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceKey) {
      throw new Error("Missing Supabase configuration");
    }

    const authClient = createClient(
      supabaseUrl,
      anonKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    );

    const jwt = authorization.slice(7);

    const { data: userData, error: userError } =
      await authClient.auth.getUser(jwt);

    if (userError || !userData.user) {
      return respond(
        { error: "Invalid session" },
        401,
      );
    }

    const userId = userData.user.id;

    // ============================================
    // 2. CLIENTE ADMINISTRATIVO
    // ============================================

    const admin = createClient(
      supabaseUrl,
      serviceKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    );

    // ============================================
    // 3. IDENTIFICAR OPERAÇÃO
    // ============================================

    if((request.headers.get("content-type")||"").includes("multipart/form-data"))return await sendHandler(request);
    const body = await request.json().catch(() => ({}));

    if(body.action)return await sendHandler(new Request(request.url,{method:"POST",headers:request.headers,body:JSON.stringify(body)}));
    const mode = body?.mode ?? "setup";

    // 9.9: cobranças manuais usam prévia assinada, histórico e trava contra duplicidade.
    if(mode==='preview'||mode==='send_individual'){
     const invoke=async(payload:any)=>sendHandler(new Request(request.url,{method:'POST',headers:request.headers,body:JSON.stringify(payload)}));
     if(mode==='preview'){
      const r=await admin.from('sicoob_collections').select('company,external_reference,due_date,amount,status').eq('id',body.collection_id).eq('owner_id',userId).single();
      if(r.error||!r.data)return respond({error:'Título não localizado'},404);
      if(!['pending','sent'].includes(String(r.data.status)))return respond({error:'Este título não está em aberto para cobrança. Verifique se já foi pago ou cancelado.'},409);
      const c=await admin.from('sicoob_contacts').select('email').eq('owner_id',userId).eq('company',r.data.company).single();
      if(c.error||!c.data)return respond({error:'Destinatários não localizados'},409);
      const addresses=String(c.data.email).split(/[;,\n]+/).map((x:string)=>x.trim()).filter(Boolean),t=r.data;
      const resendOf=body.resend_of?String(body.resend_of):await latestCollectionResendSource(admin,userId,String(body.collection_id));
      const resendReason=String(body.resend_reason||'Nova cobrança solicitada manualmente no Financeiro HSN.');
      const preparePayload:any={action:'prepare',kind:'collection',collection_ids:[body.collection_id],company:t.company,to:[addresses[0]],cc:addresses.slice(1),subject:(resendOf?'Reenvio de cobrança':'Hotel Serra Negra | Pendência financeira')+' | '+t.external_reference,content:'Prezados(as),\n\nIdentificamos em nosso controle financeiro uma pendência referente ao documento '+t.external_reference+' da empresa '+t.company+', com vencimento em '+formatDate(t.due_date)+' e valor de '+formatMoney(t.amount)+'. Caso o pagamento já tenha sido realizado, pedimos a gentileza de desconsiderar esta mensagem e, se possível, encaminhar o comprovante para atualização de nossos registros.\n\nAtenciosamente,\nVanderson Santos\nHotel Serra Negra',confirm_documents:true};
      if(resendOf){preparePayload.resend_of=resendOf;preparePayload.resend_reason=resendReason;}
      const result=await invoke(preparePayload);
      if(!result.ok)return result;const p=await result.json();
      return respond({success:true,mode:'preview',sending_enabled:false,collection_id:body.collection_id,company:t.company,document_number:t.external_reference,due_date:t.due_date,amount:t.amount,to:addresses[0],cc:addresses.slice(1),subject:p.snapshot.subject,content:p.snapshot.content,approval_token:JSON.stringify({id:p.id,approval:p.approval}),approval_expires_seconds:900});
     }
     let token;try{token=JSON.parse(body.approval_token);}catch{return respond({error:'Refaça a conferência antes de enviar'},409);}
     const approved=await admin.from('hsn_send_jobs').select('kind,snapshot').eq('id',token.id).eq('owner_id',userId).single();
     if(approved.error||approved.data?.kind!=='collection'||approved.data.snapshot?.titles?.length!==1||approved.data.snapshot.titles[0].id!==body.collection_id)return respond({error:'Autorização pertence a outro título.'},409);
     return await invoke({action:'send',id:token.id,approval:token.approval,confirm:'ENVIAR_APROVADOS'});
    }

    // ============================================
    // 5. TESTE CONTROLADO DE ENVIO
    //    SOMENTE PARA O E-MAIL DO HOTEL
    // ============================================

    if (mode === "test_send") {
      if (body.confirm !== "ENVIAR_TESTE_HSN") {
        return respond(
          {
            error:
              "Confirmação explícita obrigatória",
          },
          400,
        );
      }

      const clientId =
        Deno.env.get("ZOHO_CLIENT_ID");

      const clientSecret =
        Deno.env.get("ZOHO_CLIENT_SECRET");

      const encryptionKey =
        Deno.env.get("ZOHO_TOKEN_ENCRYPTION_KEY");

      if (
        !clientId ||
        !clientSecret ||
        !encryptionKey
      ) {
        return respond(
          {
            error:
              "Configuração Zoho incompleta",
          },
          500,
        );
      }

      const {
        data: stored,
        error: readError,
      } = await admin
        .from("zoho_mail_tokens")
        .select("refresh_token, account_id")
        .eq("user_id", userId)
        .maybeSingle();

      if (readError || !stored?.account_id) {
        return respond(
          { error: "Zoho não conectado" },
          404,
        );
      }

      const refreshToken = await decryptToken(
        stored.refresh_token,
        encryptionKey,
      );

      const tokenResponse = await fetch(
        "https://accounts.zoho.com/oauth/v2/token",
        {
          method: "POST",
          headers: {
            "Content-Type":
              "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({
            grant_type: "refresh_token",
            client_id: clientId,
            client_secret: clientSecret,
            refresh_token: refreshToken,
          }),
        },
      );

      const tokenData =
        await tokenResponse.json();

      if (
        !tokenResponse.ok ||
        !tokenData.access_token
      ) {
        return respond(
          {
            error:
              "Falha ao renovar autorização Zoho",
          },
          502,
        );
      }

      const subject =
        "Hotel Serra Negra | TESTE CONTROLADO - NAO E COBRANCA";

      const content = [
        "TESTE CONTROLADO - NAO E COBRANCA",
        "",
        "Esta mensagem confirma o funcionamento",
        "da integracao entre Financeiro HSN e Zoho Mail.",
        "",
        "Nenhum cliente foi envolvido.",
        "Nenhum boleto foi alterado.",
        "",
        "Hotel Serra Negra",
      ].join("\n");

      const sendResponse = await fetch(
        `https://mail.zoho.com/api/accounts/${
          encodeURIComponent(String(stored.account_id))
        }/messages`,
        {
          method: "POST",
          headers: {
            Authorization:
              `Zoho-oauthtoken ${tokenData.access_token}`,
            "Content-Type": "application/json",
            Accept: "application/json",
          },
          body: JSON.stringify({
            fromAddress: REMETENTE,
            toAddress: REMETENTE,
            subject,
            content,
            mailFormat: "plaintext",
          }),
        },
      );

      const sendData = await sendResponse.json()
        .catch(() => null);

      if (
        !sendResponse.ok ||
        (
          sendData?.status?.code &&
          Number(sendData.status.code) !== 200
        )
      ) {
        console.error("Zoho test send failed:", {
          httpStatus: sendResponse.status,
          zohoCode: sendData?.status?.code,
        });

        return respond(
          {
            success: false,
            error:
              "Falha no envio de teste pelo Zoho",
          },
          502,
        );
      }

      return respond({
        success: true,
        test_only: true,
        recipient: REMETENTE,
        message:
          "Mensagem de teste aceita pelo Zoho.",
      });
    }

    // ============================================
    // 6. BLOQUEAR ENVIO REAL DE COBRANÇAS
    // ============================================

    if (mode !== "setup") {
      return respond(
        {
          error:
            "Operação não habilitada. O envio real de cobranças permanece bloqueado.",
          sending_enabled: false,
        },
        403,
      );
    }

    // ============================================
    // 7. CONFIGURAÇÃO ORIGINAL DA CONTA ZOHO
    // ============================================

    const clientId =
      Deno.env.get("ZOHO_CLIENT_ID");

    const clientSecret =
      Deno.env.get("ZOHO_CLIENT_SECRET");

    const encryptionKey =
      Deno.env.get("ZOHO_TOKEN_ENCRYPTION_KEY");

    if (
      !clientId ||
      !clientSecret ||
      !encryptionKey
    ) {
      throw new Error("Missing Zoho configuration");
    }

    const {
      data: stored,
      error: readError,
    } = await admin
      .from("zoho_mail_tokens")
      .select("refresh_token")
      .eq("user_id", userId)
      .maybeSingle();

    if (readError || !stored) {
      return respond(
        { error: "Zoho not connected" },
        404,
      );
    }

    const refreshToken = await decryptToken(
      stored.refresh_token,
      encryptionKey,
    );

    const tokenResponse = await fetch(
      "https://accounts.zoho.com/oauth/v2/token",
      {
        method: "POST",
        headers: {
          "Content-Type":
            "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          grant_type: "refresh_token",
          client_id: clientId,
          client_secret: clientSecret,
          refresh_token: refreshToken,
        }),
      },
    );

    const tokenData =
      await tokenResponse.json();

    if (
      !tokenResponse.ok ||
      !tokenData.access_token
    ) {
      return respond(
        {
          error:
            "Zoho token refresh failed",
        },
        502,
      );
    }

    const accountsResponse = await fetch(
      "https://mail.zoho.com/api/accounts",
      {
        headers: {
          Authorization:
            `Zoho-oauthtoken ${tokenData.access_token}`,
          Accept: "application/json",
        },
      },
    );

    const accountsData =
      await accountsResponse.json();

    if (!accountsResponse.ok) {
      return respond(
        {
          error:
            "Zoho accounts lookup failed",
        },
        502,
      );
    }

    const accounts = Array.isArray(
      accountsData.data,
    )
      ? accountsData.data
      : [];

    const account = accounts.find(
      (item: any) => {
        const addresses = [
          item.primaryEmailAddress,
          item.mailboxAddress,
          ...(
            Array.isArray(item.sendMailDetails)
              ? item.sendMailDetails.flatMap(
                  (detail: any) => [
                    detail.fromAddress,
                    detail.emailAddress,
                  ],
                )
              : []
          ),
        ];

        return addresses.some(
          (address) =>
            String(address ?? "").toLowerCase() ===
            REMETENTE.toLowerCase(),
        );
      },
    );

    if (!account?.accountId) {
      return respond(
        {
          error:
            "Sender account not found",
          sender: REMETENTE,
        },
        404,
      );
    }

    const {
      error: updateError,
    } = await admin
      .from("zoho_mail_tokens")
      .update({
        account_id: String(account.accountId),
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId);

    if (updateError) {
      throw updateError;
    }

    return respond({
      success: true,
      sender: REMETENTE,
      account_configured: true,
      sending_enabled: false,
    });
  } catch (error) {
    console.error(
      "Zoho function error:",
      error,
    );

    return respond(
      {
        error:
          "Falha ao processar solicitação",
      },
      500,
    );
  }
});
})();

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
   if(Deno.env.get('HSN_ENABLE_EMAIL')!=='true')return reply('Integração desativada neste clone. Conclua a configuração e a homologação.',503);
  }
  return handler(request);
 });
}

function hsnApiKey(name:string):string|undefined{
 const mapping=name==='SUPABASE_SERVICE_ROLE_KEY'?'SUPABASE_SECRET_KEYS':'SUPABASE_PUBLISHABLE_KEYS';
 try{const keys=JSON.parse(Deno.env.get(mapping)||'{}');if(typeof keys.default==='string'&&keys.default)return keys.default;}catch{}
 return Deno.env.get(name);
}
