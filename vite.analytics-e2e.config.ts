import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import viteReact from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// Browser acceptance runs on Node without the Cloudflare workerd runtime.
// These synthetic values are available only in this dedicated E2E config.
export default defineConfig({
  plugins: [tanstackStart(), viteReact()],
  define: {
    "import.meta.env.VITE_POSTHOG_PROJECT_TOKEN": JSON.stringify("phc_openplay_browser_test_only"),
    "import.meta.env.VITE_POSTHOG_HOST": JSON.stringify("https://eu.i.posthog.com"),
    "import.meta.env.VITE_POSTHOG_PRIVACY_SETTINGS_VERIFIED": JSON.stringify("true"),
    "import.meta.env.VITE_OPENPLAY_ANALYTICS_E2E": JSON.stringify("true"),
    "import.meta.env.VITE_SUPABASE_URL": JSON.stringify("http://127.0.0.1:54321"),
    "import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY": JSON.stringify("sb_publishable_browser_test_only"),
  },
});
