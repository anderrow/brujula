const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
// Add a language code here when the iPhone app supports another language,
// then translate every catalog entry before shipping that language.
const languages = ['en', 'es'];
const catalogPath = path.join(root, 'Brujula', 'Localizable.xcstrings');
const infoPath = path.join(root, 'Brujula', 'InfoPlist.xcstrings');
const projectPath = path.join(root, 'Brujula.xcodeproj', 'project.pbxproj');
const swiftDir = path.join(root, 'Brujula');

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function unescape(value) {
  return value.replace(/\\n/g, '\n').replace(/\\"/g, '"').replace(/\\\\/g, '\\');
}

function uiLiterals(source) {
  const found = new Set();
  const add = value => {
    const text = unescape(value);
    if (text && !text.includes('\\(') && !text.startsWith('http') && !['brujula-backup', 'brujula-recovery-copy'].includes(text)) found.add(text);
  };
  for (const line of source.split('\n')) {
    for (const match of line.matchAll(/(?:Text|Button|Section|Label|Toggle|Picker|TextField|Link|LabeledContent|navigationTitle|accessibilityLabel|accessibilityValue|accessibilityHint|eyebrow|statistic|localized|localizedFormat|\.alert)\(\s*"((?:\\.|[^"\\])*)"/g)) add(match[1]);
    for (const match of line.matchAll(/String\(localized:\s*"((?:\\.|[^"\\])*)"/g)) add(match[1]);
    for (const match of line.matchAll(/foot:\s*"((?:\\.|[^"\\])*)"/g)) add(match[1]);
    if (line.includes('systemName') || line.includes('systemImage')) continue;
    for (const match of line.matchAll(/\?\s*"((?:\\.|[^"\\])*)"\s*:\s*"((?:\\.|[^"\\])*)"/g)) {
      add(match[1]);
      add(match[2]);
    }
  }
  return found;
}

if (!fs.existsSync(catalogPath)) fail('Missing ios/Brujula/Localizable.xcstrings');
if (!fs.existsSync(infoPath)) fail('Missing ios/Brujula/InfoPlist.xcstrings');
if (process.exitCode) process.exit(process.exitCode);

const catalog = readJSON(catalogPath);
const info = readJSON(infoPath);
if (catalog.sourceLanguage !== 'en') fail('The string catalog source language must be English.');
if (info.sourceLanguage !== 'en') fail('The Info.plist catalog source language must be English.');

const strings = catalog.strings || {};
const literals = new Set();
for (const file of fs.readdirSync(swiftDir).filter(name => name.endsWith('.swift'))) {
  for (const literal of uiLiterals(fs.readFileSync(path.join(swiftDir, file), 'utf8'))) literals.add(literal);
}

for (const literal of literals) {
  if (!strings[literal]) fail(`UI string is missing from the catalog: ${JSON.stringify(literal)}`);
}

const sameInEveryLanguage = new Set(['Brújula', '%lld / 10', '%lld/10', '%lld / 4000', '.', '/ 10', 'English', 'Español']);
// New recovery copy remains in English; existing localized copy stays unchanged.
for (const key of ['Retry loading', 'Export preserved data (recovery copy)', 'Some reminders could not be restored. Open Reminders and save again.']) sameInEveryLanguage.add(key);
// Optional prompt copy follows the same explicit English-only artifact rule.
for (const key of ["Reflection prompts", "What have you done recently to improve this area of your life?", "What else could you have tried, or what got in the way?", "What small step would you like to take next?", "These questions are optional. Use whichever helps you reflect."]) sameInEveryLanguage.add(key);
for (const [key, entry] of Object.entries(strings)) {
  for (const language of languages) {
    const unit = entry.localizations?.[language]?.stringUnit;
    if (!unit || unit.state !== 'translated' || !String(unit.value || '').trim()) {
      fail(`Missing ${language} translation for ${JSON.stringify(key)}`);
    }
  }
  const english = entry.localizations.en.stringUnit.value;
  const spanish = entry.localizations.es.stringUnit.value;
  if (english === spanish && !sameInEveryLanguage.has(key)) {
    fail(`Spanish matches English for ${JSON.stringify(key)}`);
  }
  const placeholders = value => [...value.matchAll(/%(?:\d+\$)?(?:lld|@)/g)].map(match => match[0]).sort().join(',');
  if (placeholders(english) !== placeholders(spanish)) fail(`Format placeholders differ for ${JSON.stringify(key)}`);
  if (!entry.comment) fail(`Missing translator comment for ${JSON.stringify(key)}`);
}

const areas = {
  Health: 'Salud',
  Work: 'Trabajo',
  Finances: 'Finanzas',
  Family: 'Familia',
  Friends: 'Amistades',
  Partner: 'Pareja',
  Leisure: 'Ocio',
  Growth: 'Crecimiento'
};
for (const [english, spanish] of Object.entries(areas)) {
  if (strings[english]?.localizations?.es?.stringUnit?.value !== spanish) {
    fail(`Area ${english} must use the Android Spanish name ${spanish}.`);
  }
}

for (const key of ['CFBundleDisplayName', 'CFBundleName']) {
  const entry = info.strings?.[key];
  for (const language of languages) {
    const unit = entry?.localizations?.[language]?.stringUnit;
    if (!unit || unit.state !== 'translated' || !String(unit.value || '').trim()) {
      fail(`Info.plist ${key} needs a ${language} value.`);
    }
  }
}

const project = fs.readFileSync(projectPath, 'utf8');
if (!project.includes('Localizable.xcstrings') || !project.includes('InfoPlist.xcstrings')) {
  fail('Both string catalogs must be members of the Xcode project.');
}
const regions = project.match(/knownRegions = \(([^)]*)\)/);
for (const language of languages) {
  if (!regions || !regions[1].split(',').map(item => item.trim()).includes(language)) {
    fail(`knownRegions must include ${language}.`);
  }
}

const requiredFormats = ['Language', 'System language', 'English', 'Español', '%@ score', '%@ plus one', '%@ minus one', '%lld/10 · compared with %lld/10', '%lld out of 10', 'Dashed line: %@'];
for (const key of requiredFormats) {
  if (!strings[key]) fail(`Missing format string ${JSON.stringify(key)}`);
}

if (!process.exitCode) console.log(`iPhone catalog coverage validated for ${languages.join(' and ')} (${Object.keys(strings).length} entries; new recovery and prompt messages use English source copy).`);
