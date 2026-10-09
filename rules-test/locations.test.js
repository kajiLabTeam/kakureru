// database.rules.json の locations のルールを、Firebase Local Emulator Suite
// 上で確かめる。LocationRepository が lat/lng と同じ update() で書く
// snapLat / snapLng(他人に見せる、マスの中心に丸めた位置)が弾かれないこと。
//
// 実行: cd rules-test && npm install && npm test
// (Java と firebase CLI が要る。本番のFirebaseには一切つながない)

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { get, ref, serverTimestamp, update } from 'firebase/database';

const ROOM = 'rooms/r1';
const ME = 'me';
const OTHER = 'other';
const OUTSIDER = 'outsider';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-kakureru',
    database: {
      rules: readFileSync(new URL('../database.rules.json', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const { set } = await import('firebase/database');
    await set(ref(ctx.database(), `${ROOM}/users`), {
      [ME]: { displayName: '自分', role: 'FUGITIVE' },
      [OTHER]: { displayName: '他の人', role: 'DEMON' },
    });
  });
});

const db = (uid) => env.authenticatedContext(uid).database();

// LocationRepository.startSendingLocation が書く update() と同じ形。
const payload = () => ({
  lat: 35.18,
  lng: 139.93,
  altitude: null,
  accuracy: 8.5,
  snapLat: 35.1807,
  snapLng: 139.9312,
  updatedAt: serverTimestamp(),
});

describe('locations の snapLat / snapLng', () => {
  test('本人は snapLat / snapLng を含めて書ける', async () => {
    await assertSucceeds(update(ref(db(ME), `${ROOM}/locations/${ME}`), payload()));
  });

  test('同室の他人はその値を読める', async () => {
    await assertSucceeds(update(ref(db(ME), `${ROOM}/locations/${ME}`), payload()));
    const snap = await assertSucceeds(get(ref(db(OTHER), `${ROOM}/locations/${ME}`)));
    assert.equal(snap.val().snapLat, 35.1807);
    assert.equal(snap.val().snapLng, 139.9312);
  });

  test('他人の locations には書けない', async () => {
    await assertFails(update(ref(db(OTHER), `${ROOM}/locations/${ME}`), payload()));
  });

  test('部屋のメンバーでない人は読めない', async () => {
    await assertSucceeds(update(ref(db(ME), `${ROOM}/locations/${ME}`), payload()));
    await assertFails(get(ref(db(OUTSIDER), `${ROOM}/locations/${ME}`)));
  });
});
