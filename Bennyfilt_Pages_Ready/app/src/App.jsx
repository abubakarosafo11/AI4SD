import React,{useMemo,useState} from "react";
import {Droplet,AlertTriangle,CheckCircle2,Download} from "lucide-react";
import {LineChart,Line,XAxis,YAxis,Tooltip,ResponsiveContainer,CartesianGrid} from "recharts";

const clamp=(x,a,b)=>Math.min(b,Math.max(a,x));
const fmt=(n,d=2)=>Number.isFinite(n)?Number(n).toFixed(d):"—";

// Fixed pilot filter assumptions (internal)
const MEDIA_MASS_G = 3000;   // 3 kg active media
const CAPACITY_MG_G = 6;     // mg/g combined capacity proxy

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

// Capacity-based life model (days changes with L/day)
function predict(pb, as, turbidity, flow_L_day){
  // Turbidity reduces removal and usable capacity (fouling)
  const turbPenalty = clamp((turbidity - 50)/1200, 0, 0.40);
  const pbRemoval = clamp(0.95 - turbPenalty, 0.60, 0.98);
  const asRemoval = clamp(0.90 - turbPenalty, 0.55, 0.97);

  const pbOut = pb*(1-pbRemoval);
  const asOut = as*(1-asRemoval);

  const foulingFactor = clamp(1 - 0.60*clamp(turbidity/1000,0,1.5), 0.35, 1.0);
  const totalCapacity_mg = Math.max(0, MEDIA_MASS_G*CAPACITY_MG_G*foulingFactor);

  const pb_removed_mg_day = (pb*flow_L_day)*pbRemoval;
  const as_removed_mg_day = (as*flow_L_day)*asRemoval;
  const removed_mg_day = Math.max(1e-9, pb_removed_mg_day + as_removed_mg_day);

  const days = clamp(totalCapacity_mg/removed_mg_day, 0, 365);
  const totalTreatable_L = days*flow_L_day;

  return {
    pbRemovalPct: pbRemoval*100,
    asRemovalPct: asRemoval*100,
    pbOut, asOut,
    days,
    totalTreatable_L,
    foulingFactor,
    removed_mg_day,
    totalCapacity_mg
  };
}

export default function App(){
  const [pb,setPb]=useState(0.20);
  const [as,setAs]=useState(1.00);
  const [turb,setTurb]=useState(500);
  const [flow,setFlow]=useState(2000);

  const out = useMemo(()=>predict(pb,as,turb,flow),[pb,as,turb,flow]);

  const trend = useMemo(()=>{
    const pts=14;
    const safe=Math.max(out.days,1e-6);
    return Array.from({length:pts},(_,i)=>{
      const day=i+1;
      const rem=Math.max(0, (1-day/pts))*100;
      const treated=Math.min(out.totalTreatable_L, day*flow);
      return {day, remaining: rem, treated};
    });
  },[out.days,out.totalTreatable_L,flow]);

  const payload = {
    generatedAt: new Date().toISOString(),
    inputs: { lead_mgL: pb, arsenic_mgL: as, turbidity_NTU: turb, water_L_per_day: flow },
    outputs: out,
    assumptions: { mediaMass_g: MEDIA_MASS_G, capacity_mg_g: CAPACITY_MG_G }
  };

  return (
    <div className="min-h-screen bg-[#050816] text-white">
      <div className="pointer-events-none fixed inset-0 opacity-70">
        <div className="absolute -top-48 left-1/2 h-[620px] w-[620px] -translate-x-1/2 rounded-full bg-cyan-500/15 blur-3xl" />
        <div className="absolute -bottom-56 left-16 h-[520px] w-[520px] rounded-full bg-slate-400/10 blur-3xl" />
        <div className="absolute top-24 right-10 h-[420px] w-[420px] rounded-full bg-blue-500/10 blur-3xl" />
      </div>

      <div className="relative mx-auto max-w-6xl px-4 py-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div className="flex items-center gap-3">
            <img src="./logo.png" alt="Bennyfilt" className="h-12 w-12" />
            <div>
              <div className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-3 py-1 backdrop-blur">
                <span className="text-sm text-white/90 font-semibold">Bennyfilt</span>
                <span className="rounded-xl bg-white/10 px-2 py-0.5 text-xs text-white/80">Offline PWA</span>
              </div>
              <h1 className="mt-2 text-xl sm:text-2xl font-semibold tracking-tight">Filter Life & Water Quality Predictor</h1>
              <p className="text-sm text-white/70">
                Inputs: Lead, Arsenic, Turbidity, and planned daily treated volume (L/day).
              </p>
            </div>
          </div>

          <button
            className="inline-flex items-center justify-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm shadow-sm backdrop-blur hover:bg-white/10"
            onClick={() => downloadJson("bennyfilt-report.json", payload)}
          >
            <Download className="h-4 w-4" />
            Export Report
          </button>
        </div>

        <div className="mt-5 grid grid-cols-1 gap-4 lg:grid-cols-3">
          <div className="rounded-3xl border border-white/10 bg-white/5 p-4 shadow-xl backdrop-blur">
            <h2 className="text-sm font-semibold text-white/90 mb-3">User Inputs</h2>

            <Field label="Lead concentration (mg/L)" value={pb} setValue={setPb} step={0.001} min={0} />
            <Field label="Arsenic concentration (mg/L)" value={as} setValue={setAs} step={0.001} min={0} />
            <Field label="Turbidity (NTU)" value={turb} setValue={setTurb} step={1} min={0} max={1500}
              hint="Galamsey water can be 300–1000+ NTU" />
            <Field label="Water treated per day (L/day)" value={flow} setValue={setFlow} step={10} min={0}
              hint="Increasing L/day reduces predicted filter life (days)" />

            <div className="mt-4 rounded-3xl border border-white/10 bg-white/5 p-3 text-xs text-white/70">
              Internal pilot assumptions: media mass {MEDIA_MASS_G/1000} kg; capacity {CAPACITY_MG_G} mg/g (combined).
            </div>
          </div>

          <div className="rounded-3xl border border-white/10 bg-white/5 p-4 shadow-xl backdrop-blur lg:col-span-2">
            <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
              <KPI title="Pb removal" value={`${fmt(out.pbRemovalPct,1)}%`} sub={`Pb_out: ${fmt(out.pbOut,4)} mg/L`} icon={<CheckCircle2 className="h-4 w-4"/>} />
              <KPI title="As removal" value={`${fmt(out.asRemovalPct,1)}%`} sub={`As_out: ${fmt(out.asOut,4)} mg/L`} icon={<CheckCircle2 className="h-4 w-4"/>} />
              <KPI title="Filter life" value={`${fmt(out.days,1)} days`} sub={`Total: ${fmt(out.totalTreatable_L,0)} L`} icon={<AlertTriangle className="h-4 w-4"/>} />
              <KPI title="Fouling factor" value={`${fmt(out.foulingFactor,2)}`} sub={`Load: ${fmt(out.removed_mg_day,0)} mg/day`} icon={<Droplet className="h-4 w-4"/>} />
            </div>

            <div className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-3">
              <ChartCard title="Treated volume vs days (L)">
                <div className="h-56">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={trend} margin={{top:10,right:10,left:0,bottom:0}}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="day" tick={{fontSize:12}} />
                      <YAxis tick={{fontSize:12}} />
                      <Tooltip />
                      <Line type="monotone" dataKey="treated" strokeWidth={2} dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </ChartCard>

              <ChartCard title="Remaining media trend (%)">
                <div className="h-56">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={trend} margin={{top:10,right:10,left:0,bottom:0}}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="day" tick={{fontSize:12}} />
                      <YAxis tick={{fontSize:12}} domain={[0,100]} />
                      <Tooltip />
                      <Line type="monotone" dataKey="remaining" strokeWidth={2} dot={false} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </ChartCard>
            </div>

            <div className="mt-4 rounded-3xl border border-white/10 bg-white/5 p-3 text-xs text-white/70">
              Note: This is an exhibition-ready decision-support estimator. Confirm with lab tests for final claims.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Field({label,value,setValue,step,min,max, hint}){
  return (
    <div className="space-y-1 mb-3">
      <span className="text-sm text-white/85">{label}</span>
      <input
        type="number"
        value={value}
        step={step}
        min={min}
        max={max}
        onChange={e=>setValue(parseFloat(e.target.value||"0"))}
        className="w-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none backdrop-blur focus:ring-2 focus:ring-white/20"
      />
      {hint ? <div className="text-[11px] text-white/50">{hint}</div> : null}
    </div>
  );
}

function KPI({title,value,sub,icon}){
  return (
    <div className="rounded-3xl border border-white/10 bg-white/5 p-4 backdrop-blur">
      <div className="flex items-center justify-between">
        <div className="text-xs text-white/60">{title}</div>
        <div className="text-white/70">{icon}</div>
      </div>
      <div className="mt-1 text-2xl font-semibold">{value}</div>
      <div className="mt-2 text-xs text-white/70">{sub}</div>
    </div>
  );
}

function ChartCard({title, children}){
  return (
    <div className="rounded-3xl border border-white/10 bg-white/5 p-3 backdrop-blur">
      <div className="mb-2 text-sm font-semibold text-white/90">{title}</div>
      {children}
    </div>
  );
}
