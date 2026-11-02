(() => {
  'use strict';
  const repo=window.BRUJULA_REPOSITORY;
  if(!repo||!/^https:\/\/github\.com\/[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/.test(repo))return;
  const release=repo+'/releases/latest';
  document.querySelectorAll('[data-repository]').forEach(a=>a.href=repo);
  document.querySelectorAll('[data-releases]').forEach(a=>a.href=release);
  document.querySelectorAll('[data-checksum]').forEach(a=>a.href=release+'/download/Brujula.apk.sha256');
  document.querySelectorAll('[data-download]').forEach(a=>a.href=release+'/download/Brujula.apk');
  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),8000);
  fetch('https://api.github.com/repos/'+repo.split('/').slice(-2).join('/')+'/releases/latest',{headers:{Accept:'application/vnd.github+json'},signal:controller.signal})
    .then(response=>{if(!response.ok)throw Error('Release metadata unavailable');return response.json();})
    .then(data=>{
      if(data.draft||data.prerelease||!Array.isArray(data.assets))throw Error('No stable release');
      const asset=data.assets.find(a=>a.name==='Brujula.apk')||data.assets.find(a=>/\.apk$/i.test(a.name));
      if(!asset||typeof asset.browser_download_url!=='string'||!asset.browser_download_url.startsWith(repo+'/releases/download/'))throw Error('No verified APK link');
      document.querySelectorAll('[data-download]').forEach(a=>a.href=asset.browser_download_url);
      const checksum=data.assets.find(a=>a.name===asset.name+'.sha256');
      if(checksum&&checksum.browser_download_url.startsWith(repo+'/releases/download/'))document.querySelectorAll('[data-checksum]').forEach(a=>a.href=checksum.browser_download_url);
      document.getElementById('hero-version').textContent=String(data.tag_name||'Latest stable release');
      const pieces=[String(data.tag_name||'Latest stable release')];
      if(Number.isFinite(asset.size)&&asset.size>0)pieces.push(new Intl.NumberFormat('en',{maximumFractionDigits:1}).format(asset.size/1024)+' KB');
      if(data.published_at&&Number.isFinite(Date.parse(data.published_at)))pieces.push('Published '+new Date(data.published_at).toLocaleDateString('en',{month:'long',day:'numeric',year:'numeric'}));
      document.getElementById('release-description').textContent=pieces.join(' · ');
    })
    .catch(()=>{document.getElementById('release-description').textContent='The download still points to the latest stable release. You can also view all versions on GitHub.';})
    .finally(()=>clearTimeout(timeout));
})();
