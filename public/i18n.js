(() => {
  const pages={id:'index.html',en:'en.html',jp:'ja.html',de:'de.html'};
  const labels={id:'ID',en:'EN',jp:'JP',de:'DE'};
  const tags={id:'id',en:'en',jp:'ja',de:'de'};
  const path=location.pathname.split('/').pop()||'index.html';
  const active=Object.entries(pages).find(([,file])=>file===path)?.[0]||'id';
  document.documentElement.lang=tags[active];
  const wrap=document.querySelector('.site-header .nav-wrap');
  if(!wrap||wrap.querySelector('.language-switcher'))return;
  const switcher=document.createElement('div');switcher.className='language-switcher';switcher.setAttribute('role','navigation');switcher.setAttribute('aria-label','Language');
  Object.entries(labels).forEach(([locale,label])=>{const a=document.createElement('a');a.href=pages[locale];a.textContent=label;a.className=locale===active?'active':'';a.setAttribute('hreflang',tags[locale]);if(locale===active)a.setAttribute('aria-current','page');switcher.append(a)});
  const menu=wrap.querySelector('.menu-button');wrap.insertBefore(switcher,menu||wrap.querySelector('nav'));
  window.KLII18n={current:()=>active,t:text=>text};
})();
