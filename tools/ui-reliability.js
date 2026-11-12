async (page) => {
  const checks = [];
  const check = (value, message) => { if (!value) throw Error(message); checks.push(message); };
  const context = await page.context().browser().newContext({viewport: {width: 393, height: 852}});
  const app = await context.newPage();
  const base = 'http://127.0.0.1:8877/docs/web-app/';
  try {
    await app.goto(base);
    await app.getByRole('button', {name: 'Health, Not rated', exact: true}).waitFor();
    check(await app.getByRole('button', {name: 'Settings', exact: true}).isEnabled(), 'First upgraded browser page can edit');
    const second = await context.newPage();
    await second.goto(base);
    check(await second.getByText('This page is read-only.', {exact: false}).isVisible(), 'Second browser page is read-only before editing');
    check(await second.getByRole('button', {name: 'Settings', exact: true}).isDisabled(), 'Read-only page cannot replace stored state');
    await second.close();

    await app.evaluate(() => {
      const original = Storage.prototype.setItem;
      window.__restoreStorage = () => { Storage.prototype.setItem = original; };
      Storage.prototype.setItem = function(key, value) { if (key === 'brujula-state-v1') throw new DOMException('Synthetic quota denial', 'QuotaExceededError'); original.call(this, key, value); };
      window.BrujulaWeb.exportBackup = (data, recovery) => { window.__exported = {data, recovery}; };
    });
    await app.getByRole('button', {name: 'Health, Not rated', exact: true}).click();
    await app.getByRole('textbox', {name: 'Your reflection', exact: true}).fill('Synthetic unsaved reflection');
    check((await app.locator('.note-hint').textContent()).includes('Not saved'), 'Failed autosave never retains a saved-success hint');
    await app.getByRole('button', {name: 'Done', exact: true}).click();
    check(await app.locator('#save-status').isVisible(), 'Failed autosave remains visible after the editor closes');
    await app.getByRole('button', {name: 'Export preserved data (recovery copy)', exact: true}).click();
    check(await app.evaluate(() => window.__exported.recovery && JSON.parse(window.__exported.data).draft.notes.health === 'Synthetic unsaved reflection'), 'Recovery export retains memory-only notes');
    await app.evaluate(() => window.__restoreStorage());
    await app.getByRole('button', {name: 'Retry saving', exact: true}).click();
    check(await app.locator('#save-status').isHidden(), 'Only a successful retry clears failed-save status');
    await app.reload();
    await app.getByRole('button', {name: 'Health, Not rated', exact: true}).waitFor();
    check(await app.evaluate(() => JSON.parse(localStorage.getItem('brujula-state-v1')).draft.notes.health === 'Synthetic unsaved reflection'), 'Retried draft survives reload');

    const observer = await context.newPage(); await observer.goto(base);
    await observer.evaluate(() => { window.BrujulaWeb.exportBackup = data => { window.__recovery = data; }; });
    await app.getByRole('button', {name: 'Work, Not rated', exact: true}).click();
    await app.getByRole('textbox', {name: 'Your reflection', exact: true}).fill('Change after read-only page opened');
    await app.getByRole('button', {name: 'Done', exact: true}).click();
    await observer.locator('#save-status').waitFor();
    await observer.locator('#recover').click();
    check(await observer.evaluate(() => JSON.parse(window.__recovery).draft.notes.health === 'Synthetic unsaved reflection'), 'Read-only recovery retains complete original reflections after another page writes');
    await observer.close();

    const legacy = await context.newPage();
    await legacy.goto(base);
    await legacy.evaluate(() => {
      const state = JSON.parse(localStorage.getItem('brujula-state-v1'));
      state.draft.notes.work = 'Synthetic legacy writer'; localStorage.setItem('brujula-state-v1', JSON.stringify(state));
    });
    await app.getByRole('button', {name: 'Reload stored data', exact: true}).waitFor();
    check(await app.locator('#save-status').isVisible(), 'Detected legacy writer freezes the upgraded page and exposes recovery');
    const durable = await app.evaluate(() => localStorage.getItem('brujula-state-v1'));
    await app.getByRole('button', {name: 'Work, Not rated', exact: true}).click();
    await app.getByRole('textbox', {name: 'Your reflection', exact: true}).fill('Blocked stale write');
    check(await app.evaluate(() => localStorage.getItem('brujula-state-v1')) === durable, 'A frozen stale page cannot overwrite externally changed data');
    await app.getByRole('button', {name: 'Done', exact: true}).click();
    await legacy.close();
    await app.screenshot({path: 'output/playwright/reliability-conflict.png', fullPage: true});
  } finally { await context.close(); }

  const unsupported = await page.context().browser().newContext();
  try {
    await unsupported.addInitScript(() => Object.defineProperty(Navigator.prototype, 'locks', {get: () => undefined, configurable: true}));
    const readonly = await unsupported.newPage(); await readonly.goto(base);
    check(await readonly.getByText('This page is read-only.', {exact: false}).isVisible(), 'Browsers without exclusive editing support fail read-only');
  } finally { await unsupported.close(); }

  const installed = await page.context().browser().newContext();
  try {
    await installed.addInitScript(() => {
      Object.defineProperty(navigator, 'standalone', {value: true});
      const register = navigator.serviceWorker.register.bind(navigator.serviceWorker);
      let attempt = 0;
      navigator.serviceWorker.register = async (...args) => {
        if (attempt++ === 0) {
          await new Promise(resolve => setTimeout(resolve, 300));
          throw Error('Synthetic offline setup failure');
        }
        return register(...args);
      };
    });
    const app = await installed.newPage(); await app.goto(base);
    check(await app.locator('.offline-status').isVisible(), 'Installed app keeps offline preparation visible');
    await app.getByRole('button', {name: 'Retry offline setup', exact: true}).waitFor();
    check(await app.locator('.offline-status').isVisible(), 'Installed app keeps offline failure and retry visible');
    check(await app.locator('.install-tip details').isHidden(), 'Installed app hides only installation instructions');
    await app.getByRole('button', {name: 'Retry offline setup', exact: true}).click();
    await app.getByText('Ready for offline use.', {exact: false}).waitFor();
    check(await app.locator('.offline-status').isVisible(), 'Successful offline retry remains observable in installed mode');
    await app.evaluate(async () => { if (!navigator.serviceWorker.controller) await new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once: true})); });
    await installed.setOffline(true); await app.reload();
    await app.getByRole('button', {name: 'Health, Not rated', exact: true}).waitFor();
    check(await app.locator('.offline-status').isVisible(), 'Installed app reopens from its prepared cache offline');
  } finally { await installed.close(); }

  const oversized = await page.context().browser().newContext();
  try {
    await oversized.addInitScript(() => {
      window.__writes = 0;
      window.BrujulaNative = {
        read: () => {
          const C = window.BrujulaCore, state = C.initial(); state.locale = 'en';
          state.draft.notes.health = 'Original draft';
          const saved = C.clone(state.draft);
          for (const area of C.categories) { saved.scores[area.id] = 5; saved.notes[area.id] = '€'.repeat(4000); }
          state.history = Array.from({length: 100}, (_, i) => ({...saved, id: 'preserved-' + i, at: '2026-01-01T12:00:00.000Z', title: 'Preserved check-in'}));
          window.__raw = JSON.stringify(state); return window.__raw;
        },
        write: () => { window.__writes++; return false; },
        readReminders: () => JSON.stringify({enabled: false, canNotify: true}),
        exportBackup: data => { window.__exported = data; }
      };
    });
    const app = await oversized.newPage(); await app.goto('http://127.0.0.1:8877/app/src/main/assets/web/');
    await app.getByText('This existing data exceeds', {exact: false}).waitFor();
    check(await app.evaluate(() => window.__writes === 0), 'Oversized original is never overwritten during startup');
    await app.getByRole('button', {name: 'Health, Not rated', exact: true}).click();
    await app.getByRole('textbox', {name: 'Your reflection', exact: true}).fill('Edited oversized draft');
    await app.getByRole('button', {name: 'Done', exact: true}).click();
    check(await app.evaluate(() => window.__writes === 0), 'Oversized edits fail before native replacement');
    await app.locator('#recover-save').click();
    check(await app.evaluate(() => window.__exported === window.__raw), 'Oversized recovery export preserves exact original bytes after rejected edits');
  } finally { await oversized.close(); }

  const recovery = await page.context().browser().newContext();
  try {
    await recovery.addInitScript(() => {
      window.BrujulaNative = {
        read: () => { throw Error('Synthetic initial read failure'); },
        restoreData: data => { window.__restored = data; return true; },
        consumeTransfer: id => { window.__cancelled = id; }, write: () => false,
        readReminders: () => JSON.stringify({enabled: false, canNotify: true}),
        exportBackup: data => { window.__exported = data; }
      };
    });
    const app = await recovery.newPage(), errors = []; app.on('pageerror', error => errors.push(error.message));
    await app.goto('http://127.0.0.1:8877/app/src/main/assets/web/');
    await app.locator('#retry-load').waitFor();
    await app.evaluate(() => window.importUnavailable('unreadable-import'));
    await app.locator('#cancel').click();
    check(await app.evaluate(() => window.__cancelled === 'unreadable-import') && await app.locator('#retry-load').isVisible() && errors.length === 0, 'Cancelling a staged import retains a usable failed-load recovery screen');
    await app.evaluate(() => {
      const restored = window.BrujulaCore.initial(); restored.locale = 'en';
      window.restoreBackup(JSON.stringify(restored), 'retained-import');
    });
    await app.locator('#confirm').click();
    check(await app.getByRole('button', {name: 'Settings', exact: true}).isEnabled(), 'A retained import restores editing after failed initial loading');
    await app.getByRole('button', {name: 'Health, Not rated', exact: true}).click();
    await app.getByRole('textbox', {name: 'Your reflection', exact: true}).fill('Unsaved note after recovery import');
    await app.getByRole('button', {name: 'Done', exact: true}).click();
    await app.locator('#recover-save').click();
    check(await app.evaluate(() => JSON.parse(window.__exported).draft.notes.health === 'Unsaved note after recovery import'), 'Recovery export retains failed draft edits after an initial-load recovery import');
  } finally { await recovery.close(); }
  return {passed: checks.length, checks};
}
