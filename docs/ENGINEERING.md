# Engineering Principles

These principles guide Sonzra as a maintainable Rails application. Prefer the
smallest conventional solution that keeps the domain clear.

## Architecture

Sonzra is a modular monolith. Rails remains responsible for HTTP, persistence,
jobs, and rendering; application behaviour is organised around the domain.

- Use object-oriented design: objects should represent meaningful domain
  concepts and own the behaviour that belongs to them.
- Apply Domain-Driven Design where a domain has meaningful rules or language.
  Name objects using the vocabulary of Jellyfin and Sonzra users.
- Apply hexagonal architecture at system boundaries. Domain and application
  code must not depend directly on Jellyfin HTTP, Active Record, or other
  infrastructure. Define a narrow port when a boundary needs to be isolated,
  then provide an adapter for the external system.
- Do not introduce ports, adapters, or layers for simple Rails CRUD. Add them
  when they clarify a domain rule, enable substitution, or isolate an external
  dependency.
- Keep controllers, jobs, and views thin. They translate inputs and delegate
  to application or domain objects; they do not contain business rules.

## Object Design

- Apply SOLID pragmatically. These principles should improve clarity and
  changeability, not require abstractions before they are useful.
  - **Single responsibility:** keep classes and methods small, cohesive, and
    named for what they do. A class should have one reason to change.
  - **Open/closed:** extend behaviour through well-named collaborators,
    polymorphism, or composition when variation is real; avoid repeatedly
    modifying a central conditional for each new case.
  - **Liskov substitution:** a replacement implementation must honour the
    contract, return values, and failure behaviour expected by its caller.
    Do not make callers special-case an adapter or subclass.
  - **Interface segregation:** expose small, purpose-specific ports. A caller
    should not depend on methods it does not use.
  - **Dependency inversion:** application and domain code depend on stable
    abstractions, not external infrastructure. Infrastructure adapters depend
    on those ports, especially at Jellyfin and persistence boundaries.
- Use service objects sparingly. A service object is appropriate for a single
  application use case or workflow, not as a default home for unrelated logic.
- Prefer domain objects, value objects, query objects, policies, and Rails
  models when they communicate intent more directly.
- Pass collaborators explicitly when doing so improves testability or makes a
  dependency clear.
- Avoid clever abstractions and premature generalisation. Refactor when a
  concrete need appears.

## Rails and Ruby

- Follow current Ruby and Rails conventions: RESTful routes, conventional
  naming, Active Record validations and associations, framework generators,
  and standard test locations.
- Keep the application server-rendered and Hotwire-first as described in
  `docs/CONTEXT.md`.
- Run `bundle exec rubocop` before submitting changes. The project uses
  `rubocop-rails-omakase`; its configuration is in `.rubocop.yml`.

## Responsive and Native UX

Sonzra is browser-first but will also be delivered through Hotwire Native.
Every user-facing change must work at narrow mobile widths as well as desktop.

- Build mobile-first layouts. Use responsive CSS to enhance larger screens;
  do not make mobile navigation or primary playback actions unreachable.
- Test important screens at a narrow phone viewport (at least 375px wide) and
  at a desktop viewport. Avoid horizontal page scrolling, clipped controls,
  and content hidden behind the persistent player.
- Keep touch targets comfortably tappable (roughly 44px for primary controls)
  and ensure keyboard focus remains visible on the web.
- Preserve Hotwire Native compatibility: favour standard HTML controls,
  Turbo navigation, and small Stimulus controllers over browser-only or
  desktop-only interaction patterns.

## Testing

Every meaningful feature and bug fix must include automated tests. Tests are
not required to be written before implementation, but must accompany it.

- Test behaviour and business rules, including success and meaningful failure
  paths, rather than implementation details.
- Use the narrowest useful test: unit tests for domain objects, model tests for
  persistence behaviour, request tests for HTTP behaviour, and system tests
  for important user journeys.
- Add tests around external adapters using realistic, controlled responses.
  Never require a live Jellyfin server for the regular test suite.
- Keep tests deterministic, readable, and independent. Avoid arbitrary sleeps
  and shared mutable state.
- Run `bin/rails test` and `bundle exec rubocop` before submitting changes.
