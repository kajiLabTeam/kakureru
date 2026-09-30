// database.rules.json の catches / catchPhotos のルールを、Firebase Local
// Emulator Suite 上で確かめる(issue #144)。
//
// 実行: cd rules-test && npm install && npm test
// (Java と firebase CLI が要る。本番のFirebaseには一切つながない)

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  get,
  push,
  ref,
  remove,
  runTransaction,
  serverTimestamp,
  set,
  update,
} from 'firebase/database';

const ROOM = 'rooms/r1';
const DEMON = 'demon';
const FUGITIVE = 'fugitive';
const OTHER = 'other';

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
    await set(ref(ctx.database(), `${ROOM}/users`), {
      [DEMON]: { displayName: '鬼', role: 'DEMON' },
      [FUGITIVE]: { displayName: '逃走者', role: 'FUGITIVE' },
      [OTHER]: { displayName: '他の人', role: 'FUGITIVE' },
    });
  });
});

const db = (uid) => env.authenticatedContext(uid).database();

// reportCatch と同じ形の新規作成。
const newCatch = (overrides = {}) => ({
  demonUserId: DEMON,
  fugitiveUserId: FUGITIVE,
  caughtAt: serverTimestamp(),
  ...overrides,
});

// 既にある捕獲(caughtAtは固定値)をルールを通さずに置く。
async function seedCatch(id = 'c1', extra = {}) {
  const value = {
    demonUserId: DEMON,
    fugitiveUserId: FUGITIVE,
    caughtAt: 1000,
    ...extra,
  };
  await env.withSecurityRulesDisabled(async (ctx) => {
    await set(ref(ctx.database(), `${ROOM}/catches/${id}`), value);
  });
  return value;
}

async function seedCatchPhoto(id = 'p1') {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await set(ref(ctx.database(), `${ROOM}/catchPhotos/${id}`), {
      catchId: 'c1',
      demonUid: DEMON,
      fugitiveUid: FUGITIVE,
      takenAt: 1000,
    });
  });
}

describe('catches の新規作成', () => {
  test('鬼が自分のuidで、同じルームの逃走者を捕まえられる', async () => {
    await assertSucceeds(set(push(ref(db(DEMON), `${ROOM}/catches`)), newCatch()));
  });

  test('他人になりすまして捕獲を書けない', async () => {
    await assertFails(set(ref(db(OTHER), `${ROOM}/catches/c1`), newCatch()));
  });

  test('未ログインでは書けない', async () => {
    await assertFails(
      set(ref(env.unauthenticatedContext().database(), `${ROOM}/catches/c1`), newCatch()),
    );
  });

  test('caughtAtを過去や未来の時刻にできない', async () => {
    const d = db(DEMON);
    await assertFails(set(ref(d, `${ROOM}/catches/c1`), newCatch({ caughtAt: Date.now() - 60_000 })));
    await assertFails(set(ref(d, `${ROOM}/catches/c2`), newCatch({ caughtAt: Date.now() + 60_000 })));
  });

  test('ルームの参加者でない相手は捕まえられない', async () => {
    await assertFails(
      set(ref(db(DEMON), `${ROOM}/catches/c1`), newCatch({ fugitiveUserId: 'stranger' })),
    );
  });

  test('自分自身は捕まえられない', async () => {
    await assertFails(
      set(ref(db(DEMON), `${ROOM}/catches/c1`), newCatch({ fugitiveUserId: DEMON })),
    );
  });

  test('ルームの参加者でなければ捕獲を書けない', async () => {
    await assertFails(
      set(ref(db('stranger'), `${ROOM}/catches/c1`), newCatch({ demonUserId: 'stranger' })),
    );
  });

  test('既にあるcatchIdは上書きできない', async () => {
    await seedCatch('c1');
    await assertFails(set(ref(db(DEMON), `${ROOM}/catches/c1`), newCatch()));
  });

  test('作成時に写真IDや余計な項目を混ぜられない', async () => {
    const d = db(DEMON);
    await assertFails(set(ref(d, `${ROOM}/catches/c1`), newCatch({ catchPhotoId: 'p1' })));
    await assertFails(set(ref(d, `${ROOM}/catches/c2`), newCatch({ extra: true })));
  });

  test('必須の項目が欠けていると書けない', async () => {
    await assertFails(
      set(ref(db(DEMON), `${ROOM}/catches/c1`), {
        demonUserId: DEMON,
        caughtAt: serverTimestamp(),
      }),
    );
  });
});

describe('catches の削除(取り消し)', () => {
  test('捕まった逃走者本人は取り消せる', async () => {
    await seedCatch();
    await assertSucceeds(remove(ref(db(FUGITIVE), `${ROOM}/catches/c1`)));
  });

  test('捕獲を作った鬼は取り消せる', async () => {
    await seedCatch();
    await assertSucceeds(remove(ref(db(DEMON), `${ROOM}/catches/c1`)));
  });

  test('当事者以外は取り消せない', async () => {
    await seedCatch();
    await assertFails(remove(ref(db(OTHER), `${ROOM}/catches/c1`)));
  });

  test('当事者以外はcatchesをまとめて消せない', async () => {
    await seedCatch();
    await assertFails(remove(ref(db(OTHER), `${ROOM}/catches`)));
  });

  // 取り消しの期限(10秒)はルールでは見ない(時計のずれで正当な取り消しを弾かないため)。
  test('期限を過ぎた古い捕獲でも、ルール上は取り消せる', async () => {
    await seedCatch('c1', { caughtAt: 1 });
    await assertSucceeds(remove(ref(db(FUGITIVE), `${ROOM}/catches/c1`)));
  });
});

describe('catches の更新(写真の紐づけ)', () => {
  test('鬼はattachCatchPhotoと同じ形で写真IDを付けられる', async () => {
    await seedCatch();
    const result = await assertSucceeds(
      runTransaction(ref(db(DEMON), `${ROOM}/catches/c1`), (current) =>
        current == null ? null : { ...current, catchPhotoId: 'p1' },
      ),
    );
    if (!result.committed || result.snapshot.val()?.catchPhotoId !== 'p1') {
      throw new Error('写真IDが付いていない');
    }
  });

  // attachCatchPhotoは手元にキャッシュが無いとnullで呼ばれ、そのまま返す。
  // 取り消し済みの捕獲に対して権限エラーにならず、nullで確定すること。
  test('取り消し済みの捕獲へのトランザクションはnullのまま確定する', async () => {
    const result = await assertSucceeds(
      runTransaction(ref(db(DEMON), `${ROOM}/catches/gone`), (current) =>
        current == null ? null : { ...current, catchPhotoId: 'p1' },
      ),
    );
    if (result.snapshot.val() !== null) throw new Error('捕獲ができてしまった');
  });

  test('caughtAt・demonUserId・fugitiveUserIdは書き換えられない', async () => {
    const base = await seedCatch();
    const d = db(DEMON);
    await assertFails(set(ref(d, `${ROOM}/catches/c1`), { ...base, catchPhotoId: 'p1', caughtAt: 2000 }));
    await assertFails(set(ref(d, `${ROOM}/catches/c1`), { ...base, catchPhotoId: 'p1', fugitiveUserId: OTHER }));
    await assertFails(update(ref(d, `${ROOM}/catches/c1`), { caughtAt: 2000 }));
    await assertFails(set(ref(d, `${ROOM}/catches/c1/caughtAt`), 2000));
  });

  test('鬼が交代しても、別の鬼を名乗るようには書き換えられない', async () => {
    const base = await seedCatch();
    await assertFails(set(ref(db(OTHER), `${ROOM}/catches/c1`), { ...base, demonUserId: OTHER }));
  });

  test('鬼以外は写真IDを付けられない', async () => {
    await seedCatch();
    await assertFails(update(ref(db(FUGITIVE), `${ROOM}/catches/c1`), { catchPhotoId: 'p1' }));
    await assertFails(update(ref(db(OTHER), `${ROOM}/catches/c1`), { catchPhotoId: 'p1' }));
  });

  test('余計な項目は足せない', async () => {
    await seedCatch();
    await assertFails(update(ref(db(DEMON), `${ROOM}/catches/c1`), { extra: true }));
  });
});

describe('catchPhotos', () => {
  const photo = (overrides = {}) => ({
    catchId: 'c1',
    demonUid: DEMON,
    fugitiveUid: FUGITIVE,
    takenAt: serverTimestamp(),
    ...overrides,
  });

  test('鬼は自分のuidで写真のメタデータを書ける', async () => {
    await assertSucceeds(set(ref(db(DEMON), `${ROOM}/catchPhotos/p1`), photo()));
  });

  test('他人になりすまして書けない', async () => {
    await assertFails(set(ref(db(OTHER), `${ROOM}/catchPhotos/p1`), photo()));
  });

  test('ルームの参加者でなければ書けない', async () => {
    await assertFails(
      set(ref(db('stranger'), `${ROOM}/catchPhotos/p1`), photo({ demonUid: 'stranger' })),
    );
  });

  test('fugitiveUidは同じルームの自分以外の参加者に限る', async () => {
    const d = db(DEMON);
    await assertFails(set(ref(d, `${ROOM}/catchPhotos/p1`), photo({ fugitiveUid: 'stranger' })));
    await assertFails(set(ref(d, `${ROOM}/catchPhotos/p2`), photo({ fugitiveUid: DEMON })));
  });

  test('takenAtを過去や未来の時刻にできない', async () => {
    const d = db(DEMON);
    await assertFails(set(ref(d, `${ROOM}/catchPhotos/p1`), photo({ takenAt: Date.now() - 60_000 })));
    await assertFails(set(ref(d, `${ROOM}/catchPhotos/p2`), photo({ takenAt: Date.now() + 60_000 })));
  });

  test('既にある写真は上書き・書き換えできない', async () => {
    await seedCatchPhoto();
    const d = db(DEMON);
    await assertFails(set(ref(d, `${ROOM}/catchPhotos/p1`), photo()));
    await assertFails(update(ref(d, `${ROOM}/catchPhotos/p1`), { fugitiveUid: OTHER }));
  });

  test('撮った鬼と、捕まった逃走者は消せる', async () => {
    await seedCatchPhoto('p1');
    await seedCatchPhoto('p2');
    await assertSucceeds(remove(ref(db(DEMON), `${ROOM}/catchPhotos/p1`)));
    await assertSucceeds(remove(ref(db(FUGITIVE), `${ROOM}/catchPhotos/p2`)));
  });

  test('当事者以外は消せない', async () => {
    await seedCatchPhoto();
    await assertFails(remove(ref(db(OTHER), `${ROOM}/catchPhotos/p1`)));
  });
});

// undoCatchは捕獲・写真・自分の役割の3つを続けて書く。すべて通ること。
test('undoCatchと同じ書き込みの組が、捕まった本人から通る', async () => {
  await seedCatch('c1', { catchPhotoId: 'p1' });
  await seedCatchPhoto('p1');
  const d = db(FUGITIVE);
  await assertSucceeds(
    Promise.all([
      set(ref(d, `${ROOM}/catches/c1`), null),
      set(ref(d, `${ROOM}/catchPhotos/p1`), null),
      update(ref(d, `${ROOM}/users/${FUGITIVE}`), { role: 'FUGITIVE', becameDemonAt: null }),
    ]),
  );
});

describe('既存の機能が壊れていない', () => {
  test('自分の位置を書ける', async () => {
    await assertSucceeds(set(ref(db(DEMON), `${ROOM}/locations/${DEMON}`), { lat: 1, lng: 2 }));
  });

  test('足元写真のメタデータを書ける', async () => {
    await assertSucceeds(
      set(ref(db(DEMON), `${ROOM}/photos/p1`), { uid: DEMON, takenAt: serverTimestamp() }),
    );
  });

  test('イベントログを追記できる', async () => {
    await assertSucceeds(
      set(push(ref(db(DEMON), `${ROOM}/events`)), {
        type: 'catch',
        at: serverTimestamp(),
        uid: DEMON,
        targetUid: FUGITIVE,
      }),
    );
  });

  test('参加者は捕獲と写真の一覧を読める', async () => {
    await seedCatch();
    await assertSucceeds(get(ref(db(OTHER), `${ROOM}/catches`)));
    await assertSucceeds(get(ref(db(OTHER), `${ROOM}/catchPhotos`)));
  });
});
