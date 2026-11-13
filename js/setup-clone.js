'use strict';
document.getElementById('setup').addEventListener('submit',event=>{
 event.preventDefault();const status=document.getElementById('status');
 try{
  const config=Object.fromEntries([...new FormData(event.currentTarget)].map(([key,value])=>[key,String(value).trim()]));
  HSN_CLONE_GUARD.validate(config);
  const blob=new Blob(['// Somente configuração pública do clone.\nwindow.HSN_CONFIG=Object.freeze('+JSON.stringify(config,null,2)+');\n'],{type:'text/javascript;charset=utf-8'});
  const url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download='config.js';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  status.textContent='Configuração válida. Substitua js/config.js pelo arquivo baixado.';
 }catch(error){status.textContent=error.message;}
});
