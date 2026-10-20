// App Store screenshots: a chalk headline on a strip of tape over each raw simulator shot.
//   node Store/art/frame.mjs <dir of CI shots> [locale: en-US | ja | ko | zh-Hans]
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const loc = process.argv[3] || "en-US";
const out = process.argv[4] && process.argv[4] !== "main" ? `C:/Users/Matthew/ironbook/Store/art/cpp/${process.argv[4]}` : `C:/Users/Matthew/ironbook/fastlane/screenshots/${loc}`;
// No prices, "free", discounts or subscription words in any caption (App Review 2.3.7).
// An optional 5th item picks a set: `node frame.mjs <shots> <locale> [set]` with set = main | lifter | starter (custom product pages).
const plan = [
  ["session", "LIVE", "Know what<br>to beat.", "Last time's numbers <b>beside every set.</b>"],
  ["widgets", "LOCK SCREEN", "Your rest timer<br>on the Lock Screen.", "And your week <b>as a ring.</b>"],
  ["train", "THIS WEEK", "Hit the week.<br>Keep the streak.", "A weekly goal and <b>a monthly challenge.</b>"],
  ["challenge", "MONTHLY", "A new challenge<br>every month.", "Finish it, <b>win the medal.</b>"],
  ["poster", "NEW PR", "Every PR,<br>in gold.", "Called out, <b>made to share.</b>"],
  ["balance", "INSIGHTS", "See every<br>muscle's week.", "Sets per muscle and <b>the lifts climbing fastest.</b>"],
  ["progress", "PROGRESS", "Watch the line<br>go up.", "Est. one-rep max, <b>PRs in gold.</b>"],
  ["block", "NEXT BLOCK", "Four weeks,<br>planned for you.", "Targets from <b>your own numbers.</b>"],
  ["calc", "1RM", "Your max<br>from any set.", "Every percentage, <b>every plate.</b>"],
  ["records", "WALL OF FAME", "Every lift,<br>ranked.", "Best set, heaviest set, <b>est. 1RM.</b>"],
];
// Captions for the Japanese, Korean and Simplified Chinese store pages; the app screens themselves stay English.
const L10N = {
  "ja": [
    ["session", "ライブ", "超えるべき<br>数字がわかる。", "すべてのセットの横に<b>前回の記録。</b>"],
    ["widgets", "ロック画面", "休憩タイマーを<br>ロック画面に。", "1週間の記録も<b>リングで。</b>"],
    ["train", "今週", "週の目標と<br>ストリーク。", "毎週の目標と<b>月間チャレンジ。</b>"],
    ["challenge", "月間", "毎月、新しい<br>チャレンジ。", "達成すれば<b>メダル獲得。</b>"],
    ["poster", "自己ベスト", "自己ベストは<br>ゴールドで。", "お祝いして、<b>シェアしよう。</b>"],
    ["balance", "分析", "部位ごとの<br>1週間を見る。", "部位別セット数と<b>伸びている種目。</b>"],
    ["progress", "推移", "伸びていく<br>グラフを見よう。", "推定1RMと、<b>ゴールドの自己ベスト。</b>"],
    ["block", "NEXT BLOCK", "次の4週間を<br>計画しよう。", "目標は<b>自分の数字から。</b>"],
    ["calc", "1RM", "どのセットからも<br>MAXを計算。", "すべての%と<b>プレート計算。</b>"],
    ["records", "殿堂入り", "全種目を<br>ランキング。", "ベストセット、最重量、<b>推定1RM。</b>"],
  ],
  "ko": [
    ["session", "실시간", "넘어야 할<br>숫자를 한눈에.", "모든 세트 옆에 <b>지난 기록.</b>"],
    ["widgets", "잠금 화면", "잠금 화면에<br>휴식 타이머.", "한 주 기록도 <b>링으로.</b>"],
    ["train", "이번 주", "주간 목표와<br>연속 기록.", "매주 목표와 <b>월간 챌린지.</b>"],
    ["challenge", "월간", "매달 새로운<br>챌린지.", "완료하면 <b>메달 획득.</b>"],
    ["poster", "새 PR", "모든 PR을<br>골드로.", "축하하고, <b>공유하고.</b>"],
    ["balance", "분석", "부위별<br>한 주 보기.", "부위별 세트 수와 <b>가장 빨리 느는 종목.</b>"],
    ["progress", "진행", "올라가는<br>그래프.", "예상 1RM, <b>골드로 빛나는 PR.</b>"],
    ["block", "NEXT BLOCK", "다음 4주를<br>계획대로.", "목표는 <b>내 기록에서.</b>"],
    ["calc", "1RM", "어떤 세트로도<br>1RM 계산.", "모든 퍼센트와 <b>원판 계산.</b>"],
    ["records", "명예의 전당", "모든 종목,<br>순위대로.", "최고 세트, 최고 중량, <b>예상 1RM.</b>"],
  ],
  "zh-Hans": [
    ["session", "实时", "知道这次<br>要超越什么。", "每一组旁边都有<b>上次的数字。</b>"],
    ["widgets", "锁屏", "休息计时<br>就在锁屏上。", "一周训练<b>化作圆环。</b>"],
    ["train", "本周", "每周目标,<br>连续不断。", "每周目标与<b>每月挑战。</b>"],
    ["challenge", "每月", "每个月,<br>新的挑战。", "完成即可<b>赢得奖牌。</b>"],
    ["poster", "新 PR", "每个 PR,<br>都是金色。", "点出来,<b>再分享。</b>"],
    ["balance", "分析", "每块肌肉的<br>一周训练量。", "各部位组数与<b>进步最快的动作。</b>"],
    ["progress", "进步", "看着曲线<br>往上走。", "预估 1RM,<b>金色的 PR。</b>"],
    ["block", "NEXT BLOCK", "接下来四周,<br>都安排好了。", "目标来自<b>你自己的数据。</b>"],
    ["calc", "1RM", "任意一组<br>算出极限。", "每个百分比,<b>每片杠铃片。</b>"],
    ["records", "名人堂", "每个动作,<br>都有排名。", "最佳组、最大重量、<b>预估 1RM。</b>"],
  ],
};
// Custom product page sets (en-US captions, different order and lead): who each page is for.
const SETS = {
  main: null,
  lifter: ["calc", "progress", "block", "records", "balance", "session", "poster", "widgets"],
  starter: ["train", "session", "challenge", "widgets", "poster", "calc", "progress", "records"],
};
const setName = process.argv[4] || "main";
const base = loc === "en-US" ? plan : L10N[loc];
const steps = SETS[setName] ? SETS[setName].map((k) => base.find((x) => x[0] === k)) : base;
const cjk = { ja: "Noto Sans JP", ko: "Noto Sans KR", "zh-Hans": "Noto Sans SC" }[loc];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, tape, head, sub] of steps) {
  const f = files.find((x) => x.endsWith(`-${key}.png`));
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  const tapeCol = key === "theme" ? "linear-gradient(135deg,#2f7be6,#173e8c)" : "linear-gradient(135deg,#e6382f,#8c1a1a)";
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,700;0,900;1,900&display=block" rel="stylesheet">${cjk ? `
<link href="https://fonts.googleapis.com/css2?family=${cjk.replace(/ /g, "+")}:wght@500;600;700;800;900&display=block" rel="stylesheet">` : ""}
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:#0b0b0c;font-family:Nunito,${cjk ? `"${cjk}",` : ""}sans-serif}
  .dust{position:absolute;inset:0;background:radial-gradient(900px 700px at 12% 4%,rgba(245,242,235,.10),transparent 60%),radial-gradient(1000px 900px at 105% 100%,rgba(230,56,47,.16),transparent 60%)}
  .col{position:absolute;left:96px;right:96px;top:150px;display:flex;flex-direction:column;align-items:flex-start}
  .tape{color:#fff;font-weight:900;font-size:40px;letter-spacing:8px;padding:12px 26px;background:${tapeCol};transform:rotate(-2deg);box-shadow:0 10px 24px rgba(0,0,0,.5)}
  h1{margin:40px 0 0;color:#f5f2eb;font-weight:900;font-style:italic;font-size:108px;line-height:1.0;letter-spacing:-2px}
  p{margin:26px 0 0;color:rgba(245,242,235,.6);font-weight:700;font-size:48px;line-height:1.2}
  p b{color:#fbcc33;font-weight:900}
  .phone{margin:64px auto 0;align-self:center;width:1060px;border-radius:120px;padding:22px;background:#1a1a1d;box-shadow:0 0 0 3px rgba(245,242,235,.12),0 60px 140px rgba(0,0,0,.75)}
  .phone img{display:block;width:100%;border-radius:100px}
${cjk ? "h1,p{text-wrap:balance}" : ""}</style></head><body><div class="dust"></div>
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
