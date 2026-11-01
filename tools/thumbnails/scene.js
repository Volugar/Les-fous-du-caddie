import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

const params = new URLSearchParams(location.search);
const SCENE = params.get('scene') || 'office';
const W = +params.get('w') || 1920;
const H = +params.get('h') || 1080;

// ---------------------------------------------------------------- helpers
let seed = 1234;
function rand() {
	seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
	let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
	t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
	return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const rr = (a, b) => a + (b - a) * rand();
const pick = (list) => list[Math.floor(rand() * list.length)];

const scene = new THREE.Scene();
const matCache = new Map();
function M(color, o = {}) {
	const key = JSON.stringify([color, o.r, o.m, o.e, o.ei, o.t]);
	if (!o.map && matCache.has(key)) return matCache.get(key);
	const m = new THREE.MeshStandardMaterial({
		color, roughness: o.r ?? 0.55, metalness: o.m ?? 0,
		emissive: o.e ?? 0x000000, emissiveIntensity: o.ei ?? 1,
		map: o.map || null, transparent: o.t !== undefined, opacity: o.t ?? 1,
	});
	if (!o.map) matCache.set(key, m);
	return m;
}
function add(mesh, parent, shadow = true) {
	mesh.castShadow = shadow; mesh.receiveShadow = true;
	(parent || scene).add(mesh); return mesh;
}
function box(w, h, d, mat, x, y, z, parent, shadow) {
	const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
	m.position.set(x, y, z); return add(m, parent, shadow);
}
function rbox(w, h, d, r, mat, x, y, z, parent) {
	const m = new THREE.Mesh(new RoundedBoxGeometry(w, h, d, 3, r), mat);
	m.position.set(x, y, z); return add(m, parent);
}
function cyl(rt, rb, h, mat, x, y, z, parent, seg = 24) {
	const m = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat);
	m.position.set(x, y, z); return add(m, parent);
}
function ball(r, mat, x, y, z, parent) {
	const m = new THREE.Mesh(new THREE.SphereGeometry(r, 24, 16), mat);
	m.position.set(x, y, z); return add(m, parent);
}
function group(parent) { const g = new THREE.Group(); (parent || scene).add(g); return g; }

// Texture de texte (panneaux, étiquettes).
function textTex(lines, o = {}) {
	const c = document.createElement('canvas');
	c.width = o.w || 512; c.height = o.h || 128;
	const g = c.getContext('2d');
	g.fillStyle = o.bg || '#2a8aa8'; g.fillRect(0, 0, c.width, c.height);
	if (o.border) { g.strokeStyle = o.border; g.lineWidth = o.borderW || 12; g.strokeRect(6, 6, c.width - 12, c.height - 12); }
	if (o.draw) o.draw(g, c);
	const list = Array.isArray(lines) ? lines : [lines];
	const size = o.size || c.height * 0.55 / list.length;
	g.font = `${o.weight || ''} ${size}px ${o.font || 'Fredoka'}`;
	g.textAlign = 'center'; g.textBaseline = 'middle';
	list.forEach((line, i) => {
		const y = c.height / 2 + (i - (list.length - 1) / 2) * size * 1.15 + (o.dy || 0);
		if (o.stroke) { g.strokeStyle = o.stroke; g.lineWidth = size * 0.18; g.lineJoin = 'round'; g.strokeText(line, c.width / 2, y); }
		g.fillStyle = o.fg || '#fff'; g.fillText(line, c.width / 2, y);
	});
	const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
	return t;
}
function patternTex(drawFn, size = 256, repeat = [1, 1]) {
	const c = document.createElement('canvas'); c.width = c.height = size;
	drawFn(c.getContext('2d'), size);
	const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
	t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(...repeat); t.anisotropy = 8;
	return t;
}

const BRIGHT = [0xe8463c, 0x2e78e2, 0xfac428, 0x3cb460, 0xf08228, 0xa05ad2, 0x28bec8, 0xf06eaa];
const WOOD = 0xdc9c60, CREAM = 0xf6eedd, TEAL = 0x2a8aa8;

// ---------------------------------------------------------------- personnage (style blocs, original)
function faceTex(skin, mood = 'happy') {
	const c = document.createElement('canvas'); c.width = c.height = 256;
	const g = c.getContext('2d');
	g.fillStyle = skin; g.fillRect(0, 0, 256, 256);
	g.fillStyle = '#1d1d22';
	for (const x of [88, 168]) {
		g.beginPath(); g.ellipse(x, 108, 15, 24, 0, 0, Math.PI * 2); g.fill();
		g.fillStyle = '#fff'; g.beginPath(); g.arc(x + 5, 98, 6, 0, Math.PI * 2); g.fill(); g.fillStyle = '#1d1d22';
	}
	g.lineWidth = 11; g.lineCap = 'round'; g.strokeStyle = '#1d1d22';
	g.beginPath();
	if (mood === 'wow') { g.fillStyle = '#7a2a2a'; g.ellipse(128, 178, 22, 26, 0, 0, Math.PI * 2); g.fill(); }
	else { g.arc(128, 150, 48, 0.15 * Math.PI, 0.85 * Math.PI); g.stroke(); }
	g.fillStyle = 'rgba(240,120,120,0.45)';
	for (const x of [62, 194]) { g.beginPath(); g.ellipse(x, 150, 18, 11, 0, 0, Math.PI * 2); g.fill(); }
	const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

function character(o = {}) {
	const root = group(o.parent);
	const skin = o.skin || '#f4c9a0';
	const skinM = M(new THREE.Color(skin));
	const shirtM = M(o.shirt ?? 0xf4f4f0);
	const vestM = M(o.vest ?? 0x2f6fd0, { r: 0.6 });
	const pantsM = M(o.pants ?? 0x2b2f3a);
	const shoeM = M(0x1c1c20, { r: 0.4 });
	const hairM = M(o.hair ?? 0x8a4a22, { r: 0.7 });

	const hip = group(root); hip.position.y = 2.1;
	const torso = group(hip); torso.position.y = 0;
	rbox(2.0, 2.0, 1.0, 0.12, shirtM, 0, 1.0, 0, torso);
	// gilet / tablier
	rbox(2.06, 1.7, 1.06, 0.1, vestM, 0, 0.92, 0.01, torso);
	box(0.5, 1.2, 0.02, shirtM, 0, 1.25, 0.55, torso);
	const tag = box(0.55, 0.3, 0.04, M(0xffffff, { map: textTex('TIDY', { w: 128, h: 64, bg: '#ffffff', fg: '#2f6fd0', size: 40 }) }), 0.52, 1.35, 0.55, torso);
	box(0.18, 0.18, 0.03, M(0xffd23c, { m: 0.6, r: 0.3 }), -0.55, 1.4, 0.55, torso);
	// tête
	const headG = group(torso); headG.position.y = 2.65;
	const faceM = M(0xffffff, { map: faceTex(skin, o.mood) });
	const head = new THREE.Mesh(new RoundedBoxGeometry(1.25, 1.25, 1.25, 4, 0.22), [skinM, skinM, skinM, skinM, faceM, skinM]);
	add(head, headG);
	// cheveux en mèches
	rbox(1.36, 0.42, 1.36, 0.12, hairM, 0, 0.55, -0.02, headG);
	for (let i = 0; i < 7; i++) {
		const s = rbox(0.42, 0.42, 0.62, 0.1, hairM, -0.5 + i * 0.17, 0.62 + (i % 2) * 0.12, 0.38 - (i % 3) * 0.2, headG);
		s.rotation.set(rr(-0.4, 0.2), rr(-0.4, 0.4), rr(-0.5, 0.5));
	}
	rbox(1.36, 0.8, 0.3, 0.1, hairM, 0, 0.1, -0.6, headG);
	if (o.cap) {
		rbox(1.4, 0.35, 1.4, 0.12, M(o.cap), 0, 0.78, 0, headG);
		box(1.1, 0.1, 0.7, M(o.cap), 0, 0.65, 0.85, headG);
	}
	headG.rotation.set(o.headTilt ?? 0.08, o.headTurn ?? 0, o.headRoll ?? 0);
	// bras
	const arms = [];
	for (const side of [-1, 1]) {
		const shoulder = group(torso); shoulder.position.set(side * 1.48, 1.75, 0);
		rbox(0.9, 1.9, 0.9, 0.12, shirtM, 0, -0.85, 0, shoulder);
		rbox(0.92, 0.75, 0.92, 0.12, vestM, 0, -0.25, 0, shoulder);
		rbox(0.88, 0.5, 0.88, 0.14, skinM, 0, -1.9, 0, shoulder);
		arms.push(shoulder);
	}
	// jambes
	const legs = [];
	for (const side of [-1, 1]) {
		const leg = group(hip); leg.position.set(side * 0.5, 0, 0);
		rbox(0.95, 2.0, 0.95, 0.1, pantsM, 0, -1.0, 0, leg);
		rbox(1.0, 0.45, 1.25, 0.15, shoeM, 0, -1.95, 0.15, leg);
		box(0.6, 0.06, 0.4, M(0xffffff), 0, -1.8, 0.74, leg);
		legs.push(leg);
	}

	const pose = o.pose || 'sweep';
	if (pose === 'sweep') {
		torso.rotation.set(0.2, 0.1, 0);
		arms[0].rotation.set(-0.95, 0, 0.55);
		arms[1].rotation.set(-0.75, 0, -0.25);
		legs[0].rotation.x = 0.35; legs[1].rotation.x = -0.25;
		// balai tenu en diagonale devant le corps, brosse au sol
		const broom = group(root);
		const stick = group(broom);
		cyl(0.11, 0.11, 7.2, M(0xc89660, { r: 0.6 }), 0, -3.6, 0, stick);
		box(2.4, 0.45, 0.6, M(0x2f6fd0), 0, -7.2, 0, stick);
		box(2.3, 0.7, 0.55, M(0xf2c442, { r: 0.9 }), 0, -7.7, 0, stick);
		for (let i = 0; i < 9; i++) box(0.12, 0.75, 0.5, M(0xe0ae2c, { r: 0.9 }), -1.05 + i * 0.26, -7.75, 0.05, stick);
		const top = new THREE.Vector3(0.7, 4.9, 1.2), bottom = new THREE.Vector3(-1.6, 0.25, 4.2);
		broom.position.copy(top);
		const dir = bottom.clone().sub(top).normalize();
		broom.quaternion.setFromUnitVectors(new THREE.Vector3(0, -1, 0), dir);
		stick.scale.y = top.distanceTo(bottom) / 7.95;
		stick.rotateY(0.6);
		// pelle et papiers balayés
		const pan = group(root); pan.position.set(-2.9, 0, 4.9); pan.rotation.y = 0.5;
		box(2.2, 0.08, 1.6, M(0xdc3a32, { r: 0.4 }), 0, 0.05, 0, pan); box(2.2, 0.7, 0.1, M(0xdc3a32), 0, 0.35, -0.8, pan);
		const ph = cyl(0.1, 0.1, 2.4, M(0xdc3a32), 0, 1.3, -1.0, pan); ph.rotation.x = -0.35;
		for (let i = 0; i < 4; i++) looseSheet(-1.5 + rr(-1, 1), 4 + rr(-0.8, 0.8), root);
	} else if (pose === 'carry') {
		torso.rotation.set(-0.05, 0, 0);
		arms[0].rotation.set(-0.75, 0, 0.18);
		arms[1].rotation.set(-0.75, 0, -0.18);
		legs[0].rotation.x = 0.4; legs[1].rotation.x = -0.4;
		const stack = group(root);
		let y = 0;
		const parts = [[2.6, 0.9, 1.6, 0xcf9e64], [2.2, 0.55, 1.5, 0xe8463c], [1.9, 0.6, 1.3, 0x2e78e2]];
		for (const [w, h, d, col] of parts) {
			const b = rbox(w, h, d, 0.06, M(col, { r: 0.8 }), rr(-0.1, 0.1), y + h / 2, 0, stack);
			b.rotation.y = rr(-0.12, 0.12);
			if (col === 0xcf9e64) box(w + 0.02, 0.04, 0.4, M(0xe4bc82), b.position.x, y + h + 0.01, 0, stack);
			y += h;
		}
		const bear = teddy(-0.85, y, 0.1, 0xb0784a, stack, 0.55); bear.rotation.y = 0.4;
		stack.position.set(0, 2.05, 1.75);
	} else if (pose === 'wave') {
		arms[1].rotation.set(0, 0, 2.6);
		arms[0].rotation.set(0.1, 0, -0.15);
		torso.rotation.y = rr(-0.2, 0.2);
	} else if (pose === 'jump') {
		arms[0].rotation.set(0, 0, -2.5); arms[1].rotation.set(0, 0, 2.5);
		legs[0].rotation.x = 0.5; legs[1].rotation.x = -0.3;
		root.position.y += 1.5;
	} else if (pose === 'duster') {
		torso.rotation.set(0.05, -0.2, 0);
		arms[1].rotation.set(-2.2, 0, 0.4);
		arms[0].rotation.set(-0.3, 0, -0.2);
		const d = group(arms[1]);
		cyl(0.08, 0.08, 1.8, M(0x8a5a30), 0, -2.6, 0.2, d);
		for (let i = 0; i < 10; i++) {
			const f = ball(0.32, M(pick([0xf06eaa, 0xfac428, 0x28bec8])), rr(-0.35, 0.35), -3.7 + rr(-0.3, 0.3), 0.2 + rr(-0.3, 0.3), d);
			f.scale.set(1, 1.6, 1);
		}
	}
	root.scale.setScalar(o.scale || 1);
	return root;
}

// ---------------------------------------------------------------- objets détaillés
function cardboardBox(x, y, z, w = 2.1, h = 1.6, d = 1.6, parent, label = true) {
	const g = group(parent); g.position.set(x, y, z);
	box(w, h, d, M(0xcf9e64, { r: 0.85 }), 0, h / 2, 0, g);
	box(w + 0.02, 0.03, 0.45, M(0xe8c48c, { r: 0.4 }), 0, h + 0.01, 0, g);
	box(0.45, 0.45, d + 0.02, M(0xe8c48c, { r: 0.4 }), 0, h - 0.22, 0, g);
	if (label) {
		box(0.8, 0.5, 0.02, M(0xffffff, { map: textTex(['||| ||| |'], { w: 128, h: 80, bg: '#fafafa', fg: '#111', size: 36 }) }), -0.4, h * 0.45, d / 2 + 0.01, g);
		if (rand() < 0.5) box(0.02, 0.4, 0.9, M(0xffffff, { map: textTex('FRAGILE', { w: 256, h: 96, bg: '#dc3a32', size: 52 }) }), w / 2 + 0.01, h * 0.6, 0, g).rotation.y = 0;
	}
	return g;
}
function parcel(x, z, color, parent) {
	const g = group(parent); g.position.set(x, 0, z); g.rotation.y = rr(0, 6.28);
	box(0.9, 0.65, 0.9, M(0xcf9e64, { r: 0.85 }), 0, 0.325, 0, g);
	box(0.92, 0.02, 0.22, M(0xe8c48c), 0, 0.66, 0, g);
	box(0.5, 0.025, 0.36, M(color), 0.15, 0.665, 0.18, g);
	box(0.55, 0.34, 0.02, M(color), 0, 0.33, 0.46, g);
	return g;
}
function paperStack(x, z, parent) {
	const g = group(parent); g.position.set(x, 0, z); g.rotation.y = rr(0, 6.28);
	for (let i = 0; i < 4; i++) {
		const s = box(1.05, 0.06, 1.45, M(pick([0xfcfaf2, 0xecf4fc, 0xfcf6de])), rr(-0.05, 0.05), 0.03 + i * 0.065, 0, g);
		s.rotation.y = rr(-0.15, 0.15);
	}
	box(0.3, 0.1, 0.12, M(0x1e1e22), 0, 0.3, -0.66, g);
	return g;
}
function looseSheet(x, z, parent) {
	const s = box(1.05, 0.02, 1.45, M(pick([0xfcfaf2, 0xecf4fc, 0xfcf6de])), x, 0.02 + rand() * 0.02, z, parent, false);
	s.rotation.set(rr(-0.08, 0.08), rr(0, 6.28), rr(-0.08, 0.08));
	return s;
}
function folder(x, z, parent) {
	const g = group(parent); g.position.set(x, 0, z); g.rotation.y = rr(0, 6.28);
	const col = pick([0xecc478, 0x4078d2, 0xd23c3c, 0x3ca060, 0x965ac8]);
	box(1.3, 0.04, 1.6, M(col), 0, 0.02, 0, g);
	box(1.22, 0.08, 1.5, M(0xfcfcf6), 0.06, 0.08, 0.02, g);
	const top = box(1.3, 0.04, 1.6, M(col), -0.05, 0.15, 0, g); top.rotation.y = 0.12;
	box(0.6, 0.01, 0.4, M(0xffffff), 0, 0.175, 0.2, g);
	return g;
}
function mug(x, z, parent, tipped) {
	const g = group(parent); g.position.set(x, 0, z);
	const col = pick([0xfafaf6, 0xe6504a, 0x3c78d2, 0xfac43c]);
	cyl(0.25, 0.23, 0.55, M(col, { r: 0.3 }), 0, 0.275, 0, g);
	const h = new THREE.Mesh(new THREE.TorusGeometry(0.15, 0.05, 8, 16), M(col)); h.position.set(0.3, 0.3, 0); add(h, g);
	if (tipped) { g.rotation.z = Math.PI / 2; g.position.y = 0.25; g.rotation.y = rr(0, 6); }
	return g;
}
function plant(x, z, parent, scale = 1) {
	const g = group(parent); g.position.set(x, 0, z); g.scale.setScalar(scale);
	cyl(0.45, 0.35, 0.8, M(pick([0xf0f0ec, 0xcc7850, 0xf0c450])), 0, 0.4, 0, g);
	cyl(0.48, 0.48, 0.12, M(0xe6e6e0), 0, 0.82, 0, g);
	for (let i = 0; i < 6; i++) ball(rr(0.3, 0.5), M(pick([0x3e9640, 0x60ba50, 0x2e783c]), { r: 0.8 }), rr(-0.3, 0.3), rr(1.1, 1.7), rr(-0.3, 0.3), g);
	return g;
}
function officeChair(x, z, parent, tipped, col) {
	const g = group(parent); g.position.set(x, 0, z);
	const c = M(col ?? pick([0x2e56a0, 0xc84638, 0x3c9670, 0x46464e]), { r: 0.7 });
	box(1.6, 0.15, 1.6, M(0x30323a, { m: 0.4 }), 0, 0.15, 0, g);
	cyl(0.12, 0.12, 1.4, M(0xb4b8c0, { m: 0.8, r: 0.3 }), 0, 0.9, 0, g);
	rbox(1.9, 0.4, 1.8, 0.12, c, 0, 1.8, 0, g);
	rbox(1.8, 1.9, 0.3, 0.12, c, 0, 3.0, 0.85, g);
	if (tipped) { g.rotation.set(0, rr(0, 6.28), 0); const inner = g; inner.rotation.z = Math.PI / 2 * 0.98; inner.position.y = 1.0; }
	return g;
}
function teddy(x, y, z, fur, parent, scale = 1) {
	const g = group(parent); g.position.set(x, y, z); g.scale.setScalar(scale);
	const f = M(fur, { r: 0.95 }), l = M(new THREE.Color(fur).lerp(new THREE.Color(0xffffff), 0.45), { r: 0.95 }), k = M(0x111111, { r: 0.3 });
	ball(0.5, f, 0, 0.5, 0, g); ball(0.3, l, 0, 0.5, 0.25, g);
	ball(0.4, f, 0, 1.2, 0, g);
	for (const s of [-1, 1]) {
		ball(0.16, f, s * 0.3, 1.55, 0, g); ball(0.09, l, s * 0.3, 1.55, 0.08, g);
		ball(0.06, k, s * 0.14, 1.28, 0.36, g);
		ball(0.2, f, s * 0.5, 0.65, 0.12, g); ball(0.24, f, s * 0.28, 0.15, 0.22, g);
	}
	ball(0.16, l, 0, 1.12, 0.34, g); ball(0.07, k, 0, 1.17, 0.48, g);
	box(0.4, 0.14, 0.1, M(0xdc2832), 0, 0.85, 0.38, g);
	return g;
}
function toyCar(x, z, parent) {
	const g = group(parent); g.position.set(x, 0, z); g.rotation.y = rr(0, 6.28);
	const p = M(pick(BRIGHT), { r: 0.25, m: 0.2 });
	rbox(1.3, 0.4, 0.7, 0.1, p, 0, 0.42, 0, g); rbox(0.7, 0.35, 0.65, 0.1, p, -0.05, 0.78, 0, g);
	box(0.72, 0.25, 0.67, M(0xbfe6fa, { r: 0.1 }), -0.05, 0.8, 0, g);
	for (const sx of [-1, 1]) for (const sz of [-1, 1]) { const w = cyl(0.2, 0.2, 0.14, M(0x111111), sx * 0.42, 0.2, sz * 0.36, g); w.rotation.x = Math.PI / 2; }
	return g;
}
function bottle(x, z, parent, tipped) {
	const g = group(parent); g.position.set(x, 0, z);
	const c = pick([0x3c8ce6, 0xfac432, 0x50c8dc, 0xe678c8, 0x78d25a]);
	rbox(0.75, 1.0, 0.48, 0.12, M(c, { r: 0.3 }), 0, 0.5, 0, g);
	rbox(0.5, 0.3, 0.42, 0.1, M(c, { r: 0.3 }), -0.08, 1.1, 0, g);
	cyl(0.12, 0.12, 0.18, M(0xffffff), -0.15, 1.33, 0, g);
	box(0.58, 0.5, 0.02, M(0xffffff, { map: textTex(['CLEAN', '★'], { w: 128, h: 128, bg: '#ffffff', fg: '#' + new THREE.Color(c).getHexString(), size: 34 }) }), 0, 0.5, 0.25, g);
	if (tipped) { g.rotation.set(0, rr(0, 6), Math.PI / 2); g.position.y = 0.38; }
	return g;
}
function can(x, z, parent, tipped) {
	const g = group(parent); g.position.set(x, 0, z);
	const col = pick(['#dc322e', '#3c8c46', '#fac428', '#f0dc96', '#fa963c']);
	const tex = textTex(['SOUP', ''], { w: 256, h: 128, bg: col, fg: '#fff', size: 48, draw: (gg) => { gg.fillStyle = '#fff'; gg.fillRect(0, 84, 256, 14); } });
	cyl(0.25, 0.25, 0.65, [M(0xffffff, { map: tex }), M(0xd2d6dc, { m: 0.8, r: 0.3 }), M(0xd2d6dc, { m: 0.8, r: 0.3 })], 0, 0.325, 0, g);
	if (tipped) { g.rotation.set(0, rr(0, 6), Math.PI / 2); g.position.y = 0.25; }
	return g;
}
function shoeBox(x, z, parent) {
	const g = group(parent); g.position.set(x, 0, z); g.rotation.y = rr(0, 6.28);
	const c = pick([0xf07828, 0x286ee0, 0x222226, 0xdc3232, 0x3caa64]);
	box(1.6, 0.6, 1.0, M(c), 0, 0.3, 0, g);
	box(1.66, 0.24, 1.06, M(c === 0x222226 ? 0xe64040 : 0xfafaf6), 0, 0.68, 0, g);
	const sw = box(0.7, 0.07, 0.02, M(0xffffff), 0.05, 0.3, 0.51, g); sw.rotation.z = 0.2;
	return g;
}
function beachBall(x, z, parent) {
	const g = group(parent); g.position.set(x, 0.55, z);
	const tex = patternTex((gg, s) => { const cols = ['#e83c38', '#fff', '#fad228', '#fff', '#2e78e2', '#fff', '#3cb460', '#fff']; cols.forEach((c, i) => { gg.fillStyle = c; gg.fillRect(i * s / 8, 0, s / 8 + 1, s); }); });
	add(new THREE.Mesh(new THREE.SphereGeometry(0.55, 32, 20), M(0xffffff, { map: tex, r: 0.3 })), g);
	g.rotation.set(rr(0, 1), rr(0, 6), 0.4);
	return g;
}
function tapeRoll(x, z, parent) {
	const g = group(parent); g.position.set(x, 0, z);
	const t = new THREE.Mesh(new THREE.TorusGeometry(0.33, 0.14, 12, 24), M(pick([0xe2b06e, 0xe63c32, 0xf0e2ba]), { r: 0.3 }));
	t.rotation.x = Math.PI / 2; t.position.y = 0.18; add(t, g);
	return g;
}
function trophy(x, y, z, parent, metal) {
	const g = group(parent); g.position.set(x, y, z);
	const m = M(metal ?? pick([0xf5c13c, 0xd2d6de, 0xce8246]), { m: 0.9, r: 0.2 });
	box(0.7, 0.25, 0.5, M(0x1e1e22, { r: 0.3 }), 0, 0.125, 0, g);
	box(0.45, 0.14, 0.32, M(0x28282e), 0, 0.32, 0, g);
	cyl(0.06, 0.06, 0.3, m, 0, 0.54, 0, g);
	cyl(0.34, 0.12, 0.55, m, 0, 0.95, 0, g);
	for (const s of [-1, 1]) { const h = new THREE.Mesh(new THREE.TorusGeometry(0.14, 0.035, 8, 16, Math.PI), m); h.position.set(s * 0.38, 1.0, 0); h.rotation.z = s * -Math.PI / 2; add(h, g); }
	box(0.3, 0.08, 0.02, M(0xf5c13c, { m: 0.8, r: 0.3 }), 0, 0.125, 0.26, g);
	return g;
}
function photoFrame(x, z, parent, flat = true) {
	const g = group(parent); g.position.set(x, 0, z);
	const tex = patternTex((gg, s) => { gg.fillStyle = '#82c8fa'; gg.fillRect(0, 0, s, s); gg.fillStyle = '#5ab450'; gg.beginPath(); gg.ellipse(s * 0.3, s, s * 0.6, s * 0.4, 0, 0, Math.PI * 2); gg.fill(); gg.fillStyle = '#46963c'; gg.beginPath(); gg.ellipse(s * 0.8, s, s * 0.5, s * 0.5, 0, 0, Math.PI * 2); gg.fill(); gg.fillStyle = '#ffdc50'; gg.beginPath(); gg.arc(s * 0.25, s * 0.28, s * 0.1, 0, 7); gg.fill(); });
	box(1.2, 0.95, 0.1, M(pick([0xecba46, 0x68422a, 0x1e1e22]), { m: 0.3 }), 0, 0, 0, g);
	box(1.02, 0.78, 0.02, M(0xffffff, { map: tex }), 0, 0, 0.055, g);
	if (flat) { g.rotation.set(-Math.PI / 2, 0, rr(0, 6)); g.position.y = 0.06; }
	return g;
}
function binder(x, z, parent, color) {
	const g = group(parent); g.position.set(x, 0.2, z);
	box(0.4, 1.3, 1.0, M(color ?? pick([0x2e9660, 0x2c4696, 0x9646b4, 0xf07828])), 0, 0, 0, g);
	box(0.3, 1.22, 0.92, M(0xfaf8f0), 0, 0, 0.06, g);
	box(0.3, 0.4, 0.02, M(0xffffff), 0, 0.25, -0.51, g);
	g.rotation.set(0, rr(0, 6), Math.PI / 2);
	return g;
}
function cushion(x, z, parent) {
	const c = rbox(1.2, 0.4, 1.2, 0.18, M(pick([0xecbe6e, 0xd25046, 0x50aaa0, 0x9664c8]), { r: 0.95 }), x, 0.2, z, parent);
	c.rotation.y = rr(0, 6); return c;
}
function laptop(x, z, parent) {
	const g = group(parent); g.position.set(x, 0, z); g.rotation.y = rr(0, 6.28);
	box(1.2, 0.06, 0.9, M(0x3c4048, { m: 0.6, r: 0.4 }), 0, 0.03, 0, g);
	const lid = box(1.2, 0.04, 0.9, M(0xc4c8d0, { m: 0.7, r: 0.3 }), 0, 0.08, 0, g);
	box(0.18, 0.01, 0.18, M(0xffffff, { e: 0xffffff, ei: 0.6 }), 0, 0.105, 0, g);
	return g;
}

// ---------------------------------------------------------------- décor
function hangingSign(text, x, y, z, width, color, ceilingY, rotY = 0) {
	const g = group(); g.position.set(x, y, z); g.rotation.y = rotY;
	const h = Math.max(1.8, width * 0.24);
	const tex = textTex(text, { w: 1024, h: Math.round(1024 * h / width), bg: '#' + new THREE.Color(color).getHexString(), fg: '#ffffff', font: 'Fredoka', weight: '700', size: Math.round(1024 * h / width * 0.42) });
	rbox(width + 0.35, h + 0.35, 0.3, 0.15, M(0xffffff), 0, 0, -0.05, g);
	const front = M(0xffffff, { map: tex, e: 0xffffff, ei: 0.0 });
	const b = new THREE.Mesh(new RoundedBoxGeometry(width, h, 0.36, 3, 0.12), [M(color), M(color), M(color), M(color), front, front]);
	add(b, g);
	if (ceilingY) for (const s of [-1, 1]) cyl(0.04, 0.04, ceilingY - y - h / 2, M(0x333338), s * (width / 2 - 0.5), (ceilingY - y + h / 2) / 2 + h / 4, 0, g, 6);
	return g;
}
function pendant(x, ceilingY, z, drop, color = 0x2c2f36, withLight = true, intensity = 30) {
	const g = group(); g.position.set(x, ceilingY - drop, z);
	cyl(0.03, 0.03, drop, M(0x111111), 0, drop / 2, 0, g, 6);
	const shade = new THREE.Mesh(new THREE.ConeGeometry(1.1, 0.9, 24, 1, true), M(color, { m: 0.5, r: 0.4 }));
	shade.material.side = THREE.DoubleSide; shade.position.y = -0.2; add(shade, g, false);
	ball(0.32, M(0xfff0c8, { e: 0xffe6b0, ei: 4 }), 0, -0.55, 0, g);
	if (withLight) { const l = new THREE.PointLight(0xffe0b8, intensity, 30, 1.6); l.position.y = -0.9; g.add(l); }
	return g;
}
function chandelier(x, ceilingY, z, scale = 1) {
	const g = group(); g.position.set(x, ceilingY - 2.6 * scale, z); g.scale.setScalar(scale);
	const gold = M(0xf0be4a, { m: 0.95, r: 0.2 });
	cyl(0.06, 0.06, 2.6, gold, 0, 1.3, 0, g, 6);
	const ring = new THREE.Mesh(new THREE.TorusGeometry(1.7, 0.1, 10, 40), gold); ring.rotation.x = Math.PI / 2; add(ring, g, false);
	ball(0.45, gold, 0, -0.2, 0, g);
	for (let k = 0; k < 10; k++) {
		const a = k / 10 * Math.PI * 2;
		ball(0.2, M(0xfff0c8, { e: 0xffe0a0, ei: 5 }), Math.cos(a) * 1.7, 0.35, Math.sin(a) * 1.7, g);
		const c = new THREE.Mesh(new THREE.OctahedronGeometry(0.16), M(0xe6f4ff, { m: 0.2, r: 0.05 })); c.position.set(Math.cos(a) * 1.7, -0.4, Math.sin(a) * 1.7); c.scale.y = 1.8; add(c, g, false);
	}
	const l = new THREE.PointLight(0xffd8a0, 10, 30, 1.8); l.position.y = -0.3; g.add(l);
	return g;
}
function palm(x, z, scale = 1) {
	const g = group(); g.position.set(x, 0, z); g.scale.setScalar(scale);
	cyl(1.7, 1.4, 2.2, M(0xffffff, { r: 0.3 }), 0, 1.1, 0, g);
	cyl(1.85, 1.85, 0.3, M(0xf0be4a, { m: 0.9, r: 0.25 }), 0, 2.2, 0, g);
	for (let i = 0; i < 7; i++) cyl(0.42 - i * 0.03, 0.46 - i * 0.03, 1.2, M(0x8c6440, { r: 0.9 }), i * 0.08, 2.8 + i * 1.1, 0, g, 10);
	for (let k = 0; k < 9; k++) {
		const a = k / 9 * Math.PI * 2;
		const leaf = box(0.9, 0.1, 4.6, M(k % 2 ? 0x4ea044 : 0x66b850, { r: 0.8 }), 0, 0, 0, g);
		leaf.position.set(0.6 + Math.cos(a) * 1.9, 10.2 - 0.6, Math.sin(a) * 1.9);
		leaf.rotation.set(0, -a + Math.PI / 2, 0); leaf.rotateX(0.45);
	}
	return g;
}
function slatCeiling(x0, x1, z0, z1, y, holesZ = []) {
	const slatM = M(0xd68e52, { r: 0.7 });
	for (let z = z0; z < z1; z += 2.4) {
		if (holesZ.some(([a, b]) => z > a && z < b)) continue;
		box(x1 - x0, 0.35, 1.0, slatM, (x0 + x1) / 2, y, z, null, false);
	}
	box(x1 - x0, 0.5, z1 - z0, M(0xf2ead8), (x0 + x1) / 2, y + 0.5, (z0 + z1) / 2, null, false);
	for (const [a, b] of holesZ) {
		box(x1 - x0 - 6, 0.2, b - a, M(0xcfeaff, { e: 0xbfe4ff, ei: 1.6 }), (x0 + x1) / 2, y + 0.9, (a + b) / 2, null, false);
		for (const zz of [a, b]) box(x1 - x0 - 6, 0.6, 0.4, M(0xffffff), (x0 + x1) / 2, y + 0.2, zz, null, false);
	}
}
function lightStrips(x0, x1, z0, z1, y, step = 9) {
	for (let z = z0; z < z1; z += step) box(x1 - x0 - 10, 0.12, 0.5, M(0xfff4dc, { e: 0xfff0d0, ei: 3 }), (x0 + x1) / 2, y - 0.25, z, null, false);
}
function tileFloor(x0, x1, z0, z1, base = '#f2e6cc', grout = '#d8c8a8', tile = 4, opts = {}) {
	const w = x1 - x0, d = z1 - z0;
	const tex = patternTex((g, s) => { g.fillStyle = base; g.fillRect(0, 0, s, s); g.strokeStyle = grout; g.lineWidth = 6; g.strokeRect(0, 0, s, s); if (opts.vein) { g.strokeStyle = 'rgba(160,160,170,0.25)'; g.lineWidth = 2; for (let i = 0; i < 5; i++) { g.beginPath(); g.moveTo(rand() * s, 0); g.bezierCurveTo(rand() * s, rand() * s, rand() * s, rand() * s, rand() * s, s); g.stroke(); } } }, 256, [w / tile, d / tile]);
	const m = new THREE.Mesh(new THREE.PlaneGeometry(w, d), new THREE.MeshStandardMaterial({ map: tex, roughness: opts.r ?? 0.35, metalness: 0.0 }));
	m.rotation.x = -Math.PI / 2; m.position.set((x0 + x1) / 2, 0, (z0 + z1) / 2); m.receiveShadow = true; scene.add(m);
	return m;
}
function desk(x, z, rot = 0) {
	const g = group(); g.position.set(x, 0, z); g.rotation.y = rot;
	box(6, 0.2, 3, M(0xe0ae72, { r: 0.5 }), 0, 2.5, 0, g);
	for (const s of [-1, 1]) box(0.2, 2.4, 2.8, M(0xc8ccd4, { m: 0.5 }), s * 2.85, 1.2, 0, g);
	box(0.4, 0.5, 0.3, M(0x1e1e22), 0, 2.85, -0.8, g);
	box(2.3, 1.4, 0.12, M(0x1e1e22), 0, 3.7, -0.8, g);
	box(2.1, 1.2, 0.02, M(0x4aa0e8, { e: 0x3a90e0, ei: 0.9 }), 0, 3.7, -0.73, g);
	box(1.6, 0.08, 0.5, M(0x26262a), 0, 2.64, 0.4, g);
	box(1.4, 0.1, 1.8, M(0x30323a), 2, 2.65, 0.2, g);
	return g;
}
function rackRow(x, z0, z1, side, levels = 4) {
	const g = group(); const len = z1 - z0; const cz = (z0 + z1) / 2;
	const blue = M(0x2860b0, { m: 0.4, r: 0.4 }), orange = M(0xf07824, { m: 0.3, r: 0.4 }), wood = M(0xd6b482, { r: 0.8 });
	for (let z = z0; z <= z1 + 0.01; z += len / Math.ceil(len / 9)) for (const s of [-1, 1]) box(0.3, 11, 0.3, blue, x + s * 2.05, 5.5, z, g);
	for (let l = 0; l < levels; l++) {
		const y = 0.4 + l * 2.6;
		box(4.2, 0.12, len, wood, x, y, cz, g);
		for (const s of [-1, 1]) box(0.12, 0.3, len, orange, x + s * 2.16, y - 0.15, cz, g);
		// marchandises rangées (côté visible)
		let zz = z0 + 0.8;
		while (zz < z1 - 0.8) {
			const kind = rand();
			const fx = x + side * 1.0;
			if (kind < 0.4) { const w = rr(1.0, 1.8); cardboardBox(fx, y + 0.06, zz, 1.6, rr(1.2, 1.9), w, g, rand() < 0.4); zz += w + 0.25; }
			else if (kind < 0.7) { const c = M(pick(BRIGHT), { r: 0.4 }); for (let k = 0; k < 3; k++) rbox(0.9, 1.3, 0.7, 0.1, c, fx, y + 0.71, zz + k * 0.85, g); zz += 2.8; }
			else { for (let k = 0; k < 4; k++) can(fx + rr(-0.4, 0.4), zz + k * 0.6, g).position.y = y + 0.06; zz += 2.6; }
			if (rand() < 0.18) zz += rr(1.5, 3.5);
		}
	}
	box(4.2, 0.15, len, wood, x, 10.6, cz, g);
	return g;
}

// ---------------------------------------------------------------- éparpillement
function scatter(n, x0, x1, z0, z1, makers, avoid = []) {
	let placed = 0, tries = 0;
	const pts = [];
	while (placed < n && tries < n * 30) {
		tries++;
		const x = rr(x0, x1), z = rr(z0, z1);
		if (avoid.some(([ax, az, r]) => (x - ax) ** 2 + (z - az) ** 2 < r * r)) continue;
		if (pts.some(([px, pz]) => (px - x) ** 2 + (pz - z) ** 2 < 0.9)) continue;
		pts.push([x, z]);
		pick(makers)(x, z);
		placed++;
	}
}

// ---------------------------------------------------------------- scènes
const camera = new THREE.PerspectiveCamera(50, W / H, 0.1, 600);
let bloomStrength = 0.12;

function lightsBase(sunPos = [40, 80, 30], sunIntensity = 2.2) {
	scene.add(new THREE.HemisphereLight(0xfff4e6, 0xa08868, 0.6));
	const sun = new THREE.DirectionalLight(0xfff0dc, sunIntensity);
	sun.position.set(...sunPos); sun.castShadow = true;
	sun.shadow.mapSize.set(4096, 4096);
	const c = sun.shadow.camera; c.left = -70; c.right = 70; c.top = 70; c.bottom = -70; c.near = 1; c.far = 300;
	sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.04;
	scene.add(sun);
	return sun;
}

function buildOffice(closeUp) {
	scene.background = new THREE.Color(0xf6eedd);
	scene.fog = new THREE.Fog(0xf3e8d4, 90, 170);
	lightsBase([20, 60, 40], 1.8);
	tileFloor(-40, 40, -90, 30, '#f4e8d0', '#dccbaa', 4);
	slatCeiling(-40, 40, -90, 30, 14, [[-36, -26], [-6, 2]]);
	lightStrips(-40, 40, -88, 28);
	// murs
	const wallM = M(CREAM, { r: 0.8 });
	box(80, 16, 1, wallM, 0, 8, -90);
	for (const s of [-1, 1]) { box(1, 16, 120, wallM, s * 40, 8, -30); box(0.3, 3.5, 120, M(TEAL), s * 39.6, 1.75, -30); }
	box(80, 3.5, 0.3, M(TEAL), 0, 1.75, -89.4);
	// fenêtres côté droit
	for (let z = -80; z < 20; z += 14) box(0.2, 6, 9, M(0xbfe8ff, { e: 0xbfe8ff, ei: 1.2 }), 39.4, 7.5, z, null, false);
	// étagères d'archives à gauche
	for (let z = -70; z < 10; z += 9) {
		const g = group(); g.position.set(-37.5, 0, z);
		box(2, 9, 7, M(0xc89a68), 0, 4.5, 0, g);
		for (let l = 0; l < 4; l++) for (let k = 0; k < 9; k++) box(1.4, 1.5, 0.4, M(pick([0xecc478, 0x4078d2, 0xd23c3c, 0x3ca060, 0x965ac8])), 1.0, 1.3 + l * 2.1, -3 + k * 0.72, g);
	}
	// bureaux
	for (let z = -70; z <= -10; z += 15) for (const x of [-22, -8, 8, 22]) {
		desk(x, z, 0);
		officeChair(x + rr(-1, 1), z + 2.6, null, rand() < 0.5);
	}
	// accueil
	const rec = group(); rec.position.set(0, 0, -2);
	rbox(14, 3.8, 2.6, 0.15, M(0x8a5a36, { r: 0.5 }), 0, 1.9, 0, rec);
	box(14.4, 0.25, 3, M(0xf4f0e8, { r: 0.2 }), 0, 3.9, 0, rec);
	box(5, 1, 0.05, M(0xffffff, { map: textTex('RECEPTION', { w: 512, h: 100, bg: '#2a8aa8', size: 60 }) }), 0, 2.3, 1.32, rec);
	// panneaux suspendus
	hangingSign('ARCHIVES', -24, 9.5, -34, 9, 0x2a8aa8, 14);
	hangingSign('BREAK ROOM', 16, 9.8, -52, 10, 0xe8783c, 14);
	hangingSign('MAIL ROOM', -6, 10, -72, 9, 0x3ca060, 14);
	hangingSign('OFFICES', 22, 9.5, -20, 8, 0x5a6ad2, 14);
	for (const p of [[-34, 20], [34, 20], [-34, -84], [34, -84], [12, -2]]) plant(p[0], p[1], null, 1.6);
	pendant(-14, 13.6, 6, 4, 0xe8783c); pendant(14, 13.6, 6, 4, 0xe8783c);
	// le désordre
	const makers = [
		(x, z) => paperStack(x, z), (x, z) => looseSheet(x, z), (x, z) => looseSheet(x, z), (x, z) => folder(x, z),
		(x, z) => mug(x, z, null, true), (x, z) => mug(x, z), (x, z) => cardboardBox(x, 0, z, 2.1, 1.6, 1.6, null).rotation.y = rr(0, 6),
		(x, z) => laptop(x, z), (x, z) => cushion(x, z), (x, z) => photoFrame(x, z), (x, z) => binder(x, z), (x, z) => plant(x, z, null, 0.8),
	];
	scatter(closeUp ? 160 : 520, -34, 34, -80, 25, makers, [[7.5, 12, 3.2], [5, 16.5, 2.4]]);
	for (let i = 0; i < 6; i++) officeChair(rr(-30, 30), rr(-60, 10), null, true);
	// personnage
	const hero = character({ pose: 'sweep', vest: 0x2f6fd0, hair: 0x8a4a22, scale: 1.3 });
	hero.position.set(closeUp ? 1.2 : 7.5, 0, closeUp ? 15 : 11.5); hero.rotation.y = closeUp ? -0.35 : -0.5;
	if (closeUp) {
		camera.position.set(-4.5, 4.4, 27); camera.lookAt(-0.2, 3.9, 13); camera.fov = 46;
	} else {
		camera.position.set(-1, 5.4, 27); camera.lookAt(2.5, 3.6, 6); camera.fov = 52;
	}
}

function buildWarehouse() {
	scene.background = new THREE.Color(0xeee6d8);
	scene.fog = new THREE.Fog(0xece2d0, 70, 170);
	lightsBase([-30, 90, 20], 1.6);
	tileFloor(-50, 50, -150, 30, '#e6e2d8', '#d6d0c2', 10, { r: 0.25 });
	for (const x of [-7, 7]) box(0.4, 0.02, 180, M(0xfacc28), x, 0.01, -60, null, false);
	slatCeiling(-50, 50, -150, 30, 28, [[-100, -88], [-40, -30], [5, 13]]);
	lightStrips(-50, 50, -148, 28, 14);
	box(100, 30, 1, M(CREAM), 0, 15, -150);
	box(100, 4, 0.4, M(TEAL), 0, 2, -149.5);
	for (const x of [-12, 12]) rackRow(x, -140, 8, x < 0 ? 1 : -1, 4);
	for (const x of [-30, 30]) rackRow(x, -140, 8, x < 0 ? 1 : -1, 4);
	for (const x of [-18, 18]) rackRow(x, -140, 8, x < 0 ? -1 : 1, 4);
	for (const x of [-36, 36]) rackRow(x, -140, 8, x < 0 ? -1 : 1, 4);
	for (let z = -130; z < 20; z += 22) for (const x of [-21, 0, 21]) pendant(x, 27.6, z, 7, 0x2c2f36, x === 0, 50);
	hangingSign('TOYS & GAMES', 0, 18, -12, 14, 0xe64690, 28);
	hangingSign('PANTRY', -24, 18, -40, 11, 0x50aa50, 28);
	hangingSign('ELECTRONICS', 24, 18, -55, 13, 0x6e5ad2, 28);
	hangingSign('FOOTWEAR', 0, 18, -78, 11, 0xe8603c, 28);
	hangingSign('HOUSEHOLD', -24, 18, -100, 12, 0x3c96dc, 28);
	// chariot élévateur
	const f = group(); f.position.set(-3.5, 0, -46); f.rotation.y = 0.7;
	rbox(3, 2, 4.4, 0.2, M(0xfacc28, { r: 0.4 }), 0, 1.4, 0.4, f); box(3, 0.2, 2.8, M(0x222226), 0, 6, 0.7, f);
	for (const s of [-1, 1]) { box(0.2, 3.6, 0.2, M(0x222226), s * 1.4, 4.2, -0.6, f); box(0.2, 3.6, 0.2, M(0x222226), s * 1.4, 4.2, 2, f); box(0.3, 6, 0.3, M(0x46464e), s, 3.4, -2, f); box(0.4, 0.15, 3, M(0x46464e), s * 0.8, 0.3, -3.6, f); for (const wz of [-1.2, 2.2]) { const w = cyl(0.7, 0.7, 0.6, M(0x111111), s * 1.55, 0.7, wz, f); w.rotation.z = Math.PI / 2; } }
	cardboardBox(-1, 0.5, -3.4, 3, 1.5, 2.4, f);
	// désordre
	const makers = [
		(x, z) => teddy(x, 0, z, pick([0xb0784a, 0xf0aac0, 0x78aae6, 0xf6f0e2]), null, 0.9).rotation.set(rr(-0.3, 0.3), rr(0, 6), rand() < 0.4 ? 1.4 : 0),
		(x, z) => toyCar(x, z), (x, z) => bottle(x, z, null, rand() < 0.5), (x, z) => can(x, z, null, rand() < 0.6), (x, z) => can(x, z, null, true),
		(x, z) => parcel(x, z, pick([0xe23e34, 0x2e74de, 0x34aa56, 0xf6c428])), (x, z) => shoeBox(x, z), (x, z) => beachBall(x, z), (x, z) => tapeRoll(x, z),
		(x, z) => cardboardBox(x, 0, z, 2.1, 1.6, 1.6).rotation.y = rr(0, 6),
	];
	scatter(380, -9.5, 9.5, -120, 28, makers, [[2, 20, 4.5], [-3.5, -46, 6]]);
	scatter(140, -15.5, -14.5, -120, 10, makers); scatter(140, 14.5, 15.5, -120, 10, makers);
	const hero = character({ pose: 'carry', vest: 0xf07828, cap: 0xf07828, hair: 0x3a2618, skin: '#c98d62', scale: 1.3 });
	hero.position.set(3, 0, 19); hero.rotation.y = -0.3;
	camera.position.set(-2.5, 7, 36); camera.lookAt(1.5, 5.5, -10); camera.fov = 52;
}

function buildHQ() {
	scene.background = new THREE.Color(0x2a1e18);
	scene.fog = new THREE.Fog(0x5a4430, 70, 150);
	lightsBase([30, 70, 50], 1.1);
	tileFloor(-35, 35, -90, 30, '#f4f0ea', '#c8bca8', 6, { vein: true, r: 0.12 });
	// tapis rouge
	box(7, 0.04, 110, M(0xb4282e, { r: 0.9 }), 0, 0.02, -35, null, false);
	for (const s of [-1, 1]) box(0.3, 0.05, 110, M(0xf0be4a, { m: 0.8, r: 0.3 }), s * 3.6, 0.025, -35, null, false);
	// murs en boiserie et or
	const walnut = M(0x6a4228, { r: 0.45 }), gold = M(0xf0be4a, { m: 0.9, r: 0.25 });
	for (const s of [-1, 1]) {
		box(1, 18, 120, M(0xf0e6d4, { r: 0.7 }), s * 35, 9, -30);
		box(0.4, 5, 120, walnut, s * 34.5, 2.5, -30); box(0.5, 0.3, 120, gold, s * 34.4, 5.1, -30);
		for (let z = -85; z < 25; z += 10) { box(1.3, 18, 0.9, M(0xf4f0ea, { r: 0.3 }), s * 34.2, 9, z); box(1.6, 0.5, 1.2, gold, s * 34.1, 17.6, z); }
	}
	box(70, 18, 1, M(0xf0e6d4), 0, 9, -90);
	box(30, 5, 0.4, M(0x6a4228, { map: textTex('APEX HOLDINGS', { w: 1024, h: 170, bg: '#6a4228', fg: '#f0be4a', font: 'Luckiest Guy', size: 110 }) }), 0, 12, -89.4);
	// plafond à caissons
	box(70, 0.6, 120, M(0xf4ecdc), 0, 18.3, -30, null, false);
	for (let x = -30; x <= 30; x += 10) box(0.5, 0.5, 120, gold, x, 17.9, -30, null, false);
	for (let z = -85; z <= 25; z += 10) box(70, 0.5, 0.5, gold, 0, 17.9, z, null, false);
	for (let z = -75; z <= 15; z += 22) chandelier(0, 18, z, 1.1);
	// vitrines à trophées
	for (const s of [-1, 1]) for (let z = -70; z <= 0; z += 14) {
		const g = group(); g.position.set(s * 32.4, 0, z);
		box(1.6, 9, 6.4, walnut, s * 0.6, 4.5, 0, g);
		for (let l = 0; l < 4; l++) {
			box(1.4, 0.1, 6, M(0xd8ecf8, { t: 0.5, r: 0.1 }), 0, 0.7 + l * 1.95, 0, g);
			for (let k = 0; k < 6; k++) trophy(0, 0.75 + l * 1.95, -2.4 + k * 0.95, g).rotation.y = s * -Math.PI / 2;
		}
		box(0.08, 8, 6, M(0xdff2ff, { t: 0.18, r: 0.05 }), -s * 0.7, 4.6, 0, g, false);
		const l = new THREE.PointLight(0xffe6c0, 2, 8, 2); l.position.set(-s * 1, 8, 0); g.add(l);
	}
	for (const p of [[-28, 22], [28, 22], [-28, -84], [28, -84]]) palm(p[0], p[1], 0.9);
	// désordre de luxe
	const makers = [
		(x, z) => { const t = trophy(x, 0, z); if (rand() < 0.5) { t.rotation.set(0, rr(0, 6), Math.PI / 2); t.position.y = 0.35; } },
		(x, z) => photoFrame(x, z), (x, z) => binder(x, z), (x, z) => folder(x, z), (x, z) => paperStack(x, z), (x, z) => looseSheet(x, z),
		(x, z) => cushion(x, z), (x, z) => mug(x, z, null, true), (x, z) => laptop(x, z),
	];
	scatter(330, -29, 29, -80, 26, makers, [[-5, 17, 4.5], [7, 13, 4]]);
	const hero = character({ pose: 'duster', vest: 0x7a3cb4, hair: 0xe0b040, skin: '#f4c9a0', scale: 1.3, mood: 'happy' });
	hero.position.set(-5, 0, 17); hero.rotation.y = 0.35;
	const hero2 = character({ pose: 'sweep', vest: 0x2e9660, hair: 0x2a1a10, skin: '#8d5a3c', scale: 1.15 });
	hero2.position.set(8, 0, 9); hero2.rotation.y = -0.8;
	camera.position.set(1, 6, 33); camera.lookAt(0, 4.5, -10); camera.fov = 52;
	bloomStrength = 0.15;
}

function buildLobby() {
	scene.background = new THREE.Color(0x7fbfee);
	scene.fog = new THREE.Fog(0xb8dcf4, 90, 180);
	lightsBase([30, 90, 40], 1.7);
	tileFloor(-50, 50, -70, 40, '#f2f2f8', '#d6d6e2', 6, { vein: true, r: 0.12 });
	const cyan = M(0x50e6ff, { e: 0x50e6ff, ei: 1.2 }), pink = M(0xff5ac8, { e: 0xff5ac8, ei: 1.2 });
	for (const s of [-1, 1]) {
		box(1, 24, 110, M(0xecf0fa), s * 50, 12, -15);
		box(0.6, 4, 110, M(0x24305a), s * 49.6, 2, -15);
		box(0.3, 0.3, 110, cyan, s * 49.3, 4.2, -15, null, false);
		box(0.3, 0.4, 110, pink, s * 49.3, 24, -15, null, false);
		// verrière
		const glass = box(52, 0.3, 112, M(0x9fd4f8, { t: 0.35, r: 0.05 }), s * 25, 31, -15, null, false); glass.rotation.z = -s * 0.27;
		for (let z = -70; z <= 40; z += 10) { const rib = box(52, 0.8, 0.6, M(0xffffff), s * 25, 30.4, z, null, false); rib.rotation.z = -s * 0.27; }
		for (const z of [-50, -20, 10]) {
			// colonnes
			cyl(1.5, 1.5, 24, M(0xf6f2ea, { r: 0.25 }), s * 36, 12, z + 15);
			for (const y of [0.4, 4, 23.4]) cyl(1.8, 1.8, 0.6, M(0xf0be4a, { m: 0.9, r: 0.25 }), s * 36, y, z + 15, null, 24);
		}
	}
	box(100, 24, 1, M(0xecf0fa), 0, 12, -70);
	box(26, 6, 0.5, M(0xffffff, { map: textTex('SHOP', { w: 512, h: 120, bg: '#ff5ac8', fg: '#ffffff', font: 'Luckiest Guy', size: 96 }) }), 0, 12, -69.4);
	box(30, 4, 3, M(0xffffff), 0, 2, -60); box(30.6, 0.3, 3.6, M(0xf0be4a, { m: 0.9, r: 0.25 }), 0, 4.15, -60);
	character({ pose: 'wave', vest: 0x28aac0, cap: 0xf08228, hair: 0x5a3a1e, scale: 1 }).position.set(4, 0, -64);
	// plateformes de départ
	const padColors = [0x50c8ff, 0xff78c8, 0x78e678];
	padColors.forEach((c, i) => {
		const x = (i - 1) * 22, z = -18;
		cyl(6, 6, 0.6, M(0x282c3c), x, 0.3, z, null, 48);
		cyl(6.4, 6.4, 0.25, M(c, { e: c, ei: 1.2 }), x, 0.12, z, null, 48);
		cyl(5, 5, 0.08, M(c, { e: c, ei: 0.8, t: 0.8 }), x, 0.64, z, null, 48);
		const l = new THREE.PointLight(c, 6, 14, 2); l.position.set(x, 3, z); scene.add(l);
		const sign = hangingSign(['QUEUE ' + (i + 1)], x, 10, z - 6, 8, c, null);
	});
	const crew = [
		{ vest: 0x2f6fd0, hair: 0x8a4a22, pose: 'jump', x: -2, z: -16 },
		{ vest: 0xf07828, hair: 0x2a1a10, skin: '#c98d62', pose: 'wave', x: 2.5, z: -19, cap: 0xf07828 },
		{ vest: 0x7a3cb4, hair: 0xe0b040, pose: 'wave', x: -22, z: -17 },
		{ vest: 0x2e9660, hair: 0x1e1e22, skin: '#8d5a3c', pose: 'jump', x: 22, z: -18 },
	];
	for (const c of crew) { const h = character({ ...c, scale: 1.25 }); h.position.x = c.x; h.position.z = c.z; h.rotation.y = rr(-0.3, 0.3); }
	for (const p of [[-42, 25], [42, 25], [-14, 8], [14, 8], [-42, -55], [42, -55]]) palm(p[0], p[1], 1);
	camera.position.set(0, 5.2, 5); camera.lookAt(0, 4.6, -20); camera.fov = 62;
	bloomStrength = 0.15;
}

// ---------------------------------------------------------------- rendu
async function main() {
	await Promise.all([
		new FontFace('Luckiest Guy', 'url(node_modules/@fontsource/luckiest-guy/files/luckiest-guy-latin-400-normal.woff2)').load().then(f => document.fonts.add(f)),
		new FontFace('Fredoka', 'url(node_modules/@fontsource/fredoka/files/fredoka-latin-700-normal.woff2)', { weight: '700' }).load().then(f => document.fonts.add(f)),
		new FontFace('Fredoka', 'url(node_modules/@fontsource/fredoka/files/fredoka-latin-600-normal.woff2)', { weight: '600' }).load().then(f => document.fonts.add(f)),
	]);
	const renderer = new THREE.WebGLRenderer({ canvas: document.getElementById('c'), antialias: true, preserveDrawingBuffer: true });
	renderer.setSize(W, H, false);
	renderer.setPixelRatio(1);
	renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
	renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 0.82;
	renderer.outputColorSpace = THREE.SRGBColorSpace;
	const pmrem = new THREE.PMREMGenerator(renderer);
	scene.environment = pmrem.fromScene(new RoomEnvironment(renderer), 0.04).texture;
	scene.environmentIntensity = 0.45;

	if (SCENE === 'office') buildOffice(false);
	else if (SCENE === 'icon') buildOffice(true);
	else if (SCENE === 'warehouse') buildWarehouse();
	else if (SCENE === 'hq') buildHQ();
	else if (SCENE === 'lobby') buildLobby();
	camera.aspect = W / H; camera.updateProjectionMatrix();

	const composer = new EffectComposer(renderer);
	composer.setSize(W, H);
	composer.addPass(new RenderPass(scene, camera));
	composer.addPass(new UnrealBloomPass(new THREE.Vector2(W, H), bloomStrength, 0.25, 0.97));
	composer.addPass(new OutputPass());
	composer.render();
	document.title = 'done';
}
main().catch(e => { document.title = 'error: ' + e.message; console.error(e); });
