# Changelog

## Unreleased

No changes yet.

## 1.0.0 — 2026-11-05

### Added

- Multi-architecture container image builds supporting both `linux/amd64` and `linux/arm64` published to GitHub Container Registry.
- Playwright End-to-End browser test automation in GitHub Actions CI workflow covering authentication and playlist operations.
- Full playlist addition management for single tracks, complete albums, recommendation mixes, and entire artist discographies.
- Canonical `Integrations::AuthenticationError` and `Integrations::ConnectionError` exception hierarchy.

### Changed

- Decoupled media server adapters into provider-neutral immutable DTOs (`Integrations::*ResponseData`), eliminating direct cross-provider dependencies between Plex and Jellyfin.
- Updated `public/manifest.json` description to represent multi-provider streaming support (Jellyfin & Plex).
- Updated security disclosure contact information in `SECURITY.md`.
- Updated Docker configuration and documentation across `README.md` and `docs/INSTALLATION.md` to reference `1.0.0`.

## 0.0.21-alpha — 2026-11-05

### Added

- Unified Offline Synchronization Protocol: Client IndexedDB offline outbox (`OfflineOutbox`) to queue, throttle, and deduplicate playback telemetry during offline listening or degraded network connections.
- Batch playback reporting endpoint (`POST /server_connections/:id/playback_reports/batch`) and `ServerConnections::ReportPlaybackBatch` service with historical timestamp persistence and latest-timestamp conflict resolution.
- Automatic offline outbox synchronization on window reconnection (`online`) and app restore (`pageshow`) with exponential backoff and audio feedback toast notifications.
- Resilient audio stream buffering featuring active buffer lookahead monitoring, soft-reconnecting transport, N+1 audio track preloading, and ephemeral audio caching (`EphemeralStreamStore`) with Service Worker HTTP range request interception.
- User playback preference to restrict audio preloading to Wi-Fi connections (`preload_on_wifi_only`).
- Persistent shell reconnection banner (`#connection_alerts`) and inline reconnect modal with auto-polling for QuickConnect approval, allowing seamless re-authentication without full-page navigation.
- Dynamic client `DeviceId` scoping per user web session and isolated background worker identifiers (`BuildSonicGraphJob` and `RecommendationGenerator`) to prevent token revocation and Jellyfin/Plex session collisions.

### Changed

- Standardized card media controls by encapsulating artwork, play button, and options toggle within `.listen-card__cover` across shelves, grids, and recommendation mixes.
- Refined server connection interfaces (index, show, new, edit, quick-connect, and reconnect) with redesign design system styling and responsive action layouts.
- Updated Docker Compose configuration in `README.md` to reference `0.0.21-alpha`.

### Fixed

- Card play button alignment and parallax coordinate drift on hover, anchoring controls with bottom/right 12px positioning and synchronized -3px hover elevation on the parent container.
- Transparent re-authentication on HTTP 401 responses for Jellyfin and Plex adapters with single-retry protection and write-through token updates to database and session cookies.
- Cascaded deletion of dependent records (`listening_events`, `playback_queues`, `recommendation_collections`) when deleting server connections to prevent foreign key constraint violations.
- QuickConnect session initialization for Plex during reconnection and resolution of stale token race conditions.

## 0.0.20-alpha — 2026-11-03

### Added

- Per-server genre exclusion (`HiddenGenre` model and migrations) to hide unwanted genres from discovery shelves, mixes, recommendation generators, radio queues, and library browsing (Albums, Songs, and Genres directory).
- Dedicated `/hidden_genres` management interface with asynchronous Hotwire Turbo Stream support to add and unhide genres dynamically without full-page reloads.
- Contextual quick-hide actions on mixes (optimistically removing card with audio player feedback toast) and exploration tiles.
- Canonical Sonzra Redesign Design System specification at `DESIGN_SYSTEM.md` and `docs/guidelines/design_system.md`.
- End-to-end testing suite with Playwright and comprehensive guidelines for agentic development.

### Changed

- Standardized quick-hide buttons on discovery tiles to 34px × 34px circular controls with centered icons and 44px mobile touch hitboxes (`::before { inset: -5px }`).
- Removed redundant directional arrows from exploration tiles for a clean, media-first presentation.
- Streamlined layout spacing on `/hidden_genres` for desktop and mobile viewports.
- Updated recommendation generators and media server adapters (Jellyfin and Plex) to respect excluded genres.

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
