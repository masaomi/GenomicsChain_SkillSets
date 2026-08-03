#!/usr/bin/env bash
# Install (or upgrade) the GenomicsChain SkillSets into a KairosChain instance.
#
#   ./install.sh                    install into the instance at $KAIROS_DATA_DIR or ./.kairos
#   ./install.sh --force            reinstall over an existing copy (this is what
#                                   you want after `git pull`)
#   ./install.sh --data-dir DIR     target a specific instance
#
# `kairos-chain skillset install` copies rather than links, so a `git pull` alone
# does not change what the instance runs — rerun with --force. The gem preserves
# config/ across a --force reinstall, so anchor_profile is not reset.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
force=""
data_dir_arg=()

while [ $# -gt 0 ]; do
  case "$1" in
    --force)    force="--force"; shift ;;
    --data-dir) data_dir_arg=(--data-dir "$2"); shift 2 ;;
    -h|--help)  sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)          echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

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
  kairos-chain "${data_dir_arg[@]}" skillset install "$gem_dir/templates/skillsets/mmp" $force || true
else
  echo "warning: mmp not found under $gem_dir/templates/skillsets — submit will fail closed" >&2
fi

# Dependency order: tier1 and tier2 both declare genomicschain_core.
for pkg in genomicschain_core genomicschain_tier1 genomicschain_tier2; do
  echo "==> $pkg"
  kairos-chain "${data_dir_arg[@]}" skillset install "$here/$pkg" $force
done

echo
echo "Installed. Verify with:"
echo "  kairos-chain ${data_dir_arg[*]} skillset list"
echo
echo "genomicschain_core ships anchor_profile: false, so gc_tier1_submit and"
echo "gc_tier2_submit are not registered on this node. To make this node the"
echo "anchor, copy genomicschain_core.anchor.yml.example over"
echo "config/genomicschain_core.yml in the installed copy and restart."
