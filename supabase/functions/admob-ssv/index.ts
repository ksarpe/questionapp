// ============================================================================
// AdMob rewarded-ad Server-Side Verification (SSV) callback.
//
// Google calls this endpoint (GET) after a user finishes a rewarded ad, with
// signed query params. We verify the ECDSA signature against Google's public
// keys, then log the (verified) reward.
//
// This is now a PURE AUDIT log. Under the reveal-feed model the next question is
// SERVER-PICKED (random unseen) by the reveal_ad_question RPC the client calls
// once the reward fires — so there is no specific question id to attribute here,
// and nothing for this callback to grant. It only records the verified reward.
//
// Setup
//   1. AdMob: set the rewarded ad unit's SSV callback URL to
//        https://<project-ref>.functions.supabase.co/admob-ssv
//   2. In the Flutter app, when showing the ad, set the SSV options so we know
//      WHO earned the reward:
//        ServerSideVerificationOptions(userId: supabaseUserId)  // -> ?user_id=
//   3. Deploy (public, no JWT — Google calls it):
//        supabase functions deploy admob-ssv --no-verify-jwt
//
// Docs: https://developers.google.com/admob/flutter/rewarded#ssv
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";

// ---- Google public keys (cached ~24h) -------------------------------------
let keyCache: { at: number; keys: Record<string, CryptoKey> } | null = null;

async function getVerifierKey(keyId: string): Promise<CryptoKey | null> {
  if (!keyCache || Date.now() - keyCache.at > 24 * 3600 * 1000) {
    const json = await (await fetch(KEYS_URL)).json();
    const keys: Record<string, CryptoKey> = {};
    for (const k of json.keys) keys[String(k.keyId)] = await importEcKey(k.pem);
    keyCache = { at: Date.now(), keys };
  }
  return keyCache.keys[keyId] ?? null;
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function importEcKey(pem: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "spki",
    pemToDer(pem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
}

function base64urlToBytes(s: string): Uint8Array {
  const b64 = (s.replace(/-/g, "+").replace(/_/g, "/"))
    .padEnd(s.length + ((4 - (s.length % 4)) % 4), "=");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

// AdMob signs in ASN.1 DER; Web Crypto's verify wants raw r||s (IEEE P1363).
function derToP1363(der: Uint8Array): Uint8Array {
  let i = 2; // skip SEQ tag + length (short form for P-256)
  if (der[i++] !== 0x02) throw new Error("bad DER (r)");
  let rLen = der[i++];
  const r = der.slice(i, i + rLen); i += rLen;
  if (der[i++] !== 0x02) throw new Error("bad DER (s)");
  let sLen = der[i++];
  const s = der.slice(i, i + sLen);
  const norm = (x: Uint8Array) => {
    const t = x[0] === 0x00 ? x.slice(1) : x; // drop sign byte
    const out = new Uint8Array(32);
    out.set(t, 32 - t.length);
    return out;
  };
  const out = new Uint8Array(64);
  out.set(norm(r), 0);
  out.set(norm(s), 32);
  return out;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const qs = url.search.slice(1); // raw query string, no '?'

  // Per AdMob: the last two params are always `signature` then `key_id`.
  // The content to verify is everything before `&signature=`.
  const sigIdx = qs.indexOf("&signature=");
  if (sigIdx === -1) return new Response("missing signature", { status: 400 });
  const message = qs.slice(0, sigIdx);

  const p = url.searchParams;
  const signature = p.get("signature");
  const keyId = p.get("key_id");
  if (!signature || !keyId) return new Response("missing params", { status: 400 });

  const key = await getVerifierKey(keyId);
  if (!key) return new Response("unknown key_id", { status: 400 });

  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    derToP1363(base64urlToBytes(signature)),
    new TextEncoder().encode(message),
  );
  if (!ok) return new Response("bad signature", { status: 403 });

  // ---- verified -> read the reward fields ----
  const transactionId = p.get("transaction_id")!;
  const userId = p.get("user_id");          // we passed this when loading the ad
  const rewardAmount = p.get("reward_amount");

  // Idempotent audit log (unique transaction_id). The actual reveal is done
  // client-side via reveal_ad_question, which server-picks a random unseen
  // question — so there is nothing question-specific to grant here.
  const { error: logErr } = await supabase.from("ad_reward_events").insert({
    user_id: userId,
    ad_unit_id: p.get("ad_unit"),
    reward_item: p.get("reward_item"),
    reward_amount: rewardAmount ? Number(rewardAmount) : null,
    transaction_id: transactionId,
    verified: true,
  });
  if (logErr && logErr.code !== "23505") { // 23505 = already processed
    console.error("ad_reward_events insert failed:", logErr);
    return new Response("DB error", { status: 500 });
  }

  return new Response("OK", { status: 200 });
});
