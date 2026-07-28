# Sonzra

A browser-first, self-hosted and open-source audio player for Jellyfin, built with Rails, Turbo, Stimulus, Action Cable, and a Hotwire Native-friendly navigation model.

## Stack
- Ruby **4.0.6**
- Rails **8.1.3**
- Turbo + Stimulus via import maps
- Action Cable / Solid Cable for WebSockets
- SQLite + Solid Queue + Solid Cache for a simple self-hosted deployment
- PWA metadata and full Sonzra icon set

## Start locally
Install Ruby 4.0.6 with mise, asdf, rbenv, or your preferred manager, then:

```bash
bundle install
bin/rails db:prepare
bin/dev
```

Open `http://localhost:3000`.

For a non-container development setup, configure Active Record Encryption with
environment variables or Rails credentials before creating a server connection.
Container deployments generate and persist their own encryption root secret
automatically.

## Docker

Sonzra is distributed as one container image. Its SQLite databases and Solid
Cache, Queue, and Cable data live in `/rails/storage`, which must be mounted as
a persistent volume.

Copy `.env.example` to `.env` and set the image name. No Rails setup command is
needed. Sonzra creates its own root secret on first boot and persists it in the
storage volume. You may set `SONZRA_SECRET_KEY` yourself when using a secret
manager; keep its value unchanged for the lifetime of the installation.

Do not copy or publish this repository's `config/master.key` or
`config/credentials.yml.enc`. They are deliberately excluded from the image.
Each installation owns its secrets through its private storage volume (or its
platform's secret manager). Back up that volume together with the selected
`SONZRA_SECRET_KEY`; losing both makes previously encrypted server credentials
unreadable.

### Docker Compose

```bash
docker compose up -d
```

Compose creates and manages the named `sonzra_storage` volume declared in
[`compose.yml`](compose.yml). To deploy a release image, set `SONZRA_IMAGE` in
your `.env` to `ghcr.io/<owner>/sonzra:<version>` and run `docker compose pull`
before `docker compose up -d`.

### Docker

```bash
docker volume create sonzra_storage
docker run -d --name sonzra --restart unless-stopped -p 3000:3000 \
  --env-file .env \
  -e SOLID_QUEUE_IN_PUMA=true \
  -v sonzra_storage:/rails/storage \
  ghcr.io/<owner>/sonzra:<version>
```

For a private GitHub Container Registry image, authenticate the host first with
`docker login ghcr.io`. Publish a GitHub Release tagged as a semantic version
(for example `v1.0.0`) to build and publish versioned and `latest` images.

## Brand assets
See [`docs/BRAND.md`](docs/BRAND.md). The starter page includes a Stimulus controller demonstrating live logo states.

## Engineering
The project's architecture, object-design, Rails, and testing conventions live
in [`docs/ENGINEERING.md`](docs/ENGINEERING.md). Run the full local quality
check with:

```bash
bin/quality
```

## Hotwire Native notes
Keep screens server-rendered and navigation URL-driven. Add native-specific behavior through path configuration and bridge components rather than replacing the web UI. Action Cable is already configured for live Turbo Stream updates.

## Next implementation milestones
1. Jellyfin server connection and token storage
2. Library synchronization models and background jobs
3. Audio playback service and persistent mini-player
4. Turbo Stream updates for playback/session state
5. Hotwire Native iOS and Android shells
6. Offline downloads and media session integration

## License

Sonzra is licensed under the [GNU Affero General Public License v3.0 or later](LICENSE)
(`AGPL-3.0-or-later`). The Sonzra name and visual identity are covered by the
[trademark policy](TRADEMARKS.md), not by the software license.
