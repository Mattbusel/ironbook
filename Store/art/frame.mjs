// App Store screenshots: a chalk headline on a strip of tape over each raw simulator shot.
//   node Store/art/frame.mjs <dir of CI shots>
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const out = "C:/Users/Matthew/ironbook/fastlane/screenshots/en-US";
const plan = [
  ["session", "LIVE", "Know what<br>to beat.", "Last time's numbers <b>beside every set.</b>"],
  ["widgets", "LOCK SCREEN", "Rest timer on<br>your Lock Screen.", "And your week <b>on the Home Screen.</b>"],
  ["train", "THIS WEEK", "Hit your week.", "A weekly goal and streak, <b>warm-ups and plate maths.</b>"],
  ["poster", "NEW PR", "Every PR,<br>in gold.", "Called out, <b>then shared.</b>"],
  ["block", "NEXT BLOCK", "Your next four<br>weeks, planned.", "Targets from <b>your own numbers.</b>"],
  ["progress", "PRO", "See the line<br>go up.", "Est. one-rep max, <b>PRs in gold.</b>"],
  ["records", "WALL OF FAME", "Every lift,<br>ranked.", "Best set, heaviest set, <b>est. 1RM.</b>"],
  ["history", "THE BOOK", "The whole book.", "Every session, <b>one tap to repeat.</b>"],
  ["theme", "TAPE", "Pick your tape.", "Four colours, each with <b>its own icon.</b>"],
  ["paywall", "NO SUBSCRIPTION", "Free to log.<br>Pro is $4.99 once.", "Charts, records, programs, <b>yours for good.</b>"],
];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, tape, head, sub] of plan) {
  const f = files.find((x) => x.endsWith(`-${key}.png`));
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  const tapeCol = key === "theme" ? "linear-gradient(135deg,#2f7be6,#173e8c)" : "linear-gradient(135deg,#e6382f,#8c1a1a)";
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,700;0,900;1,900&display=block" rel="stylesheet">
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:#0b0b0c;font-family:Nunito,sans-serif}
  .dust{position:absolute;inset:0;background:radial-gradient(900px 700px at 12% 4%,rgba(245,242,235,.10),transparent 60%),radial-gradient(1000px 900px at 105% 100%,rgba(230,56,47,.16),transparent 60%)}
  .col{position:absolute;left:96px;right:96px;top:150px;display:flex;flex-direction:column;align-items:flex-start}
  .tape{color:#fff;font-weight:900;font-size:40px;letter-spacing:8px;padding:12px 26px;background:${tapeCol};transform:rotate(-2deg);box-shadow:0 10px 24px rgba(0,0,0,.5)}
  h1{margin:40px 0 0;color:#f5f2eb;font-weight:900;font-style:italic;font-size:108px;line-height:1.0;letter-spacing:-2px}
  p{margin:26px 0 0;color:rgba(245,242,235,.6);font-weight:700;font-size:48px;line-height:1.2}
  p b{color:#fbcc33;font-weight:900}
  .phone{margin:64px auto 0;align-self:center;width:1060px;border-radius:120px;padding:22px;background:#1a1a1d;box-shadow:0 0 0 3px rgba(245,242,235,.12),0 60px 140px rgba(0,0,0,.75)}
  .phone img{display:block;width:100%;border-radius:100px}
</style></head><body><div class="dust"></div>
<div class="col"><div class="tape">${tape}</div><h1>${head}</h1><p>${sub}</p>
<div class="phone"><img src="data:image/png;base64,${img}"></div></div>
</body></html>`);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const name = `${String(n).padStart(2, "0")}_iPhone.png`;
  await p.screenshot({ path: `${out}/${name}`, clip: { x: 0, y: 0, width: 1320, height: 2868 } });
  console.log("wrote", name, key);
  n++;
}
await b.close();
