# Handoff: CF/OBSERVER — "Frontpage" redesign

## Overview
This package is the visual + interaction spec for redesigning **CF/OBSERVER**, the ColdFusion / CFML / Lucee job-intelligence app, into the **"Frontpage"** direction: an editorial, bold, color-blocked job board for CF job-seekers with India-eligibility + global-remote scoring.

It covers the full product surface: a daily **briefing** landing, a filterable **board**, **job detail**, **companies** + **company detail**, **alerts**, **pipeline health**, **discovery network**, **settings**, and **saved** roles — plus a working **apply flow** and a "visited-link" treatment for applied roles.

## About the design files
The files in this bundle are **design references created in HTML/React (JSX via in-browser Babel)** — a clickable prototype showing the intended look and behavior. **They are not production code to copy directly.**

The task is to **recreate these designs in the existing application environment**: the **Adobe ColdFusion 2025 / CFML codebase** (`wwwroot/index.cfm`, the `includes/layout*.cfm` partials, and `assets/cf-observer.css`), using its established server-rendered, ColdFusion-**tag-syntax** patterns (no `cfscript`). The current app already uses Tailwind via CDN + a small CSS file; you can keep that approach or move the tokens below into `cf-observer.css`. The JSON APIs (`api/jobs.cfm`, `api/companies.cfm`, `api/alerts.cfm`) and services already supply the data — wire the new markup to the same `application.jobService` / `companyService` / `alertService` calls the current `index.cfm` uses.

If you instead want to stand this up as a standalone SPA, the JSX files are a working React reference you can adapt.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, components, and interactions are all specified below and present in the prototype. Recreate the UI faithfully. Exact hex values, fonts, and pixel measurements are given in **Design Tokens**.

---

## Design Tokens

### Color (CSS custom properties — see `fp-ui.jsx` `:root`)
| Token | Value | Use |
|---|---|---|
| `--fp-cream` | `#f3efe4` | Page background (warm off-white) |
| `--fp-paper` | `#ffffff` | Card backgrounds |
| `--fp-ink` | `#141412` | Text, 2px borders, "Get alerts" button |
| `--fp-mute` | `#6c685c` | Secondary text, labels |
| `--fp-accent` | `#0e93de` | **ColdFusion cerulean** — primary signifier: buttons, score badges, "remote" pill, links, active chips, sliders |
| `--fp-accent-ink` | auto (`#f3efe4` on dark accents, `#141412` on light) | Text/icon color **on** the accent. Computed by relative luminance (>0.45 → ink, else cream) |
| `--fp-accent2` | `#e5322b` | **Adobe red** — sparing secondary: the `/` in the wordmark, the headline period, unread/notification dots |
| `--fp-deep` | `#0a1e3a` | **ColdFusion deep navy** — hero block + pipeline status banner backgrounds |
| `--fp-visited` | `color-mix(in srgb, var(--fp-accent) 40%, #837f76)` ≈ `#54809f` | Dimmed "applied/visited" tone for applied role titles + the "Applied ✓" button |
| `--fp-soft` | `color-mix(in srgb, var(--fp-accent) 16%, #fff)` | Soft accent tint: highlight tiles, "why it scored" chips |
| `--fp-radius` | `0px` (default) or `12px` | Corner radius. "sharp" is the identity; "soft" is a Tweak option |

> The brand identity is the **blue + red duo** = "Adobe ColdFusion." Blue is the product color and does ~95% of the work; red is a 2–3-spot accent only. Don't overuse red.

### Typography
- **Display:** **Bricolage Grotesque**, weight **800**, `letter-spacing: -0.02em`, `line-height: 1.05`. Used for all headings, the wordmark, score numbers, big stats. (`.fp-disp`)
- **Body / UI:** **Archivo**, weights 400/500/600/700/800. (`.fp-body`)
- **Kicker label** (`.fp-kick`): Archivo 700, `11px`, `letter-spacing: .16em`, `text-transform: uppercase`, color `--fp-mute`.
- Google Fonts import: `Archivo:wght@400;500;600;700;800` and `Bricolage+Grotesque:opsz,wght@12..96,400..800`.
- Headline sizes use `clamp()` for responsiveness, e.g. hero `clamp(44px,7vw,86px)`, page titles `clamp(28px,4vw,38px)`.

### Borders, shadows, motion
- **Borders:** `2px solid var(--fp-ink)` everywhere (cards, buttons, chips, inputs, badges). This is core to the look.
- **Card hover (clickable):** `transform: translate(-3px,-3px)` + hard shadow `6px 6px 0 var(--fp-ink)`, `transition .18s cubic-bezier(.2,.7,.3,1)`.
- **Button hover:** `transform: translate(-2px,-2px)` + `4px 4px 0 var(--fp-ink)`.
- **Route transition:** opacity-only fade `fp-enter .3s ease-out` on the view container, re-keyed per route. (Opacity only — do NOT add transform; it breaks some renderers.)
- **Toast:** slides up `fp-toast-in .3s`.
- **Apply modal:** `fp-pop .3s` (fade + slight rise + scale).
- **Success check:** SVG stroke-dashoffset draw-on, `fp-check .5s ease`.
- **Spinning seal** (hero): `fp-spin 22s linear infinite`.
- All decorative motion is wrapped in `@media (prefers-reduced-motion: reduce)` (disabled there).

### Spacing
- Page content max width **1200px**, side padding **28px** desktop / **18px** mobile (`.fp-wrap`).
- Card grids: `.fp-grid-3` (3 cols → 2 at ≤900px → 1 at ≤620px), gap **16px**.
- Card padding 22px (26px for "big" cards). Section header gap 16px with a 2px ink rule filling remaining width.

---

## Screens / Views

### 1. Top navigation (persistent) — `TopNav`
- Sticky, `--fp-cream` bg, **2px ink** bottom border, height **64px**.
- Left: wordmark **CF/OBSERVER** in Bricolage 20px — the **`/` is `--fp-accent2` (red)**.
- Nav links (Bricolage-less, `.fp-link` underline-on-hover/active in accent): **Today · Board · Companies · Alerts · Pipeline · Network**. The **Alerts** link shows a small **red** dot when there are unread alerts.
- Right: a search input (168px), a **Saved** pill (heart + count, fills accent when count>0), a **gear** (Settings), and a black **"Get alerts"** button.
- Below **1080px** the links + search + gear + button collapse into a hamburger menu (search + all links + Settings + Get alerts).

### 2. Today / Briefing (default) — `Briefing`
- **Hero block:** full-width `--fp-deep` (navy) band, `--fp-cream` text.
  - Kicker (accent): "The daily ColdFusion frontpage · 14 Jun 2026".
  - Headline (Bricolage, `clamp(44px,7vw,86px)`): "47 fresh / CF roles / **worth a look·**" — "worth a look" in accent, the **period in red (`--fp-accent2`)**.
  - Right: rotating circular **seal** (132px) with `textPath` reading "INDIA-ELIGIBLE · GLOBAL REMOTE · CFML · LUCEE ·" in accent, "NEW" in the center; spins 22s.
  - **Top-match strip:** transparent card (cream border) with a large 78px score badge, "Top match today", the role title + company, and an **Apply now →** button (opens the apply modal). If already applied, the button is the visited variant "Applied ✓".
- **More on the board:** section header + `.fp-grid-3` of the next 6 roles (first one "big"). "See all →" → Board.
- **By the numbers:** a 4-cell bordered strip — Indexed `1,284`, **New today `+47` (number in red)**, Eligible 70+ `312`, Live sources `22`.
- **Sources strip:** "Reading from 22 sources" + chips of each source name.

### 3. Board — `Board` + `FilterBar`
- **Sticky filter bar** (under nav, top:64): work-type chips **All / Remote / Hybrid / Onsite**, a divider, score chips **Any score / 70+ / 85+**, an **India-eligible ✓** toggle chip, then a right-aligned result count "N of 14" and a **Sort** select (match score / newest). Active chips = accent fill (`.fp-chip--on`).
- **Results:** `.fp-grid-3` of `JobCard`s. Every 7th card is "big" (shows summary text).
- **Empty state** (`EmptyState`): when filters match nothing — search-circle icon, "No roles match those filters", body, and a **Reset filters** button.
- **Loading state** (`LoadingGrid`): 6 shimmer-skeleton cards (`.fp-skel`) shown ~480ms after navigating to the board.
- **Company filter banner:** when arriving via a company, shows "Filtered to [Company ✕]" with a Clear link.

### 4. JobCard (component) — used on Briefing, Board, Saved, Company, Related
- 2px ink card, clickable (hover lift). Top row: **work pill** (left) + **score badge** (right). Then the **title** (Bricolage, 22px / 29px big). Big cards add a 1–2 line summary. Bottom row: company (700) + location · age (mute), and a heart **Save** button.
- **Applied (visited) state:** if the role is applied, the **title color becomes `--fp-visited`** (dimmed blue-grey) — like a visited link. No badge. Everything else unchanged.

### 5. Job detail — `JobDetail`
- "← Back to board" link.
- Two columns (1fr / 320px; stacks under 820px).
- **Main:** a header card (work pill, title `clamp(28px,4vw,40px)`, company — location · posted, and stack tags as `StackTag` chips). Then an "About the role" card: description paragraphs, then "Why it scored N" — a 2-col grid of `--fp-soft` chips each with a ✓ and a highlight.
- **Sidebar (sticky, top:84):** a card with **Apply now →** (accent; or visited "Applied ✓" if applied — both open the modal), a row of **Save** / **Alert me** ghost buttons, and a meta list (Match score, Work type, Location, Compensation, Source) — labels are kickers, values bold right-aligned.
- **Related roles:** up to 3 `JobCard`s from the same company or region.

### 6. Apply flow (modal) — `ApplyModal`
- Opened from any "Apply now". Portal overlay: `rgba(10,30,58,0.5)` + `backdrop-filter: blur(6px)`. Centered card (max 520px), `--fp-cream` bg, hard shadow `8px 8px 0 var(--fp-deep)`, `fp-pop` entrance. Esc or backdrop closes.
- **Step 1 (review):** kicker "Apply · [Company]", role title + location · match, a ✕ close. Form: **Full name** (prefilled), **Email** (prefilled), **Note to the team** (textarea). Buttons: **Submit application →** (accent) + **Posting ↗** (ghost). Small disclaimer.
- **Step 2 (sent):** accent circle with an animated drawn **check**, "Application sent", body naming the company, **Done** button. On submit the role is added to the `applied` set (persisted) → its cards + detail button switch to the visited treatment.

### 7. Companies — `Companies`
- Title "Companies hiring CF" + "{n} employers · sorted by match score".
- `.fp-grid-3` of clickable company cards: monogram circle (first letter) + score badge, name (Bricolage 22), "sector · via source", and bottom "N open roles" + "View →". Click → Company detail.

### 8. Company detail — `CompanyDetail`
- "← Companies" link. Header card: 72px monogram, name `clamp(28px,4vw,40px)`, "sector · discovered via source", **View all roles →** (filters the board to this company) + **Back to companies**, and a 72px score badge.
- 3 stat cards: Open roles / Avg match / Sources. Then "Open roles at [Company]" → grid of that company's `JobCard`s (empty state if none).

### 9. Alerts — `Alerts`
- Title "Your alerts" + "{n} matches pushed · {unread} unread".
- Two columns (1fr / 300px). **Left:** alert rows (clickable → detail): score badge, **red unread dot** (if unread) + role title, company · location, and right-aligned channel + sent time. **Right:** an "Active rules" card (rule labels with on-style toggle pills) + a "Delivery" soft card ("pushed daily at 06:00").

### 10. Pipeline health — `Pipeline`
- Title "Pipeline health" + subtitle.
- **Status banner:** `--fp-deep` navy card — accent dot, "Pipeline healthy", "Last run … · finished in 2m 16s", "Next scrape", and a **Run now →** button.
- **Run phases:** a 5-column bordered grid (→ 2 cols ≤880px → 1 ≤520px). Each phase: "Step N", label, a **status pill** (OK = accent, WARN = `#ffd24a`, FAILED = `#ff6a3d`; all ink text + ink dot), a big volume number, a note, and the sync time.
- **Source health:** "{n} live sources" + `.fp-grid-3` of source cards (status pill, name, "+N rows · time" or note, and the count).

### 11. Network / Discovery — `Network`
- Title "Discovery network" + "Who the web is associating with CF / Lucee".
- A `--fp-soft` info card: "These are **leads, not postings** … Confirmed postings live on the Board."
- A list of signal rows: monogram, company (Bricolage 19) + signal description, "source · age", a **confidence bar** (90px, accent fill over ink-bordered track + "N% conf."), and a **Track** ghost button.

### 12. Settings — `Settings`
- Title "Settings" + subtitle. Auto-fit columns (min 300px).
- **Alert rules** card: rule rows with working **toggle** switches (accent when on; ink knob), then a "Minimum score" row with a big number + a range slider (`accent-color: var(--fp-accent)`).
- **Delivery channels** card: Email / Telegram / Browser push toggles + a soft note card.
- **Saved searches** card: rows of saved queries with a "Run →" link; and an **Account** card: monogram (accent), name/email, **Save preferences** button.

### 13. Saved — `Saved`
- Reached via the nav heart. Title "Saved roles" + count. Grid of saved `JobCard`s, or an empty state ("Nothing saved yet" → "Browse the board").

---

## Interactions & Behavior
- **Navigation:** single-page; nav swaps the active view and scrolls to top. Board navigation shows skeletons for ~480ms (simulated load).
- **Search:** the nav search filters the board live (title, company, location, stack, summary). Focusing it from another view routes to the board.
- **Filters:** work-type, min-score, and India-eligible (= score ≥ 70) chips filter the board; sort by match score or newest. Active chips fill accent.
- **Save (bookmark):** heart toggles a role into `saved` (persisted to `localStorage` key `fp-saved-roles`); nav heart shows the count; Saved view lists them; toast confirms.
- **Apply:** "Apply now" → 2-step modal → on submit, role added to `applied` (persisted `fp-applied-roles`), toast "Application sent ✓".
- **Visited treatment:** applied roles show the `--fp-visited` color on their **card title** and the detail/briefing **Apply button** ("Applied ✓"); no separate badge.
- **Company → board:** "View all roles" sets the company filter and routes to the board; a banner offers Clear.
- **Tweaks panel:** (prototype-only host feature) lets you switch the **accent** swatch (CF blue / lime / coral / violet — `--fp-accent-ink` auto-recomputes for contrast) and **corners** (sharp / soft → `--fp-radius`). In the real app, expose these as theme settings only if desired.
- **Responsive:** ≤1080px nav collapses to a menu; grids reflow 3→2→1; detail + alerts columns stack at 820px; pipeline phases reflow.
- **Reduced motion:** all hover lifts, fades, spin, and pop animations are disabled under `prefers-reduced-motion: reduce`.

## State Management
Client state in the prototype (`fp-app.jsx`) — in the CFML app most of this maps to URL params + server rendering, with small JS for the rest:
- `view`, `selId` (selected job), `selCompany` — routing/selection → URL/anchors in CFML.
- `query`, `filters` `{ work, minScore, eligible, companyId }`, `sort` → already URL params in current `index.cfm` (`keyword`, `min_score`, `work_type`, `source`, `company_id`, sort params).
- `saved` `Set` + `applied` `Set` → persisted in `localStorage` (client-only feature); or persist server-side per user if accounts exist.
- `loading` (board skeleton), `toast`, `applyTarget` (modal) — pure client UI state.
Data comes from the existing services/APIs; scoring rules (0–100; 70+ = India-eligible/global-remote) are unchanged.

## Assets
- **Fonts:** Google Fonts — Archivo, Bricolage Grotesque. No icon font; all icons are inline SVG (search, gear, heart, arrows, check). No raster images — monograms are the company's first letter in a bordered circle. The rotating seal is inline SVG `textPath`.
- No third-party logos are used. **Do not** reproduce Adobe's actual "Cf" product logo — only the color language (CF blue + Adobe red) is referenced.

## Files (in this bundle)
- `CF Observer Frontpage.html` — entry point; loads React 18 + Babel + the modules below.
- `fp-data.jsx` — sample data: `JOBS`, `COMPANIES`, `ALERTS`, `ALERT_RULES`, `SOURCES`, `STATS`, `PIPELINE`, `SOURCE_HEALTH`, `DISCOVERY`, `scoreTone()`.
- `fp-ui.jsx` — design tokens (`:root`), the global stylesheet, and presentational components: `ScoreBadge`, `WorkPill`, `StackTag`, `SaveButton`, `HeartIcon`, `JobCard`, `Toast`, `useIsMobile`.
- `fp-views.jsx` — `TopNav`, `Briefing`, `Board`, `FilterBar`, `JobDetail`, `Companies`, `Alerts`, `Saved`, states.
- `fp-views2.jsx` — `CompanyDetail`, `Pipeline`, `Network`, `Settings`.
- `fp-apply.jsx` — `ApplyModal` (apply flow).
- `fp-app.jsx` — app shell: state, filtering, routing, theme tokens, render.
- `tweaks-panel.jsx` — the prototype's Tweaks host wiring (not needed in production).

### In your codebase (recreate here)
- `wwwroot/index.cfm` — main dashboard; rework its markup to the Briefing + Board structure.
- `wwwroot/includes/layoutHead.cfm`, `layoutSidebar.cfm`, `layoutTopbar.cfm`, `layoutFoot.cfm` — the chrome; replace sidebar/topbar with the new `TopNav`.
- `wwwroot/assets/cf-observer.css` — move the design tokens + component classes here.
- `wwwroot/discovery-signals.cfm` — the Network/Discovery page.
- `wwwroot/api/*.cfm`, `services/*.cfc` — unchanged data sources to bind the new views to.
