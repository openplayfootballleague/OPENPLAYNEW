import { expect, test } from "@playwright/test";

test("public homepage loads with the Open Play identity", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/Open Play/i);
  await expect(
    page.getByRole("heading", { name: /YOUR GAME\. YOUR LEAGUE\./i }),
  ).toBeVisible();
  await expect(page.getByRole("link", { name: /FIND YOUR LEAGUE/i }).first()).toBeVisible();
});
