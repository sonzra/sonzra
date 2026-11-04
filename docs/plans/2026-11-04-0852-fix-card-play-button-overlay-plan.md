# Plan: Fix Card Play Button Alignment in Shelves and Grids

## 1. Problem Statement
When browsing the dashboard (e.g., scrolling down to the "Recently played" shelf) or navigating to an artist's albums page, hovering the mouse over a card causes the circular play button to appear misaligned. Instead of sitting neatly inside the bottom-right corner of the artwork cover, it bleeds into the text area below the artwork or overlaps card metadata, and fails to elevate synchronously with the card artwork during hover.

## 2. Root Cause Analysis & Causal Chain
1. **Container Missing for Shelf & Grid Cards**:
   - In commit `ed212fe805bed926e7050addfb92ad5f2b0bd25a`, the Library collection grid (`app/views/library/_grid_items.html.erb:6-10`) introduced a dedicated container:
     ```html
     <div class="listen-card__cover">
       <a class="listen-card__art">...</a>
       <button class="listen-card__play">...</button>
       <div class="listen-card__options">...</div>
     </div>
     ```
   - However, other card renderers were left with the legacy flat structure where `.listen-card__play` and `.listen-card__options` are direct children of `<article class="listen-card">`:
     - `app/views/shared/_media_shelf.html.erb:12-17` (Dashboard shelves: "Recently played", "Most played songs", "Recently added albums", "More by this artist", "Similar albums")
     - `app/views/shared/_media_grid.html.erb:6-12` (Artist details page: "Albums" grid)
     - `app/views/shared/_recommendation_shelf.html.erb:30-38` (Recommendations shelves)

2. **Flawed CSS Coordinate Anchoring (`redesign.css`)**:
   - In `app/assets/stylesheets/redesign.css:52`:
     `.redesign .listen-card__play { position: absolute; z-index: 2; right: 12px; bottom: 42px; ... }`
   - Because `.listen-card` is the positioned ancestor (`position: relative`), `bottom: 42px` positions the play button relative to the bottom edge of the *entire card* (which includes variable-height `<h3>` title and `<p>` subtitle text).
   - When text height varies (or title wraps to multiple lines), the play button moves up or down relative to the artwork, overflowing the artwork boundaries and clipping into text.
   - Furthermore, the specific `.listen-card__cover` styling rules in `app/assets/stylesheets/redesign.css:596-600` were narrowly scoped under `.redesign .redesign-library-grid .listen-card__cover` instead of applying globally to all `.redesign .listen-card__cover` elements.

3. **Hover Elevation Desynchronization**:
   - In `app/assets/stylesheets/redesign.css:147`, hovering `.listen-card` applies `transform: translateY(-3px)` to `.listen-card__art`.
   - Without `.listen-card__cover`, `.listen-card__play` does not lift with the artwork, producing an unnatural visual disconnect where the artwork moves up while the play button stays anchored to the card box.

4. **Legacy Mode Degradation (`application.css`)**:
   - In `app/assets/stylesheets/application.css:16`:
     `.listen-card > .listen-card__play { top: 95px }`
   - The direct child combinator `>` and hardcoded `top: 95px` pixel offset were designed assuming a static 190px artwork height and direct card parenting. In fluid shelves (154px) or grids (160px-220px), `top: 95px` is off-center. Centering via `.listen-card__cover` (`top: 50%; left: 50%; transform: translate(-50%, -50%)`) provides robust geometry.

## 3. Proposed Fix
1. **Unify View Templates with `.listen-card__cover`**:
   - Update `app/views/shared/_media_shelf.html.erb` to wrap `.listen-card__art`, `.listen-card__play`, and `.listen-card__options` inside `<div class="listen-card__cover">`.
   - Update `app/views/shared/_media_grid.html.erb` to wrap `.listen-card__art`, `.listen-card__play`, and `.listen-card__options` inside `<div class="listen-card__cover">`.
   - Update `app/views/shared/_recommendation_shelf.html.erb` to wrap `.listen-card__art`, `.listen-card__play`, and `.listen-card__options` inside `<div class="listen-card__cover">`.

2. **Promote `.listen-card__cover` Styles in `redesign.css`**:
   - Promote `.redesign .redesign-library-grid .listen-card__cover` rules to `.redesign .listen-card__cover` so that all card covers across shelves, search, and artist albums inherit:
     - `position: relative; aspect-ratio: 1; border-radius: 16px; transition: transform .22s ease;`
     - `.listen-card__cover .listen-card__art { width: 100%; height: 100%; }`
     - `.listen-card__cover .listen-card__play { right: 12px; bottom: 12px; }`
     - Hover/focus on `.listen-card` transforms `.listen-card__cover` by `translateY(-3px)`.
     - Inset shadow and borders applied smoothly to the cover and art.

3. **Ensure Compatibility in `application.css` (Legacy Mode)**:
   - Add `.listen-card__cover { position: relative; aspect-ratio: 1; border-radius: 16px; }` to legacy stylesheet.
   - Update `.listen-card:hover .listen-card__play` and `.listen-card:focus-within .listen-card__play` to display and center cleanly (`top: 50%; left: 50%; transform: translate(-50%, -50%) scale(1)`), without relying on brittle child combinators or hardcoded pixel offsets.

## 4. Implementation Steps
- **Step 1 (Worktree Isolation)**:
  - Branch `fix/card-play-button-overlay` created in `.worktrees/fix-card-play-button-overlay` out of `main`.
- **Step 2 (Test-First Verification)**:
  - Add view assertions in `test/views/home/library_content_test.rb` verifying `.listen-shelf .listen-card .listen-card__cover .listen-card__play`.
  - Add view assertions in `test/controllers/library_items_controller_test.rb` verifying `.detail-albums__grid .listen-card .listen-card__cover .listen-card__play` when rendering artist albums.
  - Run `bin/rails test` to observe failure on missing `.listen-card__cover` selector.
- **Step 3 (View Updates)**:
  - Edit `app/views/shared/_media_shelf.html.erb`
  - Edit `app/views/shared/_media_grid.html.erb`
  - Edit `app/views/shared/_recommendation_shelf.html.erb`
- **Step 4 (Stylesheet Updates)**:
  - Edit `app/assets/stylesheets/redesign.css`
  - Edit `app/assets/stylesheets/application.css`
- **Step 5 (Regression & Quality Gates)**:
  - Run `bin/rails test` (full suite).
  - Run `npm run test:javascript` (Vitest controller suite).
  - Run `bin/rubocop -a` to ensure clean code style.

## 5. Verification & Acceptance Criteria
- [ ] In `app/views/shared/_media_shelf.html.erb`, card artwork and overlay controls are encapsulated in `.listen-card__cover`.
- [ ] In `app/views/shared/_media_grid.html.erb`, card artwork and overlay controls are encapsulated in `.listen-card__cover`.
- [ ] On hover over a card in "Recently played" shelf, the play button appears anchored 12px from bottom-right of artwork cover, without clipping into title text.
- [ ] On hover over an album in an artist's discography, the play button appears anchored 12px from bottom-right of artwork cover.
- [ ] Card cover and all child badges (play button, options toggle) elevate together smoothly by `translateY(-3px)`.
- [ ] Mobile view (<=700px) continues to cleanly suppress hover action buttons in favor of touch gestures and bottom sheets.
- [ ] All Rails unit/controller/view tests and Vitest suites pass without error.
