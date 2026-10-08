// The four tape-colour icons: the Ironbook icon with the tape recoloured. Writes Resources/Assets.xcassets/AppIcon-<Name>.appiconset.
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync, writeFileSync } from "fs";
const themes = { Cobalt: ["#2f7be6", "#173e8c", "#fff"], Volt: ["#7bd62b", "#3d7a12", "#fff"], Rose: ["#e6408c", "#8c1a4d", "#fff"], Bone: ["#d9d2c3", "#8a8170", "#0b0b0c"] };
const root = "C:/Users/Matthew/ironbook/Resources/Assets.xcassets";
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, [A, D, T]] of Object.entries(themes)) {
  const html = `<div style="width:1024px;height:1024px;background:radial-gradient(circle at 20% 10%,#1a1a1c,#0b0b0c 70%);position:relative;overflow:hidden;font-family:'Segoe UI Variable Display','Segoe UI',sans-serif">
    <svg width="1024" height="1024" viewBox="0 0 1024 1024" style="position:absolute;inset:0">
      <defs><filter id="chalk"><feTurbulence baseFrequency="0.9" numOctaves="2" seed="3"/><feDisplacementMap in="SourceGraphic" scale="6"/></filter></defs>
      <g filter="url(#chalk)" stroke="#f4f2eb" stroke-width="26" stroke-linecap="round" fill="none">
        <line x1="120" y1="512" x2="904" y2="512"/>
        <rect x="200" y="380" width="70" height="264" rx="12" fill="#f4f2eb" stroke="none"/><rect x="290" y="420" width="50" height="184" rx="10" fill="#f4f2eb" stroke="none"/>
        <rect x="754" y="380" width="70" height="264" rx="12" fill="#f4f2eb" stroke="none"/><rect x="684" y="420" width="50" height="184" rx="10" fill="#f4f2eb" stroke="none"/>
      </g>
    </svg>
    <div style="position:absolute;left:-40px;top:120px;transform:rotate(-8deg);background:linear-gradient(135deg,${A},${D});color:${T};font-weight:900;font-size:64px;letter-spacing:6px;padding:14px 120px 14px 90px;box-shadow:0 20px 40px rgba(0,0,0,.6)">IRONBOOK</div>
  </div>`;
  await p.setContent(`<body style="margin:0">${html}</body>`);
  const dir = `${root}/AppIcon-${name}.appiconset`;
  mkdirSync(dir, { recursive: true });
  await p.screenshot({ path: `${dir}/icon-1024.png`, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  writeFileSync(`${dir}/Contents.json`, JSON.stringify({ images: [{ filename: "icon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" }], info: { author: "xcode", version: 1 } }, null, 2));
  console.log("wrote", name);
}
await b.close();
