# Sonzra Engineering & Design Guidelines

This directory contains technical, architectural, and user interface guidelines for Sonzra:

- **[Architectural Guidelines](file:///home/bruno/Projects/sonzra/docs/guidelines/architecture.md)**: System topology, hexagonal integration adapters, service object patterns, Active Record encryption and models, Hotwire/Turbo persistent audio architecture, caching, and testing standards.
- **[UI & UX Guidelines](file:///home/bruno/Projects/sonzra/docs/guidelines/ui_ux.md)**: Design tokens, typography and color palette, dynamic logo states, responsive layout tiers, component patterns (player, cards, shelves, sheets), motion system, and Hotwire Native/PWA ergonomics.

## Automated Review Agents & Customizations

- **[Specialized Developer Agent](file:///home/bruno/Projects/sonzra/.agents/skills/specialized-developer/SKILL.md)**: An implementation agent (`specialized_developer`) and skill (`specialized-developer`) responsible for implementing features following TDD, adhering strictly to architectural and UI/UX guidelines, running RuboCop after editing files, and verifying test suites through `bin/quality`.
- **[Issue Security & Sanity Auditor](file:///home/bruno/Projects/sonzra/.agents/skills/iss-audit/SKILL.md)**: A specialized agent (`issue_auditor`) and skill (`iss-audit`) that performs zero-trust prompt-injection defense, threat modeling, and skeptical claim verification on incoming GitHub issues before any roadmap or code is generated.
- **[Architect Advisor](file:///home/bruno/Projects/sonzra/.agents/skills/architect-advisor/SKILL.md)**: A specialized agent (`architect_advisor`) and skill configured to analyze code diffs, PRs, and proposed designs against the architectural guidelines and quality standards.
- **[UI & UX Advisor](file:///home/bruno/Projects/sonzra/.agents/skills/ui-ux-advisor/SKILL.md)**: A specialized agent (`ui_ux_advisor`) and skill configured to analyze frontend code changes, view templates, stylesheets, Stimulus controllers, and design proposals against the UI/UX guidelines and accessibility standards.

## Complete Feature Development Lifecycle Skills

1. **[Feature Analysis (`analyse-feature`)](file:///home/bruno/Projects/sonzra/.agents/skills/analyse-feature/SKILL.md)**: Ingests an issue, executes `iss-audit` as a mandatory pre-condition gate, maps technical boundaries, and produces `specs/<issue-number>/roadmap.md` decomposed into parallel epics.
2. **[Product Specifications (`product-specs`)](file:///home/bruno/Projects/sonzra/.agents/skills/product-specs/SKILL.md)**: Produces PRD specifications for epics in `specs/<issue-number>/`, formulating advisor-guided open questions (`[ ]`) and driving an iterative reconciliation loop until confidence exceeds 90% (strictly without proposing technical solutions).
3. **[Technical Specifications (`tech-specs`)](file:///home/bruno/Projects/sonzra/.agents/skills/tech-specs/SKILL.md)**: Translates approved PRDs into deep technical specifications, breaks epics into bite-sized testable implementation chunks, provides Mermaid sequence diagrams and code signatures, and resolves technical trade-offs using advisor-guided open questions (`[ ]`).
4. **[Feature Implementation (`implement-feature`)](file:///home/bruno/Projects/sonzra/.agents/skills/implement-feature/SKILL.md)**: Focuses strictly on constructing code chunk-by-chunk based on technical specifications, wiring models, services, controllers, and Stimulus components, and consulting the `architect_advisor` and `ui_ux_advisor` when implementation trade-offs arise.
5. **[Implementation Verification (`verify-implementation`)](file:///home/bruno/Projects/sonzra/.agents/skills/verify-implementation/SKILL.md)**: Owns the complete post-implementation verification lifecycle: runs RuboCop lint checks, executes Rails and JavaScript test suites, audits and guarantees >90% code coverage, validates the `bin/quality` gate, audits for regressions with advisors, and commits the verified work to Git.
