/* Generate the public policy from the same text bundled in the offline app. */
const fs=require('node:fs');
const check = process.argv.includes('--check');
function emit(filename, data) {
  if (check) {
    const actual = fs.readFileSync(filename);
    const same = Buffer.isBuffer(data) ? actual.equals(data) : actual.toString('utf8').replace(/\r\n/g, '\n') === data.replace(/\r\n/g, '\n');
    if (!same) throw Error('Generated output is stale: ' + filename);
  } else fs.writeFileSync(filename, data);
}

const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'app/src/main/assets/web/privacy-copy.js'),'utf8');
const context={window:{}};vm.runInNewContext(source,context);
const policy=context.window.BrujulaPrivacy.en;
const esc=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
emit(path.join(root,'docs/privacy-copy.js'),source);
emit(path.join(root,'docs/privacy.html'),`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="Brújula privacy policy: offline reflections, optional reminders, local backups and deletion.">
<title>Brújula — Privacy policy</title><link rel="icon" href="compass.svg"><link rel="stylesheet" href="style.css?v=2026-11-12">
<style>.policy{max-width:760px;padding:55px 0}.policy h1{font-size:48px;letter-spacing:-1.5px}.policy h2{font:600 21px system-ui;letter-spacing:0;margin:32px 0 12px}.policy p{font-size:15px;line-height:1.9;color:var(--muted)}.policy a{text-decoration:underline}.policy footer{margin-top:40px}</style>
<script src="privacy-copy.js?v=2026-11-12" defer></script><script src="privacy.js?v=2026-11-05" defer></script></head><body>
<header class="site-header wrap"><a class="brand" href="./"><img src="compass.svg" width="34" height="34" alt="">Brújula.</a>
<div class="language-switch" role="group" aria-label="Language" hidden><button type="button" data-language="en" lang="en" aria-pressed="true">English</button><button type="button" data-language="es" lang="es" aria-pressed="false">Español</button></div></header>
<main class="policy wrap"><h1 id="policy-title">${esc(policy.title)}</h1><p id="policy-updated">${esc(policy.updated)}</p>
<div id="policy-sections">${policy.sections.map(([h,p])=>`<section><h2>${esc(h)}</h2><p>${esc(p)}</p></section>`).join('\n')}</div>
<footer><a id="policy-back" href="./">Back to Brújula</a><a href="https://github.com/anderrow/brujula/issues" target="_blank" rel="noopener noreferrer">GitHub Issues ↗</a></footer></main></body></html>\n`);
console.log('Generated public privacy policy from the offline app copy.');
