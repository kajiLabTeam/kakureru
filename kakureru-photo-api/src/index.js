// S3互換APIの署名付きURLやアクセスキーは使わず、R2バインディング(env.PHOTOS)経由でWorkerから直接読み書きする。
// 署名付きURLはアクセスキーの発行・失効・ローテーションという運用が新たに増えるが、
// バインディングならCloudflare側の権限管理だけで完結し、鍵をどこにも持たずに済む。

const JWK_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

const MAX_BYTES = 2 * 1024 * 1024;

// Firebase の公開鍵(JWK)セット。ユーザーごとに変わらない共有データなので、
// リクエストをまたいでモジュールスコープにキャッシュしてよい
// （リクエスト固有の状態をここに置くのは避けるべきだが、これは違う）。
let jwkCache = { keys: null, expiresAt: 0 };

async function getPublicKeys() {
  if (jwkCache.keys && Date.now() < jwkCache.expiresAt) {
    return jwkCache.keys;
  }
  const res = await fetch(JWK_URL);
  if (!res.ok) throw new Error(`jwk fetch failed: ${res.status}`);
  const body = await res.json();
  // Google 側の Cache-Control に従ってキャッシュ期間を決める（決め打ちのTTLにしない）
  const m = /max-age=(\d+)/.exec(res.headers.get("cache-control") ?? "");
  const maxAge = m ? Number(m[1]) : 3600;
  jwkCache = { keys: body.keys, expiresAt: Date.now() + maxAge * 1000 };
  return jwkCache.keys;
}

function base64UrlToBytes(input) {
  const b64 = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  const bin = atob(padded);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

function decodeJsonSegment(segment) {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(segment)));
}

// Firebase Admin SDK を使わず、Google公開のJWKを使ってIDトークンをその場で検証する。
// Cloudflare Workers から呼べる軽量な自前検証（署名アルゴリズムはFirebaseの仕様どおりRS256固定）。
async function verifyIdToken(token, projectId) {
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  let header, payload;
  try {
    header = decodeJsonSegment(parts[0]);
    payload = decodeJsonSegment(parts[1]);
  } catch {
    return null;
  }

  const now = Math.floor(Date.now() / 1000);
  if (header.alg !== "RS256" || !header.kid) return null;
  if (payload.aud !== projectId) return null;
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) return null;
  if (typeof payload.sub !== "string" || payload.sub.length === 0) return null;
  if (typeof payload.exp !== "number" || payload.exp <= now) return null;
  if (typeof payload.iat !== "number" || payload.iat > now + 300) return null;

  const jwk = (await getPublicKeys()).find((k) => k.kid === header.kid);
  if (!jwk) return null;

  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    base64UrlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );

  return valid ? payload.sub : null;
}

const PATH_PATTERN = /^\/rooms\/([A-Za-z0-9_-]{1,64})\/photos\/([A-Za-z0-9_-]{1,64})$/;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const matched = PATH_PATTERN.exec(url.pathname);
    if (!matched) {
      return new Response("not found", { status: 404 });
    }
    const [, roomId, photoId] = matched;
    const key = `rooms/${roomId}/${photoId}.jpg`;

    const authHeader = request.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return new Response("unauthorized", { status: 401 });
    }

    let uid;
    try {
      uid = await verifyIdToken(authHeader.slice(7), env.FIREBASE_PROJECT_ID);
    } catch (e) {
      console.error("token verification error", e);
      return new Response("internal error", { status: 500 });
    }
    if (!uid) {
      return new Response("unauthorized", { status: 401 });
    }

    // Phase 1: 認証済みユーザーであれば誰でも同じルームの写真を読み書きできる
    // （RTDBの photos ノードを認証済み全員に開放しているのと同じ方針に合わせている）。
    // 「uid がそのルームの参加者か」の検証は行っていない。Phase 2 の課題。

    if (request.method === "PUT") {
      const declared = Number(request.headers.get("Content-Length") ?? "0");
      if (!Number.isFinite(declared) || declared <= 0 || declared > MAX_BYTES) {
        return new Response("payload too large", { status: 413 });
      }

      // 同じキーへの上書きを409で禁止する。署名付きURLを使わずWorker経由の直接書き込みにしている以上、
      // 「他人が同じ roomId/photoId を推測して先に PUT すれば差し替えられる」を防ぐ最低限の砦がこのチェック。
      if (await env.PHOTOS.head(key)) {
        return new Response("already exists", { status: 409 });
      }

      const bytes = await request.arrayBuffer();
      if (bytes.byteLength > MAX_BYTES) {
        return new Response("payload too large", { status: 413 });
      }

      await env.PHOTOS.put(key, bytes, {
        httpMetadata: {
          contentType: "image/jpeg",
          cacheControl: "public, max-age=31536000, immutable",
        },
        customMetadata: { uid, roomId },
      });

      return new Response(null, { status: 204 });
    }

    if (request.method === "GET") {
      const object = await env.PHOTOS.get(key);
      if (!object) {
        return new Response("not found", { status: 404 });
      }
      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set("etag", object.httpEtag);
      return new Response(object.body, { headers });
    }

    return new Response("method not allowed", { status: 405 });
  },
};
