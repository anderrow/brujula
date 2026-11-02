(() => {
  'use strict';
  const key='brujula-web-locale';
  function select(locale,remember=false){
    const copy=window.BrujulaPrivacy[locale];
    if(!copy)return;
    document.documentElement.lang=locale;
    document.title='Brújula — '+copy.title;
    document.getElementById('policy-title').textContent=copy.title;
    document.getElementById('policy-updated').textContent=copy.updated;
    const content=document.getElementById('policy-sections');
    content.replaceChildren(...copy.sections.map(([heading,body])=>{
      const section=document.createElement('section'),h=document.createElement('h2'),p=document.createElement('p');
      h.textContent=heading;p.textContent=body;section.append(h,p);return section;
    }));
    document.getElementById('policy-back').textContent=locale==='es'?'Volver a Brújula':'Back to Brújula';
    document.querySelector('.language-switch').setAttribute('aria-label',locale==='es'?'Idioma':'Language');
    document.querySelectorAll('[data-language]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.language===locale)));
    if(remember){try{localStorage.setItem(key,locale);}catch(_){}}
  }
  let locale=navigator.language.toLowerCase().startsWith('es')?'es':'en';
  try{const saved=localStorage.getItem(key);if(saved==='es'||saved==='en')locale=saved;}catch(_){}
  document.querySelectorAll('[data-language]').forEach(b=>b.addEventListener('click',()=>select(b.dataset.language,true)));
  select(locale);document.querySelector('.language-switch').hidden=false;
})();
