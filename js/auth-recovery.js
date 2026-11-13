/* Recuperação de senha: nenhuma mensagem ou alteração ocorre ao abrir a página. */
'use strict';
(async()=>{
 const $=id=>document.getElementById(id),cfg=window.HSN_CONFIG;
 const status=(text,error=false)=>{$('status').textContent=text;$('status').classList.toggle('error',error);};
 let client,working=false,ready=false;
 const linkError=new URLSearchParams(location.hash.slice(1)).has('error');
 function message(error){
  const code=String(error?.code||'');
  if(/rate_limit|over_email_send/.test(code))return 'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.';
  if(code==='email_address_not_authorized')return 'O serviço de e-mail do Supabase ainda não permite enviar para esta conta. Solicite ao administrador a configuração do SMTP de autenticação.';
  if(/weak_password|same_password/.test(code))return 'Escolha uma senha diferente e mais forte, seguindo as exigências do Supabase.';
  return 'Não foi possível concluir. Confira a conexão. Se o link expirou ou já foi usado, solicite outro.';
 }
 async function verifiedOwner(){
  const {data,error}=await client.auth.getUser();
  if(error||data?.user?.id!==cfg.ownerId)throw new Error('owner_required');
  return data.user;
 }
 async function run(button,action){
  if(working)return;working=true;button.disabled=true;
  try{await action();}catch(error){status(message(error),true);}finally{working=false;button.disabled=false;}
 }
 try{
  HSN_CLONE_GUARD.validate(cfg);
  if(!window.supabase)throw new Error('sdk_unavailable');
  $('account').textContent='Conta: '+cfg.loginEmail;
  client=window.supabase.createClient(cfg.supabaseUrl,cfg.supabaseAnonKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,flowType:'implicit',storageKey:'hsn-clone-v2-'+cfg.projectRef+'-auth'}});
  // O SDK consome o retorno de recuperação antes de getSession concluir.
  const {data,error}=await client.auth.getSession();
  // Não deixa tokens, descrições de erro ou códigos de retorno no endereço.
  history.replaceState(null,'',location.pathname);
  if(!linkError&&!error&&data?.session){
   try{await verifiedOwner();ready=true;}catch{status('Esta sessão não permite alterar a senha da gerência. Abra um novo link de recuperação.',true);}
  }
  $('password-form').hidden=!ready;$('request-form').hidden=ready;
  if(ready){$('title').textContent='Definir nova senha';status('Acesso confirmado. Preencha e confirme sua nova senha.');}
  else if(linkError||error)status('O link expirou ou já foi usado. Solicite um novo link de recuperação.',true);
  else if(!$('status').classList.contains('error'))status('Você pode solicitar um link para '+cfg.loginEmail+'.');
 }catch{status('Não foi possível iniciar a recuperação. Confira a conexão e a configuração do aplicativo.',true);return;}
 $('request-form').onsubmit=event=>{
  event.preventDefault();run($('send-link'),async()=>{
   const {error}=await client.auth.resetPasswordForEmail(cfg.loginEmail,{redirectTo:new URL('senha.html',location.href).href});
   if(error)throw error;
   $('request-form').hidden=true;status('Solicitação aceita pelo Supabase. Confira a caixa de entrada e o spam de '+cfg.loginEmail+'. A entrega depende do serviço de e-mail de autenticação.');
  });
 };
 $('password-form').onsubmit=event=>{
  event.preventDefault();run($('save-password'),async()=>{
   if(!ready)return;
   const password=$('new-password').value;
   if(password.length<8){status('Use pelo menos 8 caracteres.',true);return;}
   if(password!==$('confirm-password').value){status('As duas senhas precisam ser iguais.',true);return;}
   await verifiedOwner();
   const {error}=await client.auth.updateUser({password});if(error)throw error;
   $('password-form').reset();$('password-form').hidden=true;ready=false;
   const signedOut=await client.auth.signOut({scope:'local'});
   status(signedOut.error?'Senha atualizada. Volte ao sistema para continuar.':'Senha atualizada. Volte ao sistema e entre com a nova senha.');
  });
 };
})();
