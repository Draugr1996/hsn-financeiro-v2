/* Navegação por setor. Usa os botões existentes e não altera registros. */
(()=>{'use strict';
 const sidebar=document.querySelector('.sidebar'),toggle=document.getElementById('navigation-toggle'),nav=document.getElementById('topic-navigation');
 if(!sidebar||!toggle||!nav)return;
 const groups=[...nav.querySelectorAll('.nav-sector')];
 const mobile=()=>window.matchMedia('(max-width: 850px)').matches;
 function closeMenu(){sidebar.classList.remove('menu-open');toggle.setAttribute('aria-expanded','false');}
 function expand(group,open){
  const links=group.querySelector('.sector-links'),control=group.querySelector('.sector-toggle');
  links.hidden=!open;control.setAttribute('aria-expanded',String(open));
  if(group.classList.contains('sector-open')!==open)group.classList.toggle('sector-open',open);
 }
 function openOnly(group){groups.forEach(item=>expand(item,item===group));}
 toggle.addEventListener('click',()=>{const open=sidebar.classList.toggle('menu-open');toggle.setAttribute('aria-expanded',String(open));});
 groups.forEach(group=>group.querySelector('.sector-toggle').addEventListener('click',()=>{
  const open=group.querySelector('.sector-links').hidden;
  if(open)openOnly(group);else expand(group,false);
 }));
 let lastActive=null;
 function sync(){
  const active=nav.querySelector('[data-view].active'),group=active?.closest('.nav-sector');
  nav.querySelectorAll('[data-view]').forEach(button=>{if(button===active)button.setAttribute('aria-current','page');else button.removeAttribute('aria-current');});
  groups.forEach(item=>{const selected=item===group;if(item.classList.contains('has-current')!==selected)item.classList.toggle('has-current',selected);});
  nav.dataset.section=group?.dataset.sector||'dashboard';
  if(active&&active!==lastActive){openOnly(group);lastActive=active;}
  const title=document.getElementById('view-title')?.textContent;
  if(title)document.getElementById('navigation-current').textContent=title;
 }
 nav.addEventListener('click',event=>{
  const button=event.target.closest('[data-view]');if(!button)return;
  if(button.classList.contains('sector-home'))openOnly(button.closest('.nav-sector'));
  if(mobile()){closeMenu();document.getElementById('view-title')?.scrollIntoView?.({block:'start',behavior:'auto'});}
 });
 document.addEventListener('keydown',event=>{
  if(event.key!=='Escape')return;
  if(sidebar.classList.contains('menu-open')){closeMenu();toggle.focus();}
  else if(nav.contains(document.activeElement)){const group=document.activeElement.closest('.nav-sector');if(group&&!group.querySelector('.sector-links').hidden){expand(group,false);group.querySelector('.sector-toggle').focus();}}
 });
 new MutationObserver(sync).observe(nav,{attributes:true,subtree:true,attributeFilter:['class']});
 const title=document.getElementById('view-title');if(title)new MutationObserver(sync).observe(title,{childList:true,characterData:true,subtree:true});
 sync();
})();
