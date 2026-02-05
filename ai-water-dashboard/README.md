# AI for Water – Offline PWA Dashboard (Pb/As)

This is a mobile-friendly **Progressive Web App (PWA)** for water-quality decision support.

## Inputs
- Lead (Pb) in mg/L
- Arsenic (As) in mg/L
- pH
- Turbidity (NTU)

## Outputs
- Predicted Pb/As removal (%)
- Predicted effluent concentrations
- Guideline compliance check
- Operational risk estimate + recommendations
- Export report (JSON)

## Run locally (Codespaces or laptop)
```bash
npm install
npm run dev
```

## Build
```bash
npm run build
npm run preview
```

## Install on iPhone (PWA)
1. Open the app URL in **Safari**
2. Tap **Share**
3. Tap **Add to Home Screen**
4. Launch from the new icon
