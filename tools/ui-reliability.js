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
  return {passed: checks.length, checks};
}
