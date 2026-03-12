#!/usr/bin/env bash
# create-test-mirror-entries.sh — add or update {PR_NUMBER}_merge-* test image entries
# in mirror.yaml and mirror.lock.yaml files in the DataDog/images repo.
#
# This script is called in the create-test-mirror-pr Github workflow.
# It must be run from the root of DataDog/images and requires crane to be installed.
#
# Required env var:
#   PR_NUMBER  — pull request number in dd-trace-java-docker-build (numeric)
#
# Outputs (when GITHUB_OUTPUT is set):
#   mode=add|update, indicating whether the test images were added or their digests were updated

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! [[ "${PR_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "::error::PR_NUMBER must be numeric (got: '${PR_NUMBER}')" >&2
  exit 1
fi

readonly PREFIX="${PR_NUMBER}_merge-"

# Check if entries already exist in mirror.yaml (use base variant as tester)
if grep -qF "ghcr.io/datadog/dd-trace-java-docker-build:${PREFIX}base" mirror.yaml; then
  MODE="update"
  echo "Entries for '${PREFIX}' already exist — updating digests only"
else
  MODE="add"
  echo "No entries found for '${PREFIX}' — adding new entries"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "mode=${MODE}" >> "${GITHUB_OUTPUT}"
fi

# shellcheck source=scripts/get-image-digests.sh
source "${SCRIPT_DIR}/get-image-digests.sh"

if [[ "$MODE" == "add" ]]; then
  for variant in "${CI_VARIANTS[@]}"; do
    tag="${PREFIX}${variant}"
    printf '  - source: "%s:%s"\n    dest:\n      repo: "dd-trace-java-docker-build"\n      tag: "%s"\n    replication_target: ""\n' \
      "ghcr.io/datadog/dd-trace-java-docker-build" "${tag}" "${tag}" >> mirror.yaml
  done
  echo "Appended ${#CI_VARIANTS[@]} entries to mirror.yaml"

  for variant in "${CI_VARIANTS[@]}"; do
    tag="${PREFIX}${variant}"
    printf '    - source: %s:%s\n      digest: %s\n' \
      "ghcr.io/datadog/dd-trace-java-docker-build" "${tag}" "${DIGESTS[$variant]}" >> mirror.lock.yaml
  done
  echo "Appended ${#CI_VARIANTS[@]} entries to mirror.lock.yaml"
else
  for variant in "${CI_VARIANTS[@]}"; do
    tag="${PREFIX}${variant}"
    update_digest "${tag}" "${DIGESTS[$variant]}" mirror.lock.yaml
    echo "Updated mirror.lock.yaml: ${tag}"
  done
fi
