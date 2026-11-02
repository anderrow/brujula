(() => {
  'use strict';
  const translations=window.BRUJULA_TRANSLATIONS;
  if(!translations?.en||!translations?.es)return;
  const preferenceKey='brujula-web-locale';
  const browserLanguage=navigator.language.toLowerCase().startsWith('es')?'es':'en';
  let locale=browserLanguage;
  try {
    const saved=localStorage.getItem(preferenceKey);
    if(saved==='en'||saved==='es')locale=saved;
  }catch(_){ /* Language switching still works if browser storage is unavailable. */ }
  let releaseData=null,releaseFailed=false;
  const t=key=>translations[locale][key]??translations.en[key];
  function renderRelease(){
    document.getElementById('hero-version').textContent=releaseData?.tag_name||t('latest');
    if(!releaseData){
      document.getElementById('release-description').textContent=t(releaseFailed?'releaseFallback':'releaseLoading');
      return;
    }
    const pieces=[String(releaseData.tag_name||t('latest'))];
    const asset=releaseData.selectedAsset;
    if(Number.isFinite(asset.size)&&asset.size>0)pieces.push(new Intl.NumberFormat(locale,{maximumFractionDigits:1}).format(asset.size/1024)+' KB');
    if(releaseData.published_at&&Number.isFinite(Date.parse(releaseData.published_at)))pieces.push(t('published')+' '+new Date(releaseData.published_at).toLocaleDateString(locale,{month:'long',day:'numeric',year:'numeric'}));
    document.getElementById('release-description').textContent=pieces.join(' · ');
  }
  function setLanguage(next,remember=false){
    if(next!=='en'&&next!=='es')return;
    locale=next;
    document.documentElement.lang=locale;
    document.title=t('title');
    document.querySelector('meta[name="description"]').content=t('description');
    document.querySelectorAll('[data-i18n]').forEach(element=>{element.textContent=t(element.dataset.i18n);});
    document.querySelectorAll('[data-i18n-aria]').forEach(element=>{element.setAttribute('aria-label',t(element.dataset.i18nAria));});
    document.querySelectorAll('[data-i18n-alt]').forEach(element=>{element.alt=t(element.dataset.i18nAlt);});
    document.querySelectorAll('[data-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.language===locale)));
    if(remember){try{localStorage.setItem(preferenceKey,locale);}catch(_){ /* Keep the current selection for this visit. */ }}
    renderRelease();
  }
  document.querySelectorAll('[data-language]').forEach(button=>button.addEventListener('click',()=>setLanguage(button.dataset.language,true)));
  setLanguage(locale);
  document.querySelector('.language-switch').hidden=false;
  const repo=window.BRUJULA_REPOSITORY;
  if(!repo||!/^https:\/\/github\.com\/[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/.test(repo))return;
  const release=repo+'/releases/latest';
  document.querySelectorAll('[data-repository]').forEach(a=>a.href=repo);
  document.querySelectorAll('[data-releases]').forEach(a=>a.href=release);
  document.querySelectorAll('[data-checksum]').forEach(a=>a.href=release+'/download/Brujula.apk.sha256');
  document.querySelectorAll('[data-download]').forEach(a=>a.href=release+'/download/Brujula.apk');
  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),8000);
  fetch('https://api.github.com/repos/'+repo.split('/').slice(-2).join('/')+'/releases/latest',{headers:{Accept:'application/vnd.github+json'},cache:'no-store',signal:controller.signal})
    .then(response=>{if(!response.ok)throw Error('Release metadata unavailable');return response.json();})
    .then(data=>{
      if(data.draft||data.prerelease||!Array.isArray(data.assets))throw Error('No stable release');
      const asset=data.assets.find(a=>a.name==='Brujula.apk')||data.assets.find(a=>/\.apk$/i.test(a.name));
      if(!asset||typeof asset.browser_download_url!=='string'||!asset.browser_download_url.startsWith(repo+'/releases/download/'))throw Error('No verified APK link');
      // Preserve the permanent URL for the stable alias, even if metadata is stale.
      if(asset.name!=='Brujula.apk')document.querySelectorAll('[data-download]').forEach(a=>a.href=asset.browser_download_url);
      const checksum=data.assets.find(a=>a.name===asset.name+'.sha256');
      if(asset.name!=='Brujula.apk'&&checksum&&checksum.browser_download_url.startsWith(repo+'/releases/download/'))document.querySelectorAll('[data-checksum]').forEach(a=>a.href=checksum.browser_download_url);
      releaseData={...data,selectedAsset:asset};
      renderRelease();
    })
    .catch(()=>{releaseFailed=true;renderRelease();})
    .finally(()=>clearTimeout(timeout));
})();
