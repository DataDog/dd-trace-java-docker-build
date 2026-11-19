#!/usr/bin/env bash
# delete-test-mirror-entries.sh — remove {PR_NUMBER}_merge-* test image entries
# from mirror.yaml and mirror.lock.yaml in the ddoghq/images repo.
#
# This script is called in the delete-test-mirror-pr GitHub workflow.
# It must be run from the root of ddoghq/images.
#
# The tags to remove are read from the PR's group in mirror.yaml rather than
# from a hard-coded variant list. The workflow always runs this script from the
# default branch, so the group may have been created with a different set of
# variants (e.g. before or after an EA JDK was added or removed).
#
# Required env var:
#   PR_NUMBER  — pull request number in dd-trace-java-docker-build (numeric)

set -euo pipefail

readonly SOURCE_PREFIX="ghcr.io/datadog/dd-trace-java-docker-build"
readonly DEST_REPO="dd-trace-java-docker-build"

if ! [[ "${PR_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "::error::PR_NUMBER must be numeric (got: '${PR_NUMBER}')" >&2
  exit 1
fi

readonly PREFIX="${PR_NUMBER}_merge-"

# Perl snippet defining $group_re, which matches the whole mirror.yaml group
# whose tags all start with ${PREFIX}. The leading quote anchors the prefix, so
# "12_merge-" does not match "123_merge-" tags. Capture group 1 holds the tag lines.
# shellcheck disable=SC2016 # Expanded by perl, not bash.
readonly GROUP_RE_PERL='my $group_re = qr/^  - source_prefix: "\Q$ENV{GROUP_SOURCE_PREFIX}\E"\n    dest_repo: "\Q$ENV{GROUP_DEST_REPO}\E"\n    tags:\n((?:      - "\Q$ENV{GROUP_PREFIX}\E[^"\n]+"\n)+)    replication_target: ""(?:\n|\z)/m;'

# run_group_perl CODE [FILE...] — run perl in slurp mode with $group_re defined.
run_group_perl() {
  local code="$1"
  shift
  GROUP_SOURCE_PREFIX="${SOURCE_PREFIX}" \
  GROUP_DEST_REPO="${DEST_REPO}" \
  GROUP_PREFIX="${PREFIX}" \
    perl -0777 -e "${GROUP_RE_PERL} ${code}" "$@"
}

# Prints the tags of the PR's group in mirror.yaml, one per line.
# Exits 46 unless exactly one matching group is found.
list_group_tags() {
  run_group_perl '
    local $_ = <>;
    my @groups;
    push @groups, $1 while /$group_re/g;
    exit 46 if @groups != 1;
    print "$1\n" while $groups[0] =~ /"([^"]+)"/g;
  ' mirror.yaml
}

remove_group_from_mirror_yaml() {
  local file="mirror.yaml"
  run_group_perl '
    local $_ = <>;
    s/$group_re// or exit 44;
    print;
  ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

require_lock_entry_exists() {
  local tag="$1"
  if ! grep -qxF "    - source: ${SOURCE_PREFIX}:${tag}" mirror.lock.yaml; then
    echo "::error::Missing mirror.lock.yaml entry for ${SOURCE_PREFIX}:${tag}" >&2
    exit 1
  fi
}

remove_from_mirror_lock() {
  local tag="$1"
  local src="    - source: ${SOURCE_PREFIX}:${tag}"
  local file="mirror.lock.yaml"
  awk -v src="${src}" '
    $0 == src { skip_digest=1; removed=1; next }
    skip_digest && /^      digest: / { skip_digest=0; next }
    { print }
    END {
      if (!removed) {
        exit 45
      }
    }
  ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

echo "Looking up test mirror entries for prefix '${PREFIX}'..."
if ! group_tags="$(list_group_tags)"; then
  echo "::error::Expected exactly one mirror.yaml group with '${PREFIX}*' tags for ${SOURCE_PREFIX}" >&2
  exit 1
fi
TAGS=()
while IFS= read -r tag; do
  TAGS+=("${tag}")
done <<< "${group_tags}"
echo "Found ${#TAGS[@]} tags: ${TAGS[*]}"

echo "Validating mirror.lock.yaml entries..."
for tag in "${TAGS[@]}"; do
  require_lock_entry_exists "${tag}"
done

echo "Removing test mirror entries for prefix '${PREFIX}'..."
remove_group_from_mirror_yaml
for tag in "${TAGS[@]}"; do
  remove_from_mirror_lock "${tag}"
done

echo "Removed grouped mirror.yaml entry and ${#TAGS[@]} entries from mirror.lock.yaml"
