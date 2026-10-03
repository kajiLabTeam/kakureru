// 作成から一定日数(既定7日)以上たったルームを rooms/{roomId} ごと削除し、
// 対応する roomCodes/{code} も削除する(docs/rtdb-schema.md「ルームの掃除方針」)。
//
// 既定は dry-run(一覧を出すだけで何も消さない)。--apply を付けたときだけ削除する。
// 認証は環境変数 GOOGLE_APPLICATION_CREDENTIALS(サービスアカウント鍵のパス)を
// 人が渡す。このスクリプトは鍵の中身を読まない(Admin SDK が読む)し、出力にも出さない。
//
// 使い方は docs/rtdb-schema.md の「古いルームの掃除スクリプト」を参照。

import { pathToFileURL } from 'node:url';

const DAY_MS = 24 * 60 * 60 * 1000;
export const DEFAULT_DAYS = 7;

export function parseArgs(argv) {
  const opts = { apply: false, days: DEFAULT_DAYS, databaseURL: undefined };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--apply') {
      opts.apply = true;
    } else if (arg === '--days') {
      opts.days = Number(argv[++i]);
    } else if (arg === '--database-url') {
      opts.databaseURL = argv[++i];
    } else {
      throw new Error(`不明な引数: ${arg}`);
    }
  }
  if (!Number.isInteger(opts.days) || opts.days < 1) {
    throw new Error('--days は1以上の整数で指定してください');
  }
  return opts;
}

/**
 * 削除対象を決める(副作用なし)。
 *
 * @param rooms `rooms` ノードの値(roomId -> {meta: {createdAt, roomCode}, ...})
 * @param codeOwners 各ルームの roomCode が現在どの roomId を指しているか(code -> roomId | null)
 * @returns {{stale, skipped}} stale: 削除対象。skipped: 判断できず触らないもの
 */
export function planCleanup({ rooms, codeOwners, nowMs, days }) {
  const cutoff = nowMs - days * DAY_MS;
  const stale = [];
  const skipped = [];
  for (const [roomId, room] of Object.entries(rooms ?? {})) {
    const createdAt = room?.meta?.createdAt;
    if (typeof createdAt !== 'number') {
      // 作成時刻が読めないルームは古いかどうか判断できないので消さない。
      skipped.push({ roomId, reason: 'meta/createdAt が無い' });
      continue;
    }
    if (createdAt > cutoff) continue;

    const code = room.meta.roomCode;
    // コードは使い回される。別の(新しい)ルームがそのコードを取り直していたら、
    // roomCodes/{code} はそちらのものなので消さない。
    const ownsCode = typeof code === 'string' && codeOwners[code] === roomId;
    stale.push({ roomId, createdAt, code: typeof code === 'string' ? code : null, deleteCode: ownsCode });
  }
  return { stale, skipped };
}

export function deletionPaths(entry) {
  const updates = { [`rooms/${entry.roomId}`]: null };
  if (entry.deleteCode) updates[`roomCodes/${entry.code}`] = null;
  return updates;
}

export async function run({ argv, env, db, nowMs = Date.now(), log = console.log }) {
  const opts = parseArgs(argv);
  const cutoff = nowMs - opts.days * DAY_MS;

  // 作成時刻の昇順で並ぶので、cutoff以前だけを取る。createdAtの無いルームも
  // (nullは最小として)含まれるが、planCleanup が除外する。
  const snapshot = await db.ref('rooms').orderByChild('meta/createdAt').endAt(cutoff).get();
  const rooms = snapshot.val() ?? {};

  const codeOwners = {};
  for (const room of Object.values(rooms)) {
    const code = room?.meta?.roomCode;
    if (typeof code === 'string' && !(code in codeOwners)) {
      codeOwners[code] = (await db.ref(`roomCodes/${code}`).child('roomId').get()).val();
    }
  }

  const { stale, skipped } = planCleanup({ rooms, codeOwners, nowMs, days: opts.days });

  log(`${opts.apply ? '[APPLY]' : '[DRY-RUN]'} 作成から${opts.days}日以上たったルーム: ${stale.length}件`);
  for (const e of stale) {
    const created = new Date(e.createdAt).toISOString();
    const codeNote = e.deleteCode ? `roomCodes/${e.code} も削除` : 'roomCodes は触らない(別ルームが使用中か未設定)';
    log(`  rooms/${e.roomId}  作成=${created}  ${codeNote}`);
  }
  for (const s of skipped) log(`  スキップ rooms/${s.roomId}: ${s.reason}`);

  if (!opts.apply) {
    log('何も削除していません。実際に消すには --apply を付けてください。');
    return { stale, skipped, deleted: 0 };
  }

  let deleted = 0;
  for (const e of stale) {
    // ルームとコードを1回の更新で消す(片方だけ残る状態を作らない)。
    await db.ref().update(deletionPaths(e));
    deleted++;
  }
  log(`${deleted}件削除しました。`);
  return { stale, skipped, deleted };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error(
      'GOOGLE_APPLICATION_CREDENTIALS が未設定です。サービスアカウント鍵のパスを人が渡してください',
    );
  }
  const databaseURL = opts.databaseURL ?? process.env.FIREBASE_DATABASE_URL;
  if (!databaseURL) {
    throw new Error('対象DBのURLを --database-url か FIREBASE_DATABASE_URL で指定してください');
  }
  const { initializeApp, applicationDefault } = await import('firebase-admin/app');
  const { getDatabase } = await import('firebase-admin/database');
  initializeApp({ credential: applicationDefault(), databaseURL });
  await run({ argv: process.argv.slice(2), env: process.env, db: getDatabase() });
  process.exit(0);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
