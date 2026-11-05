<p align="center"><strong>sonzra</strong></p>

<p align="center">Your private listening home.</p>

Sonzra is a self-hosted audio player for personal Jellyfin and Plex libraries.
It brings music, podcasts, and audiobooks into one focused listening experience
with offline downloads, synced lyrics, saved mixes, and a persistent queue.

## Highlights

- Connect Jellyfin and Plex accounts independently, then switch servers at any time.
- Browse artists, albums, playlists, genres, audiobooks, and podcasts.
- Keep playback, queue, favourites, resume positions, and radio close at hand.
- Download music for offline playback in supported browsers.
- Listen to scheduled, saved mixes such as Friday Rediscovery and Top of the Month.
- Hide artists per server so they do not appear in browsing, mixes, queues, radio, or downloads.

## Install

The complete deployment guide is in [docs/INSTALLATION.md](docs/INSTALLATION.md).
The short version is to create `docker-compose.yml`:

```yaml
services:
  sonzra:
    image: ghcr.io/sonzra/sonzra:0.0.21-alpha
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      SOLID_QUEUE_IN_PUMA: "true"
      RAILS_ASSUME_SSL: "false"
      # Required only when adding a Plex connection.
      # PLEX_CLIENT_ID: "a-stable-uuid-for-this-installation"
    volumes:
      - sonzra_storage:/rails/storage

volumes:
  sonzra_storage:
```

Run `docker compose up -d`. The container runs pending database migrations on
startup. Keep the `sonzra_storage` volume: it contains the SQLite databases,
encrypted credentials, cache, and the installation secret.

## Requirements

- A reachable Jellyfin or Plex server with audio libraries.
- A modern browser for the web player and offline downloads.
- Optional `.lrc` files embedded or available to the media server for synced lyrics.
- Optional Plex client identifier (`PLEX_CLIENT_ID`) when adding Plex.
- Plex libraries named exactly `Audiobooks` and `Podcasts` are shown in their
  dedicated Sonzra sections; name matching is case-insensitive.

## Contributing and Architecture

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and pull
request expectations. Key guides and references:

- **[Design System](DESIGN_SYSTEM.md)**: Tokens, component specifications, 34px corner badges, 48px baseline controls, and touch ergonomics for the modern redesign interface.
- **[Engineering Principles](docs/ENGINEERING.md)**: Modular monolith architecture, hexagonal integration boundaries, and testing guidelines.
- **[Guidelines Directory](docs/guidelines/README.md)**: Detailed architecture, UI/UX, and agent specifications.
- **[Release Procedure](docs/RELEASING.md)**: Maintainer deployment and release checklist.

```bash
bundle install
bin/rails db:prepare
bin/dev
bin/quality
```

## Security and license

Report vulnerabilities using [SECURITY.md](SECURITY.md), not public issues.
Sonzra is licensed under the [GNU AGPL-3.0](LICENSE).
