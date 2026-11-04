const fs = require('node:fs');
const model = require('../../app/src/main/assets/web/core.js');
const state = model.initial();
for (const area of model.categories) state.draft.scores[area.id] = area.id === 'health' ? 0 : 6;
state.draft.notes.health = 'Walk by the canal.';
state.history.push(model.snapshot(state, 'A check-in'));
state.version = 1;
fs.writeFileSync(process.argv[2], JSON.stringify(state));
