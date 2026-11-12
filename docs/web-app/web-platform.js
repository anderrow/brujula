(() => {
  'use strict';

  const backupFile = document.getElementById('backup-file');
  const maximumBackupBytes = 8_000_000;
  const stateKey = 'brujula-state-v1';
  let owned = false, conflicted = false, exiting = false, baseline = '', release;
  const ready = new Promise(resolve => {
    if (!navigator.locks) { resolve(false); return; }
    navigator.locks.request('brujula-reflection-editor', {ifAvailable: true}, async lock => {
      if (!lock || exiting) { resolve(false); return; }
      baseline = localStorage.getItem(stateKey) || ''; owned = true; resolve(true);
      await new Promise(done => { release = done; });
      owned = false;
    }).catch(() => resolve(false));
  });
  window.addEventListener('pagehide', () => { exiting = true; owned = false; release?.(); });
  window.addEventListener('pageshow', event => { if (event.persisted) location.reload(); });
  window.addEventListener('storage', event => {
    if ((event.key === stateKey || event.key === null) && (event.newValue || '') !== baseline) {
      conflicted = true; window.dispatchEvent(new Event('brujula-storage-conflict'));
    }
  });

  window.BrujulaWeb = {
    ready,
    get hasConflict() { return conflicted; },
    writeState(data) {
      if (!owned || conflicted || exiting || (localStorage.getItem(stateKey) || '') !== baseline) {
        conflicted = true;
        throw Error('This page cannot safely replace the stored reflections. Export your edits, close other pages and reload.');
      }
      localStorage.setItem(stateKey, data); baseline = data;
    },
    privacySummary: {"en":"Scores, notes, and check-ins are saved in your browser on this device.","es":"Las puntuaciones, notas y evaluaciones se guardan en el navegador de este dispositivo."},
    backupSummary: {"en":"Export a backup before clearing browser data or changing devices. Backup files contain your notes, so keep them private.","es":"Exporta una copia antes de borrar los datos del navegador o cambiar de dispositivo. Las copias contienen tus notas: guárdalas en un lugar privado."},
    versionLabel: {"en":"Brújula web app","es":"Aplicación web de Brújula"},
    clearCopy: {"en":"This deletes the scores, notes, and check-ins saved by this copy of the web app. Export a backup first if you want to keep them.","es":"Se borrarán las puntuaciones, notas y evaluaciones guardadas en esta aplicación web. Exporta antes una copia si quieres conservarlas."},
    privacyPolicy: {en: {
      title: 'Privacy policy',
      updated: 'Brújula web app',
      sections: [
        ['Local storage', 'Your scores, notes, and check-ins stay in browser storage. Brújula does not send them to a server or use ads or analytics.'],
        ['Backups', 'Use Settings to export or restore a JSON backup. You choose where exported files are saved. The web app can restore Brújula backups from Android or iPhone.'],
        ['Retention and deletion', 'Clear your data in Settings to remove saved reflections from this copy of the web app. Clearing browser data can also remove reflections. Delete exported files separately.'],
        ['Hosting', 'GitHub Pages serves the app files and handles ordinary web requests. Once the app files are cached, you can use the wheel offline.']
      ]
    },es: {"title":"Política de privacidad","updated":"Aplicación web de Brújula","sections":[["Almacenamiento local","Tus puntuaciones, notas y evaluaciones permanecen en el almacenamiento del navegador. Brújula no las envía a un servidor ni utiliza anuncios o analítica."],["Copias de seguridad","Usa Ajustes para exportar o restaurar una copia JSON. Tú eliges dónde guardarla. La aplicación web puede restaurar copias de Brújula de Android o iPhone."],["Conservación y borrado","Borra los datos desde Ajustes para eliminar las reflexiones de esta aplicación web. Borrar los datos del navegador también puede eliminarlas. Borra las copias exportadas por separado."],["Alojamiento","GitHub Pages sirve los archivos de la aplicación y procesa las peticiones web habituales. Una vez guardados los archivos en la caché, puedes utilizar la rueda sin conexión."]]}},

    exportBackup(data, recovery = false) {
      const url = URL.createObjectURL(new Blob([data], {type: 'application/json'}));
      const link = document.createElement('a');
      link.href = url;
      link.download = recovery ? 'brujula-recovery-copy.json' : 'brujula-backup.json';
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 60_000);
    },

    importBackup() {
      backupFile.click();
    }
  };

  backupFile.addEventListener('change', async () => {
    const [file] = backupFile.files;
    backupFile.value = '';
    if (!file) return;
    if (file.size > maximumBackupBytes) {
      window.nativeNotice('invalidBackup');
      return;
    }
    try {
      window.restoreBackup(await file.text());
    } catch (_) {
      window.nativeNotice('importFailed');
    }
  });

  if (navigator.standalone) document.documentElement.classList.add('is-standalone');
  const status = document.createElement('p'); status.className = 'offline-status'; status.setAttribute('role', 'status');
  document.querySelector('.install-tip').append(status);

  const interfaceCopy = {"installLabel":["Install Brújula on iPhone","Instala Brújula en tu iPhone"],"installTitle":["Add Brújula to your iPhone","Añade Brújula a tu iPhone"],"installSteps":["Open this page in Safari. Tap Share (in the page menu if needed) and choose Add to Home Screen. Enable Open as Web App if shown, then tap Add.","Abre esta página en Safari. Pulsa Compartir (en el menú de la página si es necesario) y elige Añadir a pantalla de inicio. Activa Abrir como app web si aparece y pulsa Añadir."],"installOffline":["Open the new Home Screen icon once while online before saving your first check-in. Wait for the offline-ready message, then reopen it offline once to verify access. Scheduled reminders are available in the native app.","Abre el nuevo icono de la pantalla de inicio con conexión antes de guardar tu primera evaluación. Espera al mensaje de acceso sin conexión y vuelve a abrir la app sin Internet para comprobarlo. Los recordatorios programados están disponibles en la aplicación nativa."],"preparing":["Preparing offline access…","Preparando el acceso sin conexión…"],"ready":["Ready for offline use. Reopen the installed app once without a connection to verify it. Browser data or cache removal can still erase local data or offline access.","Lista para usar sin conexión. Abre la aplicación instalada sin Internet para comprobarlo. Borrar los datos o la caché del navegador puede eliminar los datos locales o el acceso sin conexión."],"failed":["Offline setup is not ready. Stay online and retry before relying on offline access. ","El acceso sin conexión aún no está listo. Mantén la conexión y vuelve a intentarlo antes de usar la aplicación sin Internet. "],"retry":["Retry offline setup","Reintentar acceso sin conexión"]};
  let interfaceLocale=document.documentElement.lang==='es'?'es':'en', offlineState='preparing';
  const text=key=>interfaceCopy[key][interfaceLocale==='es'?1:0];
  function localizeInterface(){
    document.querySelector('.install-tip').setAttribute('aria-label',text('installLabel'));
    document.querySelector('.install-tip summary').textContent=text('installTitle');
    const paragraphs=document.querySelectorAll('.install-tip details p');
    paragraphs[0].textContent=text('installSteps');paragraphs[1].textContent=text('installOffline');
    status.textContent=text(offlineState);
    if(offlineState==='failed'){const retry=document.createElement('button');retry.textContent=text('retry');retry.onclick=prepareOffline;status.append(retry);}
  }
  window.addEventListener('brujula-locale',event=>{interfaceLocale=event.detail;localizeInterface();});
  async function prepareOffline() {
    offlineState='preparing';localizeInterface();
    let timer;
    try {
      if (!('serviceWorker' in navigator)) throw Error('Unavailable');
      await navigator.serviceWorker.register('service-worker.js');
      await Promise.race([navigator.serviceWorker.ready, new Promise((_, reject) => { timer = setTimeout(() => reject(Error('Not ready')), 20000); })]);
      offlineState='ready';localizeInterface();
    } catch (_) {
      offlineState='failed';localizeInterface();
    } finally { clearTimeout(timer); }
  }
  prepareOffline();
})();
