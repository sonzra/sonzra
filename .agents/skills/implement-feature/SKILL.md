---
name: implement-feature
description: >-
  Implements features based on technical specifications in specs/<issue-number>/tech-spec-epic-*.md.
  Spawns isolated Git worktrees from feature branches (and optional per-epic child worktrees for parallel execution),
  constructs code chunk-by-chunk, integrates models, services, controllers, Stimulus components, and E2E suites,
  drives an iterative verify-implementation remediation loop, merges to the feature branch, and opens a Pull Request.
---

# Feature Implementation Skill (`implement-feature`)

The `implement-feature` skill focuses on **feature construction and delivery**. It provisions an isolated Git worktree for the feature (and optional per-epic worktrees when epics can proceed in parallel), implements specifications chunk-by-chunk, consults advisors when trade-offs arise, drives an iterative remediation loop with [`verify-implementation`](file:///home/bruno/Projects/sonzra/.agents/skills/verify-implementation/SKILL.md), integrates all epics into the feature branch, and opens a Pull Request for review.

---

## 1. Execution Workflow

```mermaid
flowchart TD
    TechSpec["specs/<issue-number>/tech-spec-epic-*.md\n(Approved Tech Spec)"] --> InitWorktree["1. Initialize Feature Branch & Worktree\n(git worktree add ../sonzra-feat-issue-<N> -b feat/issue-<N>-<slug>)"]
    InitWorktree --> CheckParallel{"Multiple Parallel Epics\n(Big Feature)?"}
    
    CheckParallel -->|Yes: Parallel Tracks| SpawnEpicWorktrees["Spawn Child Worktree per Epic\n(git worktree add ../sonzra-epic-<E> -b feat/issue-<N>/epic-<E>)"]
    SpawnEpicWorktrees --> ExecParallel["Implement Epics in Parallel Worktrees"]
    
    CheckParallel -->|No: Single/Sequential| ExecSingle["Implement Chunks in Feature Worktree"]
    
    subgraph EpicExecution["Chunk Implementation & Verification"]
        ExecParallel --> ChunkLoop["Iterate Chunks (Models, Services, Controllers, Views, E2E)"]
        ExecSingle --> ChunkLoop
        ChunkLoop --> BuildCode["Construct Code & Baseline Tests\n(Consult architect_advisor / ui_ux_advisor if needed)"]
        BuildCode --> CallVerify["Invoke verify-implementation in worktree"]
        
        CallVerify --> VerifyGate{"All Gates Pass\n(Status 0)?"}
        VerifyGate -->|No: Failures / Gaps| Remediation["implement-feature Retakes Control:\nAnalyze Diagnostics & Fix Defects"]
        Remediation --> CallVerify
        VerifyGate -->|Yes: Committed| EpicDone["Epic Verified & Committed"]
    end
    
    EpicDone --> MergeEpics{"Were Child Epic\nWorktrees Used?"}
    MergeEpics -->|Yes| Integrate["Merge Epic Branches into Feature Branch\nClean up epic worktrees"]
    MergeEpics -->|No| FinalVerify["Final Integration verify-implementation Pass"]
    Integrate --> FinalVerify
    
    FinalVerify --> FinalCheck{"Full Feature Green\n(bin/quality Pass)?"}
    FinalCheck -->|No| Remediation
    FinalCheck -->|Yes| PushPR["2. Push Feature Branch & Open Pull Request\n(gh pr create --base main --head feat/issue-<N>-<slug>)"]
    PushPR --> ReviewHandoff["3. Ready for Review Agent Audit"]
```

---

## 2. Ingestion, Worktree & Branch Initialization

Before writing code:

### 1. Read Specifications & Architecture Guidelines:
- Locate `specs/<issue-number>/roadmap.md` and `specs/<issue-number>/tech-spec-epic-*.md`.
- Ensure technical specification status is `Approved - Ready to Build`.
- Review [Architectural Guidelines](file:///home/bruno/Projects/sonzra/docs/guidelines/architecture.md), [UI/UX Guidelines](file:///home/bruno/Projects/sonzra/docs/guidelines/ui_ux.md), and [Engineering Principles](file:///home/bruno/Projects/sonzra/docs/ENGINEERING.md).

### 2. Spawn Feature Branch & Dedicated Worktree:
Every new feature implementation **must** run in an isolated Git worktree branched off the latest `main`:
```bash
git fetch origin main
# Create feature branch and isolated worktree
git worktree add ../sonzra-feat-issue-<issue-number> -b feat/issue-<issue-number>-<slug> origin/main
cd ../sonzra-feat-issue-<issue-number>
```
- Verify dependencies and clean test state in the new worktree:
  ```bash
  bundle check || bundle install
  npm install
  bin/rails db:prepare
  ```

### 3. Determine Epic Parallelization Strategy:
Check Section 4 of `specs/<issue-number>/roadmap.md` (*Epic Decomposition & Parallel Execution Strategy*):
- **Single or Sequential Epics:** Work directly inside `../sonzra-feat-issue-<issue-number>`.
- **Parallel Epics (Big Features):** When epics represent independent tracks (e.g., Track A: Backend, Track B: UI), spawn child worktrees per epic from the feature branch:
  ```bash
  git worktree add ../sonzra-epic-<epic-number> -b feat/issue-<issue-number>/epic-<epic-number>-<slug> feat/issue-<issue-number>-<slug>
  ```
  Subagents or tasks can then develop each epic in parallel within their dedicated worktree without colliding.

---

## 3. Chunk-by-Chunk Implementation

Iterate sequentially through each implementation chunk defined in Section 4 of the technical specification:

### Chunk Categories & Responsibilities:

1. **Data Models & Persistence (Chunk 1)**:
   - Generate and run database migrations if needed (`bin/rails db:migrate`).
   - Define Active Record models with validations, associations, and database scopes.
   - Ensure credentials use Active Record Encryption: `encrypts :username, :password, :access_token`.
   - Keep models skinny—business workflows must not be placed in model callbacks.
   - Write accompanying model tests in `test/models/`.

2. **Integration Adapters & Domain Services (Chunk 2)**:
   - If calling upstream media servers (Jellyfin/Plex), route calls through [`Integrations::Client.for(server_connection)`](file:///home/bruno/Projects/sonzra/app/services/integrations/client.rb#L3-L9). Never make direct external HTTP calls.
   - Check provider capability support via `client.supports?(...)`.
   - Implement single-purpose domain service objects in appropriate namespaces (`ServerConnections::*`, `Library::*`, `Playback::*`).
   - Use constructor dependency injection (`initialize(server_connection, client: nil)`).
   - Return immutable `Data.define` result objects (`*ResultData`) with a `#success?` predicate.
   - Write accompanying service tests in `test/services/` using plain Ruby test doubles (`Object.new` with singleton methods).

3. **Controllers & Routing (Chunk 3)**:
   - Declare RESTful routes in `config/routes.rb`.
   - Keep controllers thin: sanitize parameters, delegate immediately to services, negotiate formats (`format.html`, `format.turbo_stream`).
   - Write accompanying controller integration tests in `test/controllers/`.

4. **Views, Stimulus & UI Components (Chunk 4)**:
   - Server-rendered HTML partials with Hotwire conventions.
   - **Preserve Persistent Playback**: Ensure `#player`, `#player-queue`, and `#player-feedback` maintain `data-turbo-permanent`.
   - Apply `--rz-*` CSS design tokens (`--rz-primary`, `--rz-background`, `--rz-line`, etc.).
   - Enforce 44px minimum touch targets on mobile and include safe-area insets (`env(safe-area-inset-top)` / `env(safe-area-inset-bottom)`).
   - Use tabular numbers for duration timers: `font-variant-numeric: tabular-nums`.
   - Implement lightweight Stimulus controllers; extract complex business/storage logic into pure JS classes.
   - Write accompanying Stimulus tests in `test/javascript/` using Vitest and JSDOM.

5. **End-to-End Playwright Tests (Chunk 5 - Mandatory for UI Epics)**:
   - Create `test/e2e/<feature>.spec.js` mapping all PRD Observable Acceptance Criteria.
   - **Strict Route Mocking**: Intercept backend and media server routes with `page.route` via test helpers (`test/e2e/support/helpers.js`). Never connect to a live Jellyfin or media server instance.
   - Verify complete user journeys on both desktop and mobile viewports.

---

## 4. Advisor Consultation During Implementation

When unforeseen ambiguities or trade-offs occur while coding:
- **Call [`architect_advisor`](file:///home/bruno/Projects/sonzra/.agents/skills/architect-advisor/SKILL.md)**:
  - If boundary isolation, Active Record encryption, caching strategy, or service object structures are unclear.
  - To verify whether a collaborator pattern preserves hexagonal boundaries.
- **Call [`ui_ux_advisor`](file:///home/bruno/Projects/sonzra/.agents/skills/ui-ux-advisor/SKILL.md)**:
  - If responsive layout behavior, touch ergonomics, motion transitions, or dialog/sheet placement need clarification.
  - To ensure styling conforms to the "quiet listening room" aesthetic and `--rz-*` tokens.

---

## 5. Verification Dependency & Remediation Loop

`implement-feature` is **strictly dependent** on `verify-implementation` and must never declare itself complete without a successful verification run.

### The Verification Loop:
1. **Trigger Verification:** Once all chunks (including Chunk 5: E2E Playwright tests) have been constructed, `implement-feature` triggers the `verify-implementation` procedure.
2. **Handle Verification Failures:** If `verify-implementation` fails at any gate:
   - **Missing Deliverables:** (e.g. `test/e2e/<feature>.spec.js` was omitted or lacks required user journey scenarios)
   - **Test Failures:** (Rails, Vitest, or Playwright assertions failed)
   - **Lint Offenses:** (RuboCop offenses detected)
   - **Coverage Gaps:** (New code has <90% test coverage or untested error branches)
   
   👉 **`implement-feature` immediately takes control back**, parses the failure diagnostics, patches the application or test code, and re-invokes `verify-implementation`.
3. **Termination Condition:** The loop only terminates when `verify-implementation` reports:
   - Deliverables audit passed.
   - All tests green across all viewports.
   - Coverage >90%.
   - `bin/quality` passed.
   - Changes committed to git.
4. Only when `verify-implementation` completes successfully with a commit does `implement-feature` proceed to integration and PR creation.

---

## 6. Integration, Epic Merging & Pull Request Creation

Once all epics and chunks have been implemented and independently verified:

### 1. Merge Epic Worktrees into Feature Branch (if Parallel Worktrees Used):
In the feature worktree (`../sonzra-feat-issue-<issue-number>`):
```bash
cd ../sonzra-feat-issue-<issue-number>

# Merge each verified epic branch
git merge --no-ff feat/issue-<issue-number>/epic-<epic-number>-<slug> \
  -m "feat(epic-<epic-number>): merge epic into feature branch"

# Clean up temporary child worktree and branch
git worktree remove ../sonzra-epic-<epic-number>
git branch -d feat/issue-<issue-number>/epic-<epic-number>-<slug>
```

### 2. Final Integrated Verification Gate:
Inside `../sonzra-feat-issue-<issue-number>`, execute the final integrated quality gate:
```bash
bin/quality
```
- All Rails tests, Vitest tests, Playwright E2E suites, and RuboCop lint checks must pass with 0 failures across the integrated feature.
- If conflicts or integration regressions emerge, enter the remediation loop in the feature worktree to fix them immediately.

### 3. Mandatory Pull Request Creation:
Push the feature branch to origin and open a Pull Request:
```bash
git push -u origin feat/issue-<issue-number>-<slug>

gh pr create --base main --head feat/issue-<issue-number>-<slug> \
  --title "feat(issue-<issue-number>): <feature title>" \
  --body "## Summary
<overview of changes implemented across epics>

## Technical Deliverables
- Chunks 1..N implemented and verified
- Dedicated E2E suite (test/e2e/<feature>.spec.js) with 100% mocked server routes
- Coverage >90% across new services, controllers, and models

## Verification Results
- 0 RuboCop lint offenses
- All Rails, Vitest, and Playwright tests passing
- bin/quality clean (Exit 0)

Closes #<issue-number>"
```

### 4. Handoff to Review Agent:
> [!IMPORTANT]
> **Mandatory Review Gate:** The Pull Request **MUST** remain open for audit by the dedicated review agent. `implement-feature` marks the technical delivery as ready for review and hands over the PR link to the reviewer agent to evaluate code quality, architectural compliance, and propose any required changes.
