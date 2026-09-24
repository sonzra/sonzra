# Releasing Sonzra

`main` is the protected integration branch. Changes arrive through normal pull
requests; releases arrive through a dedicated `release/` pull request.

## Version policy

The root [`VERSION`](../VERSION) file is the authoritative release version and
does not include the Git tag's `v` prefix. Its value must be valid Semantic
Versioning 2.0.0 and match a dated heading in `CHANGELOG.md`.

| Change | Version increment |
| --- | --- |
| Backward-compatible fix | Patch (`0.1.1`) |
| Backward-compatible feature | Minor (`0.2.0`) |
| Breaking public API or configuration | Major (`1.0.0`) |

Before a stable release, use prerelease identifiers such as
`0.1.0-alpha.1`, `0.1.0-beta.1`, and `0.1.0-rc.1`. The GitHub tag for
`0.1.0-alpha.1` is `v0.1.0-alpha.1`.

## Release procedure

1. Start from current `main`: `git switch -c release/v0.1.0-alpha.1 main`.
2. Update `VERSION` and move the release notes from `Unreleased` into a dated
   `CHANGELOG.md` heading with the exact same version.
3. Open a pull request into `main` and wait for the **Quality** check.
4. Merge the release PR. The release workflow validates the version and notes,
   creates and pushes a signed `v$VERSION` tag, creates the matching GitHub
   release, and triggers the container-image workflow.

Never reuse, move, or delete a published version tag.

## One-time signing setup

Use a dedicated GPG key for release automation. Do not put a personal signing
key in GitHub Actions.

1. Create a GPG signing key whose user ID uses a verified email address on the
   GitHub account that will own releases.
2. Add its **public** armored key in GitHub: **Settings → SSH and GPG keys →
   New GPG key**.
3. Add these repository secrets under **Settings → Secrets and variables →
   Actions**:
   - `RELEASE_GPG_PRIVATE_KEY`: the armored private key.
   - `RELEASE_GPG_PASSPHRASE`: its passphrase.
4. Add these repository variables in the same area:
   - `RELEASE_GIT_NAME`: the GPG key's release identity, such as `Sonzra Release`.
   - `RELEASE_GIT_EMAIL`: the matching verified email address.

The release workflow fails before creating a tag if any signing setting is
missing. Its tagger email must match both the GPG key identity and a verified
email on the GitHub account for GitHub to mark the tag as verified.
