# Changelog

## Unreleased

No changes yet.

## 0.0.19-alpha — 2026-09-24

### Added

- A redesign-only Favorites page that loads every favourite track from the active Jellyfin or Plex server, with desktop and PWA/mobile navigation entries.

### Changed

- Favourite tracks now use the redesigned full-width track list, with direct play, a favourite toggle, and queue/download actions in the overflow menu.
- Favorite pages now reveal tracks with the redesign’s staggered card motion, while the heart animates only after a user action.
- The PWA/mobile navigation remains focused on the hamburger menu, and queue scroll hints no longer block interaction with a single queued track.

### Fixed

- Removed legacy tooltip behavior from redesign screens so accessible control labels no longer appear in unexpected positions.

## 0.0.18-alpha — 2026-09-24

### Added

- A complete responsive Sonzra redesign for web and installed PWA use, including the dashboard, library, mixes, genres, downloads, account surfaces, and connected-server setup.
- A unified global search that returns matching artists, albums, and tracks from the active server.
- Redesigned playback controls, queue, lyrics, and contextual track actions that stay touch-friendly on mobile.

### Changed

- The dashboard now uses the most recently played item as its default hero.
- Library cards, detail pages, mixes, genre covers, download collections, and track lists now share the new spacing, typography, animation, and control system.
- The persistent player now includes animated playback feedback, an optimistically updated favourite control, clearer volume progress, and mobile-specific actions.

### Fixed

- Track actions now remain aligned, fully visible, and usable across detail, search, web, and PWA layouts.
- Queue and lyrics panels now keep their controls, metadata, scrolling affordances, and current-line shortcut within the available viewport.

## 0.0.17-alpha — 2026-09-11

### Added

- Sonic Music Map & Radio Similarity Graph: versioned local SQLite graph data, full-viewport WebGL visualization (`/sonic_graph`), and the external [`sonzra-analyzer`](https://github.com/sonzra/sonzra-analyzer) synchronization API. The analyzer now stores Essentia-based v5 section profiles for more consistent recommendations.
- Command-line tool `script/sync_lyrics` and `MusicLibrary::LyricsSynchronizer` to batch synchronize and write `.lrc` sidecar files directly to your music storage.
- Rake task `sonic_graph:prune_non_music` to prune podcasts and audiobooks from existing similarity graphs.
- Weekly Monday "All-Time Heavy Rotation" mix strategy featuring top 20 most-played tracks of all time.
- Infinite scroll and vertical A–Z / # alphabet sidebar for Albums and Artists library pages.
- Provider capabilities system (`Integrations::Capabilities`) to enable feature UI based on provider capabilities.
- Custom styled tooltip Stimulus controller (`tooltip_controller.js`) across actionable items.
- Artist subtitles on mixed track lists in playlists and recommendation collections.

### Changed

- Filtered out non-music items (podcasts and audiobooks) from Sonic Graph indexing.
- Optimized Sonic Map loading performance for large libraries through server-side response caching and bounded artist-level aggregation.
- Added a reset workflow so existing graph data can be safely cleared before a fresh analyzer run.
- Standardized library pagination size to 60 items across providers.
- Excluded short tracks under one minute from generated recommendation mixes.
- Mixes now start playback in Radio mode automatically.
- Added vertical spacing above form actions in server connection settings.

### Fixed

- Automatic lyrics reload when track advances while the lyrics tab is open.
- Refined active track highlight styling so track numbers remain fully visible.

## 0.0.13-alpha — 2026-08-13

### Added

- A branded GitHub Pages site with product, requirements, and installation information.
- Pull request quality checks for RuboCop, Rails, and JavaScript tests.
- Release automation for merged `release/**` branches, plus contribution, security, issue, and pull-request guidance.

### Changed

- Repository documentation now reflects Jellyfin and Plex support, multi-server listening, offline downloads, mixes, hidden artists, and automatic database migrations in the container.

## 0.0.12-alpha — 2026-08-13

### Added

- Plex server connections, including secure Plex account linking and multi-server switching.
- Plex support for browsing, playback reporting and resume, playlists, favourites, radio, lyrics, mixes, audiobooks, and podcasts.
- A per-user Hidden artists library, with tools to restore hidden artists later.

### Changed

- The active server is remembered in the user profile and current session; switching servers clears the active player queue and cached dashboard content.
- Hidden artists are excluded from browsing, search, home shelves, mixes, radio, playback queues, and local downloads.
- Server setup and administration now use provider-neutral language.
- Queue track actions use an overflow menu that remains accessible at the top of the list and dismisses on outside clicks.
- Cancelled audio-stream requests now end quietly instead of being logged as server errors.

## 0.0.11-alpha — 2026-08-12

### Added

- Personalized music mixes: Friday Rediscovery, Best of Genre, More from Artist, and Top of the Month.
- Saved mix history, album-style mix detail pages, and automatic mix generation through Solid Queue.
- Playback-history support for accurate monthly rankings from Jellyfin activity.

### Changed

- The home dashboard now uses a compact genre grid and surfaces mixes below it.
- Queue track actions are grouped in a compact overflow menu.

## 0.0.10-alpha — 2026-08-12

### Added

- Offline downloads for tracks, albums, playlists, and artist selections, with an on-device Downloads library.
- Offline playback with cached media, artwork, and application shell support.
- Per-cover download progress rings that allow multiple downloads to continue while browsing.

### Changed

- Album detail pages now share aligned playback controls and overflow actions.
- Desktop account and administration actions are grouped in a Profile menu.
- Artist downloads retain each track's original album grouping.
