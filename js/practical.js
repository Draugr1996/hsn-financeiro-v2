/* Navegação pessoal; nenhum registro financeiro é alterado. */
(()=>{'use strict';
 // O menu curto permanece legível mesmo se houver preferência antiga de recolhimento.
 document.documentElement.classList.remove('hsn-sidebar-collapsed');
 const nav=document.getElementById('topic-navigation');
 const config=nav?.querySelector('details');
 function sync(){
  const active=nav?.querySelector('[data-view].active');
  if(!active)return;
  const bankSection=['imports','dda','sicoob_collections'].includes(active.dataset.view);
  nav.dataset.section=bankSection?'bank':'';
  if(config?.contains(active)&&!bankSection)config.open=true;
  else if(bankSection&&config)config.open=false;
 }
 if(nav)new MutationObserver(sync).observe(nav,{subtree:true,attributes:true,attributeFilter:['class']});
 document.addEventListener('keydown',e=>{
  if(!(e.ctrlKey||e.metaKey)||e.key.toLowerCase()!=='k')return;
  const field=document.querySelector('#finance-controls input[type="search"]')||document.getElementById('search');
  if(field?.offsetParent){e.preventDefault();field.focus();field.select();}
 });
 sync();
})();
