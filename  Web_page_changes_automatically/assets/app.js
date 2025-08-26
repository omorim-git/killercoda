// app.js
const express = require("express");
const app = express();

const NODE_ENV = (process.env.NODE_ENV || "development").toLowerCase();
const FEATURE_X = process.env.FEATURE_X === "1";
const PORT = Number(process.env.PORT || 3000);

const isProd = NODE_ENV === "production";

app.get("/", (_req, res) => {
  const title = isProd ? "PRODUCTION MODE" : "DEVELOPMENT MODE";
  const subtitle = isProd
    ? "本番環境で稼働中"
    : "開発モード（最適化・キャッシュが無効の場合あり）";

  const html = `
  <!doctype html>
  <html lang="ja">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>${title} | Node.js Env Demo</title>
    <style>
      :root{
        --bg1:${isProd ? "#0f172a" : "#111827"};
        --bg2:${isProd ? "#1e293b" : "#0f172a"};
        --accent:${isProd ? "#22d3ee" : "#f59e0b"};
        --accent-weak:${isProd ? "rgba(34,211,238,.18)" : "rgba(245,158,11,.18)"};
        --text:#e5e7eb;
        --muted:#94a3b8;
        --ok:${isProd ? "#10b981" : "#60a5fa"};
        --warn:${isProd ? "#f43f5e" : "#f59e0b"};
      }
      *{box-sizing:border-box}
      body{
        margin:0;
        min-height:100dvh;
        color:var(--text);
        background: radial-gradient(1200px 600px at 80% -10%, var(--accent-weak), transparent 60%),
                    radial-gradient(1200px 600px at -10% 110%, var(--accent-weak), transparent 60%),
                    linear-gradient(135deg,var(--bg1),var(--bg2));
        font: 16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,"Apple Color Emoji","Segoe UI Emoji";
        display:grid; place-items:center;
      }
      .card{
        width:min(880px,92vw);
        backdrop-filter:saturate(140%) blur(6px);
        background:rgba(255,255,255,0.04);
        border:1px solid rgba(255,255,255,0.08);
        border-radius:20px;
        box-shadow: 0 20px 60px rgba(0,0,0,.35);
        padding:28px 28px 22px;
        animation: pop .6s ease-out;
      }
      @keyframes pop{from{transform:translateY(8px) scale(.98);opacity:.0}to{transform:none;opacity:1}}
      .badge{
        display:inline-flex;gap:.5rem;align-items:center;
        padding:.35rem .7rem;border-radius:9999px;
        font-weight:700;letter-spacing:.06em;
        color:${isProd ? "#052f35" : "#1f2937"};
        background:${isProd ? "#22d3ee" : "#fbbf24"};
        text-transform:uppercase;font-size:.8rem;
      }
      .header{display:flex;justify-content:space-between;align-items:center;gap:1rem;flex-wrap:wrap}
      h1{margin:.2rem 0 0;font-size:clamp(1.6rem,3vw,2rem);font-weight:800;letter-spacing:.02em}
      p.sub{margin:.2rem 0;color:var(--muted)}
      .grid{
        display:grid;gap:14px;margin-top:18px;
        grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      }
      .tile{
        border:1px solid rgba(255,255,255,.08);
        background:rgba(0,0,0,.18);
        padding:16px;border-radius:14px;
      }
      .k{display:block;color:var(--muted);font-size:.82rem}
      .v{display:block;font-size:1.05rem;font-weight:700;margin-top:.25rem}
      .pulse{
        position:relative;display:inline-block;margin-left:.4rem;
      }
      .pulse::after{
        content:"";position:absolute;inset:-6px;
        border:2px solid var(--accent);border-radius:9999px;
        opacity:.45;animation: ping 1.6s cubic-bezier(0,0,.2,1) infinite;
      }
      @keyframes ping { 0%{transform:scale(.9);opacity:.6} 70%{transform:scale(1.25);opacity:0} 100%{opacity:0} }
    </style>
  </head>
  <body>
    <main class="card">
      <div class="header">
        <div>
          <span class="badge">
            ${isProd ? "● PRODUCTION" : "● DEVELOPMENT"}
          </span>
          <span class="pulse"></span>
          <h1>Node.js Environment Demo</h1>
          <p class="sub">${subtitle}</p>
        </div>
        <div>
          ${isProd
            ? `<span class="badge" style="background:var(--ok);color:#03291e">安全対策ON</span>`
            : `<span class="badge" style="background:var(--warn);color:#3b0a0f">デバッグ表示</span>`
          }
        </div>
      </div>

      <section class="grid">
        <div class="tile">
          <span class="k">NODE_ENV</span>
          <span class="v">${NODE_ENV}</span>
        </div>
        <div class="tile">
          <span class="k">FEATURE_X</span>
          <span class="v">${FEATURE_X}</span>
        </div>
        <div class="tile">
          <span class="k">PORT</span>
          <span class="v">${PORT}</span>
        </div>
        <div class="tile">
          <span class="k">PID / TIME</span>
          <span class="v">${process.pid} / ${new Date().toLocaleString()}</span>
        </div>
      </section>
    </main>
  </body>
  </html>`;
  res.status(200).send(html);
});

app.listen(PORT, () => {
  console.log(`[boot] NODE_ENV=${NODE_ENV} FEATURE_X=${FEATURE_X} PORT=${PORT}`);
});
