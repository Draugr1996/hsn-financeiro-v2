/* Navegação pessoal; nenhum registro financeiro é alterado. */
(()=>{'use strict';
 // O menu curto permanece legível mesmo se houver preferência antiga de recolhimento.
 document.documentElement.classList.remove('hsn-sidebar-collapsed');
 document.addEventListener('keydown',e=>{
  if(!(e.ctrlKey||e.metaKey)||e.key.toLowerCase()!=='k')return;
  const field=document.querySelector('#finance-controls input[type="search"]')||document.getElementById('search');
  if(field?.offsetParent){e.preventDefault();field.focus();field.select();}
 });
})();
