---
title: "Card Cover Encapsulation and Hover Motion Synchronization"
date: "2026-11-04"
category: "ui-bugs"
module: "app/views/shared"
problem_type: "ui_bug"
component: "frontend"
severity: "medium"
symptoms:
  - "Quick-play button floats over text metadata or overflows card boundary on hover in media shelves and grids"
  - "Hover elevation transform desynchronizes, separating artwork from quick-play button"
root_cause: "layout_encapsulation_missing"
resolution_type: "code_fix"
tags:
  - "css"
  - "redesign"
  - "listen-card"
  - "hover-state"
  - "transform-sync"
  - "hotwire"
---

# Card Cover Encapsulation and Hover Motion Synchronization

## Problem
In Sonzra's modern redesign (`ui_variant: "redesign"`), hovering over media cards in shelves (e.g., "Recently played") or grid views (e.g., Artist albums) displayed a misaligned quick-play button that drifted outside the artwork thumbnail into the text metadata area. Additionally, hover animations caused the album cover and the action button to elevate at different speeds, visually detaching the controls from the image.

## Symptoms
- On desktop viewports, hovering over `.listen-card` elements placed the 46px quick-play button (`.listen-card__play`) over card titles or below the bottom edge of the image rather than inset at the bottom-right of the cover.
- In cards with multi-line titles or variable artist metadata, the offset varied because absolute positioning calculated against the variable-height `<article class="listen-card">` container rather than the fixed 1:1 image.
- When hovering, the album artwork shifted up by -6px while the play button shifted by -3px, causing the play button to detach and lag behind the artwork.

## What Didn't Work
- **Directly overriding `bottom: 12px; right: 12px` on `.listen-card__play`**: In `app/assets/stylesheets/redesign.css`, positioning the button against `.listen-card` still anchored coordinates to the entire article container. Because `.listen-card` includes the `<h3>` and `<p>` text blocks below the thumbnail, cards with different text lengths produced inconsistent play button placement.
- **Specifying `right` and `bottom` without resetting `top` and `left`**: In `app/assets/stylesheets/application.css`, `.listen-card__play` was originally centered via `left: 50%; top: 50%; transform: translate(-50%, -50%)`. When `redesign.css` declared `right: 12px; bottom: 12px`, CSS cascading rules caused `top` and `left` to conflict with `bottom` and `right`.
- **Applying `-3px` hover translateY to `.listen-card__cover` while retaining it on `.listen-card__art`**: When `.listen-card__cover` was introduced, both the cover wrapper and the inner `.listen-card__art` retained `transform: translateY(-3px)`. This compounded into a `-6px` lift on the artwork while the play button only lifted `-3px`.

## Solution
The fix resolved the issue in PR #10 through a combination of DOM encapsulation and CSS cascade normalization:

### 1. Encapsulate Visual Media in `.listen-card__cover`
In `app/views/shared/_media_shelf.html.erb`, `app/views/shared/_media_grid.html.erb`, and `app/views/shared/_recommendation_shelf.html.erb`, wrap the artwork link, quick-play button, and options toggle within a dedicated `<div class="listen-card__cover">`:

```erb
<%# Before %>
<article class="listen-card" ...>
  <%= link_to ..., class: "listen-card__art" do %>...<% end %>
  <button class="listen-card__play" ...>...</button>
  <%= render "shared/card_options", ... %>
  <h3><%= link_to item["Name"], ... %></h3>
  <p><%= item["AlbumArtist"] %></p>
</article>

<%# After %>
<article class="listen-card" ...>
  <div class="listen-card__cover">
    <%= link_to ..., class: "listen-card__art" do %>...<% end %>
    <button class="listen-card__play" ...>...</button>
    <%= render "shared/card_options", ... %>
  </div>
  <h3><%= link_to item["Name"], ... %></h3>
  <p><%= item["AlbumArtist"] %></p>
</article>
```

### 2. Define Cover Geometry and Coordinate Resets in Redesign CSS
In `app/assets/stylesheets/redesign.css` (lines 49-57):
- Define `.listen-card__cover` with `position: relative; aspect-ratio: 1; overflow: hidden; border-radius: 16px;`.
- Anchor `.listen-card__play` relative to `.listen-card__cover` with explicit `top: auto; left: auto; right: 12px; bottom: 12px;`.
- Unify hover elevation on `.listen-card:hover .listen-card__cover` with `transform: translateY(-3px); box-shadow: ...;`, removing individual hover transforms from `.listen-card__art`.

```css
.redesign .listen-card__cover {
  position: relative;
  aspect-ratio: 1;
  overflow: hidden;
  border-radius: 16px;
  background: var(--rz-raised);
  box-shadow: inset 0 0 0 1px rgb(255 255 255 / 10%), 0 15px 32px rgb(0 0 0 / 24%);
  transition: transform .22s ease, box-shadow .22s ease;
}

.redesign .listen-card__play {
  position: absolute;
  z-index: 2;
  top: auto;
  left: auto;
  right: 12px;
  bottom: 12px;
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  padding: 0;
  border: 1px solid rgb(255 255 255 / 48%);
  border-radius: 50%;
  background: rgb(9 9 15 / 84%);
  color: #fff;
  box-shadow: 0 8px 20px rgb(0 0 0 / 40%);
  cursor: pointer;
  opacity: 0;
  transform: translateY(7px) scale(.9);
  transition: opacity .22s cubic-bezier(.2, .8, .2, 1), transform .22s cubic-bezier(.2, .8, .2, 1), background .18s ease;
}

.redesign .listen-card:hover .listen-card__cover,
.redesign .listen-card:focus-within .listen-card__cover {
  transform: translateY(-3px);
  box-shadow: inset 0 0 0 1px rgb(255 255 255 / 20%), 0 22px 45px rgb(0 0 0 / 36%);
}
```

### 3. Add View Regression Tests
Added structural assertions in `test/views/home/library_content_test.rb` (lines 30-31), `test/controllers/library_items_controller_test.rb` (lines 112-113), and `test/controllers/recommendation_collections_controller_test.rb` (lines 14-15) to ensure `.listen-card__cover` encapsulates both `.listen-card__art` and `.listen-card__play`.

## Why This Works
1. **Isolated Coordinate System**: By wrapping only the media thumbnail and action controls inside `.listen-card__cover`, the `position: absolute` context for `.listen-card__play` is bounded to a strict 1:1 aspect ratio square. Variable-height text elements below the thumbnail cannot affect the button's vertical offset.
2. **Deterministic Absolute Placement**: Overriding `top: auto; left: auto;` neutralizes legacy rules from `app/assets/stylesheets/application.css`, allowing `bottom: 12px; right: 12px;` to reliably dock the button in the bottom-right corner.
3. **Synchronized Motion Hierarchy**: Elevating the parent `.listen-card__cover` translates all nested children (artwork, play button, and options badge) as a single composite unit, eliminating parallax drift and jitter.

## Prevention
- **Encapsulate Media Boundaries**: Never place absolutely positioned media overlay controls directly inside an article or card container that also contains text metadata. Always use a dedicated square wrapper (`.listen-card__cover`).
- **Reset Orthogonal Coordinate Properties**: When overriding absolute positioning between base stylesheets and scoped design systems, explicitly reset opposing properties (`top: auto; left: auto;`).
- **Animate Container Transforms, Not Children**: When applying elevation or translation to a card on hover, apply the transform to the outer visual container (`.listen-card__cover`) rather than transforming internal layers individually.
- **Automated Assertions**: Maintain view tests verifying that all card implementations wrap art and controls inside `.listen-card__cover`:
  ```ruby
  assert_select ".listen-card .listen-card__cover .listen-card__art", 1
  assert_select ".listen-card .listen-card__cover .listen-card__play", 1
  ```

## Related Issues
- Resolved in PR #10 (merged)
