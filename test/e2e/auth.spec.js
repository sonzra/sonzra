import { expect, test } from "@playwright/test"

test.describe("Authentication flow", () => {
  test("redirects unauthenticated users to the sign-in page", async ({ page }) => {
    await page.goto("/")
    await expect(page).toHaveURL(/\/session\/new/)
    await expect(page.locator("h1, .auth-sign-in-copy")).toContainText("Sign in to your personal music library.")
    await expect(page.locator("input[name='email_address']")).toBeVisible()
    await expect(page.locator("input[name='password']")).toBeVisible()
    await expect(page.locator("button, input[type='submit']", { hasText: "Sign in" })).toBeVisible()
  })

  test("shows error flash when entering invalid credentials", async ({ page }) => {
    await page.goto("/session/new")
    await page.fill("input[name='email_address']", "invalid@example.com")
    await page.fill("input[name='password']", "wrongpassword")
    await page.click("input[type='submit']")

    await expect(page).toHaveURL(/\/session\/new/)
    await expect(page.locator(".auth-flash--alert")).toContainText("Try another email address or password.")
  })

  test("successfully signs in with valid credentials and preserves persistent player shell", async ({ page }) => {
    await page.goto("/session/new")
    await page.fill("input[name='email_address']", "one@example.com")
    await page.fill("input[name='password']", "password")
    await page.click("input[type='submit']")

    // Should redirect to root home page
    await expect(page).toHaveURL("/")

    // Persistent player container must exist in the DOM with data-turbo-permanent
    const player = page.locator("#player")
    await expect(player).toHaveAttribute("data-turbo-permanent", "")

    // Top navigation should be visible
    await expect(page.locator("header")).toBeVisible()
  })
})
