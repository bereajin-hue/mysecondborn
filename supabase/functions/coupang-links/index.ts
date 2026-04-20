import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const ACCESS_KEY = Deno.env.get('COUPANG_ACCESS_KEY') ?? '';
const SECRET_KEY = Deno.env.get('COUPANG_SECRET_KEY') ?? '';
const TRACKING_ID = Deno.env.get('COUPANG_TRACKING_ID') ?? '';
const API_BASE = 'https://api-gateway.coupang.com';
const DEEP_LINK_PATH = '/v2/providers/affiliate_open_api/apis/openapi/v1/deeplink';

async function hmacSha256Hex(message: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// 공식 가이드 기준: yyMMddTHHmmssZ (UTC, SimpleDateFormat "yyMMdd'T'HHmmss'Z'")
function coupangDatetime(): string {
  const now = new Date();
  const yy = String(now.getUTCFullYear()).slice(2);
  const MM = String(now.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(now.getUTCDate()).padStart(2, '0');
  const HH = String(now.getUTCHours()).padStart(2, '0');
  const mm = String(now.getUTCMinutes()).padStart(2, '0');
  const ss = String(now.getUTCSeconds()).padStart(2, '0');
  return `${yy}${MM}${dd}T${HH}${mm}${ss}Z`;
}

function fallbackUrl(productName: string): string {
  const q = encodeURIComponent(productName);
  const tag = TRACKING_ID ? `&lptag=${TRACKING_ID}` : '';
  return `https://www.coupang.com/np/search?q=${q}&channel=user${tag}`;
}

async function fetchDeepLink(productName: string): Promise<string> {
  if (!ACCESS_KEY || !SECRET_KEY) return fallbackUrl(productName);

  const searchUrl = `https://www.coupang.com/np/search?q=${encodeURIComponent(productName)}&channel=user`;
  const datetime = coupangDatetime();

  // 공식 가이드: message = datetime + method + path + query (개행 없음)
  const message = `${datetime}POST${DEEP_LINK_PATH}`;
  const signature = await hmacSha256Hex(message, SECRET_KEY);
  const authorization = `CEA algorithm=HmacSHA256, access-key=${ACCESS_KEY}, signed-date=${datetime}, signature=${signature}`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10_000);

  try {
    const res = await fetch(`${API_BASE}${DEEP_LINK_PATH}`, {
      method: 'POST',
      headers: {
        Authorization: authorization,
        'Content-Type': 'application/json;charset=UTF-8',
      },
      body: JSON.stringify({ coupangUrls: [searchUrl] }),
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (!res.ok) return fallbackUrl(productName);

    const json = await res.json();
    // 공식 가이드 기준 rCode는 "0" (문자열)
    if (json.rCode === '0' && json.data?.[0]?.shortenUrl) {
      return json.data[0].shortenUrl;
    }
    return fallbackUrl(productName);
  } catch {
    clearTimeout(timeoutId);
    return fallbackUrl(productName);
  }
}

async function fetchWithRetry(productName: string): Promise<string> {
  const delays = [1000, 3000, 9000];
  for (let i = 0; i < 3; i++) {
    try {
      return await fetchDeepLink(productName);
    } catch {
      if (i === 2) return fallbackUrl(productName);
      await new Promise((r) => setTimeout(r, delays[i]));
    }
  }
  return fallbackUrl(productName);
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const { product_name } = await req.json();
    if (!product_name || typeof product_name !== 'string') {
      return new Response(
        JSON.stringify({ error: '제품명이 필요해요.' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const url = await fetchWithRetry(product_name.trim());
    return new Response(JSON.stringify({ url }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch {
    return new Response(
      JSON.stringify({ url: fallbackUrl('') }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
