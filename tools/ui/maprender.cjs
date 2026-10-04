// Draws the map snapshots saved by tools/sim/mapshot.luau as PNGs (an aerial view, the cornucopia,
// and a couple of ground-level views of landmarks), using three.js in headless Chromium.
//
//   lune run tools/sim/mapshot build/maps
//   node tools/ui/maprender.cjs build/maps/*.json
//
// Needs Node, Playwright and three (`npm install three playwright`, or set THREE_DIR / install globally).
// The pictures have no Roblox textures or shadows-from-terrain, so they look flatter than the game does.

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function requireFrom(name) {
	const roots = [process.cwd(), __dirname, process.env.THREE_DIR || ""];
	try {
		roots.push(execSync("npm root -g").toString().trim());
	} catch (e) {}
	for (const root of roots) {
		if (!root) continue;
		for (const candidate of [path.join(root, "node_modules", name), path.join(root, name)]) {
			if (fs.existsSync(candidate)) return candidate;
		}
	}
	return null;
}

const playwrightDir = requireFrom("playwright");
const threeDir = requireFrom("three");
if (!playwrightDir || !threeDir) {
	console.error("needs playwright and three: npm install three playwright (or set THREE_DIR)");
	process.exit(1);
}
const { chromium } = require(playwrightDir);
const threeSource = fs.readFileSync(path.join(threeDir, "build", "three.cjs"), "utf8");

const WIDTH = 1280;
const HEIGHT = 720;

// Roblox's default terrain colours, for materials a map doesn't recolour.
const TERRAIN_DEFAULTS = {
	Grass: [106, 127, 63],
	LeafyGrass: [115, 132, 74],
	Ground: [102, 92, 59],
	Sand: [143, 126, 95],
	Rock: [102, 108, 111],
	Snow: [195, 199, 218],
	Glacier: [101, 176, 234],
	Slate: [63, 127, 107],
	Basalt: [30, 30, 37],
	CrackedLava: [232, 156, 74],
	Sandstone: [137, 90, 71],
	Mud: [58, 46, 36],
	Water: [12, 84, 92],
	Asphalt: [115, 123, 107],
	Brick: [138, 86, 62],
	Cobblestone: [132, 123, 90],
	Concrete: [127, 102, 63],
	Ice: [129, 194, 224],
	Limestone: [206, 173, 148],
	Pavement: [148, 148, 140],
	Salt: [198, 189, 181],
	WoodPlanks: [139, 109, 79],
};

function page(data) {
	return `<!doctype html><html><body style="margin:0;background:#000">
<canvas id="c" width="${WIDTH}" height="${HEIGHT}"></canvas>
<script>var module = { exports: {} }; var exports = module.exports;</script>
<script>${threeSource}</script>
<script>
window.THREE = module.exports;
const DATA = ${JSON.stringify(data)};
const DEFAULTS = ${JSON.stringify(TERRAIN_DEFAULTS)};
${renderScript.toString()}
window.views = renderScript(DATA, DEFAULTS, ${WIDTH}, ${HEIGHT});
</script></body></html>`;
}

// Runs in the browser.
function renderScript(data, defaults, width, height) {
	const THREE = window.THREE;
	const renderer = new THREE.WebGLRenderer({ canvas: document.getElementById("c"), antialias: true, preserveDrawingBuffer: true });
	renderer.setSize(width, height, false);
	renderer.outputColorSpace = THREE.SRGBColorSpace;
	renderer.toneMapping = THREE.ACESFilmicToneMapping;
	renderer.toneMappingExposure = 1.05;
	const scene = new THREE.Scene();
	const L = data.lighting || {};
	const atm = L.atmosphere || {};
	const c3 = (rgb, fallback) => (rgb ? new THREE.Color(rgb[0], rgb[1], rgb[2]) : new THREE.Color(fallback));

	// sky + fog from the map's atmosphere
	const night = L.ClockTime !== undefined && (L.ClockTime < 5.5 || L.ClockTime > 19.5);
	const fogColor = c3(atm.Color, 0xc8cde6);
	const sky = fogColor.clone().lerp(new THREE.Color(night ? 0x0a0820 : 0x6fa8ff), night ? 0.55 : 0.35);
	scene.background = sky;
	const density = atm.Density !== undefined ? atm.Density : 0.3;
	scene.fog = new THREE.Fog(fogColor.clone().lerp(sky, 0.3), 120, 260 + (1 - density) * 1500);

	// sun (or moon)
	const t = L.ClockTime !== undefined ? L.ClockTime : 14;
	const elev = night ? 0.6 : Math.max(0.12, Math.sin(((t - 6) / 12) * Math.PI));
	const azim = ((t - 12) / 12) * Math.PI;
	const sunDir = new THREE.Vector3(Math.sin(azim) * Math.cos(Math.asin(elev)), elev, -0.45).normalize();
	const brightness = L.Brightness !== undefined ? L.Brightness : 2;
	const sun = new THREE.DirectionalLight(night ? 0x8fa0ff : 0xfff2dd, (night ? 0.35 : 0.9) * brightness);
	sun.position.copy(sunDir.clone().multiplyScalar(1000));
	scene.add(sun);
	const ambient = c3(L.OutdoorAmbient, 0x808080);
	scene.add(new THREE.HemisphereLight(sky.clone().lerp(ambient, 0.5), ambient.clone().multiplyScalar(0.6), night ? 1.1 : 1.0));
	scene.add(new THREE.AmbientLight(ambient, 0.35));

	// terrain heightfield
	let heightAt = () => 0;
	if (data.terrain) {
		const T = data.terrain;
		const colorOf = (name) => {
			const rgb = (T.colors && T.colors[name]) || null;
			if (rgb) return new THREE.Color(rgb[0], rgb[1], rgb[2]);
			const d = defaults[name] || [128, 128, 128];
			return new THREE.Color(d[0] / 255, d[1] / 255, d[2] / 255);
		};
		const palette = T.names.map(colorOf);
		const nx = T.nx, nz = T.nz;
		const pos = new Float32Array(nx * nz * 3);
		const col = new Float32Array(nx * nz * 3);
		let seed = 1;
		const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
		for (let i = 0; i < nx; i++) {
			for (let j = 0; j < nz; j++) {
				const k = i * nz + j;
				const water = T.floors[k] > -999;
				const y = water ? T.floors[k] : T.heights[k];
				const m = water ? T.floorMats[k] : T.mats[k];
				pos[k * 3] = T.x0 + (i + 0.5) * T.res;
				pos[k * 3 + 1] = y;
				pos[k * 3 + 2] = T.z0 + (j + 0.5) * T.res;
				const c = m >= 0 ? palette[m].clone() : new THREE.Color(0.3, 0.3, 0.3);
				const n = 0.9 + rand() * 0.2;
				col[k * 3] = c.r * n;
				col[k * 3 + 1] = c.g * n;
				col[k * 3 + 2] = c.b * n;
			}
		}
		const idx = [];
		for (let i = 0; i < nx - 1; i++) {
			for (let j = 0; j < nz - 1; j++) {
				const a = i * nz + j, b = (i + 1) * nz + j, c = i * nz + j + 1, d = (i + 1) * nz + j + 1;
				idx.push(a, c, b, b, c, d);
			}
		}
		const geo = new THREE.BufferGeometry();
		geo.setAttribute("position", new THREE.BufferAttribute(pos, 3));
		geo.setAttribute("color", new THREE.BufferAttribute(col, 3));
		geo.setIndex(idx);
		geo.computeVertexNormals();
		scene.add(new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 })));
		heightAt = (x, z) => {
			const i = Math.min(nx - 1, Math.max(0, Math.floor((x - T.x0) / T.res)));
			const j = Math.min(nz - 1, Math.max(0, Math.floor((z - T.z0) / T.res)));
			return T.heights[i * nz + j];
		};
		// water
		if (T.names.includes("Water")) {
			const w = data.water || { color: [0.2, 0.5, 0.7], transparency: 0.5 };
			const water = new THREE.Mesh(
				new THREE.PlaneGeometry(nx * T.res, nz * T.res),
				new THREE.MeshStandardMaterial({
					color: c3(w.color),
					transparent: true,
					opacity: Math.min(0.9, 1 - w.transparency * 0.6),
					roughness: 0.15,
					metalness: 0.1,
				}),
			);
			water.rotation.x = -Math.PI / 2;
			water.position.set(T.x0 + (nx * T.res) / 2, data.liquidLevel, T.z0 + (nz * T.res) / 2);
			scene.add(water);
		}
	}

	// parts
	const geoCache = {};
	const wedgeGeo = (() => {
		const g = new THREE.BufferGeometry();
		const v = [
			-0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, 0.5, -0.5, -0.5, 0.5, // bottom
			-0.5, 0.5, 0.5, 0.5, 0.5, 0.5, // top back edge
		];
		const f = [0, 2, 1, 0, 3, 2, 3, 4, 5, 3, 5, 2, 0, 1, 5, 0, 5, 4, 0, 4, 3, 1, 2, 5];
		g.setAttribute("position", new THREE.Float32BufferAttribute(v, 3));
		g.setIndex(f);
		return g.toNonIndexed();
	})();
	wedgeGeo.computeVertexNormals();
	const shapeGeo = (shape, cls) => {
		const key = cls === "WedgePart" ? "Wedge" : shape;
		if (geoCache[key]) return geoCache[key];
		let g;
		if (key === "Wedge") g = wedgeGeo;
		else if (key === "Cylinder") {
			g = new THREE.CylinderGeometry(0.5, 0.5, 1, 20);
			g.rotateZ(-Math.PI / 2);
		} else if (key === "Ball") g = new THREE.SphereGeometry(0.5, 18, 12);
		else g = new THREE.BoxGeometry(1, 1, 1);
		geoCache[key] = g;
		return g;
	};
	const lights = [];
	const matCache = {};
	for (const p of data.parts) {
		const color = new THREE.Color(p.k[0], p.k[1], p.k[2]);
		const neon = p.m === "Neon";
		const glassy = p.m === "Glass" || p.m === "Ice" || p.m === "ForceField";
		const metal = p.m === "Metal" || p.m === "DiamondPlate" || p.m === "Foil" || p.m === "CorrodedMetal";
		const opacity = 1 - p.t;
		const key = p.k.map((v) => v.toFixed(3)).join(",") + p.m + opacity.toFixed(2);
		let mat = matCache[key];
		if (!mat) {
			if (neon) {
				mat = new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(1.4), transparent: opacity < 1, opacity, fog: true });
			} else {
				mat = new THREE.MeshStandardMaterial({
					color,
					roughness: glassy ? 0.1 : metal ? 0.35 : p.m === "SmoothPlastic" ? 0.5 : 0.85,
					metalness: metal ? 0.65 : 0,
					transparent: opacity < 1 || glassy,
					opacity: glassy ? Math.min(opacity, 0.75) : opacity,
				});
			}
			matCache[key] = mat;
		}
		const mesh = new THREE.Mesh(shapeGeo(p.s, p.c), mat);
		let sx = p.z[0], sy = p.z[1], sz = p.z[2];
		if (p.s === "Cylinder") {
			const d = Math.min(sy, sz);
			sy = d;
			sz = d;
		} else if (p.s === "Ball") {
			const d = Math.min(sx, sy, sz);
			sx = sy = sz = d;
		}
		const f = p.f;
		const m4 = new THREE.Matrix4().set(f[3], f[4], f[5], f[0], f[6], f[7], f[8], f[1], f[9], f[10], f[11], f[2], 0, 0, 0, 1);
		m4.multiply(new THREE.Matrix4().makeScale(sx, sy, sz));
		mesh.matrixAutoUpdate = false;
		mesh.matrix.copy(m4);
		scene.add(mesh);
		if (p.l) lights.push({ pos: new THREE.Vector3(f[0], f[1], f[2]), color: p.l[0], range: p.l[1], brightness: p.l[2] });
		if (p.fire) {
			const flame = new THREE.Mesh(new THREE.ConeGeometry(1.2, 3.5, 8), new THREE.MeshBasicMaterial({ color: 0xff8a2a }));
			flame.position.set(f[0], f[1] + 2, f[2]);
			scene.add(flame);
			lights.push({ pos: new THREE.Vector3(f[0], f[1] + 2, f[2]), color: [1, 0.6, 0.3], range: 20, brightness: 2 });
		}
	}

	// a pool of point lights, moved to the lights nearest each view's target
	const POOL = 16;
	const pool = [];
	for (let i = 0; i < POOL; i++) {
		const pl = new THREE.PointLight(0xffffff, 0, 30, 1.2);
		scene.add(pl);
		pool.push(pl);
	}
	const camera = new THREE.PerspectiveCamera(60, width / height, 0.5, 5000);
	const shots = {};
	function shoot(name, from, at, fov) {
		camera.fov = fov || 60;
		camera.updateProjectionMatrix();
		camera.position.copy(from);
		camera.lookAt(at);
		const near = lights
			.map((l) => ({ l, d: l.pos.distanceTo(at) }))
			.sort((a, b) => a.d - b.d)
			.slice(0, POOL);
		pool.forEach((pl, i) => {
			const entry = near[i];
			if (entry) {
				pl.position.copy(entry.l.pos);
				pl.color.setRGB(entry.l.color[0], entry.l.color[1], entry.l.color[2]);
				pl.distance = entry.l.range * 1.6;
				pl.intensity = entry.l.brightness * 60;
			} else pl.intensity = 0;
		});
		renderer.render(scene, camera);
		shots[name] = renderer.domElement.toDataURL("image/png");
	}

	if (data.kind === "arena") {
		const R = data.radius;
		const py = data.plazaY;
		shoot("1_overview", new THREE.Vector3(0, R * 1.05, R * 1.15), new THREE.Vector3(0, 0, R * 0.05), 55);
		shoot("2_cornucopia", new THREE.Vector3(10, py + 34, 78), new THREE.Vector3(0, py + 4, 0), 60);
		const marks = (Array.isArray(data.landmarks) ? data.landmarks : []).slice(0, 6);
		marks.forEach((m, i) => {
			const p = new THREE.Vector3(m.p[0], m.p[1], m.p[2]);
			const out = new THREE.Vector3(p.x, 0, p.z).normalize();
			if (out.length() < 0.5) out.set(1, 0, 0);
			const side = new THREE.Vector3(-out.z, 0, out.x);
			const eye = p.clone().add(out.clone().multiplyScalar(-44)).add(side.multiplyScalar(18));
			eye.y = Math.max(heightAt(eye.x, eye.z), data.liquidLevel) + 14;
			shoot(`${3 + i}_${m.name}`, eye, new THREE.Vector3(p.x, heightAt(p.x, p.z) + 5, p.z), 65);
		});
		// a wide ground-level vista from the plaza edge outwards
		const vEye = new THREE.Vector3(0, py + 12, 60);
		shoot("9_vista", vEye, new THREE.Vector3(0, py + 10, 400), 70);
	} else if (data.kind === "showcase") {
		// mannequins in a row, five studs apart: two close-ups of each half, front and back
		const n = data.count;
		const half = Math.ceil(n / 2);
		for (let k = 0; k < 2; k++) {
			const first = k * half, last = Math.min(n, (k + 1) * half) - 1;
			const cx = ((first + last) / 2 - (n - 1) / 2) * 5;
			shoot(`${1 + k}_front`, new THREE.Vector3(cx, 4.2, -17), new THREE.Vector3(cx, 3, 0), 50);
			shoot(`${3 + k}_back`, new THREE.Vector3(cx + 4, 5, 15), new THREE.Vector3(cx, 3, 0), 50);
		}
	} else {
		const box = new THREE.Box3();
		for (const p of data.parts) box.expandByPoint(new THREE.Vector3(p.f[0], p.f[1], p.f[2]));
		const center = box.getCenter(new THREE.Vector3());
		const size = box.getSize(new THREE.Vector3());
		shoot("1_overview", center.clone().add(new THREE.Vector3(0, size.length() * 0.45, size.length() * 0.5)), center, 55);
		const marks = Array.isArray(data.landmarks) ? data.landmarks : [];
		marks.forEach((m, i) => {
			const p = new THREE.Vector3(m.p[0], m.p[1], m.p[2]);
			shoot(`${2 + i}_${m.name}`, p.clone().add(new THREE.Vector3(30, 18, 30)), p, 60);
		});
	}
	return shots;
}

(async () => {
	const files = process.argv.slice(2);
	if (files.length === 0) {
		console.error("usage: node tools/ui/maprender.cjs build/maps/*.json");
		process.exit(1);
	}
	const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
	for (const file of files) {
		const data = JSON.parse(fs.readFileSync(file, "utf8"));
		const tab = await browser.newPage({ viewport: { width: WIDTH, height: HEIGHT } });
		tab.on("pageerror", (e) => console.error(file, e.message));
		tab.on("console", (m) => console.log(file, m.text()));
		await tab.setContent(page(data), { timeout: 300000 });
		const shots = await tab.waitForFunction(() => window.views, null, { timeout: 60000 }).then((h) => h.jsonValue());
		const base = file.replace(/\.json$/, "");
		for (const [name, url] of Object.entries(shots)) {
			const out = `${base}_${name}.png`;
			fs.writeFileSync(out, Buffer.from(url.split(",")[1], "base64"));
			console.log("wrote " + out);
		}
		await tab.close();
	}
	await browser.close();
})();
