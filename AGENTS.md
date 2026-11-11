# Sonzra Agent Instructions

## Workspace Isolation Invariant
- **Git Worktree Isolation:** All multi-phase roadmap features, epics, and implementation sessions (`ce-brainstorm`, `ce-plan`, `ce-work`) must execute in an isolated git worktree under `.worktrees/<branch-name>` off `main`.
- If the current working directory is the repository root on `main`, immediately invoke `ce-worktree` or run `git worktree add -b <branch-name> .worktrees/<branch-name> origin/main` to establish the isolated worktree before modifying files, running tests, or authoring plans.
- Never write or make feature commits directly on the root `main` checkout.

## Technical Architecture & Invariants
- **Hotwire & Server-Rendered HTML:** Follow [docs/guidelines/architecture.md](docs/guidelines/architecture.md) and [docs/ENGINEERING.md](docs/ENGINEERING.md). No SPA frameworks (React/Vue).
- **Redesign Universal Theme:** The `.redesign` theme is the sole design system. Never re-introduce legacy UI styles or conditionals.
- **Persistent Player & Scrubber:** Mobile screens must preserve touch-accessible seek and scrubbing on the timeline slider (minimum 44x44px hitboxes).
- **Hexagonal Boundary:** Integrations (`Integrations::*`) must remain decoupled; Plex must never inherit or alias Jellyfin-specific classes or exceptions.
- **PWA & Offline Resilience:** Service Worker navigation requests must never return raw `text/plain` responses (which destroys the document context in WebKit standalone PWAs); fallbacks must always be self-contained HTML documents. PWA connectivity monitors must listen to `visibilitychange` (filtering for `visible`) and `focus` in addition to `online` to handle VPN and app switches.
- **Native Audio Pipeline Shielding:** Never route `<audio>` playback elements through Web Audio API (`createMediaElementSource`) on mobile WebKit; doing so enforces `MediaType::WebAudio` background restrictions (`BackgroundProcessPlaybackRestricted`) and silences background audio on app switch. Visualizers must use CSS animation fallbacks (`redesign-playing-bar`) or non-intercepting streams.
- **Mobile Queue Lookahead Handoff:** Never rely solely on JavaScript timers (`setInterval`/`setTimeout`) or DOM `ended` events for background queue advancement on mobile WebKit. WebKit freezes timers in the background and releases audio assertions on buffer underrun before `ended` events dispatch (WebKit Bug 173332 / 261858). Queue transitions must use lookahead checks in `timeupdate` (~0.35s before duration) while audio decoding is actively sustained.
- **AudioSession Re-Arming:** On mobile devices, audio sessions deactivate after idle pauses. Re-assert `navigator.audioSession.type = "playback"` on every explicit user play interaction (`toggle()`, `playCurrent()`) and on foreground visibility return.
- **Documented Solutions:** Consult [docs/solutions/](docs/solutions/) for verified solutions to past runtime, mobile WebKit, and architecture problems (organized by category with YAML frontmatter).
- **Quality Gate:** All changes must pass `bin/quality` (RuboCop, Rails minitest, Vitest, Playwright E2E).

## Compound Engineering Lifecycle & Custom Skill Integration Hooks
When executing Compound Engineering skills (`ce-brainstorm`, `ce-plan`, `ce-work`, `ce-code-review`), you must actively integrate Sonzra's specialized advisor and verification skills at each phase:

### 1. Planning Phase (`ce-brainstorm`, `ce-plan`)
- **Architectural Scoping:** Consult [`architect-advisor`](.agents/skills/architect-advisor/SKILL.md) to ensure backend services respect hexagonal isolation (`Integrations::*`), use immutable `Data.define` DTOs, and encrypt sensitive server credentials.
- **UI/UX Budgeting:** For all frontend work, consult [`ui-ux-advisor`](.agents/skills/ui-ux-advisor/SKILL.md) during scoping. Calculate mobile geometry budgets ($\le 390\text{px}$) and enforce the 3-row player hierarchy (Identity -> Scrubber -> Transport) in the plan specification.
- Every plan unit modifying UI must define explicit visual containment and mobile responsiveness criteria.

### 2. Execution & TDD Phase (`ce-work`)
- **Component Layout Discipline:** Follow [`specialized-developer`](.agents/skills/specialized-developer/SKILL.md). Never compress more than 2 secondary controls next to artwork and text on mobile. Maintain $\ge 180\text{px}$ usable width for titles with clean ellipsis truncation.
- **Redesign Self-Sufficiency:** In redesign mode, `redesign.css` is the *only* stylesheet loaded. Never rely on or reuse classes from legacy sheets (`queue.css`, `application.css`). Modals must strictly follow the canonical `.redesign-*-dialog` pattern.

### 3. Verification & Review Phase (`ce-work` quality check, `ce-code-review`)
- **Automated Quality Gate:** Run [`verify-implementation`](.agents/skills/verify-implementation/SKILL.md) to ensure 0 RuboCop offenses, 100% test pass on Rails and Vitest suites, and exit 0 on `bin/quality`.
- **Multimodal Visual Verification Gate:** For any change touching views, styles, or Stimulus controllers, capture screenshots on desktop (`1440x900`) and mobile (`390x844`). The agent must inspect image files directly using `read_file` to confirm:
  1. Zero container clipping or edge overflow.
  2. Metadata legibility ($\ge 180\text{px}$ usable width, clean truncation).
  3. Dialog and theme integrity (zero browser-default white `<dialog>` frames or un-themed buttons).
  4. Control deduplication (zero redundant action toggles across adjacent surfaces).
- Never issue an approval receipt or complete `ce-work` if visual clipping or un-themed artifacts are present.
- **Cross-Project Parity Hook:** Immediately after `ce-work` finishes, invoke the [`cross-project-parity`](.agents/skills/cross-project-parity/SKILL.md) agent to audit changes against `sonzra-tizen` and automatically file structured GitHub issues on `sonzra/sonzra-tizen` for any needed player engine adaptations or feature parity gaps.
