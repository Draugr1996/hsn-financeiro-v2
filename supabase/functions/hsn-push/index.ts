// @ts-nocheck
// Arquivo completo para o editor da Edge Function hsn-push.
import {createClient} from "npm:@supabase/supabase-js@2.102.0";
import webpush from "npm:web-push@3.6.7";
import {createECDH} from "node:crypto";
import {Buffer} from "node:buffer";
(function(root){'use strict';
const pad=n=>String(n).padStart(2,'0');
function parse(s){if(!/^\d{4}-\d{2}-\d{2}$/.test(s||''))throw Error('Data inválida');const [y,m,d]=s.split('-').map(Number);const t=new Date(Date.UTC(y,m-1,d));if(format(t)!==s)throw Error('Data inválida');return t;}
function format(d){return d.getUTCFullYear()+'-'+pad(d.getUTCMonth()+1)+'-'+pad(d.getUTCDate());}
function add(s,n){const d=parse(s);d.setUTCDate(d.getUTCDate()+n);return format(d);}
function today(){return new Intl.DateTimeFormat('sv-SE',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());}
function monthDay(month,day){const [y,m]=month.split('-').map(Number);if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(month))throw Error('Competência inválida');return `${month}-${pad(Math.min(Number(day),new Date(Date.UTC(y,m,0)).getUTCDate()))}`;}
function easter(y){const a=y%19,b=Math.floor(y/100),c=y%100,d=Math.floor(b/4),e=b%4,f=Math.floor((b+8)/25),g=Math.floor((b-f+1)/3),h=(19*a+b-d-g+15)%30,i=Math.floor(c/4),k=c%4,l=(32+2*e+2*i-h-k)%7,m=Math.floor((a+11*h+22*l)/451),mo=Math.floor((h+l-7*m+114)/31),da=(h+l-7*m+114)%31+1;return `${y}-${pad(mo)}-${pad(da)}`;}
function holidays(year,custom=[]){const map=new Map();for(const [s,name]of [['01-01','Confraternização Universal'],['04-21','Tiradentes'],['05-01','Dia do Trabalho'],['09-07','Independência do Brasil'],['10-12','Nossa Senhora Aparecida'],['11-02','Finados'],['11-15','Proclamação da República'],['12-25','Natal']])map.set(year+'-'+s,name);if(year>=2024)map.set(year+'-11-20','Consciência Negra');const e=easter(year);for(const [offset,name]of [[-48,'Carnaval (segunda)'],[-47,'Carnaval (terça)'],[-2,'Sexta-feira Santa'],[60,'Corpus Christi']])map.set(add(e,offset),name);for(const h of custom){const date=h.annually?year+h.holiday_date.slice(4):h.holiday_date;if(Number(date.slice(0,4))===year){try{parse(date);map.set(date,(map.has(date)?map.get(date)+' · ':'')+h.name);}catch{}}}return map;}
function business(s,custom=[]){const d=parse(s);return ![0,6].includes(d.getUTCDay())&&!holidays(d.getUTCFullYear(),custom).has(s);}
function adjust(s,rule,custom=[]){if(rule==='keep')return s;if(!['before','after'].includes(rule))throw Error('Regra inválida');let result=s,count=0;while(!business(result,custom)){result=add(result,rule==='before'?-1:1);if(++count>370)throw Error('Não há dia útil disponível');}return result;}
function br(s){return s?s.slice(8,10)+'/'+s.slice(5,7)+'/'+s.slice(0,4):'—';}
function status(p){return p.payment_status==='paid'?'paid':p.due_date<today()?'overdue':p.due_date===today()?'today':'upcoming';}
root.HSN_DATES={parse,format,add,today,monthDay,easter,holidays,business,adjust,br,status};
})(typeof window!=='undefined'?window:globalThis);

/* Regras puras, testáveis. Alertas de contas e comissões nunca se somam. */
(function(root){'use strict';
const payableDefaults={lead_days:[7,3,1,0],variation_percent:30,daily_summary:true,missing_documents:true,missing_bill:true,waiting_approval:true,variation_alert:true};
const commissionDefaults={lead_days:[7,3,1,0],daily_summary:true,monthly_reminder:true,review_day:5,checklist_template:['Conferir reservas e competências','Conferir percentuais e bases de cálculo','Conferir cancelamentos e no-shows','Conferir divergências com a agência','Registrar conclusão da conferência']};
const delta=(from,to)=>Math.round((HSN_DATES.parse(to)-HSN_DATES.parse(from))/86400000);
function history(accounts,p){if(!p.model_id)return [];return accounts.filter(r=>r.id!==p.id&&r.model_id===p.model_id&&r.payment_status==='paid'&&!r.archived&&r.competence<p.competence&&r.actual_amount!==null).sort((a,b)=>b.competence.localeCompare(a.competence)).slice(0,3);}
function variation(accounts,p,percent=30){if(p.actual_amount===null||p.actual_amount===undefined)return null;const h=history(accounts,p);if(!h.length)return null;const mean=h.reduce((n,r)=>n+Number(r.actual_amount),0)/h.length;const current=Number(p.actual_amount),increase=mean===0?(current>0?Infinity:0):(current-mean)/mean*100;if(!(current>mean*(1+Number(percent)/100)+0.000001))return null;return {history:h,mean,current,increase,threshold:Number(percent)};}
function payables(accounts,documents,config={},today=HSN_DATES.today()){
 const s={...payableDefaults,...config},out=[];
 const push=(p,category,detail,severity='info')=>out.push({id:p.id+':'+category,module:'payables',record_id:p.id,title:p.title,date:p.due_date,category,detail,severity});
 for(const p of accounts){if(p.archived)continue;const unpaid=p.payment_status!=='paid',diff=delta(today,p.due_date),files=documents.filter(d=>d.payable_id===p.id),month=p.competence.slice(0,7);
 if(unpaid){if(diff<0)push(p,'overdue',Math.abs(diff)+' dia(s) de atraso','danger');else if(diff===0)push(p,'today','Vence hoje','warning');else if(s.lead_days.includes(diff))push(p,'upcoming','Vence em '+diff+' dia(s)','info');
 if(s.missing_bill&&p.arrival_day){const arrival=HSN_DATES.monthDay(month,p.arrival_day);if(today>arrival&&!files.some(d=>d.document_type==='boleto'))push(p,'missing_bill','Boleto esperado desde '+HSN_DATES.br(arrival),'warning');}
 if(s.waiting_approval&&p.approval_status==='waiting')push(p,'approval','Aguardando aprovação externa','warning');}
 if(s.missing_documents){const missing=(p.required_documents||[]).filter(k=>!files.some(d=>d.document_type===k));if(missing.length)push(p,'documents','Faltam: '+missing.map(k=>({boleto:'boleto',nota_fiscal:'nota fiscal',comprovante:'comprovante',outros:'outros'}[k]||k)).join(', '),'warning');}
 if(s.variation_alert){const v=variation(accounts,p,s.variation_percent);if(v){const change=Number.isFinite(v.increase)?v.increase.toFixed(1).replace('.',',')+'%':'média anterior zero';push(p,'variation','Valor acima da média: '+change+' (limite '+s.variation_percent+'%)','warning');out[out.length-1].variation=v;}}
 }
 const weight={danger:0,warning:1,info:2};return out.sort((a,b)=>weight[a.severity]-weight[b.severity]||a.date.localeCompare(b.date)||a.title.localeCompare(b.title));
}
function commissions(records,reviews,config={},today=HSN_DATES.today()){
 const s={...commissionDefaults,...config},out=[];
 for(const c of records){if(c.archived||c.review_status==='confirmed')continue;const diff=delta(today,c.due_date);let category='',detail='';if(diff<0){category='overdue';detail='Conferência atrasada há '+Math.abs(diff)+' dia(s)';}else if(diff===0){category='today';detail='Conferir hoje';}else if(s.lead_days.includes(diff)){category='upcoming';detail='Conferir em '+diff+' dia(s)';}if(category)out.push({id:c.id+':'+category,module:'commissions',record_id:c.id,title:c.title,date:c.due_date,category,detail,severity:category==='overdue'?'danger':category==='today'?'warning':'info'});}
 const month=today.slice(0,7),date=HSN_DATES.monthDay(month,s.review_day),review=reviews.find(r=>r.competence===month+'-01');
 if(s.monthly_reminder&&review?.review_status!=='completed'){const diff=delta(today,date);if(diff<=0||s.lead_days.includes(diff))out.unshift({id:'monthly:'+month,module:'commissions',record_id:review?.id||null,title:'Conferência mensal de comissões',date,category:'monthly',detail:diff<0?'Checklist mensal ainda não concluído':diff===0?'Dia da conferência mensal':'Checklist mensal em '+diff+' dia(s)',severity:diff<0?'danger':'warning',month});}
 return out.sort((a,b)=>a.date.localeCompare(b.date));
}
function summary(records,module,today=HSN_DATES.today()){const active=records.filter(r=>!r.archived&&(module==='payables'?r.payment_status!=='paid':r.review_status!=='confirmed'));const weekEnd=HSN_DATES.add(today,7);const dueToday=active.filter(r=>r.due_date===today),week=active.filter(r=>r.due_date>today&&r.due_date<=weekEnd),late=active.filter(r=>r.due_date<today);return {module,today:dueToday,week,late};}
root.HSN_ALERT_ENGINE={payableDefaults,commissionDefaults,delta,history,variation,payables,commissions,summary};
})(typeof window!=='undefined'?window:globalThis);

/* Resumos push: dados separados, sem nomes, documentos ou valores no payload. */
(function(root){'use strict';
const modules=['payables','commissions','dda'];
function allowedEndpoint(endpoint){try{const u=new URL(endpoint);return u.protocol==='https:'&&!u.username&&!u.password&&!u.port&&!u.search&&!u.hash&&((u.hostname==='fcm.googleapis.com'&&(/^\/fcm\/send\//.test(u.pathname)||/^\/wp\//.test(u.pathname)))||(u.hostname==='updates.push.services.mozilla.com'&&/^\/wpush\//.test(u.pathname))||(u.hostname==='web.push.apple.com'&&u.pathname.length>1));}catch{return false;}}
function localClock(now=new Date()){const parts=new Intl.DateTimeFormat('sv-SE',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(now);const value=k=>parts.find(p=>p.type===k).value;return {date:value('year')+'-'+value('month')+'-'+value('day'),minute:Number(value('hour'))*60+Number(value('minute'))};}
function due(setting,clock){const start=Number(setting.send_hour)*60+Number(setting.send_minute);return setting.enabled&&clock.minute>=start&&clock.minute<=Math.min(start+120,1439);}
function payload(context,module,setting,today){if(!modules.includes(module))throw Error('Módulo inválido');const E=root.HSN_ALERT_ENGINE,D=root.HSN_DATES;let body='',hasContent=false;
 if(module==='payables'){const alerts=E.payables(context.payables,context.documents,context.payable_settings,today),summary=E.summary(context.payables,'payables',today);const count=k=>alerts.filter(a=>a.category===k).length;
 const adjustments=context.models.filter(m=>m.active&&m.contract_adjustment_date&&D.add(today,Number(m.contract_notice_days??30))>=m.contract_adjustment_date).length;
 body=count('overdue')+' vencida(s) · '+count('today')+' vence(m) hoje · '+count('upcoming')+' aviso(s) antecipado(s)';if(setting.include_week)body+=' · '+summary.week.length+' nos próximos 7 dias';for(const [key,label] of [['documents','com documentos faltantes'],['missing_bill','com boleto atrasado'],['approval','aguardando aprovação'],['variation','com variação de valor']])if(count(key))body+=' · '+count(key)+' '+label;if(adjustments)body+=' · '+adjustments+' reajuste(s)';hasContent=alerts.length>0||(setting.include_week&&summary.week.length>0)||adjustments>0;
 }else if(module==='commissions'){const alerts=E.commissions(context.commissions,context.reviews,context.commission_settings,today),summary=E.summary(context.commissions,'commissions',today);const count=k=>alerts.filter(a=>a.category===k).length;body=count('overdue')+' conferência(s) atrasada(s) · '+count('today')+' para hoje · '+count('upcoming')+' aviso(s) antecipado(s)';if(setting.include_week)body+=' · '+summary.week.length+' nos próximos 7 dias';if(count('monthly'))body+=' · checklist mensal pendente';hasContent=alerts.length>0||(setting.include_week&&summary.week.length>0);
 }else{const rows=context.dda.filter(r=>!r.archived&&!r.converted_payable_id&&!r.reviewed);body=rows.length+' cobrança(s) DDA aguardando conferência';hasContent=rows.length>0;}
 const title=module==='payables'?'HSN · Contas a pagar':module==='commissions'?'HSN · Comissões':'HSN · DDA';return {module,title,body:body+'. Abra o app para conferir.',view:module==='payables'?'alerts':module==='commissions'?'commission_alerts':'dda',tag:'hsn-'+module+'-'+today,hasContent};
}
root.HSN_PUSH_ENGINE={modules,allowedEndpoint,localClock,due,payload};
})(typeof window!=='undefined'?window:globalThis);

// Backend exclusivo: os três segredos existem somente no painel do Supabase.
const APP_URL=Deno.env.get('HSN_APP_URL')||'http://localhost:8080/';
const SUPABASE_URL=Deno.env.get('SUPABASE_URL')||'';
const admin=createClient(SUPABASE_URL,hsnApiKey('SUPABASE_SERVICE_ROLE_KEY')||'',{auth:{persistSession:false,autoRefreshToken:false}});
const allowedOrigins=new Set([new URL(APP_URL).origin,'https://run.spck.io']);
const good=result=>{if(result.error)throw Error('Falha na consulta de notificações.');return result.data;};
async function equalSecret(a,b){if(!a||!b||a.length>256||b.length>256)return false;const hash=async v=>new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(v)));const [x,y]=await Promise.all([hash(a),hash(b)]);let diff=0;for(let i=0;i<x.length;i++)diff|=x[i]^y[i];return diff===0;}
function publicKey(){const key=Deno.env.get('HSN_VAPID_PUBLIC_KEY')||'';if(!/^[A-Za-z0-9_-]{87}$/.test(key))throw Error('Configure HSN_VAPID_PUBLIC_KEY nos Secrets da função.');return key;}
function vapid(){const publicKeyValue=publicKey(),privateKey=Deno.env.get('HSN_VAPID_PRIVATE_KEY')||'';if(!/^[A-Za-z0-9_-]{43}$/.test(privateKey))throw Error('Configure HSN_VAPID_PRIVATE_KEY nos Secrets da função.');const ec=createECDH('prime256v1');ec.setPrivateKey(Buffer.from(privateKey,'base64url'));if(ec.getPublicKey().toString('base64url')!==publicKeyValue)throw Error('As chaves VAPID não pertencem ao mesmo par.');return {subject:(Deno.env.get('HSN_VAPID_SUBJECT')||'mailto:faturamento@hotelserranegra.com.br'),publicKey:publicKeyValue,privateKey};}
async function smallJson(request){const reader=request.body?.getReader();if(!reader)return {};const chunks=[];let size=0;while(true){const part=await reader.read();if(part.done)break;size+=part.value.byteLength;if(size>2048){await reader.cancel();throw Error('BODY_TOO_LARGE');}chunks.push(part.value);}const all=new Uint8Array(size);let at=0;for(const chunk of chunks){all.set(chunk,at);at+=chunk.byteLength;}const input=JSON.parse(new TextDecoder().decode(all)||'{}');if(!input||Array.isArray(input)||typeof input!=='object')throw Error('BAD_JSON');return input;}
export async function handler(request){
 const origin=request.headers.get('origin')||'';const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':allowedOrigins.has(origin)?origin:new URL(APP_URL).origin,'Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type,x-supabase-client-platform,x-supabase-client-platform-version,x-supabase-client-runtime,x-supabase-client-runtime-version','Access-Control-Allow-Methods':'POST,OPTIONS','Vary':'Origin'};
 const reply=(data,status=200)=>new Response(JSON.stringify(data),{status,headers});
 if(origin&&!allowedOrigins.has(origin))return reply({error:'Origem não autorizada.'},403);
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(request.method!=='POST')return reply({error:'Use POST.'},405);
 let runToken=null;
 try{
  const cron=await equalSecret(request.headers.get('x-hsn-cron-key')||'',Deno.env.get('HSN_CRON_KEY')||'');
  let caller=null;if(!cron){const authorization=request.headers.get('Authorization')||'';if(!authorization.startsWith('Bearer ')||authorization.length>8192)return reply({error:'Entre no app antes de continuar.'},401);const auth=await admin.auth.getUser(authorization.slice(7));if(auth.error||!auth.data?.user)return reply({error:'Sessão inválida. Entre novamente.'},401);caller=auth.data.user.id;}
  const owner=good(await admin.rpc('hsn_push_owner'));if(!owner)throw Error('Proprietário não configurado no banco.');if(!cron&&caller!==owner)return reply({error:'Acesso negado.'},403);
  let input;try{input=await smallJson(request);}catch(e){return reply({error:e.message==='BODY_TOO_LARGE'?'Requisição muito grande.':'JSON inválido.'},e.message==='BODY_TOO_LARGE'?413:400);}
  if(input.action==='config'&&!cron){const key=publicKey();return reply({publicKey:key,appUrl:APP_URL});}
  if((cron&&input.action!=='scheduled')||(!cron&&input.action!=='test'))return reply({error:'Ação não autorizada.'},403);
  if(!cron&&(!HSN_PUSH_ENGINE.modules.includes(input.module)||!/^[0-9a-f-]{36}$/i.test(input.subscription_id||'')))return reply({error:'Escolha aparelho e módulo válidos.'},400);
  const keys=vapid();runToken=good(await admin.rpc('hsn_push_begin',{p_owner:owner,p_kind:cron?'scheduled':'test'}));if(!runToken)return reply({error:'Aguarde 30 segundos e tente novamente. Pode haver outro envio em andamento.'},429);
  const context=good(await admin.rpc('hsn_push_context',{p_owner:owner})),clock=HSN_PUSH_ENGINE.localClock();
  const results=[];let work=[];
  for(const setting of context.settings){if(!cron&&setting.module!==input.module)continue;if(cron&&!HSN_PUSH_ENGINE.due(setting,clock))continue;
   const content=HSN_PUSH_ENGINE.payload(context,setting.module,setting,clock.date);if(cron&&!content.hasContent&&!setting.notify_empty)continue;
   for(const subscription of context.subscriptions){if(!subscription[setting.module]||(!cron&&subscription.id!==input.subscription_id))continue;work.push({setting,content,subscription});}
  }
  // No máximo 5 aparelhos x 3 módulos; até três envios simultâneos com tempo limite.
  for(let offset=0;offset<work.length;offset+=3){const outcomes=await Promise.allSettled(work.slice(offset,offset+3).map(async({setting,content,subscription})=>{
   const claim=good(await admin.rpc('hsn_push_claim',{p_subscription:subscription.id,p_module:setting.module,p_kind:cron?'daily':'test',p_key:cron?clock.date:runToken,p_date:clock.date}));if(!claim){results.push({module:setting.module,state:'skipped'});return;}
   let status=0;
   try{
    if(!HSN_PUSH_ENGINE.allowedEndpoint(subscription.endpoint))status=410;
    else if(subscription.vapid_public_key!==keys.publicKey)status=409;
    else{
     const payload={title:cron?content.title:content.title+' · teste',body:cron?content.body:'Teste de notificação recebido. Abra o app para conferir.',view:content.view,tag:cron?content.tag:'hsn-test-'+setting.module+'-'+runToken};
     const details=webpush.generateRequestDetails({endpoint:subscription.endpoint,keys:{p256dh:subscription.p256dh,auth:subscription.auth_key}},JSON.stringify(payload),{vapidDetails:keys,contentEncoding:'aes128gcm',TTL:3600,urgency:'normal'});
     const response=await fetch(subscription.endpoint,{method:'POST',headers:details.headers,body:new Uint8Array(details.body),redirect:'error',signal:AbortSignal.timeout(8000)});status=response.status;await response.body?.cancel();
    }
   }catch{status=0;}
   const saved=good(await admin.rpc('hsn_push_finish',{p_id:claim.id,p_token:claim.token,p_status:status}));
   results.push({module:setting.module,state:status>=200&&status<300?'accepted':status===404||status===410||status===409?'expired':'failed',status,recorded:saved});
  }));if(outcomes.some(r=>r.status==='rejected'))throw Error('Falha ao registrar resultado de envio.');}
  return reply({ok:true,results,message:'Aceito significa recebido pelo serviço push; confirme a exibição no aparelho.'});
 }catch(error){
  const message=error?.message||'';const known=/^Configure HSN_|^As chaves VAPID|^Proprietário não configurado/.test(message);return reply({error:known?message:'Não foi possível concluir o envio. Confira o painel de notificações e a configuração da função.'},503);
 }finally{if(runToken){try{good(await admin.rpc('hsn_push_end',{p_token:runToken}));}catch{/* A trava expira sozinha. Não há dados financeiros em logs. */}}}
}
serveIsolated(handler);


// Clone: valida sessão e proprietário no servidor antes de executar integrações.
function serveIsolated(handler: (request: Request) => Response | Promise<Response>){
 Deno.serve(async request=>{
  const origin=new URL(Deno.env.get('HSN_APP_URL')||'http://localhost:8080/').origin;
  const reply=(message:string,status:number)=>new Response(JSON.stringify({error:message}),{status,headers:{'Content-Type':'application/json','Access-Control-Allow-Origin':origin,'Vary':'Origin'}});
  if(request.method!=='OPTIONS'){
   if(Deno.env.get('HSN_ENABLE_PUSH')!=='true')return reply('Integração desativada neste clone. Conclua a configuração e a homologação.',503);
  }
  return handler(request);
 });
}

function hsnApiKey(name:string):string|undefined{
 const mapping=name==='SUPABASE_SERVICE_ROLE_KEY'?'SUPABASE_SECRET_KEYS':'SUPABASE_PUBLISHABLE_KEYS';
 try{const keys=JSON.parse(Deno.env.get(mapping)||'{}');if(typeof keys.default==='string'&&keys.default)return keys.default;}catch{}
 return Deno.env.get(name);
}
