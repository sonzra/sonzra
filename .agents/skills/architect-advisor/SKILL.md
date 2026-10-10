---
name: architect-advisor
description: >-
  Architect advisor for analyzing code changes, PRs, and architectural proposals against
  Sonzra's architectural guidelines (docs/guidelines/architecture.md and docs/ENGINEERING.md).
  Use this skill whenever reviewing code, validating new designs, or verifying compliance
  with hexagonal integration boundaries, service object conventions, Hotwire persistent playback,
  Active Record encryption, and testing standards.
---

# Sonzra Architect Advisor

The Architect Advisor evaluates code changes, proposed designs, and refactoring efforts against Sonzra's official architectural guidelines.

## Reference Documents

- [Architectural Guidelines](file:///home/bruno/Projects/sonzra/docs/guidelines/architecture.md)
- [UI & UX Guidelines](file:///home/bruno/Projects/sonzra/docs/guidelines/ui_ux.md)
- [Engineering Principles](file:///home/bruno/Projects/sonzra/docs/ENGINEERING.md)
- [Context & Vision](file:///home/bruno/Projects/sonzra/docs/CONTEXT.md)

## Core Architectural Invariants to Verify

### 1. Hexagonal Architecture (Ports & Adapters)
- **Integration Factory**: All upstream calls to media servers must use `Integrations::Client.for(server_connection)`. Direct instantiation of `Integrations::Jellyfin::Client` or `Integrations::Plex::Client` in controllers or views is strictly forbidden.
- **Capability Checking**: If a feature varies across media providers, verify it checks `client.supports?(capability)` from `Integrations::Capabilities`.
- **Error Isolation**: Upstream HTTP or auth exceptions must be caught at adapter boundaries and translated into domain exceptions or result objects.

### 2. Service Objects & Immutable Data Transfer Objects
- **Single-Purpose Use Cases**: Services in `app/services/` must represent discrete workflows organized under domain namespaces (`ServerConnections::*`, `SonicGraph::*`, `Library::*`, `HiddenArtists::*`, `Admin::*`).
- **Constructor Injection**: Services must accept dependencies (e.g., `client: nil`) in `#initialize` and default them, enabling zero-mock unit testing with plain Ruby doubles.
- **Immutable Results (`Data.define`)**: Services must return immutable Result Objects (`*ResultData`) using Ruby's `Data.define` with a `#success?` predicate.
- **No CRUD Services**: Simple Rails CRUD belongs in standard RESTful controllers and models.

### 3. Persistence, Models & Security
- **Thin Active Record Models**: Models handle validations, associations, database scopes, and lifecycle callbacks only. Business workflows belong in service objects.
- **Credential Encryption**: Sensitive credentials (`username`, `password`, `access_token`) must be encrypted at rest using Rails Active Record Encryption (`encrypts :username, :password, :access_token`).
- **Aggregate Boundaries**: Shared media server configuration lives exclusively on `MediaServer`; user credentials and user-scoped data live on `ServerConnection`.
- **High-Performance SQL**: Use targeted SQL and window functions for large graph operations; avoid loading large record sets into Ruby memory.

### 4. Presentation & Hotwire Integrity
- **Server-Rendered First**: Rely on server-rendered HTML, Turbo Frames, and Turbo Streams. No SPA frameworks (React, Vue).
- **Persistent Playback (`data-turbo-permanent`)**: The player shell (`#player`), queue panel (`#player-queue`), and feedback alerts (`#player-feedback`) must have `data-turbo-permanent` so playback never pauses on navigation.
- **Deferred Frame Loading**: Upstream-dependent home sections must load asynchronously via `<turbo-frame loading="lazy">`.
- **Focused Stimulus Controllers**: Stimulus controllers manage DOM bindings only. Complex client state (like offline media storage) belongs in standalone JS modules (`OfflineMediaStore`).

### 5. Automated Testing & Quality Standards
- **Isolation in Unit Tests**: Service tests must use lightweight test doubles (`Object.new` with singleton methods). Never call live external servers in tests.
- **Quality Gate**: Code changes must pass `bin/quality` (`bundle exec rubocop`, Rails tests, and Vitest suite).

## Review Workflow

1. **Inspect Code Changes**:
   ```bash
   git diff main...HEAD
   # or inspect specific modified files
   ```
2. **Audit Against Invariants**: Run through the checklist above.
3. **Verify Quality Suite**:
   ```bash
   bin/quality
   ```
4. **Deliver Structured Review**:
   - **Verdict**: `APPROVED`, `APPROVED WITH SUGGESTIONS`, or `CHANGES REQUESTED`
   - **Checklist**: Mark compliance for each architectural dimension
   - **Findings**: Detail any anti-patterns with file and line references
   - **Recommendations**: Provide idiomatic refactoring code snippets
