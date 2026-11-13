// Gera somente chaves NOVAS e locais; não consulta nem altera o projeto original.
const fs=require('node:fs'),crypto=require('node:crypto');
const path='.env.integrations';if(fs.existsSync(path))throw Error('Arquivo já existe; preservado.');
const ec=crypto.createECDH('prime256v1');ec.generateKeys();
const values={HSN_APP_URL:'https://SEU_ENDERECO_DO_CLONE/',HSN_ENABLE_EMAIL:'false',HSN_ENABLE_PUSH:'false',ZOHO_CLIENT_ID:'PREENCHER_NO_SUPABASE',ZOHO_CLIENT_SECRET:'PREENCHER_NO_SUPABASE',ZOHO_TOKEN_ENCRYPTION_KEY:crypto.randomBytes(32).toString('base64'),HSN_CRON_KEY:crypto.randomBytes(48).toString('base64url'),HSN_VAPID_PUBLIC_KEY:ec.getPublicKey().toString('base64url'),HSN_VAPID_PRIVATE_KEY:ec.getPrivateKey().toString('base64url'),HSN_VAPID_SUBJECT:'mailto:faturamento@hotelserranegra.com.br'};
fs.writeFileSync(path,Object.entries(values).map(([k,v])=>k+'='+v).join('\n')+'\n',{mode:0o600,flag:'wx'});
console.log('Chaves novas salvas em .env.integrations. Configure-as nos Secrets do Supabase novo. Esse arquivo não deve entrar no GitHub.');
