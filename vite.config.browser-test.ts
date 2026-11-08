import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import viteReact from "@vitejs/plugin-react";
import { defineConfig } from "vite";

/**
 * Browser acceptance runs the app through Vite's Node SSR runtime.
 * Production Cloudflare compatibility is verified separately by the build
 * and Worker dry-run workflow; keeping Miniflare out of this test server
 * avoids coupling browser consent tests to the runner's workerd date.
 */
export default defineConfig({
  plugins: [tanstackStart(), viteReact()],
});
