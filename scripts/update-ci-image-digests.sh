#!/usr/bin/env bash
# update-ci-image-digests.sh - add/update ci-* image mirror entries in the DataDog/images repo.
#
# This script is called in the update-mirror-digests Github workflow.
# It must be run from the root of DataDog/images and requires crane to be installed.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_PREFIX="ghcr.io/datadog/dd-trace-java-docker-build"
readonly DEST_REPO="dd-trace-java-docker-build"

is_amd64_only_variant() {
  [[ "$1" == "7" || "$1" == "ibm8" ]]
}

insert_entry_after_last_ci_block() {
  local file="$1" ci_line_prefix="$2" next_block_regex="$3" entry_file="$4"

  awk -v file="${file}" -v ci_line_prefix="${ci_line_prefix}" -v next_block_regex="${next_block_regex}" -v entry_file="${entry_file}" '
    function print_entry(line) {
      while ((getline line < entry_file) > 0) {
        print line
      }
      close(entry_file)
    }
    { lines[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (index(lines[i], ci_line_prefix) == 1) {
          last_ci = i
        }
      }
      if (!last_ci) {
        print "missing dd-trace-java-docker-build ci-* section in " file > "/dev/stderr"
        exit 1
      }
      insert_at = NR + 1
      for (i = last_ci + 1; i <= NR; i++) {
        if (lines[i] ~ next_block_regex) {
          insert_at = i
          break
        }
      }
      for (i = 1; i <= NR; i++) {
        if (i == insert_at) {
          print_entry()
        }
        print lines[i]
      }
      if (insert_at == NR + 1) {
        print_entry()
      }
    }
  ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

write_mirror_yaml_entry() {
  local file="$1" variant="$2" tag="ci-${variant}"

  {
    printf '  - source: "%s:%s"\n' "${SOURCE_PREFIX}" "${tag}"
    printf '    dest:\n'
    printf '      repo: "%s"\n' "${DEST_REPO}"
    printf '      tag: "%s"\n' "${tag}"
    printf '    replication_target: ""\n'
    printf '    platforms:\n'
    printf '      - "linux/amd64"\n'
    if ! is_amd64_only_variant "${variant}"; then
      printf '      - "linux/arm64"\n'
    fi
    printf '    renovate:\n'
    printf '      enabled: true\n'
  } > "${file}"
}

write_mirror_lock_entry() {
  local file="$1" tag="$2" digest="$3"

  printf '    # renovate\n    - source: %s:%s\n      digest: %s\n' \
    "${SOURCE_PREFIX}" "${tag}" "${digest}" > "${file}"
}

insert_mirror_yaml_entry() {
  local variant="$1" entry_file

  entry_file="$(mktemp)"
  write_mirror_yaml_entry "${entry_file}" "${variant}"
  if ! insert_entry_after_last_ci_block mirror.yaml "  - source: \"${SOURCE_PREFIX}:ci-" '^(  (#|- source:)|image_groups:)' "${entry_file}"; then
    rm -f "${entry_file}"
    return 1
  fi
  rm -f "${entry_file}"
}

insert_mirror_lock_entry() {
  local tag="$1" digest="$2" entry_file

  entry_file="$(mktemp)"
  write_mirror_lock_entry "${entry_file}" "${tag}" "${digest}"
  if ! insert_entry_after_last_ci_block mirror.lock.yaml "    - source: ${SOURCE_PREFIX}:ci-" '^    (# renovate|- source:)' "${entry_file}"; then
    rm -f "${entry_file}"
    return 1
  fi
  rm -f "${entry_file}"
}

readonly PREFIX="ci-"
# shellcheck source=scripts/get-image-digests.sh
source "${SCRIPT_DIR}/get-image-digests.sh"

for variant in "${CI_VARIANTS[@]}"; do
  tag="ci-${variant}"
  source="${SOURCE_PREFIX}:${tag}"

  if ! grep -qF "${source}" mirror.yaml; then
    insert_mirror_yaml_entry "${variant}"
    echo "Added mirror.yaml entry: ${tag}"
  fi

  if ! grep -qF "${source}" mirror.lock.yaml; then
    insert_mirror_lock_entry "${tag}" "${DIGESTS[$variant]}"
    echo "Added mirror.lock.yaml entry: ${tag}"
  fi
done

for variant in "${CI_VARIANTS[@]}"; do
  tag="ci-${variant}"
  update_digest "${tag}" "${DIGESTS[$variant]}" mirror.lock.yaml
  echo "Updated mirror.lock.yaml: ${tag}"
done
