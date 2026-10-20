// Store art that is not a screenshot: 1024x1024 promoted-purchase images and In-App Event cards.
//   node Store/art/promo.mjs [<dir of raw CI shots>]
// Writes Store/art/promo/*.png. No prices or words like "free" anywhere (App Review 2.3.7); almost no text at all.
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync, readFileSync, readdirSync, existsSync } from "fs";

const out = "C:/Users/Matthew/ironbook/Store/art/promo";
const raw = process.argv[2];
mkdirSync(out, { recursive: true });
const b = await chromium.launch();

const BOARD = `background:#0b0b0c;background-image:radial-gradient(900px 700px at 15% 5%,rgba(245,242,235,.10),transparent 60%),radial-gradient(1000px 900px at 105% 100%,rgba(230,56,47,.18),transparent 60%)`;
const FONT = `<link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,800;0,900;1,900&display=block" rel="stylesheet">`;
// A starburst as an SVG polygon.
function star(points, inner, size, fill) {
  const r = size / 2, pts = [];
  for (let i = 0; i < points * 2; i++) {
    const a = (i * Math.PI) / points - Math.PI / 2, rr = i % 2 === 0 ? r : r * inner;
    pts.push(`${(r + Math.cos(a) * rr).toFixed(1)},${(r + Math.sin(a) * rr).toFixed(1)}`);
  }
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><polygon points="${pts.join(" ")}" fill="${fill}"/></svg>`;
}
const tape = (t, rot = -4, size = 64, col = "linear-gradient(135deg,#e6382f,#8c1a1a)") =>
  `<div style="display:inline-block;transform:rotate(${rot}deg);background:${col};color:#f5f2eb;font:900 ${size}px Nunito;letter-spacing:${size / 8}px;padding:${size / 4}px ${size / 2}px;box-shadow:0 18px 40px rgba(0,0,0,.6)">${t}</div>`;
const glyph = (name) => ({
  crown: `<svg width="300" height="300" viewBox="0 0 24 24"><path fill="#0b0b0c" d="M3 7l4.5 4L12 4l4.5 7L21 7l-2 11H5L3 7z"/></svg>`,
  stack: `<svg width="300" height="300" viewBox="0 0 24 24" fill="#0b0b0c"><path d="M12 2 2 7l10 5 10-5-10-5z"/><path d="M2 12l10 5 10-5" stroke="#0b0b0c" stroke-width="2.2" fill="none" stroke-linejoin="round"/><path d="M2 17l10 5 10-5" stroke="#0b0b0c" stroke-width="2.2" fill="none" stroke-linejoin="round"/></svg>`,
  shield: `<svg width="300" height="300" viewBox="0 0 24 24"><path fill="#0b0b0c" d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3z"/></svg>`,
  medal: `<svg width="300" height="300" viewBox="0 0 24 24" fill="#0b0b0c"><path d="M7 2h4l1 4-3 3-3-3z"/><path d="M13 2h4l1 4-3 3-3-3z" opacity=".75"/><circle cx="12" cy="15" r="6.5"/></svg>`,
}[name]);

async function square(file, inner) {
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  await p.setContent(`<!doctype html><html><head>${FONT}</head><body style="margin:0;width:1024px;height:1024px;overflow:hidden;${BOARD};position:relative">${inner}</body></html>`);
  await p.waitForTimeout(600);
  await p.screenshot({ path: `${out}/${file}`, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  await p.close();
  console.log("wrote", file);
}
const center = (html) => `<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">${html}</div>`;
const badge = (g, fill = "#fbcc33") => center(`<div style="position:relative;width:640px;height:640px;filter:drop-shadow(0 0 60px rgba(251,204,51,.35))">${star(16, 0.8, 640, fill)}<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">${glyph(g)}</div></div>`);

await square("plus.png", badge("crown") + `<div style="position:absolute;left:0;right:0;bottom:70px;text-align:center">${tape("PLUS", -3, 84)}</div>`);
await square("plus-monthly.png", badge("crown", "#f5f2eb") + `<div style="position:absolute;left:0;right:0;bottom:70px;text-align:center">${tape("PLUS", 3, 84)}</div>`);
await square("block.png", badge("stack"));
await square("shield.png", badge("shield"));
// Fireworks: gold and red bursts.
let dots = "";
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
for (const [cx, cy, col] of [[330, 360, "#fbcc33"], [700, 300, "#e6382f"], [520, 640, "#fbcc33"], [800, 700, "#f5f2eb"], [230, 720, "#e6382f"]]) {
  for (let i = 0; i < 48; i++) {
    const a = (i / 48) * Math.PI * 2, d = 60 + rnd() * 150, s = 8 + rnd() * 10;
    dots += `<div style="position:absolute;left:${cx + Math.cos(a) * d}px;top:${cy + Math.sin(a) * d}px;width:${s}px;height:${s}px;border-radius:50%;background:${col};opacity:${0.5 + rnd() * 0.5};box-shadow:0 0 14px ${col}"></div>`;
  }
}
await square("fireworks.png", dots);

// In-App Event cards: 1920x1080 (no text; the App Store prints the event name over it) and 1080x1920 details.
async function shot(file, w, h, inner) {
  const p = await b.newPage({ viewport: { width: w, height: h } });
  await p.setContent(`<!doctype html><html><head>${FONT}</head><body style="margin:0;width:${w}px;height:${h}px;overflow:hidden;${BOARD};position:relative">${inner}</body></html>`);
  await p.waitForTimeout(600);
  await p.screenshot({ path: `${out}/${file}`, clip: { x: 0, y: 0, width: w, height: h } });
  await p.close();
  console.log("wrote", file);
}
const pick = (k) => {
  if (!raw) return null;
  const f = readdirSync(raw).find((x) => x.endsWith(`-${k}.png`));
  return f ? readFileSync(`${raw}/${f}`).toString("base64") : null;
};
const phone = (b64, x, y, wd, rot) => b64 ? `<div style="position:absolute;left:${x}px;top:${y}px;width:${wd}px;transform:rotate(${rot}deg);border-radius:${wd / 7}px;padding:${wd / 34}px;background:#1a1a1d;box-shadow:0 0 0 3px rgba(245,242,235,.12),0 50px 120px rgba(0,0,0,.75)"><img style="display:block;width:100%;border-radius:${wd / 8}px" src="data:image/png;base64,${b64}"></div>` : "";
const medals = [0, 1, 2].map((i) => `<div style="position:absolute;left:${180 + i * 230}px;top:${330 + (i % 2) * 90}px;transform:rotate(${(i - 1) * 9}deg);filter:drop-shadow(0 0 40px rgba(251,204,51,.35))">${star(16, 0.8, 300, "#fbcc33")}<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;transform:scale(.45)">${glyph("medal")}</div></div>`).join("");
await shot("event-challenge-card.png", 1920, 1080, medals + phone(pick("challenge"), 1080, 90, 420, 6) + phone(pick("train"), 1450, 160, 380, 10));
await shot("event-plus-card.png", 1920, 1080,
  `<div style="position:absolute;left:170px;top:250px;filter:drop-shadow(0 0 60px rgba(251,204,51,.35))">${star(16, 0.8, 560, "#fbcc33")}<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">${glyph("crown")}</div></div>`
  + phone(pick("balance"), 900, 90, 420, -5) + phone(pick("widgets"), 1330, 140, 400, 7));
for (const [file, keys] of [["event-challenge-details.png", ["challenge"]], ["event-plus-details.png", ["balance"]]]) {
  const img = pick(keys[0]);
  await shot(file, 1080, 1920, img ? `<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center"><div style="width:760px;border-radius:110px;padding:22px;background:#1a1a1d;box-shadow:0 0 0 3px rgba(245,242,235,.12),0 60px 140px rgba(0,0,0,.75)"><img style="display:block;width:100%;border-radius:90px" src="data:image/png;base64,${img}"></div></div>` : medals);
}
await b.close();
