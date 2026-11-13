/* Validação antes de criar qualquer conexão com o banco. */
(function(root){
 'use strict';
 function validate(config){
  if(!config)throw Error('Configure este clone antes de entrar.');
  let url;try{url=new URL(config.supabaseUrl);}catch{throw Error('Informe o URL do novo Supabase.');}
  if(url.hostname==='gbpmovhcehtqahjbnrpt.supabase.co')throw Error('O banco do sistema original está bloqueado neste clone.');
  if(!/^[a-z]{20}$/.test(config.projectRef||'')||url.protocol!=='https:'||url.hostname!==config.projectRef+'.supabase.co'||url.pathname!=='/'||url.search||url.hash||url.username||url.password)throw Error('O URL deve corresponder ao projeto independente configurado.');
  const key=String(config.supabaseAnonKey||'');
  if(key.startsWith('sb_secret_'))throw Error('Use somente a chave pública; chaves secretas não podem ficar no aplicativo.');
  if(!/^sb_publishable_[A-Za-z0-9_-]{16,}$/.test(key)){
   let payload;try{payload=JSON.parse(atob(key.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));}catch{throw Error('Informe a chave publishable ou anon do novo projeto.');}
   if(payload.role!=='anon'||payload.ref!==config.projectRef)throw Error('A chave deve ser anon e pertencer ao novo projeto. Nunca use service_role.');
  }
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(config.loginEmail||''))throw Error('Informe o e-mail do usuário criado no Auth do novo projeto.');
  if(!/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(config.ownerId||''))throw Error('Informe o UUID do usuário criado no Auth do novo projeto.');
  if(config.ownerId==='4f64d795-34c1-4333-92fc-55e427c7d998')throw Error('Crie um usuário no novo projeto e utilize o novo UUID.');
  return true;
 }
 const api=Object.freeze({validate});
 if(typeof module==='object'&&module.exports)module.exports=api;
 else root.HSN_CLONE_GUARD=api;
})(typeof window==='object'?window:globalThis);
