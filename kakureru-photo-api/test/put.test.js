import assert from "node:assert/strict";
import { generateKeyPairSync, createSign } from "node:crypto";
import { test } from "node:test";
import worker from "../src/index.js";

const PROJECT = "test-project";
const { publicKey, privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: "jwk" }), kid: "k1", alg: "RS256" };

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");

function makeToken(uid) {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: "RS256", kid: "k1" });
  const body = b64({
    aud: PROJECT,
    iss: `https://securetoken.google.com/${PROJECT}`,
    sub: uid,
    iat: now,
    exp: now + 600,
  });
  const sig = createSign("RSA-SHA256").update(`${head}.${body}`).sign(privateKey).toString("base64url");
  return `${head}.${body}.${sig}`;
}

globalThis.fetch = async () =>
  new Response(JSON.stringify({ keys: [jwk] }), { headers: { "cache-control": "max-age=3600" } });

// put が onlyIf を解釈する最小のR2フェイク。head は意図的に無い（呼ばれたら失敗する）。
function fakeBucket() {
  const store = new Map();
  const puts = [];
  return {
    store,
    puts,
    async put(key, value, options) {
      puts.push({ key, options });
      if (options?.onlyIf?.etagDoesNotMatch === "*" && store.has(key)) return null;
      store.set(key, value);
      return { key };
    },
  };
}

function put(env, uid, body = new Uint8Array([1, 2, 3])) {
  return worker.fetch(
    new Request("https://x/rooms/r1/photos/p1", {
      method: "PUT",
      headers: { Authorization: `Bearer ${makeToken(uid)}`, "Content-Length": String(body.length) },
      body,
    }),
    env,
  );
}

test("初回のPUTは204で、onlyIf と private の cacheControl で保存される", async () => {
  const PHOTOS = fakeBucket();
  const res = await put({ PHOTOS, FIREBASE_PROJECT_ID: PROJECT }, "u1");
  assert.equal(res.status, 204);
  assert.deepEqual(PHOTOS.puts[0].options.onlyIf, { etagDoesNotMatch: "*" });
  assert.match(PHOTOS.puts[0].options.httpMetadata.cacheControl, /^private,/);
});

test("同じキーへの2回目のPUTは409で、中身は上書きされない", async () => {
  const PHOTOS = fakeBucket();
  const env = { PHOTOS, FIREBASE_PROJECT_ID: PROJECT };
  assert.equal((await put(env, "u1", new Uint8Array([1]))).status, 204);
  assert.equal((await put(env, "u2", new Uint8Array([9]))).status, 409);
  assert.deepEqual([...new Uint8Array(PHOTOS.store.get("rooms/r1/p1.jpg"))], [1]);
});

test("同時に来た2件のPUTは片方だけ成功する", async () => {
  const PHOTOS = fakeBucket();
  const env = { PHOTOS, FIREBASE_PROJECT_ID: PROJECT };
  const statuses = (await Promise.all([put(env, "u1"), put(env, "u2")])).map((r) => r.status).sort();
  assert.deepEqual(statuses, [204, 409]);
});
