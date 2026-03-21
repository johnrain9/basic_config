# basic_config

Portable shell and CLI dotfiles for WSL2 and macOS.

This repo is the source of truth for:

- `~/.zshrc`
- `~/.zshrc.d/*`
- `~/.gitconfig`
- `~/.local/bin/ffmpeg_wrap.sh`

The repo uses a package-style layout that is compatible with `stow`, but it does not require `stow`. A checked-in `bootstrap.sh` script creates and maintains the symlinks directly so a new machine can be set up with only Git and a shell.

## Philosophy

- Keep shared behavior in tracked files.
- Keep OS-specific behavior in tracked platform fragments.
- Keep machine-specific and secret values in untracked local override files.
- Keep `$HOME` as the real home directory.
- Default interactive shells to `~/projects` instead of changing `$HOME`.
- Prefer `$HOME` and `PROJECTS_DIR` over hardcoded `/home/<user>` paths.

## Layout

```text
basic_config/
  bootstrap.sh
  README.md
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

## How It Works

`bootstrap.sh` symlinks the managed files into your home directory:

- `zsh/.zshrc` -> `~/.zshrc`
- `zsh/.zshrc.d` -> `~/.zshrc.d`
- `git/.gitconfig` -> `~/.gitconfig`
- `bin/.local/bin/ffmpeg_wrap.sh` -> `~/.local/bin/ffmpeg_wrap.sh`

If a target already exists and is not already the expected symlink, the script moves it into a timestamped backup directory under `~/.dotfiles-backups/`.

The script also:

- creates `~/projects`
- creates `~/.local/bin`
- creates `~/.zshrc.local` from the example file if missing
- creates `~/.gitconfig.local` from the example file if missing

## Quick Start

On a new machine:

```bash
mkdir -p ~/projects
git clone https://github.com/johnrain9/basic_config.git ~/projects/basic_config
cd ~/projects/basic_config
./bootstrap.sh
exec zsh
```

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

## Adding More Dotfiles

Follow the existing package layout:

- put shell files under `zsh/`
- put git files under `git/`
- put CLI scripts in `bin/.local/bin/`

Then update `bootstrap.sh` to link the new files.

## Optional Stow Usage

If `stow` is installed later, this repo layout is close to what `stow` expects:

```bash
cd ~/projects/basic_config
stow zsh git bin
```

This repository does not depend on that workflow, but it remains compatible with it.

## AI / Maintainer Map

If another AI or user needs to modify this repo, start here:

- `README.md`: explains the operating model and install flow
- `bootstrap.sh`: defines the symlink contract into `$HOME`
- `zsh/.zshrc`: the shell entrypoint
- `zsh/.zshrc.d/00-base.zsh`: shared environment, detection, prompt, and helpers
- `zsh/.zshrc.d/30-tooling.zsh`: repo-aware shell functions for local tools
- `git/.gitconfig`: shared Git defaults

The intended rule is:

- if a setting should be shared across WSL2 and macOS, track it here
- if a setting is OS-specific but still shared by all machines of that OS, track it in a platform fragment
- if a setting is unique to one machine or contains secrets, keep it local and untracked
