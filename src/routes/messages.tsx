import { createFileRoute, redirect } from "@tanstack/react-router";

/** Kept so existing links and notification actions keep working; Messages now lives in the Inbox. */
export const Route = createFileRoute("/messages")({
  beforeLoad: () => {
    throw redirect({ to: "/inbox", search: { tab: "messages" } });
  },
});
