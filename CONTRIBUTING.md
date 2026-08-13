# Contributing to Sonzra

Thanks for helping improve Sonzra. For bugs and ideas, start with a GitHub issue.
For changes, open a pull request against `main` from a focused branch.

## Local setup

```bash
bundle install
npm install
bin/rails db:prepare
bin/dev
```

Run the full quality suite before opening a pull request:

```bash
bin/quality
```

## Pull requests

- Keep a pull request focused on one change.
- Include tests for new behavior and regressions.
- Check desktop and narrow mobile layouts for user-facing changes.
- Do not add server credentials, access tokens, private media, or production data.
- Follow [docs/ENGINEERING.md](docs/ENGINEERING.md).

Maintainers require a passing quality check and one approval before merging to
`main`.
