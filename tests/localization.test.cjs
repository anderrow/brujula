const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const read=path=>fs.readFileSync(path,'utf8');
function sharedCopy(){return vm.runInNewContext('('+read('app/src/main/assets/web/app.js').match(/const strings = (\{[\s\S]*?)\n  const icons/)[1].replace(/;\s*$/,'')+')');}
function complete(copy,allowed=new Set()){
 assert.deepEqual(Object.keys(copy.es).sort(),Object.keys(copy.en).sort());
 for(const key of Object.keys(copy.en)){
  assert.ok(copy.en[key]&&copy.es[key],key);
  if(!allowed.has(key))assert.notEqual(JSON.stringify(copy.es[key]),JSON.stringify(copy.en[key]),'Untranslated Spanish: '+key);
 }
}
test('Shared interface has complete, distinct English and Spanish translations',()=>{
 const copy=sharedCopy();complete(copy);
 const source=read('app/src/main/assets/web/app.js');
 for(const [,key] of source.matchAll(/\bt\('([^']+)'\)/g))assert.ok(key in copy.en,'Missing UI key: '+key);
});
test('Website translations cover every marked element and include native installation',()=>{
 const context={window:{}};vm.runInNewContext(read('docs/translations.js'),context);
 const copy=context.window.BRUJULA_TRANSLATIONS;complete(copy);
 for(const [,key] of read('docs/index.html').matchAll(/data-i18n(?:-aria|-alt)?="([^"]+)"/g))assert.ok(key in copy.es,key);
 assert.match(copy.es.iphoneDownload,/iPhone/);assert.match(copy.es.demoFoot,/español/);
});
test('Generated browser app retains Spanish and language selection',()=>{
 const source=read('docs/web-app/app.js');assert.match(source,/es: \{/);
 assert.match(source,/\+languageOptions\+/);assert.doesNotMatch(source,/if\(web\)state.locale='en'/);
 for(const area of ['Salud','Trabajo','Finanzas','Familia','Amistades','Pareja','Ocio','Crecimiento'])assert.ok(read('docs/web-app/core.js').includes(area));
});
test('Privacy paragraphs are translated in both locales',()=>{
 const context={window:{}};vm.runInNewContext(read('app/src/main/assets/web/privacy-copy.js'),context);
 const {en,es}=context.window.BrujulaPrivacy;assert.equal(en.sections.length,es.sections.length);
 en.sections.forEach((section,index)=>section.forEach((text,column)=>assert.notEqual(text,es.sections[index][column])));
 assert.notEqual(en.updated,es.updated);
});
