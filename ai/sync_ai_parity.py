#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = REPO_ROOT / "ai" / "skills.manifest.tsv"
MEMORY_SOURCE_DIR = REPO_ROOT / "ai" / "memories"

PROVIDER_HOMES = {
    "codex": Path.home() / ".codex",
    "claude": Path.home() / ".claude",
}

@dataclass(frozen=True)
class SkillSpec:
    target_name: str
    source_dir: Path
    providers: tuple[str, ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync tracked AI skills and shared memory into Codex and Claude homes."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    for command_name in ("sync", "status"):
        subparser = subparsers.add_parser(command_name)
        subparser.add_argument(
            "--provider",
            action="append",
            choices=sorted(PROVIDER_HOMES),
            help="Restrict work to one provider. Repeatable.",
        )
        subparser.add_argument(
            "--skill",
            action="append",
            help="Restrict work to one tracked skill target name. Repeatable.",
        )
        if command_name == "sync":
            subparser.add_argument(
                "--dry-run",
                action="store_true",
                help="Print planned actions without modifying provider homes.",
            )

    return parser.parse_args()


def load_manifest() -> list[SkillSpec]:
    specs: list[SkillSpec] = []
    with MANIFEST_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle, delimiter="\t")
        for row in reader:
            if not row or not row[0] or row[0].startswith("#"):
                continue
            if len(row) != 3:
                raise ValueError(f"Invalid manifest row: {row!r}")
            target_name, source_path, providers_field = row
            providers = normalize_providers(providers_field)
            specs.append(
                SkillSpec(
                    target_name=target_name,
                    source_dir=(REPO_ROOT / source_path).resolve(),
                    providers=providers,
                )
            )
    return specs


def normalize_providers(value: str) -> tuple[str, ...]:
    raw = value.strip().lower()
    if raw == "both":
        return ("codex", "claude")
    providers = tuple(part.strip() for part in raw.split(",") if part.strip())
    unknown = sorted(set(providers) - set(PROVIDER_HOMES))
    if unknown:
        raise ValueError(f"Unknown providers in manifest: {', '.join(unknown)}")
    return providers


def selected_providers(args: argparse.Namespace) -> list[str]:
    return args.provider or list(PROVIDER_HOMES)


def filtered_specs(args: argparse.Namespace, specs: Iterable[SkillSpec]) -> list[SkillSpec]:
    selected = set(args.skill or [])
    result = []
    for spec in specs:
        if selected and spec.target_name not in selected:
            continue
        result.append(spec)
    return result


def provider_skill_dir(provider: str, target_name: str) -> Path:
    return PROVIDER_HOMES[provider] / "skills" / target_name


def provider_memory_dir(provider: str) -> Path:
    return PROVIDER_HOMES[provider] / "memories" / "shared"


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def copy_tree(src: Path, dst: Path, dry_run: bool) -> None:
    if dry_run:
        print(f"dry-run  sync {src} -> {dst}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        remove_path(dst)
    shutil.copytree(src, dst)


def sync_skill(spec: SkillSpec, provider: str, dry_run: bool) -> None:
    if not spec.source_dir.is_dir():
        raise FileNotFoundError(f"Skill source not found: {spec.source_dir}")
    if not (spec.source_dir / "SKILL.md").is_file():
        raise FileNotFoundError(f"Skill missing SKILL.md: {spec.source_dir}")
    dst = provider_skill_dir(provider, spec.target_name)
    copy_tree(spec.source_dir, dst, dry_run=dry_run)
    if not dry_run:
        print(f"synced   {provider:<6} skill  {spec.target_name}")


def sync_memories(provider: str, dry_run: bool) -> None:
    if not MEMORY_SOURCE_DIR.is_dir():
        raise FileNotFoundError(f"Memory source dir not found: {MEMORY_SOURCE_DIR}")
    dst = provider_memory_dir(provider)
    if dry_run:
        print(f"dry-run  sync {MEMORY_SOURCE_DIR} -> {dst}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        remove_path(dst)
    shutil.copytree(MEMORY_SOURCE_DIR, dst)
    print(f"synced   {provider:<6} memory shared ({count_files(dst)} files)")


def count_files(root: Path) -> int:
    return sum(1 for path in root.rglob("*") if path.is_file())


def sync(args: argparse.Namespace) -> int:
    specs = filtered_specs(args, load_manifest())
    providers = selected_providers(args)
    for provider in providers:
        (PROVIDER_HOMES[provider] / "skills").mkdir(parents=True, exist_ok=True)
        for spec in specs:
            if provider not in spec.providers:
                continue
            sync_skill(spec, provider, dry_run=args.dry_run)
        sync_memories(provider, dry_run=args.dry_run)
    return 0


def status(args: argparse.Namespace) -> int:
    specs = filtered_specs(args, load_manifest())
    providers = selected_providers(args)
    print(f"manifest  {MANIFEST_PATH}")
    print(f"memories  {MEMORY_SOURCE_DIR} ({count_files(MEMORY_SOURCE_DIR)} files)")
    for provider in providers:
        home = PROVIDER_HOMES[provider]
        print(f"\n[{provider}] home={home}")
        for spec in specs:
            if provider not in spec.providers:
                continue
            dst = provider_skill_dir(provider, spec.target_name)
            status_value = "present" if (dst / "SKILL.md").is_file() else "missing"
            print(f"{status_value:<8} skill  {spec.target_name:<28} src={spec.source_dir}")
        memory_dst = provider_memory_dir(provider)
        if memory_dst.is_dir():
            print(f"present   memory shared ({count_files(memory_dst)} files) -> {memory_dst}")
        else:
            print(f"missing   memory shared -> {memory_dst}")
    return 0


def main() -> int:
    args = parse_args()
    try:
        if args.command == "sync":
            return sync(args)
        if args.command == "status":
            return status(args)
    except Exception as exc:
        print(f"error    {exc}", file=sys.stderr)
        return 1
    raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
