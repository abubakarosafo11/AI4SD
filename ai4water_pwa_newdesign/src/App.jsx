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
  Gauge,
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
  if (level === "ok") return "bg-emerald-500/15 text-emerald-100 border-emerald-400/30";
  if (level === "warn") return "bg-amber-500/15 text-amber-100 border-amber-400/30";
  return "bg-rose-500/15 text-rose-100 border-rose-400/30";
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
 * Capacity-based model:
 * - Media life (days) = total capacity (mg) / removed mass per day (mg/day)
 * - Removed mass per day depends on influent (mg/L), flow (L/day), and predicted removal (%)
 * - High turbidity reduces usable capacity via a fouling factor
 */
function predict({ pb, as, ph, turbidity, flow_L_day, mediaMass_g, capacity_mg_g }) {
  // Removal penalties (engineering heuristics)
  const turbPenalty = clamp((turbidity - 50) / 1200, 0, 0.30); // up to 0.30
  const phPenalty = clamp(Math.abs(ph - 7.5) / 5.0, 0, 0.20); // up to 0.20
  const load = pb + as;
  const loadPenalty = clamp(load / 10.0, 0, 0.12);

  let pbRemoval = 0.95 - turbPenalty - phPenalty - loadPenalty;
  let asRemoval = 0.90 - turbPenalty - phPenalty - loadPenalty;

  pbRemoval = clamp(pbRemoval, 0.55, 0.98);
  asRemoval = clamp(asRemoval, 0.50, 0.97);

  const pbOut = pb * (1 - pbRemoval);
  const asOut = as * (1 - asRemoval);

  // Display guideline limits (edit if you want different)
  const limits = { pb: 0.01, as: 0.01 };
  const pbPass = pbOut <= limits.pb;
  const asPass = asOut <= limits.as;

  // Fouling factor reduces usable capacity at high turbidity
  // 0 NTU -> ~1.00, 1000 NTU -> ~0.40–0.50 (clamped)
  const foulingFactor = clamp(1.0 - 0.60 * clamp(turbidity / 1000, 0, 1.5), 0.35, 1.0);

  // Total usable capacity (mg)
  const totalCapacity_mg = Math.max(0, mediaMass_g * capacity_mg_g * foulingFactor);

  // Daily mass in (mg/day)
  const pb_in_mg_day = Math.max(0, pb * flow_L_day);
  const as_in_mg_day = Math.max(0, as * flow_L_day);

  // Daily removed mass (mg/day)
  const pb_removed_mg_day = pb_in_mg_day * pbRemoval;
  const as_removed_mg_day = as_in_mg_day * asRemoval;

  const total_removed_mg_day = Math.max(1e-9, pb_removed_mg_day + as_removed_mg_day);

  // Media life (days) - capacity basis, so it changes with flow
  const rulDays = clamp(totalCapacity_mg / total_removed_mg_day, 0, 365);
  const totalTreatable_L = rulDays * flow_L_day;

  // Operational risk (0–1)
  let risk =
    0.10 +
    clamp((turbidity - 200) / 1200, 0, 0.45) +
    clamp(load / 12.0, 0, 0.25) +
    clamp(Math.abs(ph - 7.5) / 7.5, 0, 0.15) +
    clamp(flow_L_day / 8000, 0, 0.15);
  risk = clamp(risk, 0.05, 0.95);

  const actions = [];

  // Turbidity advice for galamsey influent
  if (turbidity >= 900) {
    actions.push({
      kind: "bad",
      title: "Very high turbidity influent",
      detail: "Prioritize coagulation–clarification and reduce flow to protect adsorption media from rapid fouling.",
    });
  } else if (turbidity >= 300) {
    actions.push({
      kind: "warn",
      title: "High turbidity influent",
      detail: "Optimize pre-treatment and monitor headloss; schedule more frequent cleaning/backwash.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Turbidity manageable",
      detail: "Influent turbidity is within a range that is easier to manage operationally.",
    });
  }

  // pH: influent range accepted, potable target flagged
  if (ph < 5.0 || ph > 9.0) {
    actions.push({
      kind: "bad",
      title: "pH outside expected influent range",
      detail: "Consider pH conditioning; adsorption/speciation may deviate strongly outside typical ranges.",
    });
  } else if (ph < 6.5 || ph > 8.5) {
    actions.push({
      kind: "warn",
      title: "pH outside drinking-water target",
      detail: "Water may be treatable but requires pH adjustment to meet potable guidelines.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "pH within drinking-water target",
      detail: "pH is within typical potable guideline range (6.5–8.5).",
    });
  }

  // Metals guideline
  if (!pbPass || !asPass) {
    actions.push({
      kind: "bad",
      title: "Predicted guideline exceedance",
      detail: "Increase contact time (reduce flow), add polishing stage, or refresh adsorption media; verify with lab testing.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Predicted within Pb/As limits",
      detail: "Predicted effluent meets the displayed limits under current inputs.",
    });
  }

  // Risk action
  if (risk >= 0.66) {
    actions.push({
      kind: "bad",
      title: "Operational risk high",
      detail: "Plan early media replacement and increase Pb/As sampling frequency.",
    });
  } else if (risk >= 0.33) {
    actions.push({
      kind: "warn",
      title: "Operational risk moderate",
      detail: "Monitor closely; schedule periodic lab verification and track throughput.",
    });
  } else {
    actions.push({
      kind: "ok",
      title: "Operational risk low",
      detail: "Operation appears stable; continue routine monitoring and logging.",
    });
  }

  return {
    pbRemovalPct: pbRemoval * 100,
    asRemovalPct: asRemoval * 100,
    pbOut,
    asOut,
    risk,
    rulDays,
    totalTreatable_L,
    totalCapacity_mg,
    total_removed_mg_day,
    foulingFactor,
    limits,
    compliance: { pbPass, asPass },
    actions,
  };
}

function makeTrend(rulDays, flow_L_day, totalTreatable_L) {
  const points = 14;
  const safeDays = Math.max(rulDays, 1e-6);
  return Array.from({ length: points }, (_, i) => {
    const day = i + 1;
    const frac = day / points;
    const remainingDays = Math.max(0, safeDays * (1 - frac));
    const treated = Math.min(totalTreatable_L, day * flow_L_day);
    const pctRemaining = clamp((remainingDays / safeDays) * 100, 0, 100);
    return { day, treated, remaining: pctRemaining };
  });
}

// Defaults tuned for galamsey-style demo
const DEFAULTS = {
  site: "Galamsey Influent",
  pb: 0.20,          // mg/L
  as: 1.00,          // mg/L
  ph: 6.2,           // expected 5–9
  turbidity: 500,    // can be 300–1000+ NTU
  flow_L_day: 2000,  // L/day (changing this changes predicted days)
  mediaMass_g: 3000, // 3 kg media
  capacity_mg_g: 6,  // mg/g (tune to your media)
};

export default function App() {
  const [site, setSite] = useState(DEFAULTS.site);
  const [pb, setPb] = useState(DEFAULTS.pb);
  const [as, setAs] = useState(DEFAULTS.as);
  const [ph, setPh] = useState(DEFAULTS.ph);
  const [turbidity, setTurbidity] = useState(DEFAULTS.turbidity);

  const [flow_L_day, setFlow] = useState(DEFAULTS.flow_L_day);
  const [mediaMass_g, setMediaMass] = useState(DEFAULTS.mediaMass_g);
  const [capacity_mg_g, setCapacity] = useState(DEFAULTS.capacity_mg_g);

  const outputs = useMemo(
    () => predict({ pb, as, ph, turbidity, flow_L_day, mediaMass_g, capacity_mg_g }),
    [pb, as, ph, turbidity, flow_L_day, mediaMass_g, capacity_mg_g]
  );

  const risk = riskLabel(outputs.risk);
  const complianceStatus = outputs.compliance.pbPass && outputs.compliance.asPass ? "ok" : "bad";

  const trend = useMemo(
    () => makeTrend(outputs.rulDays, flow_L_day, outputs.totalTreatable_L),
    [outputs.rulDays, flow_L_day, outputs.totalTreatable_L]
  );

  // Potable targets displayed (influent can be higher)
  const turbDrink = turbidity <= 5 ? "ok" : turbidity <= 10 ? "warn" : "bad";
  const phDrink = ph >= 6.5 && ph <= 8.5 ? "ok" : "warn";

  const exportPayload = {
    generatedAt: new Date().toISOString(),
    site,
    inputs: { pb_mgL: pb, as_mgL: as, ph, turbidity_NTU: turbidity, flow_L_day, mediaMass_g, capacity_mg_g },
    outputs,
  };

  return (
    <div className="min-h-screen bg-[#050816] text-white">
      {/* Tech background */}
      <div className="pointer-events-none fixed inset-0 opacity-70">
        <div className="absolute -top-48 left-1/2 h-[600px] w-[600px] -translate-x-1/2 rounded-full bg-indigo-600/25 blur-3xl" />
        <div className="absolute -bottom-56 left-16 h-[520px] w-[520px] rounded-full bg-cyan-500/20 blur-3xl" />
        <div className="absolute top-24 right-10 h-[420px] w-[420px] rounded-full bg-fuchsia-500/15 blur-3xl" />
      </div>

      <div className="relative mx-auto max-w-6xl px-4 py-6">
        {/* Header */}
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-3 py-1 backdrop-blur">
              <Droplet className="h-4 w-4 text-cyan-200" />
              <span className="text-sm text-white/90">AI for Water</span>
              <span className="rounded-xl bg-white/10 px-2 py-0.5 text-xs text-white/80">Offline PWA</span>
            </div>
            <h1 className="text-2xl font-semibold tracking-tight">Smart Filtration Performance & Media Life</h1>
            <p className="text-sm text-white/70">
              Galamsey influent-ready (high NTU + pH 5–9). Media life is capacity-based and scales with L/day.
            </p>
          </div>

          <div className="flex flex-col gap-2 sm:w-[380px]">
            <input
              className="w-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none placeholder:text-white/40 backdrop-blur focus:ring-2 focus:ring-white/20"
              value={site}
              onChange={(e) => setSite(e.target.value)}
              placeholder="Sample ID / Location"
            />
            <button
              className="inline-flex items-center justify-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm shadow-sm backdrop-blur hover:bg-white/10"
              onClick={() => downloadJson("ai4water-report.json", exportPayload)}
            >
              <Download className="h-4 w-4" />
              Export Report
            </button>
          </div>
        </div>

        {/* Grid */}
        <div className="mt-5 grid grid-cols-1 gap-4 lg:grid-cols-3">
          {/* Inputs */}
          <div className="rounded-3xl border border-white/10 bg-white/5 p-4 shadow-xl backdrop-blur">
            <div className="mb-3 flex items-center gap-2">
              <Settings2 className="h-4 w-4 text-white/80" />
              <h2 className="text-sm font-semibold text-white/90">Influent Inputs</h2>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-1">
              <Field label="Lead, Pb (mg/L)" value={pb} onChange={setPb} step={0.001} min={0} />
              <Field label="Arsenic, As (mg/L)" value={as} onChange={setAs} step={0.001} min={0} />

              <div className="space-y-1">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-white/80">pH (influent)</span>
                  <StatusPill level={phDrink} text={phDrink === "ok" ? "Potable target" : "Adjust"} />
                </div>
                <input
                  type="number"
                  step="0.1"
                  min="5"
                  max="9"
                  value={ph}
                  onChange={(e) => setPh(parseFloat(e.target.value || "0"))}
                  className="w-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none backdrop-blur focus:ring-2 focus:ring-white/20"
                />
                <div className="text-[11px] text-white/50">Expected influent range: 5–9</div>
              </div>

              <div className="space-y-1">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-white/80">Turbidity (NTU influent)</span>
                  <StatusPill level={turbDrink} text={turbDrink === "ok" ? "≤5 NTU target" : turbDrink === "warn" ? "5–10" : ">10"} />
                </div>
                <input
                  type="number"
                  step="1"
                  min="0"
                  max="1500"
                  value={turbidity}
                  onChange={(e) => setTurbidity(parseFloat(e.target.value || "0"))}
                  className="w-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none backdrop-blur focus:ring-2 focus:ring-white/20"
                />
                <div className="text-[11px] text-white/50">Galamsey can be 300–1000+ NTU</div>
              </div>
            </div>

            {/* Throughput & Media */}
            <div className="mt-4 rounded-3xl border border-white/10 bg-white/5 p-3 backdrop-blur">
              <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-white/90">
                <Gauge className="h-4 w-4" /> Throughput & Media
              </div>

              <div className="grid grid-cols-1 gap-3">
                <Field label="Flow / Throughput (L/day)" value={flow_L_day} onChange={setFlow} step={10} min={0} />
                <Field label="Media mass (g)" value={mediaMass_g} onChange={setMediaMass} step={10} min={0} />
                <Field label="Media capacity (mg/g)" value={capacity_mg_g} onChange={setCapacity} step={0.1} min={0} />
              </div>

              <div className="mt-2 text-[11px] text-white/55 leading-relaxed">
                Increasing <span className="text-white/80">L/day</span> reduces predicted <span className="text-white/80">days</span> (capacity basis).
              </div>
            </div>

            {/* Limits */}
            <div className="mt-4 rounded-3xl border border-white/10 bg-white/5 p-3 backdrop-blur">
              <div className="flex items-center gap-2 text-sm font-semibold text-white/90">
                <Beaker className="h-4 w-4" /> Display Limits
              </div>
              <div className="mt-2 grid grid-cols-2 gap-2 text-xs text-white/80">
                <div>Pb: <span className="font-semibold">{fmt(outputs.limits.pb, 3)} mg/L</span></div>
                <div>As: <span className="font-semibold">{fmt(outputs.limits.as, 3)} mg/L</span></div>
              </div>
              <div className="mt-2">
                <StatusPill level={complianceStatus} text={complianceStatus === "ok" ? "Predicted within limits" : "Predicted above limits"} />
              </div>
            </div>
          </div>

          {/* Outputs */}
          <div className="rounded-3xl border border-white/10 bg-white/5 p-4 shadow-xl backdrop-blur lg:col-span-2">
            <div className="mb-3 flex items-center gap-2">
              <Wand2 className="h-4 w-4 text-white/80" />
              <h2 className="text-sm font-semibold text-white/90">Assessment</h2>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
              <KPI title="Pb removal" value={`${fmt(outputs.pbRemovalPct, 1)}%`} sub={`Pb_out: ${fmt(outputs.pbOut, 4)} mg/L`} />
              <KPI title="As removal" value={`${fmt(outputs.asRemovalPct, 1)}%`} sub={`As_out: ${fmt(outputs.asOut, 4)} mg/L`} />
              <KPI title="Operational risk" value={`${Math.round(outputs.risk * 100)}%`} pill={<StatusPill level={risk.level} text={risk.text} />} />
              <KPI title="Media life" value={`${fmt(outputs.rulDays, 1)} days`} sub={`${fmt(outputs.totalTreatable_L, 0)} L total`} />
            </div>

            <div className="mt-3 grid grid-cols-1 gap-3 md:grid-cols-3">
              <MiniStat label="Usable capacity (mg)" value={fmt(outputs.totalCapacity_mg, 0)} />
              <MiniStat label="Removed load (mg/day)" value={fmt(outputs.total_removed_mg_day, 0)} />
              <MiniStat label="Fouling factor" value={fmt(outputs.foulingFactor, 2)} />
            </div>

            <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="rounded-3xl border border-white/10 bg-white/5 p-3 backdrop-blur">
                <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-white/90">
                  <Activity className="h-4 w-4" /> Remaining media (%) vs days
                </div>
                <div className="h-56">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={trend} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="day" tick={{ fontSize: 12 }} />
                      <YAxis tick={{ fontSize: 12 }} domain={[0, 100]} />
                      <Tooltip />
                      <ReferenceLine y={30} strokeDasharray="4 4" />
                      <Area type="monotone" dataKey="remaining" strokeWidth={2} fillOpacity={0.15} />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="rounded-3xl border border-white/10 bg-white/5 p-3 backdrop-blur">
                <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-white/90">
                  <AlertTriangle className="h-4 w-4" /> Treated volume (L) vs days
                </div>
                <div className="h-56">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={trend} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="day" tick={{ fontSize: 12 }} />
                      <YAxis tick={{ fontSize: 12 }} />
                      <Tooltip />
                      <Line type="monotone" dataKey="treated" strokeWidth={2} dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>

            <div className="mt-4 rounded-3xl border border-white/10 bg-white/5 p-3 backdrop-blur">
              <div className="mb-2 text-sm font-semibold text-white/90">Recommendations</div>
              <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
                {outputs.actions.map((a, idx) => (
                  <div
                    key={idx}
                    className={`rounded-3xl border p-3 ${
                      a.kind === "ok"
                        ? "bg-emerald-500/10 border-emerald-400/25"
                        : a.kind === "warn"
                        ? "bg-amber-500/10 border-amber-400/25"
                        : "bg-rose-500/10 border-rose-400/25"
                    }`}
                  >
                    <div className="flex items-center gap-2 text-sm font-semibold text-white/90">
                      {a.kind === "ok" ? <CheckCircle2 className="h-4 w-4" /> : a.kind === "warn" ? <AlertTriangle className="h-4 w-4" /> : <XCircle className="h-4 w-4" />}
                      {a.title}
                    </div>
                    <p className="mt-1 text-xs text-white/75 leading-relaxed">{a.detail}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-4 text-xs text-white/60">
              <span className="font-semibold text-white/80">Offline:</span> after first successful load, works without internet (PWA).
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Field({ label, value, onChange, step, min, max }) {
  return (
    <div className="space-y-1">
      <div className="flex items-center justify-between">
        <span className="text-sm text-white/80">{label}</span>
      </div>
      <input
        type="number"
        step={step}
        min={min}
        max={max}
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value || "0"))}
        className="w-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none backdrop-blur focus:ring-2 focus:ring-white/20"
      />
    </div>
  );
}

function KPI({ title, value, sub, pill }) {
  return (
    <div className="rounded-3xl border border-white/10 bg-white/5 p-4 backdrop-blur">
      <div className="text-xs text-white/60">{title}</div>
      <div className="mt-1 text-2xl font-semibold text-white">{value}</div>
      {pill ? <div className="mt-2">{pill}</div> : null}
      {sub ? <div className="mt-2 text-xs text-white/70">{sub}</div> : null}
    </div>
  );
}

function MiniStat({ label, value }) {
  return (
    <div className="rounded-3xl border border-white/10 bg-white/5 p-3 backdrop-blur">
      <div className="text-xs text-white/60">{label}</div>
      <div className="mt-1 text-lg font-semibold text-white">{value}</div>
    </div>
  );
}
