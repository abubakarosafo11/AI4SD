import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// NOTE: base:"./" makes it easier to host on GitHub Pages or any subpath.
export default defineConfig({
  plugins: [react()],
  base: "./"
});
