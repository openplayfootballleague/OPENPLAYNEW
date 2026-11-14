import { createElement as h } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { EmptyState, ErrorState, LoadingState, PageHeader, Pagination, StatTile, StatusBadge, teamInitials } from "./op-ui";

describe("Open Play shared UI", () => {
  it("derives team initials like the reference images", () => {
    expect(teamInitials("Hale Rovers")).toBe("HR");
    expect(teamInitials("6 Offenders")).toBe("6O");
    expect(teamInitials("Unathletico Madrid")).toBe("UM");
    expect(teamInitials("Perkes Rescue Squad")).toBe("PRS");
    expect(teamInitials("Inio FC")).toBe("IF");
    expect(teamInitials("Bideford")).toBe("BI");
    expect(teamInitials("  ")).toBe("?");
  });

  it("renders one h1 page title with the eyebrow and subtitle", () => {
    const html = renderToStaticMarkup(h(PageHeader, { eyebrow: "Player Hub / My Results", title: "Your Results.", subtitle: "Hale Rovers" }));
    expect(html.match(/<h1/g)).toHaveLength(1);
    expect(html).toContain("Your Results.");
    expect(html).toContain("op-eyebrow");
  });

  it("announces loading, empty and error states to assistive technology", () => {
    expect(renderToStaticMarkup(h(LoadingState, {}))).toContain('role="status"');
    expect(renderToStaticMarkup(h(EmptyState, { title: "No fixtures" }))).toContain('role="status"');
    const error = renderToStaticMarkup(h(ErrorState, { message: "Network error", onRetry: () => {} }));
    expect(error).toContain('role="alert"');
    expect(error).toContain("Try again");
  });

  it("uses semantic status tones and stat tiles", () => {
    expect(renderToStaticMarkup(h(StatusBadge, { tone: "active", children: "Active" }))).toContain("op-badge-active");
    expect(renderToStaticMarkup(h(StatTile, { value: 12, label: "Points", accent: true }))).toContain("op-stat-accent");
  });

  it("disables pagination at the boundaries and shows the range", () => {
    const html = renderToStaticMarkup(h(Pagination, { from: 1, to: 4, total: 10, hasPrevious: false, hasNext: true, onPrevious: () => {}, onNext: () => {} }));
    expect(html).toContain("1–4 of 10");
    expect(html.match(/disabled=""/g)).toHaveLength(1);
  });
});
