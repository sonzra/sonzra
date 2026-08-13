<p align="center">
  <img src="public/brand/sonzra-mark.svg" width="96" alt="Sonzra logo">
</p>

<h1 align="center">sonzra</h1>

<p align="center"><strong>Your private listening home.</strong></p>

<p align="center">
  A self-hosted, open-source player for Jellyfin music, podcasts, and audiobooks.
</p>

<p align="center">
  Built with Rails · Turbo · Stimulus · Hotwire Native ready
</p>

## What Sonzra is

Sonzra turns a personal Jellyfin library into a music-first listening
experience: browse artists and albums, rediscover recently played music, queue
what comes next, and keep playback running as you move through the app. Every
account connects to its own Jellyfin user, so library access and listening data
remain personal.

<table>
  <tr>
    <td><strong>Music-first</strong><br>Recent, most-played, genre, artist, and album shelves.</td>
    <td><strong>One player</strong><br>Streaming playback, queue management, progress, and volume controls.</td>
    <td><strong>Self-hosted</strong><br>A single container image with persistent local storage.</td>
  </tr>
</table>

## Stack
- Ruby **4.0.6**
- Rails **8.1.3**
- Turbo + Stimulus via import maps
- Action Cable / Solid Cable for WebSockets
- SQLite + Solid Queue + Solid Cache for a simple self-hosted deployment
- PWA metadata and full Sonzra icon set

## Deploy Sonzra

You do not need to clone this repository to run Sonzra. Copy the Docker Compose
configuration below into an empty directory, then start the service. Cloning is
only needed when you want to contribute to Sonzra itself.

### Docker Compose and Portainer

Create a file named `docker-compose.yml` with the following content, or paste
the same configuration into a Portainer Stack:

```yaml
services:
  sonzra:
    image: ghcr.io/sonzra/sonzra:latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      SOLID_QUEUE_IN_PUMA: "true"
      RAILS_ASSUME_SSL: "false"
      SONZRA_SECRET_KEY: "change-me"
      # Required only when adding a Plex connection:
      # PLEX_CLIENT_ID: "generate-and-keep-a-stable-uuid"
    volumes:
      - sonzra_storage:/rails/storage

volumes:
  sonzra_storage:
```

From the directory containing the file, run:

```bash
docker compose up -d
```

Set `RAILS_ASSUME_SSL` to `"true"` when TLS is terminated by a reverse proxy.
For future releases, replace `0.0.1-alpha` with the exact version you want to
run. Use `latest` only when you deliberately want the most recent stable
release.

Sonzra creates its own root secret on first boot and persists it in the storage
volume. You may set `SONZRA_SECRET_KEY` through a secret manager; keep its
value unchanged for the lifetime of the installation.

### Plex client identity (optional)

Jellyfin-only installations do not need `PLEX_CLIENT_ID`. Before adding a Plex
connection, set it to a UUID generated once for this Sonzra installation:

```bash
uuidgen
```

Store it in your deployment environment or secret manager and keep it stable
across restarts and upgrades. Multiple replicas of the same Sonzra deployment
must share the value; separate Sonzra installations must use different values.
It identifies this installed Sonzra client to Plex, rather than an individual
release or user. Plex connection support is enabled only after its local-server
validation is complete.

### Docker

```bash
docker volume create sonzra_storage
docker run -d --name sonzra --restart unless-stopped -p 3000:3000 \
  -e SOLID_QUEUE_IN_PUMA=true \
  -v sonzra_storage:/rails/storage \
  ghcr.io/sonzra/sonzra:0.0.1-alpha
```

When adding a Plex connection, also pass
`-e PLEX_CLIENT_ID="$PLEX_CLIENT_ID"` to the container.

For a private GitHub Container Registry image, authenticate the host first with
`docker login ghcr.io`.

## First-run setup and accounts

Open Sonzra at `http://your-server:3000` after the container is running.

1. Create the first Sonzra account. It automatically becomes the installation
   administrator.
2. Enter the shared Jellyfin server name and address, then choose **Connect
   with Jellyfin**. Sonzra displays a temporary code; approve it from an
   already signed-in Jellyfin client under **Settings → Quick Connect**.
3. Invite other people to create a Sonzra account. Each person approves their
   own Quick Connect code against the same configured server.

The Jellyfin address is configured once for the installation. New connections
store only encrypted access tokens in Sonzra's database and are never shared
between Sonzra users. Sonzra never receives or stores Jellyfin passwords for
Quick Connect. This keeps Jellyfin favourites, play counts, and playback
positions personalized for each person.

Quick Connect must be enabled on the Jellyfin server (it is enabled by default).
An existing password-based Sonzra connection remains usable after upgrading,
but reconnecting it uses the safer Quick Connect flow.

The first user is also the only role that can change the shared server address
or manage whether new Sonzra accounts may sign up. To close registration after
everyone has joined, open **Administration** from the Sonzra menu and turn off
new account registration.

## Contributing and local development

Install Ruby 4.0.6 with mise, asdf, rbenv, or your preferred manager, then:

```bash
bundle install
bin/rails db:prepare
bin/dev
```

Open `http://localhost:3000`.

For a non-container development setup, configure Active Record Encryption with
environment variables or Rails credentials before creating a server connection.
Do not commit `config/master.key`, `config/credentials.yml.enc`, or local
secrets.

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
