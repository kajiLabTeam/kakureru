import assert from 'node:assert/strict';
import { test } from 'node:test';
import { deletionPaths, parseArgs, planCleanup, run } from './cleanup.js';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 9, 10);

const room = (ageDays, roomCode) => ({ meta: { createdAt: NOW - ageDays * DAY, roomCode } });

test('parseArgs: 既定はdry-runで7日', () => {
  assert.deepEqual(parseArgs([]), { apply: false, days: 7, databaseURL: undefined });
  assert.equal(parseArgs(['--apply']).apply, true);
  assert.equal(parseArgs(['--days', '30']).days, 30);
});

test('parseArgs: 不正な引数は拒否する', () => {
  assert.throws(() => parseArgs(['--days', '0']));
  assert.throws(() => parseArgs(['--days', 'abc']));
  assert.throws(() => parseArgs(['--force']));
});

test('planCleanup: 7日以上前だけが対象(ちょうど7日は対象)', () => {
  const rooms = { old: room(8, '1111'), edge: room(7, '2222'), fresh: room(6, '3333') };
  const { stale } = planCleanup({ rooms, codeOwners: { 1111: 'old', 2222: 'edge' }, nowMs: NOW, days: 7 });
  assert.deepEqual(stale.map((s) => s.roomId).sort(), ['edge', 'old']);
});

test('planCleanup: コードを別ルームが取り直していたらroomCodesは消さない', () => {
  const rooms = { old: room(10, '1111') };
  const { stale } = planCleanup({ rooms, codeOwners: { 1111: 'newer' }, nowMs: NOW, days: 7 });
  assert.equal(stale[0].deleteCode, false);
  assert.deepEqual(deletionPaths(stale[0]), { 'rooms/old': null });
});

test('planCleanup: createdAtが無いルームはスキップして消さない', () => {
  const { stale, skipped } = planCleanup({ rooms: { odd: { meta: {} } }, codeOwners: {}, nowMs: NOW, days: 7 });
  assert.equal(stale.length, 0);
  assert.equal(skipped[0].roomId, 'odd');
});

test('deletionPaths: ルームとコードを同時に消す', () => {
  const paths = deletionPaths({ roomId: 'r', code: '1234', deleteCode: true });
  assert.deepEqual(paths, { 'rooms/r': null, 'roomCodes/1234': null });
});

function fakeDb({ rooms, codes }) {
  const updates = [];
  const snap = (v) => ({ val: () => v });
  return {
    updates,
    ref(path) {
      if (path === undefined) return { update: async (u) => void updates.push(u) };
      if (path === 'rooms') {
        return { orderByChild: () => ({ endAt: () => ({ get: async () => snap(rooms) }) }) };
      }
      const code = path.replace('roomCodes/', '');
      return { child: () => ({ get: async () => snap(codes[code] ?? null) }) };
    },
  };
}

test('run: dry-runでは何も削除しない', async () => {
  const db = fakeDb({ rooms: { old: room(10, '1111') }, codes: { 1111: 'old' } });
  const logs = [];
  const r = await run({ argv: [], env: {}, db, nowMs: NOW, log: (m) => logs.push(m) });
  assert.equal(db.updates.length, 0);
  assert.equal(r.deleted, 0);
  assert.equal(r.stale.length, 1);
  assert.match(logs[0], /DRY-RUN/);
});

test('run: --apply でルームとコードを削除する', async () => {
  const db = fakeDb({ rooms: { old: room(10, '1111') }, codes: { 1111: 'old' } });
  const r = await run({ argv: ['--apply'], env: {}, db, nowMs: NOW, log: () => {} });
  assert.equal(r.deleted, 1);
  assert.deepEqual(db.updates, [{ 'rooms/old': null, 'roomCodes/1111': null }]);
});
