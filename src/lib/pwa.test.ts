import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const publicFile = (path: string) =>
  readFileSync(new URL(`../../public/${path}`, import.meta.url));

function pngDimensions(path: string): [number, number] {
  const image = publicFile(path);
  expect(image.subarray(0, 8)).toEqual(
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  );
  return [image.readUInt32BE(16), image.readUInt32BE(20)];
}

describe("Open Play PWA", () => {
  it("declares a standalone installable app with correctly sized icons", () => {
    const manifest = JSON.parse(
      publicFile("manifest.webmanifest").toString("utf8"),
    ) as {
      display: string;
      icons: Array<{ src: string; sizes: string; type: string }>;
    };

    expect(manifest.display).toBe("standalone");
    expect(manifest.icons).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          src: "/icons/open-play-192.png",
          sizes: "192x192",
          type: "image/png",
        }),
        expect.objectContaining({
          src: "/icons/open-play-512.png",
          sizes: "512x512",
          type: "image/png",
        }),
      ]),
    );
    expect(pngDimensions("icons/open-play-192.png")).toEqual([192, 192]);
    expect(pngDimensions("icons/open-play-512.png")).toEqual([512, 512]);
    expect(pngDimensions("apple-touch-icon.png")).toEqual([180, 180]);
  });

  it("never caches authentication, API, function or private-route responses", () => {
    const serviceWorker = publicFile("sw.js").toString("utf8");

    expect(serviceWorker).toContain(
      'if (url.origin !== self.location.origin) return;',
    );
    expect(serviceWorker).toContain('url.pathname.startsWith("/auth/")');
    expect(serviceWorker).toContain('url.pathname.startsWith("/rest/")');
    expect(serviceWorker).toContain('url.pathname.startsWith("/functions/")');
    expect(serviceWorker).toContain('url.pathname.startsWith("/api/")');
    expect(serviceWorker).toContain('if (url.pathname !== "/") return;');
  });
});
