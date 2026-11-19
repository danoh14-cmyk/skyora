// SKYORA API proxy - Cloudflare Workers
// Set KMA_SERVICE_KEY as an encrypted Worker secret, never in Flutter or GitHub.
const UPSTREAM = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst';
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname !== '/forecast') return new Response('Not found', {status:404});
    if (request.method !== 'GET') return new Response('Method not allowed', {status:405});
    if (!env.KMA_SERVICE_KEY) return new Response(JSON.stringify({error:'Proxy key not configured'}), {status:503,headers:{'content-type':'application/json'}});
    const q = url.searchParams;
    const date = q.get('base_date') || '';
    const time = q.get('base_time') || '';
    const nx = Number(q.get('nx')), ny = Number(q.get('ny'));
    if (!/^\d{8}$/.test(date) || !/^(02|05|08|11|14|17|20|23)00$/.test(time) || !Number.isInteger(nx) || !Number.isInteger(ny) || nx < 1 || nx > 149 || ny < 1 || ny > 253) {
      return new Response(JSON.stringify({error:'Invalid forecast parameters'}), {status:400,headers:{'content-type':'application/json'}});
    }
    const target = new URL(UPSTREAM);
    target.searchParams.set('serviceKey', env.KMA_SERVICE_KEY);
    target.searchParams.set('pageNo','1');target.searchParams.set('numOfRows','1000');target.searchParams.set('dataType','JSON');
    for (const key of ['base_date','base_time','nx','ny']) target.searchParams.set(key, q.get(key));
    // Cache per-grid forecast; cache key does not include the API secret.
    const cacheKey = new Request(url.origin + '/forecast?' + new URLSearchParams({base_date:date,base_time:time,nx:String(nx),ny:String(ny)}));
    const cache = caches.default;
    const hit = await cache.match(cacheKey);
    if (hit) return hit;
    try {
      const upstream = await fetch(target.toString(), {signal: AbortSignal.timeout(10000)});
      const body = await upstream.text();
      const result = new Response(body, {status:upstream.status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'public, max-age=300'}});
      if (upstream.ok && body.includes('"resultCode":"00"')) ctx.waitUntil(cache.put(cacheKey,result.clone()));
      return result;
    } catch (_) {return new Response(JSON.stringify({error:'Weather upstream temporarily unavailable'}),{status:502,headers:{'content-type':'application/json'}});}
  }
};
