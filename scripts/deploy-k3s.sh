#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for executable in ansible-playbook infisical; do
  if ! command -v "$executable" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$executable" >&2
    exit 1
  fi
done

if ! command -v sudo >/dev/null 2>&1; then
  printf 'sudo is required to configure the local host.\n' >&2
  exit 1
fi

read -r -p "Infisical project ID: " project_id
read -r -p "Infisical environment slug: " environment
read -r -p "Infisical secret path [/]: " secret_path
secret_path="${secret_path:-/}"

if [[ -z "$project_id" || -z "$environment" ]]; then
  printf 'Project ID and environment are required.\n' >&2
  exit 1
fi

cd "$repo_root"
exec infisical secrets-manager run \
  --projectId="$project_id" \
  --env="$environment" \
  --path="$secret_path" \
  -- ansible-playbook \
    --ask-become-pass \
    --inventory ansible/inventory.yml \
    ansible/site.yml
