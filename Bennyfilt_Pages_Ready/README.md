# Bennyfilt — Non‑Expiring Link (GitHub Pages)

This repository is **ready for GitHub Pages** using **GitHub Actions**.
Once you upload it and enable Pages, your link will **not expire**.

## What you get
- Bennyfilt PWA (installable on iPhone)
- Works offline after first successful load
- Inputs ONLY: Lead (mg/L), Arsenic (mg/L), Turbidity (NTU), Water treated per day (L/day)
- Stable GitHub Pages deployment on every push

---

## Step‑by‑step (Beginner, no coding)

### 1) Upload the folder to GitHub
1. Create/open a GitHub repository (example: `AI4SD`)
2. Click **Add file → Upload files**
3. Upload **everything inside this folder** (including `.github` and `app`)
4. Click **Commit changes**

### 2) Enable GitHub Pages (makes link permanent)
1. Go to **Settings → Pages**
2. Under **Build and deployment**
3. **Source:** select **GitHub Actions**
4. Save/leave it

### 3) Wait for deployment
1. Go to **Actions**
2. You will see **Deploy Bennyfilt to GitHub Pages**
3. Wait until it becomes ✅ green

### 4) Your permanent link
Your site will be:
`https://<your-username>.github.io/<your-repo-name>/`

Example:
`https://abubakarosaf011.github.io/AI4SD/`

---

## Install on iPhone (as an app)
1. Open the permanent link in **Safari**
2. Tap **Share**
3. Tap **Add to Home Screen**
4. Name it **Bennyfilt**
5. Tap **Add**

✅ After first load, it will work offline.

---

## Optional: run locally in Codespaces
```bash
cd app
npm install
npm run dev -- --host 0.0.0.0
```
