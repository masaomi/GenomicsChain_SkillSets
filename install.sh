#!/usr/bin/env bash
# Install (or upgrade) the GenomicsChain SkillSets into a KairosChain instance.
#
#   bash install.sh                    install into $KAIROS_DATA_DIR, or ./.kairos
#   bash install.sh --force            reinstall over an existing copy (this is what
#                                      you want after `git pull`)
#   bash install.sh --data-dir DIR     target a specific instance
#   bash install.sh --anchor           the anchor's set: everything but genomicschain_tier3
#                                      (an anchor records Tier 3 and never executes it)
#
# `kairos-chain skillset install` copies rather than links, so a `git pull` alone
# does not change what the instance runs -- rerun with --force. The gem preserves
# config/ across a --force reinstall, so anchor_profile is not reset.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
force=""
anchor=""

while [ $# -gt 0 ]; do
  case "$1" in
    --force)    force="--force"; shift ;;
    --data-dir) export KAIROS_DATA_DIR="$2"; shift 2 ;;
    --anchor)   anchor=1; shift ;;
    -h|--help)  sed -n '2,13p' "${BASH_SOURCE[0]}"; exit 0 ;;
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

# Neither mode may leave genomicschain_tier3 on an anchor, where its execution
# tools would register (Tier 3 design §3.2). Checked before anything is installed.
# The target exactly as the gem resolves it (KairosMcp.resolve_data_dir): a literal ~
# expands, and an empty value is the current directory.
data_dir="$(ruby -e 'print File.expand_path(ENV["KAIROS_DATA_DIR"] || File.join(Dir.pwd, ".kairos"))')"
# A listing that failed says nothing about what is installed, so it stops both modes.
if ! listing_before="$(kairos-chain skillset list)"; then
  echo "FAILED: kairos-chain skillset list did not run for $data_dir; nothing was installed." >&2
  exit 1
fi
if [ -n "$anchor" ]; then
  if grep -q "^  genomicschain_tier3 " <<<"$listing_before"; then
    echo "FAILED: genomicschain_tier3 is installed in this target, and an anchor must not carry it." >&2
    echo "Remove it first (KAIROS_DATA_DIR=$data_dir kairos-chain skillset remove genomicschain_tier3)," >&2
    echo "then rerun with --anchor. Nothing was installed." >&2
    exit 1
  fi
else
  core_listed=0
  if grep -q "^  genomicschain_core " <<<"$listing_before"; then core_listed=1; fi
  # The probe answers with codes of its own: 10 not an anchor, 11 an anchor, 12 the
  # config cannot be read, 13 core is listed but has no config here. Anything else,
  # ruby's own 1 included, is no answer and stops: it never reads as "not an anchor".
  probe=0
  core_cfg="$(ruby -ryaml -e '
    cfg = File.join(ARGV[0], "skillsets", "genomicschain_core", "config", "genomicschain_core.yml")
    print cfg
    exit(ARGV[1] == "1" ? 13 : 10) unless File.file?(cfg)
    c = begin
      YAML.safe_load(File.read(cfg))
    rescue StandardError, Psych::SyntaxError
      exit 12
    end
    exit 10 if c.nil?
    exit 12 unless c.is_a?(Hash)
    g = c["genomicschain"]
    exit(g.is_a?(Hash) && g["anchor_profile"] ? 11 : 10)' "$data_dir" "$core_listed")" || probe=$?
  case "$probe" in
    10) ;;
    11)
      echo "FAILED: this target is an anchor (genomicschain.anchor_profile: true in $core_cfg)." >&2
      echo "Install or upgrade it with --anchor, which leaves genomicschain_tier3 out. Nothing was installed." >&2
      exit 1 ;;
    12)
      echo "FAILED: the installed $core_cfg (genomicschain_core.yml) cannot be read, so whether this" >&2
      echo "target is an anchor is unknown. Fix it, or use --anchor for an anchor. Nothing was installed." >&2
      exit 1 ;;
    13)
      echo "FAILED: the listing shows genomicschain_core, but no core config is at $core_cfg, so whether" >&2
      echo "this target is an anchor is unknown. Check KAIROS_DATA_DIR, or use --anchor for an anchor." >&2
      echo "Nothing was installed." >&2
      exit 1 ;;
    *)
      echo "FAILED: the check of the installed core config gave no answer (exit $probe), so whether this" >&2
      echo "target is an anchor is unknown. Nothing was installed." >&2
      exit 1 ;;
  esac
fi

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

# Dependency order: tier1 declares genomicschain_core; tier2 declares nothing; prov declares
# core and tier2; tier3_record declares core and prov; tier3 declares core, prov and
# tier3_record. An anchor installs the record side and never tier3, whose execution tools
# would otherwise register there (Tier 3 design §3.2).
packages="genomicschain_core genomicschain_tier1 genomicschain_tier2 genomicschain_prov genomicschain_tier3_record"
[ -n "$anchor" ] || packages="$packages genomicschain_tier3"
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
if [ -n "$anchor" ]; then
  echo "genomicschain_tier3 is deliberately not installed: this is the anchor's set,"
  echo "which records Tier 3 (genomicschain_tier3_record) and never executes it. If an"
  echo "earlier install put genomicschain_tier3 here, remove it."
  echo "genomicschain_core ships anchor_profile: false, so the submit tools are not"
  echo "registered yet. To make this node the anchor, copy"
  echo "config/genomicschain_core.anchor.yml.example over"
  echo "config/genomicschain_core.yml in the INSTALLED copy and restart."
else
  echo "genomicschain_core ships anchor_profile: false, so gc_tier1_submit and"
  echo "gc_tier3_submit are not registered on this node. An anchor is installed"
  echo "with --anchor, which leaves genomicschain_tier3 out; then copy"
  echo "config/genomicschain_core.anchor.yml.example over"
  echo "config/genomicschain_core.yml in the INSTALLED copy and restart."
fi
