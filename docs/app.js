/* Bennyfilt static dashboard (no build, works offline) */
const $ = (id) => document.getElementById(id);

const MEDIA_MASS_G = 3000;
const CAPACITY_MG_G = 6;

const clamp = (x,a,b)=>Math.min(b,Math.max(a,x));
const fmt = (n,d=2)=>Number.isFinite(n)?Number(n).toFixed(d):"—";

function predict(pb, as, turbidity, flow_L_day){
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

  return {pbRemovalPct: pbRemoval*100, asRemovalPct: asRemoval*100, pbOut, asOut, days, totalTreatable_L, foulingFactor, removed_mg_day, totalCapacity_mg};
}

function linePath(data, xKey, yKey, w, h, pad=18, yMin=null, yMax=null){
  const xs = data.map(d=>d[xKey]);
  const ys = data.map(d=>d[yKey]);
  const xmin = Math.min(...xs), xmax = Math.max(...xs);
  const ymin = (yMin!==null)?yMin:Math.min(...ys);
  const ymax = (yMax!==null)?yMax:Math.max(...ys);

  const X = (x)=> pad + ( (x - xmin) / (xmax - xmin || 1) ) * (w - 2*pad);
  const Y = (y)=> h - pad - ( (y - ymin) / (ymax - ymin || 1) ) * (h - 2*pad);

  let d = "";
  data.forEach((p,i)=>{
    const x = X(p[xKey]), y = Y(p[yKey]);
    d += (i===0?`M ${x} ${y}`:` L ${x} ${y}`);
  });
  return {d};
}

function renderChart(svgEl, data, xKey, yKey, yMin=null, yMax=null){
  const w = 900, h = 220;
  svgEl.setAttribute("viewBox", `0 0 ${w} ${h}`);
  svgEl.innerHTML = "";

  const grid = document.createElementNS("http://www.w3.org/2000/svg","g");
  grid.setAttribute("opacity","0.35");
  for(let i=0;i<5;i++){
    const y = 18 + i*( (h-36)/4 );
    const ln = document.createElementNS("http://www.w3.org/2000/svg","line");
    ln.setAttribute("x1","18"); ln.setAttribute("x2", String(w-18));
    ln.setAttribute("y1", String(y)); ln.setAttribute("y2", String(y));
    ln.setAttribute("stroke","white"); ln.setAttribute("stroke-width","1");
    ln.setAttribute("stroke-dasharray","4 6");
    grid.appendChild(ln);
  }
  svgEl.appendChild(grid);

  const {d} = linePath(data, xKey, yKey, w, h, 18, yMin, yMax);

  const path = document.createElementNS("http://www.w3.org/2000/svg","path");
  path.setAttribute("d", d);
  path.setAttribute("fill","none");
  path.setAttribute("stroke","rgba(70,211,255,0.95)");
  path.setAttribute("stroke-width","3");
  path.setAttribute("stroke-linecap","round");
  svgEl.appendChild(path);
}

function saveReport(payload){
  const blob = new Blob([JSON.stringify(payload,null,2)], {type:"application/json"});
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "bennyfilt-report.json";
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function readInputs(){
  const pb = parseFloat($("pb").value||"0");
  const as = parseFloat($("as").value||"0");
  const turb = parseFloat($("turb").value||"0");
  const flow = parseFloat($("flow").value||"0");
  return {pb, as, turb, flow};
}

function update(){
  const {pb,as,turb,flow} = readInputs();
  const out = predict(pb,as,turb,flow);

  $("k_pbrem").textContent = `${fmt(out.pbRemovalPct,1)}%`;
  $("k_asrem").textContent = `${fmt(out.asRemovalPct,1)}%`;
  $("k_life").textContent = `${fmt(out.days,1)} days`;
  $("k_foul").textContent = `${fmt(out.foulingFactor,2)}`;

  $("k_pbsub").textContent = `Pb_out: ${fmt(out.pbOut,4)} mg/L`;
  $("k_assub").textContent = `As_out: ${fmt(out.asOut,4)} mg/L`;
  $("k_lifesub").textContent = `Total: ${fmt(out.totalTreatable_L,0)} L`;
  $("k_foulsub").textContent = `Load: ${fmt(out.removed_mg_day,0)} mg/day`;

  const pts = 14;
  const days = Math.max(out.days, 1e-6);
  const totalL = out.totalTreatable_L;
  const trend = Array.from({length:pts}, (_,i)=>{
    const day=i+1;
    const treated=Math.min(totalL, day*flow);
    const remaining=Math.max(0,(1-day/pts))*100;
    return {day, treated, remaining};
  });

  renderChart($("chart1"), trend, "day", "treated");
  renderChart($("chart2"), trend, "day", "remaining", 0, 100);

  const payload = {
    generatedAt: new Date().toISOString(),
    inputs: { lead_mgL: pb, arsenic_mgL: as, turbidity_NTU: turb, water_L_per_day: flow },
    outputs: out,
    assumptions: { mediaMass_g: MEDIA_MASS_G, capacity_mg_g: CAPACITY_MG_G }
  };

  $("export").onclick = ()=>saveReport(payload);
  localStorage.setItem("bennyfilt_inputs", JSON.stringify({pb,as,turb,flow}));
}

function init(){
  try{
    const saved = JSON.parse(localStorage.getItem("bennyfilt_inputs")||"null");
    if(saved){
      $("pb").value = saved.pb ?? 0.2;
      $("as").value = saved.as ?? 1.0;
      $("turb").value = saved.turb ?? 500;
      $("flow").value = saved.flow ?? 2000;
    }
  }catch(e){}

  ["pb","as","turb","flow"].forEach(id => $(id).addEventListener("input", update));
  update();

  if("serviceWorker" in navigator){
    window.addEventListener("load", ()=>{
      navigator.serviceWorker.register("./sw.js").catch(()=>{});
    });
  }
}

document.addEventListener("DOMContentLoaded", init);
