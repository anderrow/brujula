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
    privacySummary: 'Scores, notes, and check-ins are saved in your browser on this device.',
    backupSummary: 'Export a backup before clearing browser data or changing devices. Backup files contain your notes, so keep them private.',
    versionLabel: 'Brújula web app',
    clearCopy: 'This deletes the scores, notes, and check-ins saved by this copy of the web app. Export a backup first if you want to keep them.',
    privacyPolicy: {
      title: 'Privacy policy',
      updated: 'Brújula web app',
      sections: [
        ['Local storage', 'Your scores, notes, and check-ins stay in browser storage. Brújula does not send them to a server or use ads or analytics.'],
        ['Backups', 'Use Settings to export or restore a JSON backup. You choose where exported files are saved. The web app can restore Brújula backups from Android or iPhone.'],
        ['Retention and deletion', 'Clear your data in Settings to remove saved reflections from this copy of the web app. Clearing browser data can also remove reflections. Delete exported files separately.'],
        ['Hosting', 'GitHub Pages serves the app files and handles ordinary web requests. Once the app files are cached, you can use the wheel offline.']
      ]
    },

    exportBackup(data, recovery = false) {
      const url = URL.createObjectURL(new Blob([data], {type: 'application/json'}));
      const link = document.createElement('a');
      link.href = url;
      link.download = recovery ? 'brujula-recovery-original.json' : 'brujula-backup.json';
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
  async function prepareOffline() {
    status.textContent = 'Preparing offline access…';
    let timer;
    try {
      if (!('serviceWorker' in navigator)) throw Error('Unavailable');
      await navigator.serviceWorker.register('service-worker.js');
      await Promise.race([navigator.serviceWorker.ready, new Promise((_, reject) => { timer = setTimeout(() => reject(Error('Not ready')), 20000); })]);
      status.textContent = 'Ready for offline use. Reopen the installed app once without a connection to verify it. Browser data or cache removal can still erase local data or offline access.';
    } catch (_) {
      status.textContent = 'Offline setup is not ready. Stay online and retry before relying on offline access. ';
      const retry = document.createElement('button'); retry.textContent = 'Retry offline setup'; retry.onclick = prepareOffline; status.append(retry);
    } finally { clearTimeout(timer); }
  }
  prepareOffline();
})();
