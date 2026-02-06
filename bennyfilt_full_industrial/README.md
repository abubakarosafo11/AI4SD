# Bennyfilt (Offline PWA)

Bennyfilt is an AI-assisted, offline-capable dashboard for water filtration decision support.

## User inputs (ONLY)
- Lead concentration (mg/L)
- Arsenic concentration (mg/L)
- Turbidity (NTU)
- Planned treated volume per day (L/day)

## Outputs
- Predicted Pb/As removal and effluent
- Capacity-based filter life (days) that changes with L/day
- Total treatable volume (L)
- Export report JSON

## Run (Codespaces / PC)
```bash
npm install
npm run dev -- --host 0.0.0.0
```

## Install on iPhone (PWA)
Open the hosted link in **Safari** → Share → **Add to Home Screen**.
After the first successful load, it works offline.

## Upload to GitHub (beginner)
1. Create/open your GitHub repository
2. Click **Add file → Upload files**
3. Upload all files from this folder (not the zip itself)
4. Commit changes
