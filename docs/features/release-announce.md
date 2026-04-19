# Release-Announce

Generate a themed release announcement kit for existing users from one
or more refs (tags, tag ranges, RM IDs). Produces a landing HTML page,
a slide deck, a plain notes file, and paste-ready messages for Slack,
Discord, email, in-app banner, status page, X/Twitter, and WhatsApp.

Distinct from `feature-to-market` — this one talks to people already
using the product. Different jobs, different tones.

## When to use

Right after you ship a version (or a cluster of RMs) and want to tell
your existing users what's new. Run it after `/octopus:release` has
tagged and written the CHANGELOG.

## Enable

```yaml
# .octopus.yml
skills:
  - release-announce

# Default theme for every run
theme: jade

# Default channel set when --channels is omitted
releaseChannels:
  - email
  - slack
  - in-app-banner
```

Or add `growth` to your bundles — `release-announce` ships there
alongside `feature-to-market`.

## Use

```
# default — since last tag, default channels, default theme
/octopus:release-announce

# specific version, pick a theme, include every channel
/octopus:release-announce v1.7.0 --theme=dark --channels=all

# single RM with editorial paper theme, email only
/octopus:release-announce RM-008 --theme=paper --channels=email

# multi-version bundle with developer audience
/octopus:release-announce v1.5.0..v1.7.0 --audience=developer

# synthesize a one-off theme via frontend-design
/octopus:release-announce v1.7.0 --design-from="retro arcade synthwave"
```

## Themes (v1)

| Name | Feel |
|---|---|
| `classic` (default) | Minimal newsletter — B&W + single accent |
| `jade` | Calm green, elegant typography |
| `dark` | Dark background, modern accent, high contrast |
| `bold` | Vibrant accents, large display typography |
| `newsletter` | Plain, high-density (more text per page) |
| `sunset` | Warm orange → pink, friendly serif display |
| `ocean` | Cool blues + white, professional calm |
| `terminal` | Green mono-on-black, dev-tool aesthetic |
| `paper` | Cream + warm browns + serif body, editorial feel |

## Custom themes with `--design-from`

When none of the presets fit, invoke `frontend-design` inline to
synthesize one from a free-form prompt:

```
/octopus:release-announce v1.7.0 --design-from="retro arcade synthwave"
```

The generated YAML lands at
`docs/release-announce/themes/retro-arcade-synthwave.yml`. Subsequent
runs reuse it via `--theme=retro-arcade-synthwave`.

## Output

Directory `docs/releases/YYYY-MM-DD-<slug>/` with:

- `README.md` — kit index
- `index.html` — themed landing page
- `notes.md` — plain markdown
- `theme.yml` — snapshot of the theme used
- `channels/email.html`, `channels/slack.md`, `channels/discord.md`,
  `channels/in-app-banner.md`, `channels/status-page.md`,
  `channels/x-announcement.md`, `channels/whatsapp.md`,
  `channels/slides.html` — paste-ready per-channel messages.

## Review before publishing

The kit is a draft. Always review copy against the actual release
scope before sending email to your base — the skill extracts
highlights from CHANGELOG + RMs but cannot know what you chose not
to ship.

The `README.md` in every kit has a review checklist for the final
pass.
