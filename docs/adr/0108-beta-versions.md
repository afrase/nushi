# 0108. Beta versions: pre-releases with a cask of their own

Status: accepted, 2026-11-11.

## Context
The owner wants to try a larger or uncertain change (a redesign, projects that stay in the sidebar) on the work Mac before it's released, and to drop one that doesn't work out (2026-11-11). Until now a change was tried only once it was on `main` and released. `release.yml` already builds a tag like `v1.2.3-beta.1`, and a GitHub pre-release is seen by neither the update check (GitHub's latest release, ADR 0061) nor the cask (the latest release only, ADR 0055). A first cut added a Settings switch that had the check tell of pre-releases, each downloaded by hand from its page; the owner didn't want to be told of an update with no easy way to take it.

## Decision
- **A beta version is a GitHub pre-release**, tagged `vX.Y.Z-beta.N` for the release it leads to, built by the same workflow after the same checks.
- **A second cask, `nushi@beta`, is how to follow them.** `release.yml` writes both casks from one template (`tools/cask.sh`): `nushi` follows the latest release; `nushi@beta` the newest version of all, a beta or the release that passed it, so a beta moves on to its release by itself. They install the same app and conflict. Following betas is `brew uninstall --cask nushi && brew install --cask afrase/tap/nushi@beta` (chats' data stays); going back is the reverse.
- **No setting.** A Nushi follows beta versions when the beta cask installed it (the daemon looks for `Caskroom/nushi@beta` at each check) or when it is a beta itself (one installed from a release's page, or on Linux). Then the check compares with the highest version among the repository's ten newest releases, pre-releases too. The toast is the same: Copy gives `brew update && brew upgrade --cask nushi@beta`, and Download where the app's cask doesn't have the version.
- **A beta is cut from its change's branch, not from `main`.** The change stays a pull request while it's tried, with `main` merged into it so the beta has every release's fixes. Accepted, it merges and is released; dropped, the pull request is closed and nothing is undone on `main`. One change is in beta at a time; a second stacks on the first's branch.
- **A beta never writes stored data the latest release can't read** (`settings.json`, the daemon's state, `app.json`: new keys only, as the API is additive, ADR 0004), so going back is installing the release.

## Consequences
- The beta cask first exists in the tap once a beta, or a release with this workflow, is published.
- The relay and its web app (the phone) follow releases only; a beta's daemon serves the release's phone app, as any newer daemon does.
- An agent working on a brief never tags or publishes a beta, as it never does a release.

## Alternatives considered
- The Settings switch (built, then dropped): one more setting, and every beta a download and a drag into Applications.
- Updating in place (the app downloading and replacing itself): a new thing that writes programs, with signing and rollback to get right, where Homebrew already does it.
- Betas tagged on `main`: a dropped change must be reverted, and a fix can't be released without the change still being tried.
