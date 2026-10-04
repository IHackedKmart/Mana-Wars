// Renders UI snapshot JSON (from tools/sim/uishot.luau) to PNG with headless Chromium.
//   node tools/ui/render.cjs build/ui/*.json
// Uses Playwright from the project or, failing that, a global install (npm i -g playwright).
const { readFileSync } = require("node:fs");
let chromium;
try {
	({ chromium } = require("playwright"));
} catch {
	const root = require("node:child_process").execSync("npm root -g").toString().trim();
	({ chromium } = require(root + "/playwright"));
}

const FONTS = {
	GothamMedium: "font-family:'DejaVu Sans',sans-serif;font-weight:500",
	Gotham: "font-family:'DejaVu Sans',sans-serif;font-weight:400",
	GothamBold: "font-family:'DejaVu Sans',sans-serif;font-weight:700",
	GothamBlack: "font-family:'DejaVu Sans',sans-serif;font-weight:900",
	Fantasy: "font-family:'FreeSerif',serif;font-weight:700",
	Garamond: "font-family:'FreeSerif',serif",
	Cartoon: "font-family:'DejaVu Sans',sans-serif;font-weight:700",
};

const rgba = (c, a = 0) => (c ? `rgba(${c[0]},${c[1]},${c[2]},${(1 - a).toFixed(3)})` : "transparent");
const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function richToHtml(text) {
	// keep the tags Roblox rich text and HTML share
	let out = esc(text)
		.replace(/&lt;(\/?)(b|i|u|s)&gt;/g, "<$1$2>")
		.replace(/&lt;font color="([^"]+)"&gt;/g, '<span style="color:$1">')
		.replace(/&lt;font color='([^']+)'&gt;/g, '<span style="color:$1">')
		.replace(/&lt;font[^&]*&gt;/g, "<span>")
		.replace(/&lt;\/font&gt;/g, "</span>")
		.replace(/&lt;br\s*\/?&gt;/g, "<br>");
	return out;
}

function node(n) {
	const style = [
		"position:absolute",
		`left:${n.x}px`,
		`top:${n.y}px`,
		`width:${Math.max(0, n.w)}px`,
		`height:${Math.max(0, n.h)}px`,
		"box-sizing:border-box",
	];
	if (n.gradient && n.bg && n.bgT < 1) {
		const mul = (c, g) => [0, 1, 2].map((i) => Math.round((c[i] * g[i]) / 255));
		const a = (1 - n.bgT).toFixed(3);
		const f = mul(n.bg, n.gradient.from), t = mul(n.bg, n.gradient.to);
		style.push(`background:linear-gradient(${90 + (n.gradient.rot || 0)}deg, rgba(${f},${a}), rgba(${t},${a}))`);
	} else if (n.bg && n.bgT < 1) {
		style.push(`background:${rgba(n.bg, n.bgT)}`);
	}
	if (n.radius) style.push(`border-radius:${n.radius}px`);
	if (n.stroke && n.stroke.border === "border" && n.stroke.a < 1) {
		style.push(`box-shadow:0 0 0 ${n.stroke.t}px ${rgba(n.stroke.color, n.stroke.a)}`);
	}
	if (n.clip) style.push("overflow:hidden");
	let inner = "";
	if (n.viewport) {
		inner += `<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,.25);font:12px 'DejaVu Sans'">3D preview</div>`;
	}
	if (n.text !== undefined) {
		const text = n.text === "" && n.placeholder ? n.placeholder : n.text;
		const color = n.text === "" && n.placeholder ? "rgba(150,150,160,.8)" : rgba(n.color, n.tT);
		const ja = { Left: "flex-start", Right: "flex-end", Center: "center", "": "center" };
		const ta = { Left: "left", Right: "right", Center: "center", "": "center" };
		const va = { Top: "flex-start", Bottom: "flex-end", Center: "center", "": "center" };
		const shadow = n.strokeT < 1 ? `text-shadow:0 0 2px rgba(0,0,0,${1 - n.strokeT}),0 0 1px rgba(0,0,0,${1 - n.strokeT});` : "";
		const stroke =
			n.stroke && n.stroke.border === "text" && n.stroke.a < 1
				? `-webkit-text-stroke:${Math.min(n.stroke.t, 2)}px ${rgba(n.stroke.color, n.stroke.a)};paint-order:stroke fill;`
				: "";
		const body = n.rich ? richToHtml(text) : esc(text);
		inner += `<div class="${n.scaled ? "fit" : ""}" style="position:absolute;inset:0;display:flex;justify-content:${ja[n.xa] ?? "center"};align-items:${va[n.ya] ?? "center"};text-align:${ta[n.xa] ?? "center"};color:${color};font-size:${n.size}px;line-height:1.15;${FONTS[n.font] || FONTS.GothamMedium};white-space:${n.wrap ? "pre-wrap" : "pre"};overflow:visible;${shadow}${stroke}"><span>${body}</span></div>`;
	}
	for (const k of Array.isArray(n.kids) ? n.kids : []) inner += node(k);
	return `<div title="${esc(n.name || "")}" style="${style.join(";")}">${inner}</div>`;
}

async function main() {
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
for (const file of process.argv.slice(2)) {
	const data = JSON.parse(readFileSync(file, "utf8"));
	const html = `<!doctype html><html><head><meta charset="utf-8"><style>
		body{margin:0;width:1280px;height:720px;overflow:hidden;position:relative;
			background:linear-gradient(180deg,#6d8fb5 0%,#9fb7cf 45%,#5e7a4a 46%,#3d5530 100%)}
	</style></head><body>${(Array.isArray(data.guis) ? data.guis : []).map((g) => node(g)).join("")}
	<script>
		// TextScaled: shrink the text until it fits its box
		for (const el of document.querySelectorAll('.fit')) {
			let size = el.parentElement.clientHeight;
			el.style.fontSize = size + 'px';
			const span = el.firstElementChild;
			while (size > 6 && (span.offsetWidth > el.clientWidth || span.offsetHeight > el.clientHeight)) {
				size -= 1; el.style.fontSize = size + 'px';
			}
		}
	</script></body></html>`;
	await page.setContent(html, { waitUntil: "load" });
	const out = file.replace(/\.json$/, ".png");
	await page.screenshot({ path: out });
	console.log("wrote " + out);
}
await browser.close();
}
main().catch((err) => {
	console.error(err);
	process.exit(1);
});
