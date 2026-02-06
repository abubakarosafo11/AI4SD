import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  // Relative base makes it work on GitHub Pages project sites (username.github.io/repo/)
  base: "./"
});
