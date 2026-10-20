// App Store screenshots: a chalk headline on a strip of tape over each raw simulator shot.
//   node Store/art/frame.mjs <dir of CI shots> [locale: en-US | ja | ko | zh-Hans]
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const loc = process.argv[3] || "en-US";
const out = `C:/Users/Matthew/ironbook/fastlane/screenshots/${loc}`;
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
// Captions for the Japanese, Korean and Simplified Chinese store pages; the app screens themselves stay English.
const L10N = {
  "ja": [
    ["session", "ライブ", "超えるべき<br>数字がわかる。", "すべてのセットの横に<b>前回の記録。</b>"],
    ["widgets", "ロック画面", "休憩タイマーを<br>ロック画面に。", "1週間の記録は<b>ホーム画面に。</b>"],
    ["train", "今週", "今週の目標を<br>達成しよう。", "週の目標とストリーク、<b>ウォームアップとプレート計算。</b>"],
    ["poster", "自己ベスト", "自己ベストは<br>ゴールドで。", "お祝いして、<b>シェアしよう。</b>"],
    ["block", "NEXT BLOCK", "次の4週間を<br>計画しよう。", "目標は<b>自分の数字から。</b>"],
    ["progress", "PRO", "伸びていく<br>グラフを見よう。", "推定1RMと、<b>ゴールドの自己ベスト。</b>"],
    ["records", "殿堂入り", "全種目を<br>ランキング。", "ベストセット、最重量、<b>推定1RM。</b>"],
    ["history", "記録帳", "すべてを<br>1冊に。", "どのセッションも<b>ワンタップでもう一度。</b>"],
    ["theme", "テープ", "テープを選ぼう。", "4色、それぞれに<b>専用アイコン。</b>"],
    ["paywall", "サブスクなし", "記録は無料。<br>Proは買い切り。", "グラフ、記録、プログラムが<b>ずっと使える。</b>"],
  ],
  "ko": [
    ["session", "실시간", "넘어야 할<br>숫자를 한눈에.", "모든 세트 옆에 <b>지난 기록.</b>"],
    ["widgets", "잠금 화면", "잠금 화면에<br>휴식 타이머.", "한 주 기록은 <b>홈 화면에.</b>"],
    ["train", "이번 주", "이번 주<br>목표 달성.", "주간 목표와 연속 기록, <b>워밍업과 원판 계산.</b>"],
    ["poster", "새 PR", "모든 PR을<br>골드로.", "축하하고, <b>공유하고.</b>"],
    ["block", "NEXT BLOCK", "다음 4주를<br>계획대로.", "목표는 <b>내 기록에서.</b>"],
    ["progress", "PRO", "올라가는<br>그래프.", "예상 1RM, <b>골드로 빛나는 PR.</b>"],
    ["records", "명예의 전당", "모든 종목,<br>순위대로.", "최고 세트, 최고 중량, <b>예상 1RM.</b>"],
    ["history", "운동 일지", "모든 기록을<br>한 권에.", "모든 세션을 <b>탭 한 번으로 다시.</b>"],
    ["theme", "테이프", "테이프 고르기.", "4가지 색, 각각 <b>전용 아이콘.</b>"],
    ["paywall", "구독 없음", "기록은 무료.<br>Pro는 한 번 결제.", "그래프, 기록, 프로그램을 <b>평생.</b>"],
  ],
  "zh-Hans": [
    ["session", "实时", "知道这次<br>要超越什么。", "每一组旁边都有<b>上次的数字。</b>"],
    ["widgets", "锁屏", "休息计时<br>就在锁屏上。", "一周训练<b>放在主屏幕。</b>"],
    ["train", "本周", "完成本周目标。", "每周目标与连续记录,<b>热身组和配片计算。</b>"],
    ["poster", "新 PR", "每个 PR,<br>都是金色。", "点出来,<b>再分享。</b>"],
    ["block", "NEXT BLOCK", "接下来四周,<br>都安排好了。", "目标来自<b>你自己的数据。</b>"],
    ["progress", "PRO", "看着曲线<br>往上走。", "预估 1RM,<b>金色的 PR。</b>"],
    ["records", "名人堂", "每个动作,<br>都有排名。", "最佳组、最大重量、<b>预估 1RM。</b>"],
    ["history", "训练簿", "完整的训练簿。", "每次训练,<b>一键再练。</b>"],
    ["theme", "胶带", "选择你的胶带。", "四种颜色,各有<b>专属图标。</b>"],
    ["paywall", "没有订阅", "记录免费。<br>Pro 一次买断。", "图表、纪录、训练计划,<b>永久拥有。</b>"],
  ],
};
const steps = loc === "en-US" ? plan : L10N[loc];
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
