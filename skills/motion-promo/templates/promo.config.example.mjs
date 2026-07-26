// promo.config.mjs — lives in the TARGET repo (e.g. video/<slug>/), never in the skill.
// Everything project-specific is here; the engine + composition are app-agnostic.
export default {
  // ── App under test ───────────────────────────────────────────────────────
  // Origin the built app is served from. MUST be in the demo API's CORS
  // allow-list (probe it; do not disable web security). Serve a production
  // build pointed at the demo API before running the engine.
  appUrl: "http://localhost:8081",
  apiUrl: "https://demo-api.example.com", // used to wait for real data + CORS probe

  // ── Auth recipe (headless) ────────────────────────────────────────────────
  // Return the values to inject BEFORE first navigation so the app boots
  // authenticated. Adapt to the target app (token in localStorage, cookie, …).
  // `page` is a puppeteer Page; do whatever login the app needs and return the
  // init-script payload.
  async authInject() {
    // Example: exchange demo creds for a JWT, inject into localStorage + consent cookie.
    const res = await fetch(this.apiUrl + "/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "demo@example.com", password: "Demo@123" }),
    });
    const { accessToken, refreshToken } = await res.json();
    return {
      localStorage: { auth_token: accessToken, refresh_token: refreshToken },
      cookies: [{ name: "consent", value: encodeURIComponent(JSON.stringify({ analytics: true })), path: "/" }],
    };
  },

  // ── Viewports ─────────────────────────────────────────────────────────────
  viewports: {
    desktop: { width: 1920, height: 1080, deviceScaleFactor: 2 },
    mobile: { width: 440, height: 900, deviceScaleFactor: 2 },
  },

  // Note: beats.json highlight boxes can be `{selector, label, padding?}`
  // instead of manual x/y/w/h — capture.mjs measures the element's live rect
  // (pixel-perfect, no hand-tuning). Prefer it over manual coords.

  // ── Output ────────────────────────────────────────────────────────────────
  chromePath: "/usr/bin/google-chrome",
  fps: 30,
  slug: "promo",

  // ── Music ─────────────────────────────────────────────────────────────────
  // "auto" fetches a CC-BY track (records attribution) unless assets/music.mp3
  // already exists. Set to a local path or a direct URL to override.
  music: { source: "auto", startOffsetSec: 6, attributionRequired: true },

  // ── Design tokens ─────────────────────────────────────────────────────────
  // Left empty → extract-design.mjs samples them from the target app.
  // Set any key to hard-override a sampled token.
  design: {
    // bg: "#17191c", accent: "#70a23f", fg: "#f5f4f0",
    // fontHero: "'Bricolage Grotesque', sans-serif", fontMono: "'DM Mono', monospace",
  },
};
