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

Before creating a server connection, configure Active Record Encryption. Run
`bin/rails db:encryption:init`, store the three generated values in your
environment (or encrypted Rails credentials), and use `.env.example` as the
variable reference. For credentials, nest the generated values under
`active_record_encryption` using the keys `primary_key`, `deterministic_key`,
and `key_derivation_salt`. Do not commit these keys.

## Docker

```bash
docker compose up --build
```

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
Choose an open-source license before publishing. AGPL-3.0 is worth considering for a networked self-hosted application; MIT is simpler and more permissive.
