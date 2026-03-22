#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest="$repo_root/projects.manifest.tsv"
projects_dir="${PROJECTS_DIR:-$HOME/projects}"

pull_existing=0
link_dotfiles_after=0
sync_ai_after=0
status_only=0
ai_status_only=0
list_only=0
dry_run=0
declare -a selected_repos=()

usage() {
  cat <<USAGE
Usage:
  ./setup.sh
  ./setup.sh --link-dotfiles
  ./setup.sh --sync-ai
  ./setup.sh --pull-existing
  ./setup.sh --dry-run
  ./setup.sh --repo <name> [--repo <name> ...]
  ./setup.sh list
  ./setup.sh status
  ./setup.sh status-ai
  ./setup.sh link-dotfiles
  ./setup.sh sync-ai
  ./setup.sh --help

Default behavior:
  - create \$PROJECTS_DIR if needed
  - clone any missing repos from projects.manifest.tsv
  - do not modify ~/.zshrc, ~/.gitconfig, or other dotfiles unless asked

Commands:
  list            Print the repo manifest.
  status          Show manifest repos and whether they already exist locally.
  status-ai       Show provider skill and shared-memory parity status.
  link-dotfiles   Run bootstrap.sh to link the repo-managed dotfiles into HOME.
  sync-ai         Sync tracked AI skills and shared memory into provider homes.

Options:
  --link-dotfiles Link dotfiles after repo checkout.
  --sync-ai       Sync tracked AI skills and shared memory after repo checkout.
  --pull-existing Run 'git pull --ff-only' in repos that already exist.
  --dry-run       Print planned actions without cloning or linking anything.
  --repo <name>   Restrict work to one repo name from the manifest. Repeatable.
  --help          Show this message.

Environment:
  PROJECTS_DIR    Override the default checkout root. Defaults to ~/projects.

Examples:
  ./setup.sh
  ./setup.sh --repo basic_config --repo CENTRAL
  ./setup.sh --pull-existing --link-dotfiles --sync-ai
  ./setup.sh --dry-run --repo photo_auto_tagging
  PROJECTS_DIR=~/code ./setup.sh
  ./setup.sh status
  ./setup.sh status-ai
  ./setup.sh link-dotfiles
  ./setup.sh sync-ai
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

run_cmd() {
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'dry-run  %s\n' "$*"
    return 0
  fi
  "$@"
}

wants_repo() {
  local name="$1"
  local selected
  if [[ ${#selected_repos[@]} -eq 0 ]]; then
    return 0
  fi
  for selected in "${selected_repos[@]}"; do
    if [[ "$selected" == "$name" ]]; then
      return 0
    fi
  done
  return 1
}

iter_manifest() {
  while IFS=$'\t' read -r name url; do
    [[ -n "$name" ]] || continue
    [[ "${name:0:1}" == "#" ]] && continue
    [[ -n "$url" ]] || {
      echo "Invalid manifest entry for repo: $name" >&2
      exit 1
    }
    printf '%s\t%s\n' "$name" "$url"
  done < "$manifest"
}

list_manifest() {
  while IFS=$'\t' read -r name url; do
    printf '%-20s %s\n' "$name" "$url"
  done < <(iter_manifest)
}

dotfile_status() {
  local target="$1"
  local expected="$2"
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$expected" ]]; then
    printf 'linked   %s -> %s\n' "$target" "$expected"
  elif [[ -e "$target" || -L "$target" ]]; then
    printf 'custom   %s\n' "$target"
  else
    printf 'missing  %s\n' "$target"
  fi
}

run_ai_status() {
  require_cmd python3
  python3 "$repo_root/ai/sync_ai_parity.py" status
}

run_ai_sync() {
  require_cmd python3
  if [[ "$dry_run" -eq 1 ]]; then
    python3 "$repo_root/ai/sync_ai_parity.py" sync --dry-run
  else
    python3 "$repo_root/ai/sync_ai_parity.py" sync
  fi
}

show_status() {
  local name url local_path remote_url

  echo "projects_dir=$projects_dir"
  while IFS=$'\t' read -r name url; do
    wants_repo "$name" || continue
    local_path="$projects_dir/$name"
    if [[ -d "$local_path/.git" ]]; then
      remote_url="$(git -C "$local_path" remote get-url origin 2>/dev/null || echo no-origin)"
      printf 'present  %-20s %s\n' "$name" "$remote_url"
    elif [[ -e "$local_path" ]]; then
      printf 'blocked  %-20s %s\n' "$name" "$local_path"
    else
      printf 'missing  %-20s %s\n' "$name" "$url"
    fi
  done < <(iter_manifest)

  dotfile_status "$HOME/.zshrc" "$repo_root/zsh/.zshrc"
  dotfile_status "$HOME/.zshrc.d" "$repo_root/zsh/.zshrc.d"
  dotfile_status "$HOME/.gitconfig" "$repo_root/git/.gitconfig"
  dotfile_status "$HOME/.local/bin/ffmpeg_wrap.sh" "$repo_root/bin/.local/bin/ffmpeg_wrap.sh"

  echo
  run_ai_status
}

checkout_repos() {
  local name url target

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'dry-run  mkdir -p %s\n' "$projects_dir"
  else
    mkdir -p "$projects_dir"
  fi

  while IFS=$'\t' read -r name url; do
    wants_repo "$name" || continue
    target="$projects_dir/$name"

    if [[ -d "$target/.git" ]]; then
      printf 'present  %s\n' "$target"
      if [[ "$pull_existing" -eq 1 ]]; then
        printf 'pull     %s\n' "$target"
        run_cmd git -C "$target" pull --ff-only
      fi
      continue
    fi

    if [[ -e "$target" ]]; then
      printf 'skip     %s exists and is not a git repo\n' "$target"
      continue
    fi

    printf 'clone    %s -> %s\n' "$url" "$target"
    run_cmd git clone "$url" "$target"
  done < <(iter_manifest)
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    list)
      list_only=1
      ;;
    status)
      status_only=1
      ;;
    status-ai)
      ai_status_only=1
      ;;
    link-dotfiles)
      if [[ "$dry_run" -eq 1 ]]; then
        printf 'dry-run  %s/bootstrap.sh\n' "$repo_root"
      else
        "$repo_root/bootstrap.sh"
      fi
      exit 0
      ;;
    sync-ai)
      run_ai_sync
      exit 0
      ;;
    --link-dotfiles)
      link_dotfiles_after=1
      ;;
    --sync-ai)
      sync_ai_after=1
      ;;
    --pull-existing)
      pull_existing=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    --repo)
      shift
      [[ $# -gt 0 ]] || {
        echo "--repo requires a value" >&2
        exit 1
      }
      selected_repos+=("$1")
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_cmd git
[[ -f "$manifest" ]] || {
  echo "Manifest not found: $manifest" >&2
  exit 1
}

if [[ "$list_only" -eq 1 ]]; then
  list_manifest
  exit 0
fi

if [[ "$status_only" -eq 1 ]]; then
  show_status
  exit 0
fi

if [[ "$ai_status_only" -eq 1 ]]; then
  run_ai_status
  exit 0
fi

checkout_repos

if [[ "$link_dotfiles_after" -eq 1 ]]; then
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'dry-run  %s/bootstrap.sh\n' "$repo_root"
  else
    "$repo_root/bootstrap.sh"
  fi
else
  echo "dotfiles skipped; run './setup.sh link-dotfiles' when you want to link ~/.zshrc, ~/.gitconfig, and related files"
fi

if [[ "$sync_ai_after" -eq 1 ]]; then
  run_ai_sync
else
  echo "ai parity skipped; run './setup.sh sync-ai' when you want to sync shared skills and memory into Codex and Claude"
fi
