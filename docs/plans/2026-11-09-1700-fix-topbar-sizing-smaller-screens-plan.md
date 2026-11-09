# Plan: Fix Top Bar Sizing and Overflow on Mid-Sized Screens (Issue #2)

## 1. Executive Summary & Problem Statement

### Problem
On mid-sized viewports between `701px` and `1024px` (such as tablets in portrait or landscape mode, split-screen desktop windows, and smaller laptop displays), Sonzra's redesign top navigation bar suffers from severe layout crowding, component collision, and horizontal clipping:

1. **Premature Desktop Layout on Tablets**: The mobile hamburger drawer only activates at `@media (max-width: 700px)`. Viewports between `701px` and `1024px` are forced into the full 3-column desktop layout (`grid-template-columns: 1fr auto 1fr`).
2. **Horizontal Grid Overflow & Clipping**: The unclipped content footprint of the desktop top bar columns is **~1036px** (Brand `~120px` + 5 Primary Links `~509px` + Actions cluster `~343px` + clamp padding `44px–64px`). On viewports $\le 1000\text{px}$, the columns collide and the right-aligned actions cluster (`.redesign-topbar__actions`) is pushed out of the viewport. At `768px` (iPad portrait), the actions container overflows by `133px`, rendering the user profile menu button **completely off-screen and invisible**.
3. **Search Shortcut Badge Vertical Wrapping**: `.redesign-icon-button kbd` lacks `white-space: nowrap`. On screens $\le 1024\text{px}$, the space between `⌘` and `K` breaks onto two vertical lines (`⌘` stacked over `K`), distorting button height and appearance.
4. **Collision with Center Navigation**: The search trigger button is squeezed flush against the center primary navigation ("Downloads") with zero breathing room.

---

## 2. Architectural & UI/UX Advisor Scoping

### UI/UX Advisor Budgeting (`ui-ux-advisor`)
According to `docs/guidelines/ui_ux.md` (§4 Layout Architecture & Responsive Breakpoints), Sonzra formally defines three responsive tiers:
- **Mobile ($\le 700\text{px}$)**: Sticky compact topbar, hamburger drawer, bottom navigation, mini-player.
- **Tablet ($701\text{px} - 980\text{px}$)**: Centered pill nav, 4-column shelves/grid, modal dialogs.
- **Desktop ($> 980\text{px}$)**: Full pill navigation, 5-column shelves, 3-column floating player.

While the shelves and player correctly adapt at `@media (max-width: 980px)`, the top bar was never given tablet-tier adaptations.

#### Geometry Budget Calculation:
- **Available Width at `768px`** (iPad portrait): $768\text{px} - 2 \times 22\text{px}\text{ (padding)} = 724\text{px}$.
- **Proposed Tablet Adaptations ($701\text{px} - 980\text{px}$)**:
  - **Brand**: $32\text{px}\text{ mark} + 9\text{px}\text{ gap} + \text{"sonzra" } (~70\text{px}) = \mathbf{115\text{px}}$.
  - **Primary Navigation**: On tablet, transition `.redesign-topbar__link` to icon-only mode with text visually hidden (`.redesign-topbar__link span { display: none; }`).
    - 5 icon links: $5 \times 38\text{px} + 4 \times 3\text{px}\text{ gap} + 8\text{px}\text{ padding} + 2\text{px}\text{ border} = \mathbf{212\text{px}}$.
    - `aria-label` preserved on each link for complete accessibility.
  - **Actions Cluster**:
    - Search button: hide `<kbd>⌘ K</kbd>` badge on tablet (`display: none;`), transforming into an ergonomic $38\times 38\text{px}$ icon button ($38\text{px}$).
    - Server pill: hide text on tablet $\le 980\text{px}$ (`display: none;`) as server switching is already present in the profile menu.
    - Profile toggle: icon-only button on tablet $\le 980\text{px}$ (`.redesign-profile__toggle span { display: none; }`) ($38\text{px}$).
    - Actions width: $38\text{px} + 9\text{px}\text{ gap} + 38\text{px} = \mathbf{85\text{px}}$.
  - **Total Tablet Content Footprint**: $115\text{px} + 212\text{px} + 85\text{px} = \mathbf{412\text{px}}$.
  - **Remaining Free Space at `768px`**: $724\text{px} - 412\text{px} = \mathbf{312\text{px}}$ of generous breathing room. Zero collision, zero overflow, 100% visibility for all controls.

### Architectural Advisor Invariants (`architect-advisor`)
- **Single Stylesheet Theme**: All style changes are made solely inside `app/assets/stylesheets/redesign.css`. No legacy classes or external stylesheets are introduced.
- **Hotwire & Stimulus Continuity**: No changes to Stimulus controllers or Turbo frames are required; existing `data-action="library-search#open"` and `data-action="profile-menu#toggle"` remain fully intact.
- **Backend & Hexagonal Boundaries**: Unaffected (view markup and CSS only).

---

## 3. Detailed Technical Changes

### Phase A: Badge Formatting & Container Robustness (Global)
1. **Prevent `<kbd>` Badge Vertical Wrap**:
   In `app/assets/stylesheets/redesign.css`:
   - Add `white-space: nowrap;` and `flex-shrink: 0;` to `.redesign-icon-button`.
   - Add `white-space: nowrap;` to `.redesign-icon-button kbd`.
2. **Top Bar Grid & Containment**:
   - Ensure `.redesign-topbar__actions` has `min-width: 0;` and `flex-shrink: 0;`.
   - Ensure `.redesign-topbar` columns prevent blowout (`grid-template-columns: minmax(max-content, 1fr) auto minmax(max-content, 1fr);`).

### Phase B: Tablet Tier Adaptations (`@media (max-width: 980px)`)
In `app/assets/stylesheets/redesign.css` inside the existing `@media (max-width: 980px)` block:
1. **Search Trigger**:
   - Hide the `<kbd>` badge: `.redesign-search-trigger kbd { display: none; }`.
   - Ensure minimum icon touch target: `width: 38px; height: 38px; justify-content: center; padding: 0;`.
2. **Server Pill**:
   - Hide `.redesign-server-pill { display: none; }` on tablet viewports $\le 980\text{px}$.
3. **Profile Menu Toggle**:
   - Hide the email/username text: `.redesign-profile__toggle span { display: none; }`.
   - Style profile toggle as a square icon button: `width: 38px; height: 38px; justify-content: center; padding: 0;`.
4. **Primary Navigation Links**:
   - Hide text labels: `.redesign-topbar__link span { display: none; }`.
   - Style links as icon buttons: `width: 38px; height: 38px; justify-content: center; padding: 0;`.
   - Add `aria-label` directly on the link elements in `app/views/shared/_navigation.html.erb` so screen readers retain full label context.

### Phase C: Small Desktop Optimization (`@media (max-width: 1100px)`)
- Between `981px` and `1100px`, constrain the server pill to prevent text overflow:
  `.redesign-server-pill { max-width: 120px; }`.

---

## 4. Implementation Steps (TDD & Execution)

### Step 1: Automated Test Suite (Vitest / Playwright)
- Add Playwright E2E tests in `test/e2e/topbar_responsive.spec.js` checking:
  - At `1440px` (desktop): primary nav text is visible, `<kbd>` badge is visible, server pill is visible, profile username is visible.
  - At `1024px` (small desktop): `<kbd>` badge does not wrap vertically (`getBoundingClientRect().height <= 24px`), no horizontal page overflow.
  - At `768px` (iPad portrait):
    - Top bar bounding box `right <= 768px`.
    - Profile toggle is visible within viewport (`getBoundingClientRect().right <= 768px`).
    - Search button is visible and clickable (`data-action="library-search#open"` opens search dialog).
    - Primary links are clickable and navigate to correct routes.
    - Zero horizontal document scrolling (`document.body.scrollWidth === window.innerWidth`).
  - At `390px` (mobile): mobile menu toggle is visible, desktop actions are hidden.

### Step 2: View & Stylesheet Updates
1. Edit `app/views/shared/_navigation.html.erb`:
   - Add `aria: { label: label }` to `.redesign-topbar__link` so icon-only tablet navigation remains fully accessible.
2. Edit `app/assets/stylesheets/redesign.css`:
   - Add `white-space: nowrap` and `flex-shrink: 0` to `.redesign-icon-button` and `.redesign-icon-button kbd`.
   - Add tablet tier rules in `@media (max-width: 980px)`.
   - Add small desktop constraints in `@media (max-width: 1100px)`.

### Step 3: Visual Verification & Multimodal Inspection Gate
- Capture screenshots across:
  - Desktop `1440x900`
  - Small Desktop `1024x768`
  - Tablet `768x1024`
  - Mobile `390x844`
- Inspect screenshots using `read_file` to confirm:
  1. Zero container clipping or edge overflow.
  2. Search button and icon alignment are crisp and centered.
  3. Profile menu toggle is fully visible and clickable.
  4. Redesign dark aesthetic is 100% preserved.

### Step 4: Quality Gate
- Run RuboCop: `bundle exec rubocop`.
- Run Rails tests: `bin/rails test`.
- Run Vitest tests: `npm run test:javascript`.
- Run Playwright E2E tests: `npm run test:e2e`.
- Run full gate: `bin/quality`.

### Step 5: Wiki Update (`sonzra-wiki`)
- Capture Iteration 1 screenshots.
- Create `features/issue-2-topbar-sizing/iteration-1.md` in `sonzra-wiki`.
- Update `features/issue-2-topbar-sizing/README.md` with side-by-side Before vs. After comparison.

---

## 5. Acceptance Criteria

- [ ] `.redesign-icon-button kbd` never wraps onto multiple lines regardless of viewport width.
- [ ] At `768px` (tablet portrait), all top bar controls (brand, primary nav links, search trigger, profile menu) are 100% visible within the viewport (zero horizontal overflow, zero clipping).
- [ ] Clicking the search trigger button on tablet viewports opens the search dialog palette.
- [ ] Clicking the user profile button on tablet viewports toggles the profile dropdown menu.
- [ ] Primary navigation links retain accessibility via `aria-label` attributes.
- [ ] Mobile viewports ($\le 700\text{px}$) retain compact mobile topbar and bottom navigation bar.
- [ ] All Rails, Vitest, and Playwright tests pass cleanly.
- [ ] `bin/quality` exits 0 with 0 RuboCop offenses.
