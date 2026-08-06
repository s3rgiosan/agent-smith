---
description: Generate a Cloudflare zone-settings matrix report (per category, deviations flagged) for every zone on the account
argument-hint: "[name] (default: cloudflare-zones-matrix) — file is written as YYYY-MM-DD-<name>.md"
disable-model-invocation: true
---

# Cloudflare settings matrix report

Produce a markdown report comparing Cloudflare zone settings across **every zone on the account**, grouped by dashboard category, with cross-domain deviations flagged and an action point for each.

**Output file:** always prefix the filename with today's date (`YYYY-MM-DD-`). Take the base name from `$ARGUMENTS` (strip any trailing `.md`); if empty, use `cloudflare-zones-matrix`. Write to `YYYY-MM-DD-<name>.md` in the current directory — e.g. `2026-08-06-cloudflare-zones-matrix.md`.

## Prerequisite

The **`cloudflare-api`** MCP server (from the `cloudflare` plugin) must be connected and authenticated. All data is read through its `execute` tool. If it is missing, tell the user to install/authenticate it (`/plugin` → cloudflare) and stop.

## Why this is a script, not free-form

The generator below is fixed. **Run it verbatim** through the `cloudflare-api` `execute` tool — do not re-derive the matrix logic or hand-format the tables, or the output drifts between runs. The `execute` tool truncates any result over ~6000 tokens, so the generator emits in **two passes**; run it twice, changing only the three marked constants, then concatenate.

## Steps

1. **Pass 1** — run the generator with the constants as written below (`EMIT` = part 1, `INCLUDE_HEADER = true`, `INCLUDE_TAIL = false`). Capture the returned markdown.
2. **Pass 2** — run the same generator again with:
   - `const EMIT = ["Speed / Optimization","Caching","Network","DNS","Logging / Misc"];`
   - `const INCLUDE_HEADER = false;`
   - `const INCLUDE_TAIL = true;`
   Capture the returned markdown.
3. **Write** pass 1 output followed by pass 2 output to the output file (single Write, pass 1 then pass 2, no separator — pass 1 already ends with `---`).
4. **Report** back the "Top priorities" list and the output path. Do not commit or push unless the user asks.

## Generator

```js
async () => {
  // ── toggle between the two passes: change ONLY these three lines ──
  const EMIT = ["SSL/TLS","Security","Scrape Shield"];   // PASS 2: ["Speed / Optimization","Caching","Network","DNS","Logging / Misc"]
  const INCLUDE_HEADER = true;                            // PASS 2: false
  const INCLUDE_TAIL = false;                             // PASS 2: true
  // ─────────────────────────────────────────────────────────────────

  const zr = await cloudflare.request({ method: "GET", path: "/zones", query: { per_page: 50 } });
  const zones = zr.result.map(z => ({ id: z.id, name: z.name })).sort((a,b)=>a.name.localeCompare(b.name));
  const data = {};
  const limit = 5;
  for (let i=0;i<zones.length;i+=limit){ const batch=zones.slice(i,i+limit); await Promise.all(batch.map(async z=>{ const rec={};
    try{const s=await cloudflare.request({method:"GET",path:`/zones/${z.id}/settings`});for(const it of (s.result||[]))rec[it.id]=it.value;}catch(e){}
    try{const b=await cloudflare.request({method:"GET",path:`/zones/${z.id}/bot_management`});rec.bot_fight_mode=b.result?.fight_mode;rec.crawler_protection=b.result?.crawler_protection;rec.ai_bots_protection=b.result?.ai_bots_protection;}catch(e){rec.bot_fight_mode="n/a";rec.crawler_protection="n/a";rec.ai_bots_protection="n/a";}
    try{const d=await cloudflare.request({method:"GET",path:`/zones/${z.id}/dnssec`});rec.dnssec=d.result?.status;}catch(e){rec.dnssec="n/a";}
    data[z.name]=rec; })); }

  const CATS=[
    ["SSL/TLS",["ssl","ssl_recommender","min_tls_version","tls_1_3","0rtt","opportunistic_encryption","opportunistic_onion","automatic_https_rewrites","always_use_https","security_header","tls_client_auth","ciphers","sha1_support","tls_1_2_only","ech","pq_keyex"]],
    ["Security",["security_level","challenge_ttl","browser_check","bot_fight_mode","ai_bots_protection","crawler_protection","waf","privacy_pass","advanced_ddos","orange_to_orange"]],
    ["Scrape Shield",["email_obfuscation","server_side_exclude","hotlink_protection"]],
    ["Speed / Optimization",["brotli","rocket_loader","mirage","polish","webp","early_hints","minify","prefetch_preload","replace_insecure_js"]],
    ["Caching",["cache_level","browser_cache_ttl","edge_cache_ttl","development_mode","always_online","sort_query_string_for_cache","origin_error_page_pass_thru"]],
    ["Network",["http2","http3","ipv6","websockets","pseudo_ipv4","ip_geolocation","true_client_ip_header","response_buffering","proxy_read_timeout","max_upload","long_lived_grpc","visitor_ip"]],
    ["DNS",["dnssec","cname_flattening"]],
    ["Logging / Misc",["log_to_cloudflare","filter_logs_to_cloudflare","mobile_redirect"]],
  ];
  const names=Object.keys(data).sort();
  const fmt=v=>{if(v===null||v===undefined)return "—";if(typeof v==="boolean")return v?"on":"off";if(typeof v==="object")return "`"+JSON.stringify(v)+"`";return String(v);};
  const LB={ssl:"SSL",ssl_recommender:"SSL Recommender",min_tls_version:"Min TLS",tls_1_3:"TLS 1.3","0rtt":"0-RTT",opportunistic_encryption:"Opp. Encryption",opportunistic_onion:"Onion Routing",automatic_https_rewrites:"Auto HTTPS Rewrites",always_use_https:"Always HTTPS",security_header:"HSTS Header",tls_client_auth:"TLS Client Auth",ciphers:"Ciphers",sha1_support:"SHA1",tls_1_2_only:"TLS 1.2 Only",ech:"ECH",pq_keyex:"PQ Keyex",security_level:"Security Level",challenge_ttl:"Challenge TTL",browser_check:"Browser Check",bot_fight_mode:"Bot Fight Mode",ai_bots_protection:"Block AI Bots",crawler_protection:"AI Labyrinth",waf:"WAF",privacy_pass:"Privacy Pass",advanced_ddos:"Advanced DDoS",orange_to_orange:"O2O",email_obfuscation:"Email Obfuscation",server_side_exclude:"Server Side Exclude",hotlink_protection:"Hotlink Protection",brotli:"Brotli",rocket_loader:"Rocket Loader",mirage:"Mirage",polish:"Polish",webp:"WebP",early_hints:"Early Hints",minify:"Minify",prefetch_preload:"Prefetch Preload",replace_insecure_js:"Replace Insecure JS",cache_level:"Cache Level",browser_cache_ttl:"Browser Cache TTL",edge_cache_ttl:"Edge Cache TTL",development_mode:"Dev Mode",always_online:"Always Online",sort_query_string_for_cache:"Sort QS Cache",origin_error_page_pass_thru:"Origin Error Passthru",http2:"HTTP/2",http3:"HTTP/3",ipv6:"IPv6",websockets:"WebSockets",pseudo_ipv4:"Pseudo IPv4",ip_geolocation:"IP Geolocation",true_client_ip_header:"True-Client-IP",response_buffering:"Response Buffering",proxy_read_timeout:"Proxy Read Timeout",max_upload:"Max Upload",long_lived_grpc:"gRPC",visitor_ip:"Visitor IP",dnssec:"DNSSEC",cname_flattening:"CNAME Flattening",log_to_cloudflare:"Log to CF",filter_logs_to_cloudflare:"Filter Logs",mobile_redirect:"Mobile Redirect"};
  const label=id=>LB[id]||id;
  const ADVICE={ssl:"Set to `strict` (Full Strict) fleet-wide. `flexible` = unencrypted CF↔origin. `full` skips cert validation.",always_use_https:"Turn `on` to force HTTPS on every request.",tls_1_3:"Enable TLS 1.3 with 0-RTT (`zrt`) for consistency.","0rtt":"Enable 0-RTT (turns on with TLS 1.3 `zrt`).",tls_client_auth:"Align across fleet; cosmetic on Free.",challenge_ttl:"Standardize the Challenge TTL.",bot_fight_mode:"Set a fleet policy.",ai_bots_protection:"Standardize AI-crawler blocking: `block` (all pages), `only_on_ad_pages`, or `disabled`.",crawler_protection:"Enable AI Labyrinth (`enabled`) fleet-wide to trap unauthorized AI crawlers.",hotlink_protection:"Standardize hotlink protection.",cache_level:"Standardize the cache level.",browser_cache_ttl:"Standardize; a non-zero value overrides origin cache headers with an edge-side browser TTL.",pseudo_ipv4:"Standardize Pseudo IPv4."};
  const sevFor=(id,v)=>{ if(id==="ssl"&&v==="flexible")return "🔴"; if(id==="ssl"&&v==="full")return "🟠"; if(id==="always_use_https"&&v==="off")return "🔴"; return "⚪"; };

  let out="";
  if(INCLUDE_HEADER){
    out+=`# Cloudflare Zones — Settings Matrix by Category\n\n`;
    out+=`**Zones:** ${names.length} · **Generated:** ${new Date().toISOString().slice(0,10)}\n\n`;
    out+=`One section per category. The matrix shows **every** setting in the category (rows = domains, columns = settings), so the applied value is visible even when it is uniform across the fleet. **Bold ⚠️** = value differs from the fleet majority for that column. Severity in fixes: 🔴 security risk · 🟠 weaker-than-ideal · ⚪ cosmetic/policy drift.\n\n---\n\n`;
  }

  for(const [cat,ids] of CATS){
    if(!EMIT.includes(cat)) continue;
    const present=ids.filter(id=>names.some(n=>id in data[n]));
    out+=`## ${cat}\n\n`;
    if(!present.length){out+=`_No settings available in this category._\n\n---\n\n`; continue;}
    const vary=[], maj={};
    for(const id of present){
      const vals={}; for(const n of names){if(!(id in data[n]))continue;const k=fmt(data[n][id]);vals[k]=(vals[k]||0)+1;}
      if(Object.keys(vals).length>1){vary.push(id); let b=null,bc=0; for(const [k,c] of Object.entries(vals)) if(c>bc){bc=c;b=k;} maj[id]=b;}
    }
    out+=`| Domain | ${present.map(label).join(" | ")} |\n|${"---|".repeat(present.length+1)}\n`;
    for(const n of names){
      const cells=present.map(id=>{const v=fmt(data[n][id]); if(!(id in maj))return v; return v===maj[id]?v:`**${v}** ⚠️`;});
      out+=`| ${n} | ${cells.join(" | ")} |\n`;
    }
    if(!vary.length){out+=`\n_No deviations in this category — every setting is uniform across all ${names.length} domains._\n\n---\n\n`; continue;}
    out+=`\n**Deviations & fixes**\n\n`;
    for(const id of vary){
      const groups={}; for(const n of names){if(!(id in data[n]))continue;const v=fmt(data[n][id]); if(v!==maj[id])(groups[v]=groups[v]||[]).push(n);}
      out+=`- **${label(id)}** — majority \`${maj[id]}\`. ${ADVICE[id]||"Align to majority."}\n`;
      for(const [v,doms] of Object.entries(groups)) out+=`  - ${sevFor(id,v)} \`${v}\` → ${doms.join(", ")}\n`;
    }
    out+=`\n---\n\n`;
  }

  if(INCLUDE_TAIL){
    out+=`## Notes\n\n- **AI Labyrinth (\`crawler_protection\`) and Block AI Bots (\`ai_bots_protection\`):** read from the Bot Management config and shown under **Security**.\n- **Super Bot Fight Mode:** not exposed by the Free-plan API (Bot Management entitlement only) — verify in dashboard → Security → Bots.\n- **Cloudflare Access (Zero Trust):** account-scoped, not a per-zone setting.\n- **Not covered** (rule-based): WAF managed/custom rules, firewall rules, page rules, redirect rules, Workers routes, DNS records.\n\n## Top priorities\n\nDerive from the deviations above, ordered: 🔴 first (SSL \`flexible\`, Always-HTTPS off), then 🟠 (SSL \`full\`), then ⚪ policy/cosmetic drift, then any setting that is uniform but weak fleet-wide (e.g. DNSSEC disabled, Min TLS 1.0).\n`;
  }

  return out;
}
```
