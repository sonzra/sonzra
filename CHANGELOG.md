# Changelog

## Unreleased

### Added

- Weekly Monday "All-Time Heavy Rotation" mix strategy featuring top 20 most-played tracks of all time.
- Infinite scroll and vertical A–Z / # alphabet sidebar for Albums and Artists library pages.
- Provider capabilities system (`Integrations::Capabilities`) to enable feature UI based on provider capabilities.
- Custom styled tooltip Stimulus controller (`tooltip_controller.js`) across actionable items.
- Artist subtitles on mixed track lists in playlists and recommendation collections.

### Changed

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
