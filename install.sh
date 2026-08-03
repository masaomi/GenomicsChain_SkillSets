#!/usr/bin/env bash
# Install (or upgrade) the GenomicsChain SkillSets into a KairosChain instance.
#
#   bash install.sh                    install into $KAIROS_DATA_DIR, or ./.kairos
#   bash install.sh --force            reinstall over an existing copy (this is what
#                                      you want after `git pull`)
#   bash install.sh --data-dir DIR     target a specific instance
#
# `kairos-chain skillset install` copies rather than links, so a `git pull` alone
# does not change what the instance runs -- rerun with --force. The gem preserves
# config/ across a --force reinstall, so anchor_profile is not reset.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
force=""

while [ $# -gt 0 ]; do
  case "$1" in
    --force)    force="--force"; shift ;;
    --data-dir) export KAIROS_DATA_DIR="$2"; shift 2 ;;
    -h|--help)  sed -n '2,11p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)          echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# The target is passed through the environment, not as a flag. `kairos-chain
# --data-dir DIR skillset install ...` parses --data-dir as a server option and
# starts the server instead of running the subcommand -- it exits 0 having
# installed nothing, which set -e cannot catch.
command -v kairos-chain >/dev/null 2>&1 || {
  echo "kairos-chain not found on PATH. Install the gem first:" >&2
  echo "  gem install kairos-chain" >&2
  exit 1
}

# mmp is required at runtime (the anchor's identity and signing key come from it)
# but is not in the gem's CORE_SKILLSETS, so it is not installed automatically.
# It does ship inside the gem, so point the installer at the gem's own templates.
gem_dir="$(ruby -e 'puts Gem::Specification.find_by_name("kairos-chain").gem_dir')"
if [ -d "$gem_dir/templates/skillsets/mmp" ]; then
  echo "==> mmp (prerequisite, from the installed gem)"
  kairos-chain skillset install "$gem_dir/templates/skillsets/mmp" $force || true
else
  echo "warning: mmp not found under $gem_dir/templates/skillsets -- submit will fail closed" >&2
fi

# Dependency order: tier1 and tier2 both declare genomicschain_core.
packages="genomicschain_core genomicschain_tier1 genomicschain_tier2"
for pkg in $packages; do
  echo "==> $pkg"
  kairos-chain skillset install "$here/$pkg" $force
done

# Verify rather than assume. The failure this catches is a silent no-op, which
# looks exactly like success in the output above.
echo
echo "==> verifying"
listing="$(kairos-chain skillset list)"
missing=""
for pkg in $packages mmp; do
  echo "$listing" | grep -q "^  $pkg " || missing="$missing $pkg"
done

if [ -n "$missing" ]; then
  echo "FAILED: not installed:$missing" >&2
  echo "target was: ${KAIROS_DATA_DIR:-<default: ./.kairos>}" >&2
  exit 1
fi

echo "ok: $(echo "$packages" | wc -w | tr -d ' ') packages + mmp installed into ${KAIROS_DATA_DIR:-./.kairos}"
echo
echo "genomicschain_core ships anchor_profile: false, so gc_tier1_submit and"
echo "gc_tier2_submit are not registered on this node. To make this node the"
echo "anchor, copy config/genomicschain_core.anchor.yml.example over"
echo "config/genomicschain_core.yml in the INSTALLED copy and restart."
