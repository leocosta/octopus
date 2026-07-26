// Shared headless-browser helper. Reads promo.config from the target project.
// App-agnostic: authentication is delegated to the config. Two styles:
//   - config.authInject(): return { localStorage?, sessionStorage?, cookies? }
//     to inject before navigation (token-in-storage / cookie / API-key apps).
//   - config.authFlow(page, { appUrl }): DRIVE the login UI in the browser
//     (interactive SSO — e.g. Azure AD). The engine then snapshots the resulting
//     session (localStorage + sessionStorage + cookies, incl. HttpOnly) and
//     injects it into every subsequent page. Use this when there is no way to
//     obtain a token programmatically.
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

// One login per process (demo APIs / IdPs commonly rate-limit). The payload is
// { localStorage, sessionStorage, cookies } regardless of which style produced it.
let _payload = null;
async function ensurePayload(browser) {
  if (_payload) return _payload;
  if (typeof config.authFlow === "function") {
    // Interactive login: drive it on a bootstrap page, then snapshot the session.
    const boot = await browser.newPage();
    await boot.setViewport(config.viewports.desktop);
    await config.authFlow(boot, { appUrl: config.appUrl });
    const storage = await boot.evaluate(() => ({
      localStorage: Object.fromEntries(Object.entries(localStorage)),
      sessionStorage: Object.fromEntries(Object.entries(sessionStorage)),
    }));
    const cookies = await boot.cookies(); // includes HttpOnly session cookies
    await boot.close();
    _payload = { ...storage, cookies };
  } else if (typeof config.authInject === "function") {
    _payload = (await config.authInject()) || {};
  } else {
    _payload = {};
  }
  return _payload;
}

export async function newAuthedPage(browser, { viewport = "desktop" } = {}) {
  const payload = await ensurePayload(browser);
  const page = await browser.newPage();
  await page.setViewport(config.viewports[viewport]);

  // Cookies via the jar (handles HttpOnly + explicit domains from a snapshot;
  // domain-less cookies from authInject get the app origin as their url).
  const cookies = (payload.cookies || []).map((c) =>
    c.domain ? c : { name: c.name, value: c.value, url: config.appUrl, path: c.path || "/" }
  );
  if (cookies.length) await page.setCookie(...cookies).catch(() => {});

  // localStorage + sessionStorage before any page script runs.
  await page.evaluateOnNewDocument(
    (ls, ss) => {
      try { for (const [k, v] of Object.entries(ls || {})) localStorage.setItem(k, v); } catch {}
      try { for (const [k, v] of Object.entries(ss || {})) sessionStorage.setItem(k, v); } catch {}
    },
    payload.localStorage || {},
    payload.sessionStorage || {},
  );
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
