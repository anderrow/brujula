const assert = require('node:assert/strict');
const { test } = require('node:test');
const C = require('../app/src/main/assets/web/core.js');

function ratedState() {
  const s=C.initial();C.categories.forEach(c=>s.draft.scores[c.id]=6);return s;
}
test('a fresh installation contains no scores, notes or check-ins', () => {
  const s = C.initial();
  assert.ok(C.categories.every(c=>s.draft.scores[c.id]===null && s.draft.notes[c.id]===''));
  assert.equal(C.average(s.draft.scores), null);
  assert.equal(s.history.length, 0);
  assert.equal(C.complete(s.draft),false);
  assert.throws(()=>C.snapshot(s,'Incomplete'));
  assert.ok(C.validate(s));
});
test('editing a draft cannot alter saved scores or notes', () => {
  const s = ratedState();
  s.draft.notes.health = 'A walk every day. <script>not code</script>';
  const saved = C.snapshot(s, 'A meaningful moment');
  s.history.push(saved);
  s.draft.notes.health = 'A different reflection';
  s.draft.scores.health = 2;
  assert.equal(s.history[0].scores.health, 6);
  assert.equal(s.history[0].notes.health, 'A walk every day. <script>not code</script>');
  assert.ok(C.validate(JSON.parse(JSON.stringify(s))));
});
test('restore validation rejects corrupt scores, notes, dates, versions and duplicate ids', () => {
  const mutations = [
    s => s.version = 99,
    s => s.draft.scores.family = 11,
    s => s.draft.scores.health = 4.5,
    s => s.draft.notes.health = 123,
    s => s.draft.notes.health = 'x'.repeat(4001),
    s => s.history[0].at = 'bad-date',
    s => s.history.push(C.clone(s.history[0])),
    s => delete s.draft.scores.partner,
    s => s.history[0].title = 'x'.repeat(81),
  ];
  for(const mutate of mutations){const s=ratedState();s.history.push(C.snapshot(s,'Saved moment'));mutate(s);assert.equal(C.validate(s),false);}
  for(const bad of [null, {}, [], {version:1}])assert.equal(C.validate(bad),false);
});
test('old backups migrate without losing scores, notes or historical entries',()=>{
  const old=ratedState();old.draft.notes.family='Keep this reflection';old.history.push(C.snapshot(old,'An earlier moment'));old.version=1;
  const migrated=C.migrate(old);
  assert.equal(migrated.version,2);assert.deepEqual(migrated.draft,old.draft);assert.deepEqual(migrated.history,old.history);assert.equal(old.version,1);
  assert.throws(()=>C.migrate({...old,version:99}));
});
test('partial averages ignore unanswered areas and preserve a deliberate zero',()=>{
  const s=C.initial();s.draft.scores.health=0;s.draft.scores.work=8;
  assert.equal(C.average(s.draft.scores),4);assert.ok(C.validate(s));assert.equal(C.complete(s.draft),false);
});
test('radar geometry maps boundary scores to center and outer ring', () => {
  const zeros=Object.fromEntries(C.categories.map(c=>[c.id,0]));
  const tens=Object.fromEntries(C.categories.map(c=>[c.id,10]));
  for(const point of C.points(zeros))assert.deepEqual(point,{x:180,y:168});
  for(const point of C.points(tens))assert.ok(Math.abs(Math.hypot(point.x-180,point.y-168)-113)<1e-9);
});
