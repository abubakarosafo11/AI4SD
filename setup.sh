#!/usr/bin/env bash
set -e

APP_DIR="ai-water-dashboard"

mkdir -p "$APP_DIR/src"

# -------------------------
# package.json
# -------------------------
cat > "$APP_DIR/package.json" <<'EOF'
{
  "name": "ai-water-dashboard",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "lucide-react": "^0.542.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "recharts": "^2.12.7"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.13",
    "vite": "^5.4.10"
  }
}
EOF

# -------------------------
# vite.config.js
# -------------------------
cat > "$APP_DIR/vite.config.js" <<'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
});
EOF

# -------------------------
# index.html
# -------------------------
cat > "$APP_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AI for Water – Pb/As Filtration Dashboard</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# -------------------------
# postcss.config.js
# -------------------------
cat > "$APP_DIR/postcss.config.js" <<'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
EOF

# -------------------------
# tailwind.config.js
# -------------------------
cat > "$APP_DIR/tailwind.config.js" <<'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {},
  },
  plugins: [],
};
EOF

# -------------------------
# src/styles.css
# -------------------------
cat > "$APP_DIR/src/styles.css" <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  -webkit-tap-highlight-color: transparent;
}
EOF

# -------------------------
# src/main.jsx
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
EOF

# -------------------------
# src/App.jsx  (Pb, As, pH, Turbidity)
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
 * Exhibition-grade explainable “AI” model (prototype decision support):
 * Inputs: Pb_in, As_in, pH, turbidity
 * Outputs: predicted removal %, predicted effluent, risk, recommendations
 *
 * NOTE: This is a simulation model (rules + simple heuristics).
 * It’s valid for demonstrations and can later be trained with real data.
 */
function predict({ pb, as, ph, turbidity }) {
  // Turbidity penalty: 0 to ~30% reduction
  const turbPenalty = clamp((turbidity - 50) / 1200, 0, 0.30);

  // pH penalty: distance from ~7.5 gives up to ~20% reduction
  const phPenalty = clamp(Math.abs(ph - 7.5) / 5.0, 0, 0.20);

  // Loading proxy: combined Pb+As (mg/L) gives up to ~12% reduction
  const load = pb + as;
  const loadPenalty = clamp(load / 10.0, 0, 0.12);

  // Base removals (prototype defaults)
  let pbRemoval = 0.95 - turbPenalty - phPenalty - loadPenalty;
  let asRemoval = 0.90 - turbPenalty - phPenalty - loadPenalty;

  pbRemoval = clamp(pbRemoval, 0.60, 0.98);
  asRemoval = clamp(asRemoval, 0.55, 0.97);

  const pbOut = pb * (1 - pbRemoval);
  const asOut = as * (1 - asRemoval);

  // Risk increases with turbidity, loading, extreme pH
  let risk =
    0.12 +
    clamp((turbidity - 200) / 1200, 0, 0.45) +
    clamp(load / 12.0, 0, 0.35) +
    clamp(Math.abs(ph - 7.5) / 7.5, 0, 0.20);
  risk = clamp(risk, 0.05, 0.95);

  // Display limits (defaults; adjust if you want)
  const limits = {
    pb: 0.01, // mg/L
    as: 0.01, // mg/L
  };

  const pbPass = pbOut <= limits.pb;
  const asPass = asOut <= limits.as;

  const actions = [];

  if (turbidity >= 900) {
    actions.push({
      kind: "bad",
      title: "Very high turbidity",
      detail: "Strengthen coagulation–clarification or reduce flow to prevent clogging and loss of adsorption capacity.",
    });
  } else if (turbidity >= 300) {
    actions.push({
      kind: "warn",
      title: "Elevated turbidity",
      detail: "Use conservative operating conditions; clean/backwash pre-filtration stages more frequently.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Turbidity manageable",
      detail: "Filtration performance should remain stable under current conditions.",
    });
  }

  if (ph < 6.0 || ph > 9.0) {
    actions.push({
      kind: "warn",
      title: "pH outside preferred range",
      detail: "Consider pH conditioning; adsorption/speciation can change at extreme pH.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "pH acceptable",
      detail: "pH supports stable operation for many adsorption media.",
    });
  }

  if (!pbPass || !asPass) {
    actions.push({
      kind: "bad",
      title: "Predicted non-compliance",
      detail: "Increase contact time, add polishing stage, or replace/refresh adsorption media. Confirm with lab tests.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Predicted compliance",
      detail: "Continue operation and record data to improve the model.",
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
      detail: "Monitor effluent closely; schedule periodic lab verification.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Breakthrough risk low",
      detail: "Operation appears stable; keep logging inputs and outputs.",
    });
  }

  // RUL proxy (days)
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

// Default demo values (edit these to match your exhibition sample)
const DEFAULTS = {
  site: "Exhibition Demo",
  pb: 0.20,      // mg/L
  as: 0.05,      // mg/L
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

  const turbStatus = turbidity < 300 ? "ok" : turbidity < 900 ? "warn" : "bad";
  const phStatus = ph < 6.0 || ph > 9.0 ? "warn" : "ok";
  const complianceStatus = outputs.compliance.pbPass && outputs.compliance.asPass ? "ok" : "bad";
  const risk = riskLabel(outputs.risk);

  const exportPayload = {
    generatedAt: new Date().toISOString(),
    site,
    inputs: { pb_mgL: pb, as_mgL: as, ph, turbidity_NTU: turbidity },
    aiOutputs: outputs,
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 to-white">
      <div className="mx-auto max-w-5xl px-4 py-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-2 rounded-2xl bg-white/70 px-3 py-1 shadow-sm ring-1 ring-slate-200">
              <Droplet className="h-4 w-4" />
              <span className="text-sm text-slate-700">AI for Water</span>
              <span className="rounded-xl bg-slate-100 px-2 py-0.5 text-xs text-slate-700">
                Mobile Dashboard (Prototype)
              </span>
            </div>
            <h1 className="text-2xl font-semibold tracking-tight text-slate-900">
              Pb/As Smart Filtration Dashboard
            </h1>
            <p className="text-sm text-slate-600">
              Enter Pb, As, pH and turbidity → AI-predicted removal, effluent, risk and actions (simulation).
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
              onClick={() => downloadJson("ai-water-dashboard-export.json", exportPayload)}
            >
              <Download className="h-4 w-4" />
              Export (JSON)
            </button>
          </div>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-3">
          <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="mb-3 flex items-center gap-2">
              <Settings2 className="h-4 w-4" />
              <h2 className="text-sm font-semibold text-slate-900">Influent Inputs</h2>
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
                  <StatusPill level={phStatus} text={phStatus === "ok" ? "Acceptable" : "Adjust"} />
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
                    text={turbStatus === "ok" ? "Good" : turbStatus === "warn" ? "High" : "Very High"}
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
                <Beaker className="h-4 w-4" /> Compliance Targets (display)
              </div>
              <div className="mt-2 grid grid-cols-2 gap-2 text-xs text-slate-700">
                <div>Pb limit: <span className="font-semibold">{fmt(outputs.limits.pb, 3)} mg/L</span></div>
                <div>As limit: <span className="font-semibold">{fmt(outputs.limits.as, 3)} mg/L</span></div>
              </div>
              <div className="mt-2">
                <StatusPill
                  level={complianceStatus}
                  text={complianceStatus === "ok" ? "Predicted compliant" : "Predicted non-compliant"}
                />
              </div>
            </div>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm lg:col-span-2">
            <div className="mb-3 flex items-center gap-2">
              <Wand2 className="h-4 w-4" />
              <h2 className="text-sm font-semibold text-slate-900">AI Predictions (Simulation)</h2>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <div className="rounded-2xl border border-slate-200 p-4">
                <div className="text-xs text-slate-500">Pb removal</div>
                <div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(outputs.pbRemovalPct, 1)}%</div>
                <div className="mt-2 text-xs text-slate-600">
                  Predicted Pb_out: <span className="font-semibold">{fmt(outputs.pbOut, 4)} mg/L</span>
                </div>
              </div>

              <div className="rounded-2xl border border-slate-200 p-4">
                <div className="text-xs text-slate-500">As removal</div>
                <div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(outputs.asRemovalPct, 1)}%</div>
                <div className="mt-2 text-xs text-slate-600">
                  Predicted As_out: <span className="font-semibold">{fmt(outputs.asOut, 4)} mg/L</span>
                </div>
              </div>

              <div className="rounded-2xl border border-slate-200 p-4">
                <div className="text-xs text-slate-500">Breakthrough risk</div>
                <div className="mt-1 flex items-center gap-2">
                  <div className="text-2xl font-semibold text-slate-900">{Math.round(outputs.risk * 100)}%</div>
                  <StatusPill level={risk.level} text={risk.text} />
                </div>
                <div className="mt-2 text-xs text-slate-600">
                  Estimated RUL: <span className="font-semibold">~{outputs.rulDays} days</span>
                </div>
              </div>
            </div>

            <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="rounded-2xl border border-slate-200 p-3">
                <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-900">
                  <Activity className="h-4 w-4" /> Media capacity trend
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
              <div className="mb-2 text-sm font-semibold text-slate-900">AI Recommendations</div>
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

              <div className="mt-3 rounded-2xl border bg-white p-3 text-xs text-slate-600">
                <span className="font-semibold text-slate-800">Presenter note:</span> Say “AI-Predicted (Simulation)” if
                you’re not streaming sensor/lab data in real time.
              </div>
            </div>
          </div>
        </div>

        <div className="mt-5 rounded-2xl border bg-white p-4 text-xs text-slate-600 shadow-sm">
          <span className="font-semibold text-slate-800">How to explain the AI:</span>{" "}
          “A decision-support model that relates Pb/As loading, pH, and turbidity to predicted filtration + adsorption
          performance, then outputs risk and operational recommendations.”
        </div>
      </div>
    </div>
  );
}
EOF

echo ""
echo "✅ Project created in: $APP_DIR"
echo "Next:"
echo "  cd $APP_DIR"
echo "  npm install"
echo "  npm run dev"
echo ""
