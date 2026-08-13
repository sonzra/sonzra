# Install Sonzra

Sonzra runs as one container with persistent local storage. It includes SQLite,
Solid Queue, Solid Cache, and Solid Cable; no separate database or queue service
is required for a standard installation.

## Requirements

- Docker Engine with Docker Compose v2, or a compatible Portainer installation.
- A Jellyfin or Plex server reachable from the Sonzra container.
- A persistent Docker volume.

For synced lyrics, expose `.lrc` lyric files to the media server. For dedicated
long-form navigation in Plex, name the relevant music libraries `Audiobooks` and
`Podcasts` (case-insensitive).

## Docker Compose

Create `docker-compose.yml`:

```yaml
services:
  sonzra:
    image: ghcr.io/sonzra/sonzra:0.0.13-alpha
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      SOLID_QUEUE_IN_PUMA: "true"
      RAILS_ASSUME_SSL: "false"
      # Required only if anyone will add a Plex connection.
      # PLEX_CLIENT_ID: "generate-once-and-keep-this-uuid"
      # Optional but recommended when supplied through a secret manager.
      # SONZRA_SECRET_KEY: "a-stable-secret"
    volumes:
      - sonzra_storage:/rails/storage

volumes:
  sonzra_storage:
```

Start it:

```bash
docker compose up -d
```

Open `http://your-host:3000`, create the first account, and add a server from
the administration area. The first account is the installation administrator.

## Persistent data and upgrades

`sonzra_storage` contains all production SQLite databases, encrypted credentials,
cache, jobs, and the generated installation secret. Back it up and do not remove
it during upgrades.

The container runs `bin/rails db:prepare` before starting the Rails server, so
pending migrations run automatically. To upgrade, change the image tag and run:

```bash
docker compose pull
docker compose up -d
```

## Environment variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `SOLID_QUEUE_IN_PUMA` | Yes | Runs scheduled jobs in the application process. |
| `RAILS_ASSUME_SSL` | Only behind TLS proxy | Set to `true` when TLS terminates upstream. |
| `SONZRA_SECRET_KEY` | Recommended | Stable installation secret; otherwise generated in the volume. |
| `PLEX_CLIENT_ID` | Only for Plex | UUID identifying this Sonzra installation to Plex. |

Generate `PLEX_CLIENT_ID` once with `uuidgen`. Keep it unchanged across restarts
and upgrades; all replicas of one installation must share it.
