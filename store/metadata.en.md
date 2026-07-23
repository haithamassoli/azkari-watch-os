# App Store — Submission Data (en)

Complete, copy-paste-ready metadata for submitting **أذكار / Adhkar** to the App Store.
Char counts are shown as `(used/limit)`. Arabic-localization copy lives in `store/metadata.ar.md`.

> Submission is manual and not done yet. Two fields still need a real value before you can submit:
> **Support URL** and **Privacy Policy URL** (see "Action required" at the bottom).

---

## App information (set once, not per-version)

| Field | Value |
|---|---|
| Bundle ID | `com.haithamassoli.azkari.watchkitapp` |
| SKU | `azkari-watch-001` (any unique string; not shown to users) |
| Primary language | Arabic (ar) |
| Primary category | Lifestyle |
| Secondary category | *(none)* |
| Content rights | Does **not** contain, show, or access third-party content |
| Age rating | **4+** — answer "None" to every content question |
| Price | Free (all territories) |
| Version | 1.0 |
| Build | 1 |
| Copyright | `2026 Haitham Assoli` |

---

## English (U.S.) localization

Adding an English listing is optional but improves discoverability. Screenshots are the same Arabic-UI images (the app is Arabic-only) — that's expected and allowed.

### App name — (23/30)
```
Adhkar: Dhikr Reminders
```
*(Primary Arabic name is `أذكار` — see metadata.ar.md.)*

### Subtitle — (30/30)
```
Quiet dhikr reminders on Watch
```

### Promotional Text — (154/170)  *editable anytime without review*
```
Remember Allah throughout your day. A gentle tap on your wrist shows one dhikr, then clears itself — fully offline, no iPhone needed, easy on the battery.
```

### Description — (~1290/4000)
```
Adhkar keeps the remembrance of Allah present through your day — a standalone Apple Watch app that works entirely on your wrist, with no iPhone and no internet connection.

At an interval you choose, Adhkar taps your wrist and shows a single dhikr drawn from a library of twelve well-known remembrances. Each reminder arrives as a quiet notification — a haptic tap, no sound — and the app keeps your Notification Center tidy by clearing old reminders for you, so nothing piles up.

Everything is two taps away from the home screen:

• Choose your reminder interval — from every 15 minutes to every 4 hours
• Set quiet hours when no reminders arrive (default 10 PM – 7 AM)
• Pick exactly which of the twelve adhkar you want to receive
• Turn all reminders on or off with a single toggle

Built to stay out of your way:

• Fully offline — no network access, ever
• Negligible battery impact — no background workouts, no complications, no location
• Reminders keep running after your watch restarts, with nothing to reopen
• Arabic interface, designed right-to-left

No account. No sign-in. No tracking. Adhkar collects no data of any kind — every setting stays on your watch.

May it be a means of constant remembrance.
```

### Keywords — (98/100)  *comma-separated, no spaces*
```
dhikr,adhkar,tasbih,islam,muslim,zikr,remembrance,dua,istighfar,prayer,reminder,quran,sunnah,faith
```

### What's New — *first submission: leave blank* (required only for updates)

### Support URL — **ACTION REQUIRED** (required)
```
https://goldentik.com          ← confirm this resolves to a support page, or replace
```

### Marketing URL — *(optional, leave blank)*

---

## App privacy

- **Data collection: Data Not Collected.** No data types selected.
- **Privacy Policy URL — ACTION REQUIRED** (required for every app, even "Data Not Collected"):
  ```
  https://goldentik.com/privacy   ← must exist before submit; ask me to generate the page text
  ```

---

## Screenshots

Source: `store/screenshots/` (416×496 — Apple Watch Series 11, 46 mm). Reuse for both localizations.

| File | Shows |
|---|---|
| `m6-home.png` | Home: reminders toggle, interval, links to Adhkar & Quiet hours |
| `m6-adhkar.png` | Adhkar list with per-item toggles |
| `m6-adhkar-long.png` | Full wrapping of a long dhikr text |
| `m6-quiet.png` | Quiet hours start/end (Arabic numerals) |
| `check-longlook.png` | The reminder as it appears on the wrist |

---

## App Review information

| Field | Value |
|---|---|
| Sign-in required | No |
| Demo account | Not needed |
| Contact | sharedmail@goldentik.com |
| Notes | Standalone watchOS app, no iOS companion. On first enable it requests notification permission — grant it to see reminders arrive (default interval 1h; lower the interval in Settings to verify faster). No account, no network, no data collected. All settings persist on-device. |

---

## Action required before submit
1. **Support URL** — a reachable page (confirm `goldentik.com` or point elsewhere).
2. **Privacy Policy URL** — a reachable page. Ask me to draft the policy text if you need it.
3. Everything else above is final and within Apple's limits.
