# basic_config

Portable shell and CLI dotfiles for WSL2 and macOS.

This repo is the source of truth for:

- `~/.zshrc`
- `~/.zshrc.d/*`
- `~/.gitconfig`
- `~/.local/bin/ffmpeg_wrap.sh`
- your default `~/projects` checkout layout
- a manifest-driven project bootstrap flow

## Philosophy

- Keep shared behavior in tracked files.
- Keep OS-specific behavior in tracked platform fragments.
- Keep machine-specific and secret values in untracked local override files.
- Keep `$HOME` as the real home directory.
- Default interactive shells to `~/projects` instead of changing `$HOME`.
- Prefer `$HOME` and `PROJECTS_DIR` over hardcoded `/home/<user>` paths.
- Make dotfile linking explicit and opt-in.

## Layout

```text
basic_config/
  README.md
  setup.sh
  bootstrap.sh
  projects.manifest.tsv
  zsh/
    .zshrc
    .zshrc.d/
      00-base.zsh
      10-aliases.zsh
      15-nvm.zsh
      30-tooling.zsh
      50-wsl.zsh
      50-macos.zsh
      90-projects-default.zsh
    .zshrc.local.example
  git/
    .gitconfig
    .gitconfig.local.example
  bin/
    .local/
      bin/
        ffmpeg_wrap.sh
```

## Recommended Workflow

On a new machine:

```bash
mkdir -p ~/projects
git clone https://github.com/johnrain9/basic_config.git ~/projects/basic_config
cd ~/projects/basic_config
./setup.sh
./setup.sh link-dotfiles
exec zsh
```

That flow is intentional:

- `setup.sh` clones any missing repos from the manifest
- `setup.sh` does not touch your live `~/.zshrc` or `~/.gitconfig` by default
- `setup.sh link-dotfiles` is the explicit step that activates the tracked shell config

If you want to preview what would happen first:

```bash
./setup.sh --dry-run
./setup.sh --dry-run --link-dotfiles
```

## Setup Script

`setup.sh` is the top-level bootstrap script for the whole workspace.

Default behavior:

- create `PROJECTS_DIR` if needed
- clone any missing repos from `projects.manifest.tsv`
- skip repos that already exist locally
- leave live dotfiles alone unless you explicitly request linking

Useful commands:

```bash
./setup.sh
./setup.sh status
./setup.sh list
./setup.sh --pull-existing
./setup.sh --repo basic_config --repo CENTRAL
./setup.sh --dry-run
./setup.sh link-dotfiles
./setup.sh --link-dotfiles
PROJECTS_DIR=~/code ./setup.sh
```

Behavior details:

- `list` prints the manifest only
- `status` shows whether each manifest repo exists locally and also shows dotfile link status
- `link-dotfiles` runs `bootstrap.sh` immediately and exits
- `--link-dotfiles` runs project checkout first, then links dotfiles afterward
- `--pull-existing` runs `git pull --ff-only` in repos that already exist
- `--repo <name>` limits work to specific repos from the manifest
- `--dry-run` prints planned actions without cloning or linking anything

## Repo Manifest

`projects.manifest.tsv` is the editable source of truth for project checkout.

Format:

```text
repo_name<TAB>git_remote_url
```

Comment lines starting with `#` are ignored.

If you want a new machine to clone more or fewer repos, edit this file.

## Dotfile Linking

`bootstrap.sh` is intentionally narrower than `setup.sh`. It only manages symlinks for the tracked dotfiles:

- `zsh/.zshrc` -> `~/.zshrc`
- `zsh/.zshrc.d` -> `~/.zshrc.d`
- `git/.gitconfig` -> `~/.gitconfig`
- `bin/.local/bin/ffmpeg_wrap.sh` -> `~/.local/bin/ffmpeg_wrap.sh`

If a target already exists and is not already the expected symlink, `bootstrap.sh` moves it into a timestamped backup directory under `~/.dotfiles-backups/`.

The script also:

- creates `~/projects`
- creates `~/.local/bin`
- creates `~/.zshrc.local` from the example file if missing
- creates `~/.gitconfig.local` from the example file if missing

## Zsh Loading Model

`~/.zshrc` is intentionally thin. It loads every tracked fragment from `~/.zshrc.d/*.zsh`, then loads the untracked local override:

```zsh
for file in "$HOME"/.zshrc.d/*.zsh; do
  [[ -r "$file" ]] && source "$file"
done

[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

This means:

- shared defaults live in `00-base.zsh`
- aliases and small helpers live in `10-aliases.zsh`
- larger repo and tooling helpers live in `30-tooling.zsh`
- WSL-only config lives in `50-wsl.zsh`
- macOS-only config lives in `50-macos.zsh`
- terminal default-directory behavior lives in `90-projects-default.zsh`

## Platform Model

The shared config sets `MY_PLATFORM` to one of:

- `wsl`
- `linux`
- `macos`
- `unknown`

Platform-specific fragments self-guard, so they can always be tracked together in the same repo.

## Project Directory Model

The config exports:

```zsh
export PROJECTS_DIR="$HOME/projects"
```

Repo-aware helper functions resolve project locations in this order:

1. `$PROJECTS_DIR/<repo>`
2. `$HOME/<repo>`

That allows a gradual migration toward `~/projects` without breaking older layouts immediately.

Examples:

- `CENTRAL` can live at `~/projects/CENTRAL` or `~/CENTRAL`
- `video_queue` can live at `~/projects/video_queue` or `~/video_queue`

## Default Terminal Directory

Interactive shells start in `~/projects` only when the shell was launched in `$HOME` and the directory exists.

That behavior is intentional:

- it does not redefine `$HOME`
- it does not interfere with shells opened for a specific directory
- it keeps standard dotfile, SSH, config, and cache behavior intact

## Local Overrides

These files are intentionally not tracked:

- `~/.zshrc.local`
- `~/.gitconfig.local`

Use them for:

- machine-only aliases
- secrets and tokens
- local PATH additions
- experimental helpers
- editor choices that differ per machine

Example uses for `~/.zshrc.local`:

```zsh
export EDITOR="nvim"
alias workvpn="openvpn --config ~/vpn/work.ovpn"
```

Example uses for `~/.gitconfig.local`:

```gitconfig
[core]
    editor = nvim
```

## Git Config Notes

The tracked `.gitconfig` keeps portable defaults and includes `~/.gitconfig.local` for machine-specific settings.

The GitHub credential helper uses:

```gitconfig
helper = !gh auth git-credential
```

That works on both WSL2 and macOS as long as the GitHub CLI is installed and authenticated.

## Adding More Dotfiles or Repos

To add a new repo to the checkout flow:

1. Add a line to `projects.manifest.tsv`.
2. Run `./setup.sh status` to confirm how it will be handled.
3. Run `./setup.sh` or `./setup.sh --dry-run`.

To add a new managed dotfile:

1. Put the tracked file in the appropriate package directory.
2. Update `bootstrap.sh` to link it into `HOME`.
3. Document the change here if it affects setup behavior.

## AI / Maintainer Map

If another AI or user needs to modify this repo, start here:

- `README.md`: overall operating model and install flow
- `setup.sh`: project bootstrap, clone policy, and dotfile-link entrypoints
- `projects.manifest.tsv`: editable repo checkout manifest
- `bootstrap.sh`: symlink contract into `$HOME`
- `zsh/.zshrc`: shell entrypoint
- `zsh/.zshrc.d/00-base.zsh`: shared environment, detection, prompt, and helpers
- `zsh/.zshrc.d/30-tooling.zsh`: repo-aware shell functions for local tools
- `git/.gitconfig`: shared Git defaults

The intended rule is:

- if a setting should be shared across WSL2 and macOS, track it here
- if a setting is OS-specific but still shared by all machines of that OS, track it in a platform fragment
- if a setting is unique to one machine or contains secrets, keep it local and untracked
