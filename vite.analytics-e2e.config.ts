import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import viteReact from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// Browser acceptance runs on Node without the Cloudflare workerd runtime.
// Production and normal development continue to use vite.config.ts.
export default defineConfig({
  plugins: [tanstackStart(), viteReact()],
});
