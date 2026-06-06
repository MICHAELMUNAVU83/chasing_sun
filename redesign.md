# ChasingSun — UI Redesign Brief

## What We're Fixing

The current design has several patterns that make it feel generic and over-engineered:

- **Too many section labels.** Every card, panel, and section has an all-caps eyebrow label ("OPERATIONS PULSE", "LIVE ESTATE VIEW", "DAILY VISIT LOG") followed by a large heading, followed by a descriptive subtitle. That's three layers of titling before any content appears. Remove the eyebrow labels entirely — the headings speak for themselves.
- **Stat cards over-explain themselves.** Each stat card has a label, a number, and a prose sentence restating what the label already said. The prose subtitles ("Greenhouses in the current filtered view", "Units currently inside the harvest window") add no information. Replace them with a single short label beneath the number, or remove the subtitle entirely where the label is unambiguous.
- **Page headers are too verbose.** Pages open with a large title and a full sentence of explanation ("Track live crop status, expected weekly output, and the next set of greenhouse actions from one place."). Drop the subtitle paragraphs. If a page needs context, a single short sentence is the ceiling — not a marketing tagline.
- **Sidebar is crowded with metadata.** "SIGNED IN", "OPERATIONS", "ADMINISTRATION" section dividers, and "Log out" sitting at the bottom behind a button all make the sidebar feel like a settings panel. Simplify: show the user's name/email in a minimal avatar row, plain nav links with no category headers, and a small logout link — no button styles.
- **Rounded corners and colored top-borders on stat cards** look dated and inconsistent. Pick one card style and use it uniformly. Prefer a clean white card with a single subtle border or shadow — no gradient tops, no coloured accent bars.
- **Table "CYCLE OVERVIEW" column** embeds nested mini-cards (Plant Count, Weekly Yield) inside a table cell. This is visually noisy. Flatten it: show the key number inline in the cell, secondary info as a small muted line below it.
- **Status badges** ("HARVESTING", "NURSERY_PLANNING") use raw underscore casing from the database. Format them as human-readable: "Harvesting", "Nursery planning". Use a pill badge with a calm colour, not a bright teal block.

---

## Design Direction

**Tone:** Refined operational tool. Think Linear, Vercel dashboard, or Retool — clean, data-forward, confident. Not a marketing site, not a SaaS landing page.

**Palette:** Keep the earthy green brand colour (`#3d6b35` or similar) as the single accent. Everything else is neutral: white surfaces, `zinc-50` / `stone-50` background, `zinc-200` borders, `zinc-500` secondary text. No yellow accent bars. No olive/khaki backgrounds on stat sections.

**Typography:**

- Remove wide-tracked all-caps labels (`letter-spacing: 0.15em` on small text is a cliché). Use normal-weight small caps or simply a 12px medium-weight label in `zinc-400`.
- Page titles: one size, one weight. `text-2xl font-semibold` is enough — not `text-4xl`.
- Nav links: `text-sm text-zinc-600`, active state gets `text-zinc-900 font-medium` and a left border accent, no background pill.

**Spacing:** Increase breathing room. The current layout is compact. Add more vertical rhythm between sections (`gap-8` or `gap-10` between major blocks, not `gap-4`).

**Cards:** Flat white, `rounded-xl`, `border border-zinc-200`, subtle `shadow-sm`. No coloured top borders. No background tinting on the stat section.

---

## Page-by-Page Changes

### Sidebar (all pages)

- Remove "GREENHOUSE OPERATIONS" eyebrow above the logo — just show the logo mark + "ChasingSun".
- Remove "SIGNED IN" label. Show `admin@gmail.com` in a small avatar row at the top (or bottom) with a muted logout link, not a button.
- Remove "OPERATIONS" and "ADMINISTRATION" section dividers. Flat list of nav links.
- Active nav item: left border (`border-l-2 border-green-700`) + `text-zinc-900 font-medium`. No background highlight pill.

### Dashboard (`/dashboard`)

- **Remove:** "OPERATIONS PULSE" eyebrow label.
- **Remove:** subtitle paragraph under the page title.
- **Page title:** "Dashboard" or keep "Greenhouse control room" — one line, `text-2xl`.
- **Venture filter tabs:** Keep, but style as borderless tab pills — `text-sm`, active state underline or filled.
- **Stat cards:** Label on top (`text-xs text-zinc-400 uppercase tracking-wide`), large number, nothing else. The label is enough — delete the prose description line.
- **"LIVE ESTATE VIEW" / "Greenhouse status board":** Remove the eyebrow. Just use "Status board" as a plain `text-lg font-medium` heading.
- **"Manage greenhouses" link:** Move to an icon-button or plain text link next to the heading — don't style it as the primary green colour if it's a secondary action.
- **Status board table:** Remove nested mini-cards in "Cycle Overview". Show `1,000 plants · 400 kg/wk` as two lines of plain text in the cell.
- **Status badge:** `HARVESTING` → `Harvesting` — small pill, `bg-green-50 text-green-700 border border-green-200`.

### Recommendations (`/recommendations`)

- **Remove:** "CROP PLANNING" eyebrow.
- **Remove:** subtitle paragraph.
- **Page title:** "Crop recommendations" — `text-2xl font-semibold`.
- **Stat cards:** Same as dashboard — label + number only, drop the prose line.
- **"RECOMMENDED ROTATIONS" / "Next crop by greenhouse":** Remove the eyebrow. Section heading: "Next crop" — plain.
- **"Updated 06 Jun 2026":** Keep as a muted timestamp next to the heading (`text-xs text-zinc-400`).
- **Greenhouse rotation cards:** Clean two-column layout — current crop on left, recommended next on right. Remove the nested card-within-card treatment. Use a simple `→` or divider.
- **`NURSERY_PLANNING` badge:** → "Nursery planning" — same pill style as above.
- **Planning alerts sidebar:** Remove "PLANNING ALERTS" eyebrow and "Notifications tied to the plan" heading — just render the list of alert items with a date stamp. The content is self-explanatory.

### Visits (`/visits`)

- **Remove:** "DAILY VISIT LOG" eyebrow.
- **Remove:** subtitle paragraph ("Capture water reserve checks, greenhouse condition...").
- **Page title:** "Farm visits" — `text-2xl font-semibold`.
- **Stat cards (3-up row):** Label + number + one short label below (e.g., "Recent reports / 0 / Last 30 days"). Drop the prose lines.
- **"QUICK ACTIONS" panel:**
  - Remove "QUICK ACTIONS" eyebrow.
  - Remove explanatory paragraph ("The form opens with one observation row for every registered greenhouse.").
  - Keep just the "New visit report" button. The button label is already self-explanatory.
  - The note "One saved report is kept per visit date, so reopening today updates today's record" — if it must stay, render it as a single `text-xs text-zinc-400` line, not a styled callout box.
- **"VISIT HISTORY" / "Saved farm visits":** Remove the eyebrow. Heading: "Visit history".
- **"9 greenhouse rows per new report"** caption in top-right: remove — this is implementation detail noise.
- **Empty state:** "No farm visit reports have been saved yet." — fine, keep as-is but centre it and add a muted icon.

---

## Tailwind Implementation Notes (Phoenix LiveView)

- Background: `bg-stone-50` on `<body>`, `bg-white` on content panels and cards.
- Sidebar: `bg-white border-r border-zinc-200 w-56` — reduce from current width, no background tinting.
- Stat cards: `bg-white border border-zinc-200 rounded-xl p-5 shadow-sm` — uniform across all pages.
- Section headings: `text-lg font-semibold text-zinc-900` with no eyebrow label above them.
- Eyebrow labels (if kept at all): `text-xs font-medium text-zinc-400 uppercase tracking-wide mb-1` — but the preference is to remove them.
- Venture filter buttons: `text-sm px-3 py-1.5 rounded-full`, active: `bg-green-700 text-white`, inactive: `border border-zinc-300 text-zinc-600 hover:border-zinc-400`.
- Table: `text-sm`, header row `text-xs text-zinc-400 uppercase tracking-wide border-b border-zinc-200`, rows `border-b border-zinc-100 py-3`.
- Primary button: `bg-green-700 hover:bg-green-800 text-white text-sm font-medium px-4 py-2 rounded-lg`.
- Status pill: `inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium` with colour by status (harvesting = green, planning = amber, soil turning = zinc).

---

## What to Preserve

- The colour palette direction (earthy green + warm neutrals) is good — just stop using the yellow/olive as a background tint.
- The logo mark and "ChasingSun" wordmark.
- The venture filter tab pattern.
- The two-column layout on Recommendations (rotation list + alerts sidebar).
- All the data and functional elements — this is purely a visual/copy trim.

---

## Summary Checklist for Claude Code

- [ ] Remove all eyebrow labels ("OPERATIONS PULSE", "LIVE ESTATE VIEW", etc.)
- [ ] Remove subtitle/description paragraphs from all page headers
- [ ] Stat card subtitles: delete prose lines, keep label + number only
- [ ] Sidebar: remove section dividers, simplify auth row, flatten nav
- [ ] Unify card style: white, `border border-zinc-200`, `rounded-xl`, `shadow-sm`
- [ ] Remove coloured top-border accents from stat cards
- [ ] Remove olive/khaki background from stat section wrapper
- [ ] Status badges: human-readable text, calm pill style
- [ ] Flatten "Cycle Overview" nested cards into inline cell text
- [ ] Remove "Quick Actions" eyebrow + explanatory paragraph on Visits page
- [ ] Remove "9 greenhouse rows per new report" caption
- [ ] Remove "Notifications tied to the plan" heading on Recommendations page
- [ ] Increase vertical spacing between major sections
- [ ] Nav active state: left border accent, no pill background
