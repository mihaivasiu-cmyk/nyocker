// Nyócker desktop in the iPhone app's format: same screens, same data, same look by time of day.
// Spots and Discover pages come from the iOS app's content.json and discover.json (copied in by build.rs).
"use strict";

const FEEDS = "https://mihaivasiu-cmyk.github.io/nyocker";
const DISTRICT = [47.4895, 19.0765];
// The same district region the iPhone map opens on (NyockerMap.district in Swift).
const DISTRICT_BOUNDS = [[47.4765, 19.0615], [47.5025, 19.0915]];
const BLAHA = [47.4963, 19.0704]; // where we pretend to stand when the computer won't say
const ROUTER = "https://routing.openstreetmap.de/routed-foot/route/v1/foot";

const CATS = [
  ["lore", "Lore", "#E8341C", "!"], ["bar", "Bars", "#F8B800", "🍷"], ["club", "Clubs", "#FF5FA2", "♫"],
  ["art", "Art", "#4CC9F0", "◧"], ["eat", "Eats", "#FF7A59", "🍴"], ["thrift", "Second hand", "#5BE37D", "👕"],
  ["local", "Local", "#E6E3F6", "⌂"],
];
const CAT = Object.fromEntries(CATS.map(([id, title, hex, sym]) => [id, { title, hex, sym }]));
const TAG = { lore: "LORE", bar: "BAR", club: "CLUB", art: "ART SPACE", eat: "EATS", thrift: "SECOND HAND", local: "LOCAL" };
/** Venue art shipped with the app, by the asset name content.json uses. */
const ART = { "kerge-pin": "data/kerge-pin.png", "kerge-hero": "data/kerge-hero.jpg", underbar: "data/underbar.png", so: "data/so.png" };
// Every other Discover hero is copied in by build.rs as data/<id>-hero.jpg.
const heroImage = (name) => ART[name] || (/^[a-z0-9]+-hero$/.test(name) ? `data/${name}.jpg` : null);

/* ---------- Time of day: the same eight phases and palettes as Theme.swift ---------- */

const PHASES = [
  { start: 4 * 60 + 30, title: "First light", icon: "☀︎", dark: true, bg: "#1D1A4A", surface: "#2D2966", raised: "#423C85", line: "#7A74BF", text: "#FFFFFF", muted: "#D6D2F0", accent: "#FFB8C9", link: "#B8DCFF", lore: "#3A2F86", fill: "#FFB8C9", sky: ["#12103A", "#3B2A78", "#B4568C"], skyInk: "#FFE4EC", body: "#FFE9B0", bodyY: 0.60, moon: false, stars: 0.7, windows: 0.8, far: "#2F2670", near: "#1B1748", ground: "#12103A" },
  { start: 5 * 60 + 30, title: "Sunrise", icon: "☀︎", dark: false, bg: "#FFE8DD", surface: "#FFF6F1", raised: "#FFD8C7", line: "#C98D76", text: "#3B1730", muted: "#6E4656", accent: "#B42A52", link: "#8A2F6F", lore: "#FFD8E0", fill: "#FF9A6B", sky: ["#3A2A7A", "#D65A8A", "#FFB56B", "#FFE59A"], skyInk: "#FFF3C4", body: "#FFF2B0", bodyY: 0.56, moon: false, stars: 0.15, windows: 0.35, far: "#7A4A8C", near: "#4A2A66", ground: "#2C1A4A" },
  { start: 7 * 60 + 30, title: "Morning", icon: "☀︎", dark: false, bg: "#E4F3FB", surface: "#FFFFFF", raised: "#CDE7F5", line: "#7FAFC9", text: "#10304A", muted: "#3F6078", accent: "#0A6AA0", link: "#0A6AA0", lore: "#D6ECFA", fill: "#FFD23F", sky: ["#5BB8EC", "#A8DDF5", "#E9F6FB"], skyInk: "#0B2A44", body: "#FFF3C0", bodyY: 0.38, moon: false, stars: 0, windows: 0, far: "#9CC4DC", near: "#6C9CBC", ground: "#34607E" },
  { start: 11 * 60, title: "Midday", icon: "☀︎", dark: false, bg: "#FFF6D8", surface: "#FFFFFF", raised: "#FFE9A8", line: "#C4AC5E", text: "#2B2408", muted: "#5E5426", accent: "#8F5400", link: "#0A6AA0", lore: "#FFEDB8", fill: "#FFD23F", sky: ["#4AA9EC", "#9AD8F7", "#DFF3FB"], skyInk: "#08233A", body: "#FFF7D0", bodyY: 0.38, moon: false, stars: 0, windows: 0, far: "#A4C8DE", near: "#78A0BC", ground: "#3E6680" },
  { start: 16 * 60, title: "Golden hour", icon: "☀︎", dark: false, bg: "#FFDFAE", surface: "#FFF0D6", raised: "#FFCF8A", line: "#B88444", text: "#3D1E08", muted: "#5E3A18", accent: "#9A3600", link: "#7A3A00", lore: "#FFD39B", fill: "#FF9E3D", sky: ["#F2A03D", "#FFC56B", "#FFE9B0"], skyInk: "#3D1E08", body: "#FFF3C4", bodyY: 0.44, moon: false, stars: 0, windows: 0.1, far: "#C48A5A", near: "#8C5A3C", ground: "#5C3826" },
  { start: 18 * 60 + 30, title: "Sunset", icon: "☀︎", dark: true, bg: "#3B1444", surface: "#56205E", raised: "#743078", line: "#A763A8", text: "#FFFFFF", muted: "#F3D6E4", accent: "#FFB36B", link: "#FFD0A8", lore: "#6B1F52", fill: "#FF9E5E", sky: ["#2A1458", "#A0357F", "#FF8A5C", "#FFC56B"], skyInk: "#FFD23F", body: "#FFD27A", bodyY: 0.60, moon: false, stars: 0.25, windows: 0.6, far: "#4A2470", near: "#2C1648", ground: "#1E0F36" },
  { start: 20 * 60, title: "Dusk", icon: "☾", dark: true, bg: "#17174A", surface: "#27276A", raised: "#3A3A8A", line: "#6C6CC0", text: "#FFFFFF", muted: "#D0D0F0", accent: "#FFC98A", link: "#B4C6FF", lore: "#2E2E7E", fill: "#FFC98A", sky: ["#100E3A", "#2A1F6E", "#7A3A8E", "#D46A6A"], skyInk: "#FFD23F", body: "#FFE9B0", bodyY: 0.38, moon: true, stars: 0.7, windows: 0.9, far: "#2A2470", near: "#191548", ground: "#100E30" },
  { start: 21 * 60 + 30, title: "Night", icon: "☾", dark: true, bg: "#100E26", surface: "#1E1B42", raised: "#332C66", line: "#5F58A3", text: "#FFFFFF", muted: "#C9C6E4", accent: "#FFD23F", link: "#A8E4FA", lore: "#232A7A", fill: "#FFD23F", sky: ["#0A0820", "#1A1650", "#3A2A7A"], skyInk: "#FFD23F", body: "#FFE9B0", bodyY: 0.38, moon: true, stars: 1, windows: 1, far: "#2A1F66", near: "#191540", ground: "#100E26" },
];

function currentPhase() {
  const now = new Date(), minute = now.getHours() * 60 + now.getMinutes();
  return [...PHASES].reverse().find((p) => p.start <= minute) || PHASES[PHASES.length - 1];
}

let phase = currentPhase();

function applyTheme() {
  const root = document.documentElement.style;
  for (const key of ["bg", "surface", "raised", "line", "text", "muted", "accent", "link", "lore", "fill", "skyInk"]) {
    root.setProperty(`--${key}`, phase[key]);
  }
  document.body.classList.toggle("dark", phase.dark);
}

/* ---------- Fit the 393 x 852 phone screen into the window, keeping its shape ---------- */

function fit() {
  const stage = document.getElementById("stage");
  const scale = Math.min(window.innerWidth / 393, window.innerHeight / 852);
  const left = (window.innerWidth - 393 * scale) / 2, top = (window.innerHeight - 852 * scale) / 2;
  stage.style.transform = `translate(${left}px, ${top}px) scale(${scale})`;
}
fit();
window.addEventListener("resize", fit);

/* ---------- Helpers ---------- */

const $ = (id) => document.getElementById(id);
const esc = (t) => String(t ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m]));
const store = {
  get(key, fallback) { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } },
  set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* storage off */ } },
};
const https = (url) => typeof url === "string" && url.startsWith("https://");

let content = { spots: [], events: [], radio: [] };
let pages = {};
let found = new Set(store.get("found", []));
let going = new Set(store.get("going", []));
let filter = null, selected = null, trip = null, routeLine = null, me = null;
const markers = {};

/** Opens outside the app, in the computer's own browser. */
function openOutside(url) {
  const opener = window.__TAURI__?.opener;
  if (opener) opener.openUrl(url); else window.open(url, "_blank");
}

/* ---------- Sheets (slide up from the bottom, like iOS) ---------- */

function openSheet(html, className = "") {
  const body = $("sheetbody");
  body.className = "sheet-body " + className;
  body.innerHTML = html;
  $("sheet").hidden = false;
  return body;
}
function closeSheet() { $("sheet").hidden = true; $("sheetbody").innerHTML = ""; }
$("sheet").addEventListener("click", (e) => { if (e.target.id === "sheet") closeSheet(); });

/** A web page inside the app, like the iPhone's in-app Safari. */
function openWeb(title, url) {
  const body = openSheet(`<div class="sheet-top web-top"><button class="sdone" id="wdone">Done</button><span>${esc(title)}</span>
    <button class="sdone" id="wout" aria-label="Open in browser">↗</button></div><iframe src="${esc(url)}" title="${esc(title)}"></iframe>`);
  body.querySelector("#wdone").onclick = closeSheet;
  body.querySelector("#wout").onclick = () => openOutside(url);
}

/* ---------- Start screen: the city skyline for the time of day (DayScene in Swift) ---------- */

function lcg(seed) {
  return (lo = 0, hi = 1) => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return lo + (hi - lo) * (seed >>> 16) / 65535;
  };
}
const BLOCKS = (() => {
  const next = lcg(8), out = [];
  for (const far of [true, false]) {
    let x = far ? -6 : -14;
    while (x < 460) {
      const width = far ? next(36, 66) : next(44, 76);
      const height = far ? next(120, 230) : next(70, 150);
      const lit = [];
      if (!far) {
        for (let wy = 12; wy < height - 12; wy += 16) {
          for (let wx = 8; wx < width - 12; wx += 13) if (next() < 0.36) lit.push([wx, wy]);
        }
      }
      out.push({ x, width, height, far, lit });
      x += width + (far ? 3 : 4);
    }
  }
  return out;
})();
const STARS = (() => { const next = lcg(42); return Array.from({ length: 56 }, () => [next(), next() * 0.5, 0.6 + next()]); })();

function drawSky() {
  const canvas = $("sky"), ratio = window.devicePixelRatio || 1;
  const w = canvas.clientWidth, h = canvas.clientHeight;
  canvas.width = w * ratio; canvas.height = h * ratio;
  const ctx = canvas.getContext("2d");
  ctx.scale(ratio, ratio);
  const p = phase, horizon = h * 0.77, scale = w / 390;

  const stops = p.sky.length === 4 ? [0.05, 0.5, 0.64, 0.78] : [0.05, 0.5, 0.78];
  const grad = ctx.createLinearGradient(0, 0, 0, h);
  p.sky.forEach((c, i) => grad.addColorStop(stops[i], c));
  ctx.fillStyle = grad; ctx.fillRect(0, 0, w, h);

  ctx.globalAlpha = p.stars; ctx.fillStyle = "#fff";
  for (const [sx, sy, r] of STARS) { ctx.beginPath(); ctx.arc(sx * w + r, sy * h + r, r, 0, 7); ctx.fill(); }
  ctx.globalAlpha = 1;

  ctx.save(); ctx.shadowColor = p.body; ctx.shadowBlur = p.moon ? 16 : 52; ctx.fillStyle = p.body;
  ctx.beginPath(); ctx.arc(w * 0.78, h * p.bodyY, 30, 0, 7); ctx.fill(); ctx.restore();

  const box = (x, y, bw, bh, color, alpha = 1) => { ctx.globalAlpha = alpha; ctx.fillStyle = color; ctx.beginPath(); ctx.roundRect(x, y, bw, bh, 3); ctx.fill(); ctx.globalAlpha = 1; };
  for (const b of BLOCKS.filter((b) => b.far)) box(b.x * scale, horizon - b.height * scale, b.width * scale, b.height * scale + 2, p.far);
  for (const b of BLOCKS.filter((b) => !b.far)) {
    const top = horizon - b.height * scale;
    box(b.x * scale, top, b.width * scale, b.height * scale + 2, p.near);
    for (const [lx, ly] of b.lit) box((b.x + lx) * scale, top + ly * scale, 6 * scale, 8 * scale, "#FFD166", p.windows);
  }
  // Keleti's arched front, with its glass lit behind the tram.
  const cx = w / 2, half = 75 * scale, spring = horizon - 60 * scale;
  ctx.fillStyle = p.ground; ctx.beginPath();
  ctx.moveTo(cx - half, horizon); ctx.lineTo(cx - half, spring); ctx.arc(cx, spring, half, Math.PI, 0); ctx.lineTo(cx + half, horizon); ctx.fill();
  for (let x = -56; x <= 56; x += 14) box(cx + x * scale - 1.5, spring - 34 * scale, 3, 34 * scale, "#4CC9F0", 0.8);
  ctx.fillStyle = p.ground; ctx.fillRect(0, horizon, w, h - horizon);

  // The 4-6 tram.
  const tw = w * 0.76, u = tw / 99, tx = (w - tw) / 2, ty = horizon - tw * 24 / 99 + 8;
  const px = (x, y, bw, bh, c) => { ctx.fillStyle = c; ctx.fillRect(tx + x * u, ty + y * u, bw * u, bh * u); };
  px(0, 0, 99, 21, "#F8B800"); px(0, 0, 99, 2, "#F8F8F8"); px(0, 14, 99, 7, "#C87800");
  for (let x = 4; x < 96; x += 12) px(x, 4, 9, 8, p.windows > 0.5 ? "#FFE08A" : "#18285F");
  px(38, 4, 5, 15, "#785000"); px(70, 4, 5, 15, "#785000");
  for (const x of [10, 30, 62, 86]) px(x, 21, 6, 3, "#0D0B1E");
}

function showStart() {
  $("phase").textContent = `${phase.icon}  ${phase.title.toUpperCase()}`;
  const lore = content.spots.filter((s) => s.c === "lore").length;
  $("tally").textContent = `${content.spots.length - lore} spots. ${lore} legends. 1 car eaten by a street.`;
  drawSky();
}
$("go").onclick = () => { $("start").hidden = true; $("app").hidden = false; map.invalidateSize(); home(false); };

/* ---------- Map ---------- */

const map = L.map("map", { zoomControl: false, attributionControl: true }).setView(DISTRICT, 15);
L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
  maxZoom: 19, attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
}).addTo(map);
map.attributionControl.setPrefix(false).setPosition("bottomleft");
map.on("click", () => { if (selected) select(null); });
function home(animate = true) {
  map.fitBounds(DISTRICT_BOUNDS, { paddingTopLeft: [8, 118], paddingBottomRight: [8, 8], animate });
}

/** A venue's own art is the reward for finding it, so it only replaces the category pin once found. */
function face(spot, size, showFound = true) {
  const cat = CAT[spot.c] || CAT.local, isFound = showFound && found.has(spot.id);
  if (isFound && spot.icon && ART[spot.icon]) {
    return `<div class="face" style="width:${size}px;height:${size}px;background-image:url(${ART[spot.icon]});border:2.5px solid ${cat.hex};outline:1.5px solid var(--bg)"><span class="tick">✓</span></div>`;
  }
  return `<div class="pin" style="width:${size}px;height:${size}px;font-size:${Math.round(size / 2.2)}px;background:${cat.hex};border:1.5px solid var(--bg);color:${spot.c === "lore" ? "#fff" : "var(--ink)"}">${isFound ? "✓" : cat.sym}</div>`;
}

function pinIcon(spot) {
  const big = selected?.id === spot.id, art = found.has(spot.id) && spot.icon;
  const size = art ? (big ? 44 : 34) : (big ? 36 : 25);
  return L.divIcon({ className: "", iconSize: [48, 48], iconAnchor: [24, 24],
    html: `<div style="width:48px;height:48px;display:flex;align-items:center;justify-content:center">${face(spot, size)}</div>` });
}

function drawPins() {
  for (const spot of content.spots) {
    const show = !filter || spot.c === filter;
    if (show && !markers[spot.id]) {
      markers[spot.id] = L.marker([spot.lat, spot.lon], { icon: pinIcon(spot), title: spot.n, keyboard: true })
        .addTo(map).on("click", () => select(spot));
    } else if (!show && markers[spot.id]) {
      map.removeLayer(markers[spot.id]); delete markers[spot.id];
    }
    markers[spot.id]?.setIcon(pinIcon(spot)).setZIndexOffset(selected?.id === spot.id ? 1000 : 0);
  }
}

function drawHeader() {
  $("count").textContent = `${found.size}/${content.spots.length} found`;
  const chip = (id, title, hex) =>
    `<button class="chip${filter === id ? " on" : ""}" data-c="${id ?? ""}"><span class="dot" style="background:${hex}"></span>${title}</button>`;
  $("chips").innerHTML = chip(null, "All", "var(--fill)") + CATS.map(([id, title, hex]) => chip(id, title, hex)).join("");
  for (const b of $("chips").children) {
    b.onclick = () => { filter = b.dataset.c || null; selected = null; home(); redraw(); };
  }
}

function redraw() { drawPins(); drawHeader(); drawCard(); }

function select(spot) {
  if (spot && filter && filter !== spot.c) filter = null;
  selected = spot;
  if (spot) {
    // Keep the pin in the upper part of the map, clear of the card.
    const zoom = 17, center = map.unproject(map.project([spot.lat, spot.lon], zoom).add([0, 140]), zoom);
    map.flyTo(center, zoom, { duration: 0.6 });
  }
  redraw();
}

/* ---------- Spot card (SpotCard in Swift) ---------- */

function drawCard() {
  const card = $("card");
  $("listbtn").hidden = !!(selected || trip);
  if (!selected && !trip) { card.hidden = true; return; }
  card.hidden = false;
  if (!selected) return drawTrip(card);

  const s = selected, isFound = found.has(s.id), page = pages[s.discover];
  card.className = "card" + (s.c === "lore" ? " lore" : "");
  card.innerHTML = `
    <div class="top">${face(s, 34)}
      <div><div class="tag">${s.when ? "LORE / " + esc(s.when) : TAG[s.c] || ""}</div><div class="name">${esc(s.n)}</div></div>
      <button class="x" id="cclose" aria-label="Close">✕</button></div>
    <div class="addr">${esc(s.a)}</div>
    <div class="desc">${esc(s.d)}</div>
    ${s.src ? `<div class="src">Source: ${esc(s.src)}</div>` : ""}
    ${s.old ? '<div class="src" style="color:var(--accent)">Older intel. Confirm before going.</div>' : ""}
    <div class="btns">
      <button class="btn primary${isFound ? " done" : ""}" id="cfound">${isFound ? "Found it" : "Mark as found"}</button>
      <button class="btn outline" id="cwalk">🚶 Directions</button>
    </div>
    <div class="btns">
      ${page ? `<button class="btn brand" id="cdisc" style="--brand-bg:${esc(page.colors.brick)};--brand-ink:${esc(page.colors.text || page.colors.paper)}">✨ Discover</button>` : ""}
      <button class="btn raised" id="cevts">📅 Events</button>
    </div>`;
  $("cclose").onclick = () => select(null);
  $("cfound").onclick = () => {
    isFound ? found.delete(s.id) : found.add(s.id);
    store.set("found", [...found]);
    redraw();
  };
  $("cwalk").onclick = () => walk(s);
  if ($("cdisc")) $("cdisc").onclick = () => showDiscover(s);
  $("cevts").onclick = () => openEvents(s);
}

$("listbtn").onclick = () => {
  const spots = content.spots.filter((s) => !filter || s.c === filter);
  const body = openSheet(`<div class="sheet-top"><b>${filter ? CAT[filter].title : "All spots"}</b><button class="sdone" id="ldone">Done</button></div>
    <div class="sheet-scroll"><div class="list">${spots.map((s) =>
      `<button class="li" data-id="${s.id}">${face(s, 30, false)}<span><b>${esc(s.n)}</b><small>${esc(s.a)}</small></span></button>`).join("")}</div></div>`);
  body.querySelector("#ldone").onclick = closeSheet;
  body.querySelectorAll(".li").forEach((r) => { r.onclick = () => { closeSheet(); select(content.spots.find((s) => s.id === r.dataset.id)); }; });
};

/* ---------- Walking directions, drawn on our own map ---------- */

function drawTrip(card) {
  card.className = "card";
  card.innerHTML = `
    <div class="top"><div class="walker">🚶</div>
      <div><div class="tag">TO ${esc(trip.spot.n.toUpperCase())}</div><div class="name" style="font-size:17px">${esc(trip.text)}</div></div>
      ${trip.loading ? '<div class="spin" aria-label="Loading"></div>' : ""}</div>
    ${trip.from ? `<div class="src">${esc(trip.from)}</div>` : ""}
    <div class="btns"><button class="btn outline" id="tend">End</button><button class="btn primary" id="tmaps">Open in Maps ↗</button></div>`;
  $("tend").onclick = () => {
    trip = null;
    if (routeLine) map.removeLayer(routeLine);
    if (me) map.removeLayer(me);
    routeLine = me = null;
    drawCard();
  };
  $("tmaps").onclick = () => openOutside(`https://www.google.com/maps/dir/?api=1&travelmode=walking&destination=${trip.spot.lat},${trip.spot.lon}`);
}

function whereAmI() {
  return new Promise((resolve) => {
    if (!navigator.geolocation) return resolve(null);
    const timer = setTimeout(() => resolve(null), 5000);
    navigator.geolocation.getCurrentPosition(
      (p) => { clearTimeout(timer); resolve([p.coords.latitude, p.coords.longitude]); },
      () => { clearTimeout(timer); resolve(null); }, { timeout: 5000, maximumAge: 60000 });
  });
}

async function walk(spot, start) {
  selected = null;
  trip = { spot, text: "Finding a walking route…", loading: true };
  redraw();
  let from = start, label = "From the blue dot. Drag it to move your start.";
  if (!from) {
    const here = await whereAmI();
    if (here && map.distance(here, DISTRICT) < 15000) {
      from = here; label = "From your location. Drag the blue dot to change it.";
    } else {
      from = store.get("start", BLAHA);
      label = "No location in Budapest from this computer, so this starts at the blue dot. Drag it to where you are.";
    }
  }
  if (trip?.spot.id !== spot.id) return;
  if (!me) {
    me = L.marker(from, { draggable: true, title: "Your start",
      icon: L.divIcon({ className: "", iconSize: [24, 24], iconAnchor: [12, 12], html: '<div class="me"></div>' }) }).addTo(map);
    me.on("dragend", () => { const at = me.getLatLng(); store.set("start", [at.lat, at.lng]); if (trip) walk(trip.spot, [at.lat, at.lng]); });
  } else {
    me.setLatLng(from);
  }
  try {
    const route = (await fetch(`${ROUTER}/${from[1]},${from[0]};${spot.lon},${spot.lat}?overview=full&geometries=geojson`).then((r) => r.json())).routes[0];
    if (trip?.spot.id !== spot.id) return;
    if (routeLine) map.removeLayer(routeLine);
    routeLine = L.polyline(route.geometry.coordinates.map(([lon, lat]) => [lat, lon]),
      { color: phase.accent, weight: 7, dashArray: "0 13", lineCap: "round" }).addTo(map);
    map.fitBounds(routeLine.getBounds(), { paddingTopLeft: [40, 150], paddingBottomRight: [40, 220] });
    const minutes = Math.max(1, Math.round(route.duration / 60));
    const distance = route.distance >= 1000 ? (route.distance / 1000).toFixed(1) + " km" : Math.round(route.distance) + " m";
    trip = { spot, text: `${minutes} min walk · ${distance}`, from: label };
  } catch {
    trip = { spot, text: "No walking route right now", from: "Check your connection, or open the route in Maps." };
  }
  drawCard();
}

/* ---------- Discover (DiscoverScreen in Swift) ---------- */

function showDiscover(spot) {
  const page = pages[spot.discover], c = page.colors, cat = CAT[spot.c] || CAT.local, st = page.style || {};
  const fonts = { rounded: 'ui-rounded, "SF Pro Rounded", "Nunito", system-ui, sans-serif', mono: 'ui-monospace, "SF Mono", Menlo, monospace',
    default: '-apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif' };
  const ink = (a) => `color-mix(in srgb, ${c.text || c.paper} ${a}%, transparent)`;
  const patterns = {
    dots: `radial-gradient(${ink(7)} 1.6px, transparent 1.8px) 0 0/18px 18px`,
    stripes: `repeating-linear-gradient(45deg, ${ink(7)} 0 1.2px, transparent 1.2px 11px)`,
    grid: `linear-gradient(${ink(7)} 1.2px, transparent 1.2px) 0 0/22px 22px, linear-gradient(90deg, ${ink(7)} 1.2px, transparent 1.2px) 0 0/22px 22px`,
    rays: `repeating-conic-gradient(from 0deg at 50% 120px, ${ink(7)} 0 .4deg, transparent .4deg 7.5deg)`,
    waves: `radial-gradient(circle at 50% 0, transparent 9px, ${ink(7)} 9.5px 10.7px, transparent 11px) 0 0/44px 34px`,
    diamonds: `linear-gradient(45deg, transparent 46%, ${ink(7)} 46% 54%, transparent 54%) 0 0/28px 28px, linear-gradient(-45deg, transparent 46%, ${ink(7)} 46% 54%, transparent 54%) 0 0/28px 28px`,
  };
  const vars = [`--d-paper:${c.paper}`, `--d-brick:${c.brick}`, `--d-deep:${c.deep}`, `--d-gold:${c.gold}`,
    c.text && `--d-text:${c.text}`, c.mark && `--d-mark:${c.mark}`, fonts[st.font] && `--d-font:${fonts[st.font]}`,
    st.corner != null && `--d-r:${st.corner}px`, st.tilt != null && `--d-tilt:${st.tilt}deg`,
    patterns[st.pattern] && `--d-pattern:${patterns[st.pattern]}`, st.logoBg && `--d-logo-bg:${st.logoBg}`].filter(Boolean).join(";");
  const classes = [st.caps && "caps", st.frame === false && "flat", ({ hard: "hard", soft: "soft", none: "noshadow" })[st.shadow || "hard"]].filter(Boolean).join(" ");
  const orn = esc(st.ornament || "✶");
  const logo = https(st.logo || "") ? `<div class="logo ${st.logoShape === "wide" ? "wide" : st.logoShape === "square" ? "square" : ""}"><img src="${esc(st.logo)}" alt="${esc(spot.n)} logo"></div>` : "";
  const numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"];
  const line = (l) => `<div class="hu">${esc(l.text)}</div>${l.english ? `<div class="en">${esc(l.english)}</div>` : ""}`;
  const art = (i) => (page.art || []).filter((a) => a.afterLine === i).map((a) => {
    const img = ART[a.image];
    return `<div class="art${a.leading ? "" : " right"}"><i aria-hidden="true" style="width:${a.image === "so" ? 115 : 137}px;transform:rotate(${a.tilt}deg);-webkit-mask-image:url(${img});mask-image:url(${img})"></i></div>`;
  }).join("");
  const links = (page.links || []).filter((l) => https(l.url));
  const body = openSheet(`<div class="sheet-scroll disc ${classes}" style="${esc(vars)}">
    <button class="close" id="dclose" aria-label="Close">✕</button>
    ${page.hero && heroImage(page.hero) ? `<img class="hero" src="${heroImage(page.hero)}" alt="${esc(spot.n)}">`
      : `${logo}<div class="badge" aria-hidden="true"${logo ? " hidden" : ""}><i style="color:${esc(c.deep)}">${cat.sym}</i></div>`}
    <div class="body">
      <div class="head">
        <div class="place">${esc(page.place)}</div>
        <h1>${esc(page.title)}</h1>
        <div class="subtitle">${esc(page.subtitle)}</div>
        ${page.note ? `<div class="note"><div class="e">e</div><div>${esc(page.note)}</div></div>` : ""}
      </div>
      <div class="paper big">${line(page.intro)}</div>
      ${page.listTitle ? `<div class="label">${esc(page.listTitle.toUpperCase())}</div>` : ""}
      ${page.lines.map((l, i) => `<div class="paper"><div class="rule">${page.numbered
        ? `<div class="num" aria-label="Rule ${i + 1}">${numerals[i]}</div>` : st.ornament ? `<div class="orn" aria-hidden="true">${orn}</div>` : '<div class="bullet"></div>'}<div>${line(l)}</div></div></div>${art(i)}`).join("")}
      ${page.closing ? `<div class="closing"><div style="opacity:.6;font-size:22px">${orn}</div><div class="hu">${esc(page.closing.text)}</div>
        ${page.closing.english ? `<div class="en">${esc(page.closing.english)}</div>` : ""}
        ${page.closing.note ? `<div class="tiny">${esc(page.closing.note)}</div>` : ""}</div>` : ""}
      <div>
        <div class="btns"><button class="btn d-paper" id="dwalk">🚶 Directions</button>
          <button class="btn d-deep" id="devts">📅 Events</button></div>
        ${links.map((l, i) => `<div class="btns"><button class="btn d-gold" data-link="${i}">↗ ${esc(l.title)}</button></div>`).join("")}
      </div>
      ${page.sources ? `<div class="sources">Sources: ${esc(page.sources)}</div>` : ""}
    </div></div>`);
  body.querySelector("#dclose").onclick = closeSheet;
  // No logo yet (not mirrored, or offline): show the category sign instead.
  body.querySelector(".logo img")?.addEventListener("error", () => { body.querySelector(".logo").remove(); body.querySelector(".badge").hidden = false; });
  body.querySelector("#dwalk").onclick = () => { closeSheet(); walk(spot); };
  body.querySelector("#devts").addEventListener("click", () => openEvents(spot));
  body.querySelectorAll("[data-link]").forEach((b) => { const l = links[b.dataset.link]; b.onclick = () => openWeb(l.title, l.url); });
}

/* ---------- Tabs ---------- */

for (const b of $("tabbar").children) {
  b.onclick = () => {
    for (const other of $("tabbar").children) other.classList.toggle("on", other === b);
    for (const id of ["map", "events", "news", "radio"]) $(`screen-${id}`).hidden = id !== b.dataset.tab;
    if (b.dataset.tab === "map") map.invalidateSize();
  };
}
function showOnMap(id) {
  $("tabbar").children[0].click();
  select(content.spots.find((s) => s.id === id));
}

/** The live feed, or the copy saved with the app if the network doesn't answer. */
async function feed(name) {
  try {
    const data = await fetch(`${FEEDS}/${name}.json`, { cache: "no-store" }).then((r) => r.json());
    if (data.version === 1) return { ...data, live: true };
  } catch { /* fall back to the saved copy */ }
  try { return { ...(await fetch(`data/${name}.json`).then((r) => r.json())), live: false }; } catch { return { items: [], live: false }; }
}

const fmtWhen = (iso) => {
  const d = new Date(iso);
  return isNaN(d) ? String(iso).slice(0, 10) : d.toLocaleString("en-GB",
    { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", timeZone: "Europe/Budapest" });
};

function title(text, sub, refreshId) {
  return `<div class="title"><div><h2>${esc(text)}</h2>${sub ? `<p>${esc(sub)}</p>` : ""}</div>
    ${refreshId ? `<button class="refresh" id="${refreshId}" aria-label="Refresh">↻</button>` : ""}</div>`;
}

async function drawEvents() {
  const live = await feed("events");
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const upcoming = live.items.filter((e) => new Date(e.start) >= today);
  const card = (id, pill, pillColor, name, place, detail, spot, link) => {
    const isIn = going.has(id);
    return `<div class="item"><span class="pill" style="background:${esc(pillColor)}">${esc(pill)}</span>
      <h3>${esc(name)}</h3><div class="place2">${esc(place)}</div>${detail ? `<div class="detail">${esc(detail)}</div>` : ""}
      <div class="btns"><button class="btn primary${isIn ? " done" : ""}" data-going="${esc(id)}">${isIn ? "You're in" : "I'm in"}</button>
      ${https(link) ? `<button class="btn outline" data-open="${esc(link)}" data-title="${esc(name)}">Details</button>` : ""}
      ${content.spots.some((s) => s.id === spot) ? `<button class="btn outline" data-spot="${esc(spot)}">On map</button>` : ""}</div></div>`;
  };
  $("screen-events").innerHTML = title("Quest board", live.live ? "Real dates from around the district." : "Offline. Showing saved events.", "erefresh")
    + (upcoming.length ? "" : `<div class="item fine" style="font-size:15px">No dated events right now. New ones land here as soon as they're posted.</div>`)
    + upcoming.map((e) => card(e.id, fmtWhen(e.start), "var(--fill)", e.title, e.venue, e.note, e.spot, e.link)).join("")
    + `<div class="subhead">Regulars</div>`
    + content.events.map((e) => card(e.id, e.when, e.color, e.title, e.place, e.d, e.spot, null)).join("");
  const root = $("screen-events");
  $("erefresh").onclick = drawEvents;
  root.querySelectorAll("[data-going]").forEach((b) => { b.onclick = () => {
    const id = b.dataset.going; going.has(id) ? going.delete(id) : going.add(id); store.set("going", [...going]); drawEvents(); }; });
  root.querySelectorAll("[data-open]").forEach((b) => { b.onclick = () => openWeb(b.dataset.title, b.dataset.open); });
  root.querySelectorAll("[data-spot]").forEach((b) => { b.onclick = () => showOnMap(b.dataset.spot); });
}

/** A spot's programme page if it has one, else its dates from the feeds (SpotEventsSheet in Swift). */
async function openEvents(spot) {
  if (https(spot.events)) return openWeb(`${spot.n} · Events`, spot.events);
  const live = await feed("events");
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const dated = live.items.filter((e) => e.spot === spot.id && new Date(e.start) >= today);
  const regulars = content.events.filter((e) => e.spot === spot.id);
  const site = (pages[spot.discover]?.links || []).find((l) => https(l.url));
  const row = (pill, colour, name, detail, link) => `<div class="item"><span class="pill" style="background:${esc(colour)}">${esc(pill)}</span>
    <h3>${esc(name)}</h3>${detail ? `<div class="detail">${esc(detail)}</div>` : ""}
    ${https(link) ? `<div class="btns"><button class="btn outline" data-open="${esc(link)}" data-title="${esc(name)}">Details</button></div>` : ""}</div>`;
  const body = openSheet(`<div class="sheet-scroll" style="padding:16px">
    <button class="close" id="eclose" aria-label="Close" style="float:right">✕</button>
    <div class="label" style="color:var(--accent);font-weight:800;letter-spacing:1.5px;font-size:12px">EVENTS</div>
    <h2 style="margin:4px 0">${esc(spot.n)}</h2><div class="fine" style="margin-bottom:14px">${esc(spot.a)}</div>
    ${dated.map((e) => row(fmtWhen(e.start), "var(--fill)", e.title, e.note, e.link)).join("")}
    ${regulars.map((e) => row(e.when, e.color, e.title, e.d, null)).join("")}
    ${dated.length || regulars.length ? "" : `<div class="item"><h3>No dates listed here yet.</h3>
      <div class="detail">New ones land on the Quest board as soon as they're posted.</div>
      ${site ? `<div class="btns"><button class="btn outline" data-open="${esc(site.url)}" data-title="${esc(site.title)}">Check ${esc(site.title)}</button></div>` : ""}</div>`}
  </div>`);
  body.querySelector("#eclose").onclick = closeSheet;
  body.querySelectorAll("[data-open]").forEach((b) => { b.onclick = () => openWeb(b.dataset.title, b.dataset.open); });
}

async function drawNews() {
  const news = await feed("news");
  let status = news.live ? "Local news from the district." : "Offline. Showing saved stories.";
  if (news.live && news.updated) {
    const mins = Math.round((Date.now() - new Date(news.updated)) / 60000);
    status = `Updated ${mins < 60 ? mins + " min" : mins < 1440 ? Math.round(mins / 60) + " hr" : Math.round(mins / 1440) + " days"} ago`;
  }
  $("screen-news").innerHTML = title("The Nyócker Times", status, "nrefresh")
    + news.items.filter((s) => https(s.url)).map((s) => `<button class="story" data-url="${esc(s.url)}">
      <div class="meta"><span>${esc(s.source)}</span><span>${esc(new Date(s.date).toLocaleDateString("en-GB", { day: "numeric", month: "short" }))}</span></div>
      <b>${esc(s.title)}</b></button>`).join("");
  $("nrefresh").onclick = drawNews;
  // Most news sites refuse to be shown inside other apps, so stories open in the browser.
  $("screen-news").querySelectorAll("[data-url]").forEach((b) => { b.onclick = () => openOutside(b.dataset.url); });
}

let track = 0;
function drawRadio() {
  const radio = content.radio, now = radio[track];
  $("screen-radio").innerHTML = `<div class="title"><div><h2>Rádió Nyócker</h2></div><span class="fine" style="font-weight:700;margin-top:12px">8.8 FM</span></div>
    <div class="radio-card">
      <div class="now"><div class="vinyl" style="--label:${esc(now.color)}"></div>
        <div><div class="pick">Pick ${track + 1} of ${radio.length}</div><div class="name">${esc(now.artist)}</div><div class="fine">${esc(now.release)}</div></div></div>
      <div class="fine">${esc(now.meta)}</div>
      <button class="btn primary" id="listen">▶ Listen</button>
      <div class="btns" style="margin:0"><button class="btn outline" id="prev">Previous</button><button class="btn outline" id="next">Next</button></div>
      <div class="fine">Plays on the artist's own Bandcamp page, so streams and sales stay with them.</div>
    </div>
    <div class="subhead" style="font-size:17px;margin-top:4px">Playlist</div>
    ${radio.map((r, i) => `<button class="track${i === track ? " on" : ""}" data-i="${i}"><b style="font-size:15px">${String(i + 1).padStart(2, "0")}</b>
      <span><b>${esc(r.artist)}</b><small>${esc(r.release)}</small></span></button>`).join("")}`;
  const step = (by) => { track = (track + by + radio.length) % radio.length; drawRadio(); };
  $("prev").onclick = () => step(-1);
  $("next").onclick = () => step(1);
  $("listen").onclick = () => openWeb(`${now.artist} · ${now.release}`,
    `https://bandcamp.com/EmbeddedPlayer/${now.player}/size=large/bgcol=ffffff/linkcol=0687f5/tracklist=true/transparent=true/`);
  $("screen-radio").querySelectorAll("[data-i]").forEach((b) => { b.onclick = () => { track = +b.dataset.i; drawRadio(); }; });
}

document.addEventListener("keydown", (e) => {
  if (e.key !== "Escape") return;
  if (!$("sheet").hidden) closeSheet(); else if (selected) select(null);
});

/* ---------- Start ---------- */

(async () => {
  [content, pages] = await Promise.all([fetch("data/content.json").then((r) => r.json()), fetch("data/discover.json").then((r) => r.json())]);
  applyTheme();
  showStart();
  redraw();
  drawRadio();
  drawEvents();
  drawNews();
  // Follow the clock, so a phase change lands even if the app stays open.
  setInterval(() => {
    const next = currentPhase();
    if (next !== phase) { phase = next; applyTheme(); if (!$("start").hidden) showStart(); }
  }, 30000);
})();
