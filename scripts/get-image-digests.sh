#!/usr/bin/env bash
# get-image-digests.sh — source this script to populate CI_VARIANTS and DIGESTS.
#
# Required env vars:
#   PREFIX       — tag prefix (e.g. "ci-" or "138_merge-")
#
# After sourcing, callers have access to:
#   CI_VARIANTS  — indexed array of variant names
#   DIGESTS      — associative array mapping image variant to its latest digest (sha256:...)

set -euo pipefail

readonly CI_VARIANTS=(base 7 8 11 17 21 25 tip zulu8 zulu11 oracle8 ibm8 semeru8 semeru11 semeru17 graalvm17 graalvm21 graalvm25)

# update_digest TAG DIGEST FILE
# Finds the line "source: ...:TAG" and updates the digest on the following line.
update_digest() {
  local tag="$1" digest="$2" file="$3"
  awk -v tag="${tag}" -v digest="${digest}" '
    $0 ~ ("source:.*:" tag "$") { found=1 }
    found && /digest:/ { sub(/digest: sha256:[a-f0-9]*/, "digest: " digest); found=0 }
    { print }
  ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

echo "Resolving digests for ${#CI_VARIANTS[@]} variants (prefix: '${PREFIX}')..." >&2
declare -A DIGESTS
for variant in "${CI_VARIANTS[@]}"; do
  tag="${PREFIX}${variant}"
  echo -n "  ${tag} ... " >&2
  DIGESTS[$variant]="$(crane digest "ghcr.io/datadog/dd-trace-java-docker-build:${tag}")"
  echo "${DIGESTS[$variant]}" >&2
done
