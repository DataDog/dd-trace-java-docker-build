#!/usr/bin/env bash
# update-ci-image-digests.sh — update pinned ci-* image digests in mirror.lock.yaml in the DataDog/images repo.
#
# This script is called in the update-mirror-digests Github workflow.
# It must be run from the root of DataDog/images and requires crane to be installed.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verify all ci-* entries exist before updating
PREFIX="ci-"
# shellcheck source=scripts/get-image-digests.sh
source "${SCRIPT_DIR}/get-image-digests.sh"

for variant in "${CI_VARIANTS[@]}"; do
  if ! grep -qF "ghcr.io/datadog/dd-trace-java-docker-build:ci-${variant}" mirror.lock.yaml; then
    echo "::error::Missing from mirror.lock.yaml: ci-${variant}" >&2
    echo "Bootstrap ci-* entries manually before running this workflow." >&2
    exit 1
  fi
done

# Update existing digest entries in mirror.lock.yaml in-place
for variant in "${CI_VARIANTS[@]}"; do
  tag="ci-${variant}"
  update_digest "${tag}" "${DIGESTS[$variant]}" mirror.lock.yaml
  echo "Updated mirror.lock.yaml: ${tag}"
done
