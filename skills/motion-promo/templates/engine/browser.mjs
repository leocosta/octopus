// Shared headless-browser helper. Reads promo.config from the target project.
// App-agnostic: authentication is delegated to config.authInject().
import puppeteer from "puppeteer-core";
import config from "../promo.config.mjs";

export async function launchBrowser() {
  return puppeteer.launch({
    executablePath: config.chromePath,
    headless: "new",
    // --no-sandbox is the accepted headless-as-root flag. Do NOT add
    // --disable-web-security — solve CORS by serving on an allow-listed origin.
    args: ["--no-sandbox", "--disable-dev-shm-usage", "--force-color-profile=srgb"],
  });
}

// Memoize the auth payload so many pages/beats cost ONE login (demo APIs
// commonly rate-limit /auth). Cleared per-process.
let _authPayload = null;
async function authPayload() {
  if (!_authPayload) _authPayload = await config.authInject();
  return _authPayload;
}

export async function newAuthedPage(browser, { viewport = "desktop" } = {}) {
  const payload = await authPayload();
  const page = await browser.newPage();
  await page.setViewport(config.viewports[viewport]);
  await page.evaluateOnNewDocument((p) => {
    for (const [k, v] of Object.entries(p.localStorage || {})) localStorage.setItem(k, v);
    for (const c of p.cookies || []) {
      const parts = [`${c.name}=${c.value}`, `path=${c.path || "/"}`, "max-age=31536000", "samesite=Lax"];
      document.cookie = parts.join("; ");
    }
  }, payload);
  return page;
}

// Navigate to a route and wait for REAL data, not just network-idle.
// networkidle2 can resolve before the app's first /api call lands → spinner shot.
export async function gotoReady(page, route, { waitFor = "main" } = {}) {
  await page.goto(config.appUrl + route, { waitUntil: "networkidle2" });
  if (waitFor) await page.waitForSelector(waitFor, { timeout: 15000 }).catch(() => {});
  await page.waitForResponse((r) => r.url().startsWith(config.apiUrl) && r.ok(), { timeout: 15000 }).catch(() => {});
  await new Promise((r) => setTimeout(r, 1800)); // settle data + intro animations
}
