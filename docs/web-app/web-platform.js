(() => {
  'use strict';

  const backupFile = document.getElementById('backup-file');
  const maximumBackupBytes = 8_000_000;

  window.BrujulaWeb = {
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

    exportBackup(data) {
      const url = URL.createObjectURL(new Blob([data], {type: 'application/json'}));
      const link = document.createElement('a');
      link.href = url;
      link.download = 'brujula-backup.json';
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
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('service-worker.js').catch(error => {
      console.warn('Offline setup failed.', error);
    });
  }
})();
