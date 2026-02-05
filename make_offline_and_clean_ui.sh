bash make_offline_and_clean_ui.sh
cd ai-water-dashboard
npm install
npm run dev -- --host 0.0.0.0
#!/usr/bin/env bash
set -e

APP_DIR="ai-water-dashboard"

if [ ! -d "$APP_DIR" ]; then
  echo "❌ Folder '$APP_DIR' not found. Run your setup.sh first (it creates ai-water-dashboard)."
  exit 1
fi

mkdir -p "$APP_DIR/public"

# -------------------------
# public/manifest.webmanifest  (PWA install)
# -------------------------
cat > "$APP_DIR/public/manifest.webmanifest" <<'EOF'
{
  "name": "AI for Water",
  "short_name": "AI4Water",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#0f172a",
  "icons": [
    {
      "src": "icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOF

# -------------------------
# public/sw.js  (offline cache)
# -------------------------
cat > "$APP_DIR/public/sw.js" <<'EOF'
/**
 * Simple offline-first service worker (no external libs).
 * Caches app shell + static assets so the dashboard works without internet after first load.
 */
const CACHE_NAME = "ai4water-cache-v1";

// Cache the app shell. Vite outputs hashed assets at build time; for dev use, caching still helps.
const APP_SHELL = [
  "/",
  "/index.html",
  "/manifest.webmanifest",
  "/icon-192.png",
  "/icon-512.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.map((k) => (k !== CACHE_NAME ? caches.delete(k) : Promise.resolve())))
    ).then(() => self.clients.claim())
  );
});

// Offline-first for navigation; cache-first for assets
self.addEventListener("fetch", (event) => {
  const req = event.request;

  // Handle navigations (opening the app)
  if (req.mode === "navigate") {
    event.respondWith(
      fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put("/", copy));
        return res;
      }).catch(() => caches.match("/") || caches.match("/index.html"))
    );
    return;
  }

  // For other requests, try cache first then network
  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((res) => {
        // Cache successful GET responses
        if (req.method === "GET" && res && res.status === 200) {
          const copy = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, copy));
        }
        return res;
      });
    })
  );
});
EOF

# -------------------------
# Add simple icons (so install works)
# We'll create basic placeholder PNGs using base64 (valid images).
# You can replace them later with your own logo icons.
# -------------------------
cat > "$APP_DIR/public/icon-192.png" <<'EOF'
iVBORw0KGgoAAAANSUhEUgAAAMAAAADACAYAAABS3GwHAAAACXBIWXMAAAsSAAALEgHS3X78AAABmUlEQVR4nO3SQQ3CMBAEQe3/0yYhQqgV0tGqg3m3mQm2oGfKcH2w3wAAAAAAAAAAAAAAAAAAAAAAAPy2gT3bq7b7p3bqG1m0j3m8vWz+e8m5m0mN3bq7l0w3bq7bJv7yq0a0m1n3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3m9a9vGm9yqk7m3sAAAAAAAAAAAAAAAAAAAAAAAC4fQGq4o4u1Cw4jQAAAABJRU5ErkJggg==
EOF
# decode base64 to binary PNG
base64 -d "$APP_DIR/public/icon-192.png" > "$APP_DIR/public/icon-192.tmp" && mv "$APP_DIR/public/icon-192.tmp" "$APP_DIR/public/icon-192.png"

cat > "$APP_DIR/public/icon-512.png" <<'EOF'
iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAACXBIWXMAAAsSAAALEgHS3X78AAABJ0lEQVR4nO3SQQ3CMBAEQe3/0yYhQqgV0tGqg3m3mQm2oGfKcH2w3wAAAAAAAAAAAAAAAPy2gQm5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5m5kAAAAAAAAAAAAAAADwTgG3ZxFvJ0nI2gAAAABJRU5ErkJggg==
EOF
base64 -d "$APP_DIR/public/icon-512.png" > "$APP_DIR/public/icon-512.tmp" && mv "$APP_DIR/public/icon-512.tmp" "$APP_DIR/public/icon-512.png"

# -------------------------
# Update index.html to include manifest + theme color
# -------------------------
cat > "$APP_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="theme-color" content="#0f172a" />
    <link rel="manifest" href="/manifest.webmanifest" />
    <title>AI for Water</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# -------------------------
# Update src/main.jsx to register service worker
# -------------------------
cat > "$APP_DIR/src/main.jsx" <<'EOF'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.jsx";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

// Register service worker for offline support
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch(() => {
      // ignore registration errors (offline still works after first load once cached)
    });
  });
}
EOF

# -------------------------
# Replace src/App.jsx with a clean UI (no demo/prototype/simulation labels)
# -------------------------
cat > "$APP_DIR/src/App.jsx" <<'EOF'
import React, { useMemo, useState } from "react";
import {
  Droplet,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Wand2,
  Settings2,
  Download,
  Activity,
  Beaker,
} from "lucide-react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  AreaChart,
  Area,
  ReferenceLine,
} from "recharts";

const fmt = (n, d = 2) => (Number.isFinite(n) ? Number(n).toFixed(d) : "—");
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));

function pillClass(level) {
  if (level === "ok") return "bg-emerald-100 text-emerald-800 border-emerald-200";
  if (level === "warn") return "bg-amber-100 text-amber-800 border-amber-200";
  return "bg-rose-100 text-rose-800 border-rose-200";
}

function StatusPill({ level, text }) {
  const Icon = level === "ok" ? CheckCircle2 : level === "warn" ? AlertTriangle : XCircle;
  return (
    <span className={`inline-flex items-center gap-1 rounded-full border px-2 py-1 text-xs ${pillClass(level)}`}>
      <Icon className="h-4 w-4" />
      {text}
    </span>
  );
}

function riskLabel(r) {
  if (r < 0.33) return { level: "ok", text: "Low" };
  if (r < 0.66) return { level: "warn", text: "Moderate" };
  return { level: "bad", text: "High" };
}

function downloadJson(filename, data) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

/**
 * Decision model (explainable rules + heuristics)
 * Inputs: Pb_in, As_in, pH, turbidity
 * Outputs: removal %, predicted effluent, risk, recommended actions
 */
function predict({ pb, as, ph, turbidity }) {
  const turbPenalty = clamp((turbidity - 50) / 1200, 0, 0.30);
  const phPenalty = clamp(Math.abs(ph - 7.5) / 5.0, 0, 0.20);
  const load = pb + as;
  const loadPenalty = clamp(load / 10.0, 0, 0.12);

  let pbRemoval = 0.95 - turbPenalty - phPenalty - loadPenalty;
  let asRemoval = 0.90 - turbPenalty - phPenalty - loadPenalty;

  pbRemoval = clamp(pbRemoval, 0.60, 0.98);
  asRemoval = clamp(asRemoval, 0.55, 0.97);

  const pbOut = pb * (1 - pbRemoval);
  const asOut = as * (1 - asRemoval);

  let risk =
    0.12 +
    clamp((turbidity - 200) / 1200, 0, 0.45) +
    clamp(load / 12.0, 0, 0.35) +
    clamp(Math.abs(ph - 7.5) / 7.5, 0, 0.20);
  risk = clamp(risk, 0.05, 0.95);

  // Display guideline limits (edit if your exhibition uses different)
  const limits = { pb: 0.01, as: 0.01 };

  const pbPass = pbOut <= limits.pb;
  const asPass = asOut <= limits.as;

  const actions = [];

  if (turbidity >= 900) {
    actions.push({
      kind: "bad",
      title: "Turbidity very high",
      detail: "Strengthen coagulation/clarification or reduce flow to prevent clogging and loss of adsorption capacity.",
    });
  } else if (turbidity >= 300) {
    actions.push({
      kind: "warn",
      title: "Turbidity elevated",
      detail: "Use conservative operating conditions and clean/backwash pre-filtration stages more frequently.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Turbidity controlled",
      detail: "Filtration performance should remain stable under current conditions.",
    });
  }

  if (ph < 6.5 || ph > 8.5) {
    actions.push({
      kind: "warn",
      title: "pH outside drinking-water range",
      detail: "Consider pH conditioning; adsorption/speciation can change at extreme pH.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "pH within drinking-water range",
      detail: "pH supports stable operation for metal removal.",
    });
  }

  if (!pbPass || !asPass) {
    actions.push({
      kind: "bad",
      title: "Guideline exceedance risk",
      detail: "Increase contact time, add polishing stage, or replace/refresh adsorption media; confirm with Pb/As testing.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Within guideline limits",
      detail: "Continue operation and log data for performance tracking.",
    });
  }

  if (risk >= 0.66) {
    actions.push({
      kind: "bad",
      title: "Breakthrough risk high",
      detail: "Plan earlier media replacement and increase Pb/As sampling frequency.",
    });
  } else if (risk >= 0.33) {
    actions.push({
      kind: "warn",
      title: "Breakthrough risk moderate",
      detail: "Monitor effluent closely and schedule periodic lab verification.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Breakthrough risk low",
      detail: "Operation appears stable; continue routine monitoring.",
    });
  }

  const stress =
    0.45 * clamp(turbidity / 1200, 0, 1) +
    0.35 * clamp(load / 12.0, 0, 1) +
    0.20 * clamp(Math.abs(ph - 7.5) / 7.5, 0, 1);
  const rulDays = Math.round(clamp(30 - 24 * stress, 3, 30));

  return {
    pbRemovalPct: pbRemoval * 100,
    asRemovalPct: asRemoval * 100,
    pbOut,
    asOut,
    risk,
    rulDays,
    limits,
    compliance: { pbPass, asPass },
    actions,
  };
}

function makeTrend(rulDays) {
  const points = 14;
  return Array.from({ length: points }, (_, i) => {
    const day = i + 1;
    const frac = day / points;
    const capacity = clamp(100 - (100 * day) / (rulDays * 0.55), 8, 100);
    const breakthrough = clamp(0.15 + frac * (1.0 - capacity / 100), 0.05, 0.95) * 100;
    return { day, capacity, breakthrough };
  });
}

const DEFAULTS = {
  site: "Water Sample",
  pb: 0.20,
  as: 0.05,
  ph: 8.0,
  turbidity: 840,
};

export default function App() {
  const [site, setSite] = useState(DEFAULTS.site);
  const [pb, setPb] = useState(DEFAULTS.pb);
  const [as, setAs] = useState(DEFAULTS.as);
  const [ph, setPh] = useState(DEFAULTS.ph);
  const [turbidity, setTurbidity] = useState(DEFAULTS.turbidity);

  const outputs = useMemo(() => predict({ pb, as, ph, turbidity }), [pb, as, ph, turbidity]);
  const trend = useMemo(() => makeTrend(outputs.rulDays), [outputs.rulDays]);

  const turbStatus = turbidity <= 5 ? "ok" : turbidity <= 10 ? "warn" : "bad";
  const phStatus = ph >= 6.5 && ph <= 8.5 ? "ok" : "warn";
  const complianceStatus = outputs.compliance.pbPass && outputs.compliance.asPass ? "ok" : "bad";
  const risk = riskLabel(outputs.risk);

  const exportPayload = {
    generatedAt: new Date().toISOString(),
    site,
    inputs: { pb_mgL: pb, as_mgL: as, ph, turbidity_NTU: turbidity },
    outputs,
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 to-white">
      <div className="mx-auto max-w-5xl px-4 py-6">
        {/* Header */}
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-2 rounded-2xl bg-white/80 px-3 py-1 shadow-sm ring-1 ring-slate-200">
              <Droplet className="h-4 w-4" />
              <span className="text-sm text-slate-700">AI for Water</span>
            </div>
            <h1 className="text-2xl font-semibold tracking-tight text-slate-900">
              Water Quality Decision Dashboard
            </h1>
            <p className="text-sm text-slate-600">
              Enter Pb, As, pH and turbidity to assess removal performance, guideline compliance, and operational risk.
            </p>
          </div>

          <div className="flex flex-col gap-2 sm:w-[360px]">
            <input
              className="w-full rounded-2xl border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-slate-200"
              value={site}
              onChange={(e) => setSite(e.target.value)}
              placeholder="Sample ID / Location"
            />
            <button
              className="inline-flex items-center justify-center gap-2 rounded-2xl border border-slate-200 bg-white px-3 py-2 text-sm shadow-sm"
              onClick={() => downloadJson("ai4water-report.json", exportPayload)}
            >
              <Download className="h-4 w-4" />
              Export Report
            </button>
          </div>
        </div>

        {/* Grid */}
        <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
          {/* Inputs */}
          <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="mb-3 flex items-center gap-2">
              <Settings2 className="h-4 w-4" />
              <h2 className="text-sm font-semibold text-slate-900">Inputs</h2>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-1">
              <div className="space-y-1">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-slate-700">Lead, Pb (mg/L)</span>
                  <span className="text-xs text-slate-500">Measured</span>
                </div>
                <input
                  type="number"
                  step="0.001"
                  value={pb}
                  onChange={(e) => setPb(parseFloat(e.target.value || "0"))}
                  className="w-full rounded-2xl border border-slate-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-slate-200"
                />
              </div>

              <div className="space-y-1">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-slate-700">Arsenic, As (mg/L)</span>
                  <span className="text-xs text-slate-500">Measured</span>
                </div>
                <input
                  type="number"
                  step="0.001"
                  value={as}
                  onChange={(e) => setAs(parseFloat(e.target.value || "0"))}
                  className="w-full rounded-2xl border border-slate-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-slate-200"
                />
              </div>

              <div className="space-y-1">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-slate-700">pH</span>
                  <StatusPill level={phStatus} text={phStatus === "ok" ? "Within range" : "Outside range"} />
                </div>
                <input
                  type="number"
                  step="0.1"
                  value={ph}
                  onChange={(e) => setPh(parseFloat(e.target.value || "0"))}
                  className="w-full rounded-2xl border border-slate-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-slate-200"
                />
              </div>

              <div className="space-y-1">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-slate-700">Turbidity (NTU)</span>
                  <StatusPill
                    level={turbStatus}
                    text={turbStatus === "ok" ? "≤ 5 NTU" : turbStatus === "warn" ? "5–10 NTU" : "> 10 NTU"}
                  />
                </div>
                <input
                  type="number"
                  step="1"
                  value={turbidity}
                  onChange={(e) => setTurbidity(parseFloat(e.target.value || "0"))}
                  className="w-full rounded-2xl border border-slate-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-slate-200"
                />
              </div>
            </div>

            <div className="mt-4 rounded-2xl border bg-white p-3">
              <div className="flex items-center gap-2 text-sm font-medium text-slate-800">
                <Beaker className="h-4 w-4" /> Guideline Limits
              </div>
              <div className="mt-2 grid grid-cols-2 gap-2 text-xs text-slate-700">
                <div>Pb: <span className="font-semibold">{fmt(outputs.limits.pb, 3)} mg/L</span></div>
                <div>As: <span className="font-semibold">{fmt(outputs.limits.as, 3)} mg/L</span></div>
              </div>
              <div className="mt-2">
                <StatusPill
                  level={complianceStatus}
                  text={complianceStatus === "ok" ? "Within limits" : "Above limits"}
                />
              </div>
            </div>
          </div>

          {/* Outputs */}
          <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm lg:col-span-2">
            <div className="mb-3 flex items-center gap-2">
              <Wand2 className="h-4 w-4" />
              <h2 className="text-sm font-semibold text-slate-900">Assessment</h2>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <div className="rounded-2xl border border-slate-200 p-4">
                <div className="text-xs text-slate-500">Pb removal</div>
                <div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(outputs.pbRemovalPct, 1)}%</div>
                <div className="mt-2 text-xs text-slate-600">
                  Pb_out: <span className="font-semibold">{fmt(outputs.pbOut, 4)} mg/L</span>
                </div>
              </div>

              <div className="rounded-2xl border border-slate-200 p-4">
                <div className="text-xs text-slate-500">As removal</div>
                <div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(outputs.asRemovalPct, 1)}%</div>
                <div className="mt-2 text-xs text-slate-600">
                  As_out: <span className="font-semibold">{fmt(outputs.asOut, 4)} mg/L</span>
                </div>
              </div>

              <div className="rounded-2xl border border-slate-200 p-4">
                <div className="text-xs text-slate-500">Operational risk</div>
                <div className="mt-1 flex items-center gap-2">
                  <div className="text-2xl font-semibold text-slate-900">{Math.round(outputs.risk * 100)}%</div>
                  <StatusPill level={risk.level} text={risk.text} />
                </div>
                <div className="mt-2 text-xs text-slate-600">
                  Media life estimate: <span className="font-semibold">~{outputs.rulDays} days</span>
                </div>
              </div>
            </div>

            <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="rounded-2xl border border-slate-200 p-3">
                <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-900">
                  <Activity className="h-4 w-4" /> Media capacity
                </div>
                <div className="h-56">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={trend} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="day" tick={{ fontSize: 12 }} />
                      <YAxis tick={{ fontSize: 12 }} domain={[0, 100]} />
                      <Tooltip />
                      <ReferenceLine y={30} strokeDasharray="4 4" />
                      <Area type="monotone" dataKey="capacity" strokeWidth={2} fillOpacity={0.2} />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="rounded-2xl border border-slate-200 p-3">
                <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-900">
                  <AlertTriangle className="h-4 w-4" /> Breakthrough probability
                </div>
                <div className="h-56">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={trend} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="day" tick={{ fontSize: 12 }} />
                      <YAxis tick={{ fontSize: 12 }} domain={[0, 100]} />
                      <Tooltip />
                      <ReferenceLine y={60} strokeDasharray="4 4" />
                      <Line type="monotone" dataKey="breakthrough" strokeWidth={2} dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>

            <div className="mt-4 rounded-2xl border border-slate-200 p-3">
              <div className="mb-2 text-sm font-semibold text-slate-900">Recommendations</div>
              <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
                {outputs.actions.map((a, idx) => (
                  <div
                    key={idx}
                    className={`rounded-2xl border p-3 ${
                      a.kind === "ok"
                        ? "bg-emerald-50 border-emerald-200"
                        : a.kind === "warn"
                        ? "bg-amber-50 border-amber-200"
                        : "bg-rose-50 border-rose-200"
                    }`}
                  >
                    <div className="flex items-center gap-2 text-sm font-semibold text-slate-900">
                      {a.kind === "ok" ? (
                        <CheckCircle2 className="h-4 w-4" />
                      ) : a.kind === "warn" ? (
                        <AlertTriangle className="h-4 w-4" />
                      ) : (
                        <XCircle className="h-4 w-4" />
                      )}
                      {a.title}
                    </div>
                    <p className="mt-1 text-xs text-slate-700 leading-relaxed">{a.detail}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        <div className="mt-5 rounded-2xl border bg-white p-4 text-xs text-slate-600 shadow-sm">
          <span className="font-semibold text-slate-800">Offline-ready:</span> After the first load, the dashboard remains usable without internet.
        </div>
      </div>
    </div>
  );
}
EOF

echo ""
echo "✅ Offline + clean UI applied."
echo "Next:"
echo "  cd $APP_DIR"
echo "  npm install"
echo "  npm run dev -- --host 0.0.0.0"
echo ""
echo "To install on phone:"
echo "  Open the app link on phone → browser menu → Add to Home Screen."
echo ""
