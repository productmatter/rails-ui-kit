# Releasing rails-ui-kit

This gem is **not** published to RubyGems. Consumers install it directly from the GitHub repository, pinned to a git tag:

```ruby
gem "rails_ui_kit", git: "git@github.com:productmatter/rails-ui-kit.git", tag: "v0.2.0"
```

Every release is therefore a **git tag** plus a `CHANGELOG.md` entry. There is no `gem push`, no RubyGems credentials, no npm publish.

## Audience

This document is the authoritative procedure for cutting a release. It is written for both human maintainers and AI agents. Follow it exactly — every step is load-bearing.

## Versioning

Semantic versioning: `MAJOR.MINOR.PATCH`.

- **MAJOR** — breaking changes to the public component API, Stimulus identifiers, or registration contract (`registerControllers`, `Ui::*Component.new` signatures).
- **MINOR** — new components, new controllers, new options, additive changes that preserve existing behavior.
- **PATCH** — bug fixes, dependency bumps, internal refactors, documentation.

Pre-1.0 caveat: while on `0.x`, treat MINOR as the breaking-change channel and PATCH as everything else. Do not bump to `1.0.0` without a deliberate stability decision.

## Single source of truth for the version

Two files carry the version string and **must** be bumped together:

1. `lib/rails_ui_kit/version.rb` — `RailsUiKit::VERSION`
2. `package.json` — `"version"`

If they drift, consumers using importmap (Ruby) and consumers using a JS bundler (npm) will resolve different versions for the same git ref. The release script below enforces this.

## Pre-release checklist

Before tagging, verify on a clean working tree:

- [ ] `bundle exec rake test` passes locally
- [ ] `bundle exec rubocop` is clean (or any new offenses are documented)
- [ ] CI is green on the commit you intend to tag
- [ ] `CHANGELOG.md` has an `## [Unreleased]` section with the changes for this release
- [ ] Both version files agree (see the script below)
- [ ] You are on `main` and up to date with `origin/main`

## Cutting the release

```bash
# 1. Pick the new version
NEW_VERSION=0.2.0

# 2. Bump both version files
sed -i '' "s/VERSION = '.*'/VERSION = '${NEW_VERSION}'/" lib/rails_ui_kit/version.rb
# Update package.json's "version" field — use jq if available, otherwise edit by hand
jq ".version = \"${NEW_VERSION}\"" package.json > package.json.tmp && mv package.json.tmp package.json

# 3. Verify they match
ruby -r./lib/rails_ui_kit/version -e "puts RailsUiKit::VERSION"
jq -r .version package.json
# Both must print ${NEW_VERSION}

# 4. Move CHANGELOG's [Unreleased] section to a dated [${NEW_VERSION}] heading
#    and add a fresh empty [Unreleased] section above it.

# 5. Commit
git add lib/rails_ui_kit/version.rb package.json CHANGELOG.md
git commit -m "Release v${NEW_VERSION}"

# 6. Tag (annotated, signed if you sign commits)
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"

# 7. Push commit and tag
git push origin main
git push origin "v${NEW_VERSION}"
```

The tag must be prefixed with `v` (e.g. `v0.2.0`), matching the format consumers reference in their Gemfile.

## CHANGELOG format

Follow [Keep a Changelog](https://keepachangelog.com/) loosely:

```markdown
# Changelog

## [Unreleased]

## [0.2.0] - 2026-05-15

### Added
- New `Ui::TooltipComponent` with `ui--tooltip` controller.

### Changed
- `Ui::ModalComponent` close animation now uses `transitionend` instead of a fixed timeout.

### Fixed
- Dropdown click-outside listener no longer races on slow devices.

### Removed
- Inline `onclick` handlers on confirm dialog buttons (CSP compatibility).
```

Every release entry should be skimmable by a consumer trying to decide whether to upgrade.

## After tagging

1. Notify consumers in the Product Matter dev channel with the tag and a one-line summary.
2. Open PRs in downstream apps that bump their `tag:` pin if the release contains fixes they need.

## Hotfix releases

For an urgent fix on top of a released version that is *not* the current `main`:

```bash
git checkout -b hotfix/v0.2.1 v0.2.0
# apply the fix, commit
# bump versions to 0.2.1, update CHANGELOG
git tag -a v0.2.1 -m "Hotfix v0.2.1"
git push origin hotfix/v0.2.1
git push origin v0.2.1
# open a PR to merge hotfix/v0.2.1 back into main
```

Never re-tag an existing version. If `v0.2.0` is broken, cut `v0.2.1`.

## What not to do

- Do **not** force-push tags. Tags are immutable contracts with consumers.
- Do **not** delete published tags from the remote.
- Do **not** publish to RubyGems or npm. This is an internal gem.
- Do **not** bump only `version.rb` or only `package.json` — they must move together.
- Do **not** tag without a corresponding `CHANGELOG.md` entry.

## For AI agents

If you are an AI agent asked to cut a release:

1. Confirm the target version with the user before running any commands.
2. Run the pre-release checklist verifications and report results before bumping.
3. Stage the version bump and CHANGELOG edit, show the diff, and **stop for user confirmation** before creating the commit.
4. Create the commit and tag, but **stop before pushing**. Show the user `git log -1` and `git tag -l "v*" -n1 | tail -5`, then ask for explicit approval to push.
5. Push only after the user confirms. Push the commit and the tag in two separate commands, in that order.
