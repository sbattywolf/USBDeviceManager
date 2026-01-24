#!/usr/bin/env python3
"""
Download GitHub Actions run artifacts to a local directory.

Usage:
  python scripts/download_artifacts.py --run-id 21315105846 --out artifacts/ci-run-21315105846

This script prefers the `gh` CLI if available. Otherwise it will use the
GitHub REST API and a token provided via `GITHUB_TOKEN` environment variable.
"""
from __future__ import annotations
import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile


def has_gh_cli() -> bool:
    try:
        subprocess.run(["gh", "--version"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False


def repo_from_env_or_git() -> str:
    repo = os.environ.get("GITHUB_REPOSITORY")
    if repo:
        return repo
    # try to read origin remote from git
    try:
        out = subprocess.check_output(["git", "remote", "get-url", "origin"], stderr=subprocess.DEVNULL)
        url = out.decode().strip()
        # support both git@github.com:owner/repo.git and https://github.com/owner/repo.git
        if url.startswith("git@"):
            # git@github.com:owner/repo.git
            _, path = url.split(":", 1)
            if path.endswith(".git"):
                path = path[:-4]
            return path
        else:
            # https://github.com/owner/repo.git
            parts = url.split("/")
            if len(parts) >= 2:
                owner = parts[-2]
                repo = parts[-1]
                if repo.endswith('.git'):
                    repo = repo[:-4]
                return f"{owner}/{repo}"
    except Exception:
        pass
    raise RuntimeError("Could not determine repository (set GITHUB_REPOSITORY or ensure git remote 'origin' exists)")


def download_with_gh(run_id: int, out_dir: str) -> int:
    print("Using gh CLI to download artifacts...")
    cmd = ["gh", "run", "download", str(run_id), "--dir", out_dir]
    return subprocess.call(cmd)


def api_list_artifacts(owner_repo: str, run_id: int, token: str | None):
    url = f"https://api.github.com/repos/{owner_repo}/actions/runs/{run_id}/artifacts"
    req = urllib.request.Request(url)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    with urllib.request.urlopen(req) as resp:
        data = json.load(resp)
    return data.get("artifacts", [])


def download_artifact_zip(artifact: dict, out_dir: str, token: str | None):
    artifact_id = artifact.get("id")
    name = artifact.get("name") or f"artifact-{artifact_id}"
    download_url = artifact.get("archive_download_url")
    if not download_url:
        print(f"No download URL for artifact {name} ({artifact_id}), skipping")
        return
    print(f"Downloading artifact {name} -> {artifact_id}")
    req = urllib.request.Request(download_url)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    dest = os.path.join(out_dir, f"{name}-{artifact_id}.zip")
    with urllib.request.urlopen(req) as resp, open(dest, "wb") as out:
        shutil.copyfileobj(resp, out)
    print(f"Saved {dest}")
    # unzip
    try:
        with zipfile.ZipFile(dest, 'r') as z:
            z.extractall(os.path.join(out_dir, name))
        print(f"Extracted to {os.path.join(out_dir, name)}")
    except zipfile.BadZipFile:
        print(f"Warning: {dest} not a valid zip file")


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--run-id", type=int, required=True, help="GitHub Actions run id")
    p.add_argument("--out", default=None, help="Output directory (default: artifacts/ci-run-<id>)")
    p.add_argument("--token", default=None, help="GitHub token (or set GITHUB_TOKEN env var)")
    args = p.parse_args(argv)

    run_id = args.run_id
    out_dir = args.out or f"artifacts/ci-run-{run_id}"
    token = args.token or os.environ.get("GITHUB_TOKEN")
    os.makedirs(out_dir, exist_ok=True)

    if has_gh_cli():
        rc = download_with_gh(run_id, out_dir)
        if rc == 0:
            print("Downloaded artifacts using gh")
            return 0
        else:
            print("gh returned non-zero; falling back to API download")

    owner_repo = repo_from_env_or_git()
    print(f"Repository determined as {owner_repo}")
    artifacts = api_list_artifacts(owner_repo, run_id, token)
    if not artifacts:
        print("No artifacts found for the run")
        return 2
    for art in artifacts:
        try:
            download_artifact_zip(art, out_dir, token)
        except Exception as e:
            print(f"Error downloading artifact: {e}")
    print("Done")
    return 0


if __name__ == '__main__':
    sys.exit(main())
