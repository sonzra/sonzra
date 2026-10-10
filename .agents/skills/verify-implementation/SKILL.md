---
name: verify-implementation
description: >-
  Verifies and validates implemented features against Sonzra quality gates: runs RuboCop lint checks,
  executes Rails and Vitest test suites, guarantees >90% code coverage across new code, verifies
  bin/quality, consults advisors on regressions if needed, and commits the finalized work.
---

# Feature Verification Skill (`verify-implementation`)

The `verify-implementation` skill owns the **entire verification, testing, code coverage auditing, linting, quality gating, and committing lifecycle** after feature implementation has completed.

---

## 1. Execution Workflow

```mermaid
flowchart TD
    Handoff["Implemented Code & Specs"] --> Lint["1. RuboCop Lint Check\n(bundle exec rubocop)"]
    Lint --> LintFix{"0 Offenses?"}
    LintFix -->|No| AutoCorrect["Auto-correct or fix offenses"]
    AutoCorrect --> Lint
    
    LintFix -->|Yes| RunTests["2. Run Test Suites\n(bin/rails test & npm run test:javascript)"]
    RunTests --> TestPass{"All Tests Pass?"}
    TestPass -->|No| FixBugs["Diagnose & Fix Failures"]
    FixBugs --> RunTests
    
    TestPass -->|Yes| AuditCoverage["3. Audit Code Coverage\n(Ensure >90% across new code)"]
    AuditCoverage --> CoverageCheck{">90% Coverage\nCovering Edge Cases & Errors?"}
    CoverageCheck -->|No: Gaps Found| AddTests["Write additional unit/integration tests"]
    AddTests --> RunTests
    
    CoverageCheck -->|Yes| QualityGate["4. Run Full Quality Gate\n(bin/quality)"]
    QualityGate --> GateCheck{"All 4 Gates Pass?"}
    GateCheck -->|No| FixQuality["Resolve Quality Issues"]
    FixQuality --> QualityGate
    
    GateCheck -->|Yes| AdvisorCheck{"Advisor Audit Needed?"}
    AdvisorCheck -->|Yes: Architectural/UX Check| ConsultAdvisors["Consult architect_advisor / ui_ux_advisor"]
    ConsultAdvisors --> Commit
    AdvisorCheck -->|No| Commit["5. Git Commit & Documentation Update"]
    Commit --> Report["6. Deliver Verification Report"]
```

---

## 2. Ingestion & Pre-Flight Checks

1. **Inspect Modified Files**:
   ```bash
   git status
   git diff --stat
   ```
2. **Read Technical Specification & Roadmap**:
   - Locate `specs/<issue-number>/tech-spec-epic-<epic-number>-<slug>.md` and `specs/<issue-number>/roadmap.md`.
   - Identify all files touched in each chunk and expected acceptance criteria.

---

## 3. Step-by-Step Verification Procedure

### Step 1: RuboCop Lint Verification
Run the RuboCop suite to verify compliance with `rubocop-rails-omakase`:
```bash
bundle exec rubocop
```
- **Requirement:** 0 offenses detected.
- If offenses exist, run safe autocorrect (`bundle exec rubocop -a`) or manually adjust code formatting and rerun until 0 offenses remain.

### Step 2: Automated Test Execution
Run both the Rails backend and JavaScript frontend test suites:
```bash
# 1. Rails Test Suite
bin/rails test

# 2. JavaScript / Vitest Suite
npm run test:javascript

# 3. Playwright End-to-End Suite
npm run test:e2e
```
- **Requirement:** 100% of tests must pass with 0 errors and 0 failures across all desktop and mobile targets.
- If any test fails, inspect the failure trace, correct the defect, and rerun until green.

### Step 3: Code Coverage Audit (>90% Requirement)
Audit all new and modified code files to ensure test coverage exceeds **90%**:
- **Happy Paths**: Are expected inputs and standard successful workflows covered?
- **Failure Paths & Errors**: Are external adapter exceptions (e.g. `Integrations::Jellyfin::Client::AuthenticationError`, `ConnectionError`) tested and properly handled?
- **Edge Cases**: Are nil parameters, blank inputs, and empty collections tested?
- **Active Record Validations**: Are all model validations and encryption attributes tested in `test/models/`?
- **Stimulus DOM & Events**: Are all UI event listeners, active/paused states, and DOM updates tested in `test/javascript/`?

**Action on Gaps:** If any branch, error path, or edge case is missing test coverage, write the necessary test cases immediately before proceeding to the quality gate.

### Step 4: Canonical Quality Gate (`bin/quality`)
Execute the project's canonical verification script:
```bash
bin/quality
```
`bin/quality` verifies:
1. `bundle exec rubocop`
2. `bin/rails db:prepare`
3. `bin/rails test`
4. `npm run test:javascript`
5. `npm run test:e2e`

**Requirement:** The script must exit with status `0`.

---

## 4. Advisor Regression Audit (Optional / High-Impact Changes)

If the implementation touched core architectural boundaries or major responsive layouts, run an advisor check:
- **Architectural Audit**: Consult [`architect_advisor`](file:///home/bruno/Projects/sonzra/.agents/skills/architect-advisor/SKILL.md) to verify that hexagonal boundaries, `Data.define` DTO contracts, Active Record encryption, and persistent player continuity (`data-turbo-permanent`) remain intact.
- **UI/UX Audit**: Consult [`ui_ux_advisor`](file:///home/bruno/Projects/sonzra/.agents/skills/ui-ux-advisor/SKILL.md) to verify that 44px touch targets, `--rz-*` tokens, safe-area insets, and reduced-motion states were not regressed.

---

## 5. Git Commit & Documentation Updates

Once all tests pass, coverage exceeds 90%, and `bin/quality` is clean:

1. **Stage Changes**:
   ```bash
   git add app/ config/ db/ lib/ test/ specs/
   ```
2. **Create Conventional Commit**:
   Commit the finalized work referencing the issue and epic:
   ```bash
   git commit -m "feat(epic-<epic-number>): implement <epic title>

   - Implemented <key capability 1>
   - Implemented <key capability 2>
   - Verified >90% test coverage across new services, models, and controllers
   - Verified 0 RuboCop lint offenses and bin/quality pass
   - Resolves #<issue-number>"
   ```
3. **Update Specification Status**:
   - In `specs/<issue-number>/tech-spec-epic-<epic-number>-<slug>.md`, update status to:  
     `Status: Completed & Verified`
   - In `specs/<issue-number>/roadmap.md`, check off the completed epic in the roadmap checklist.

---

## 6. Verification Report

Deliver a final verification report containing:
1. **Quality Status**: `PASSED & COMMITTED`.
2. **Lint Summary**: RuboCop offense count (0).
3. **Test Results**: Total Rails tests and assertions run, total Vitest tests run.
4. **Coverage Audit**: Confirmation that code coverage exceeds 90% across new code with edge cases verified.
5. **Quality Gate**: Confirmation that `bin/quality` completed with exit code 0.
6. **Git Commit**: Commit hash and commit message.
