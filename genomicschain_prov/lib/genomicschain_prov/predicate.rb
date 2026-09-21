# frozen_string_literal: true

require 'json'
require 'digest'
require_relative 'normalized'

# PinStrength — and the version of that rule, which the record signs as
# pin_strength_version because the six-level reduction lives there — ship
# with the code-reading tier (design §7: prov depends on genomicschain_tier2
# for the rule only). In a dev clone the packages sit side by side;
# installed, they sit side by side under .kairos/skillsets/. Both resolve
# through ../../../genomicschain_tier2/lib when the caller did not put it on
# the load path already.
begin
  require 'genomicschain_tier2'
rescue LoadError
  sibling = File.expand_path('../../../genomicschain_tier2/lib', __dir__)
  raise unless File.directory?(sibling)

  $LOAD_PATH.unshift(sibling)
  require 'genomicschain_tier2'
end

module GenomicsChainProv
  # Predicate — NormalizedProvenance → grades and counts (design v0.1 §5, as
  # revised after review rounds 1 and 2 on 2026-09-20).
  #
  # Deterministic on purpose, like the Tier-2 rubric it borrows its six levels
  # from: the same normalised bundle gives the same grade, so the customer can
  # run it and get the anchor's answer, and can argue with the RULE rather
  # than with a verdict. Nothing here reads a clock, a file or the network,
  # and no name heuristic enters a signed grade: the reference-genome guess,
  # the tag-likeness of a symbolic ref and the seed's presence are reported
  # BESIDE the grades.
  #
  # Aggregation:
  #   item      → one of six levels (PinStrength for images; release-shaped
  #               version strings; checksums; locators capped below immutable)
  #   stage     → environment = the STRONGER of its two routes, a container
  #               image or a package list — one route suffices (§10-8) — over
  #               the items the stage declares for ITSELF. A stage that
  #               declares nothing falls back to the workflow-level items (a
  #               BCO's software_prerequisites apply to every step); the
  #               fallback is never added to a stage's own declaration
  #   category  → environment = the WEAKEST stage, and `absent` with no
  #               stages; inputs / workflow / runtime = the weakest item. A
  #               category with nothing in it is `absent`, not skipped:
  #               declaring nothing never outgrades declaring a floating URL
  #   overall   → the weakest of environment, inputs, workflow, runtime
  #
  # Why per stage (review round 1, three seats concordant): at category level
  # one digest-pinned image made the whole environment `immutable` while other
  # stages named nothing. Why fallback-only (round 2, four seats): with the
  # workflow-level items pooled into every stage, one workflow-level tool read
  # N/N and lifted stages that said nothing themselves. The coverage the
  # claim carries beside the grade counts stages that declared their OWN
  # environment (`stages_with_own_environment/stages_total`).
  #
  # What the grade says: how far the locators in the bundle let a stranger go.
  # What it does not say: whether those locators still resolve, whether the
  # bundle tells the truth about the run, or whether the checksums it carries
  # were recomputed — all `not_checked` on the record.
  module Predicate
    PREDICATE_VERSION = 'prov-predicate-0.3.0'
    # The rule that grades images and locators is tier2's PinStrength. What
    # the record signs is that RULE's version, not the tier2 package's: a
    # package release that leaves the reduction alone must not turn every
    # earlier proof into "not re-derived" (review round 2).
    PIN_STRENGTH_VERSION = GenomicsChainTier2::PinStrength::RULE_VERSION
    # How `outputs_digest` is derived, named so a verifier can re-derive it
    # (§6): sha256 over JSON.generate of the sorted rows [name, algorithm, hex]
    # of every output carrying a checksum, name coerced to a string.
    OUTPUTS_DIGEST_RULE = 'gc-outputs-rows-0.1'
    PS = GenomicsChainTier2::PinStrength
    LEVELS = PS::LEVELS
    # The categories the overall grade is the weakest of. software and
    # container are reported beside them and enter through `environment`.
    CATEGORIES = %w[environment inputs workflow runtime].freeze
    REPORTED = %w[software container environment inputs workflow runtime].freeze

    # --- the version-string rule, in words (design §5, review round 2) ------
    # A BCO `version` is free text. It names a release when, after
    #   1. dropping a leading tool-name token ("GATK 4.5.0.0", "bash 5.2.21"),
    #   2. taking the first whitespace-separated token that remains,
    #   3. dropping a Debian-style epoch ("1:2.3"),
    # the token is digits joined by dots, with an optional leading v/V and any
    # number of suffixes joined by - + . _ ~ (1.4-r122, 0.12.1--hdfd78af_0,
    # 2.3~rc1). Before that test:
    #   - a constraint operator (< > ! ,), a wildcard (*) or a leading ~ / ^
    #     admits more than one release → ranged;
    #   - a token that is literally x (1.x, 1.x.2) → ranged;
    #   - a token from NOT_A_RELEASE, alone or with trailing digits, anywhere
    #     (latest, 0-unknown, 1.0-SNAPSHOT, 2.0.dev3) → floating;
    #   - a string with no digit at all (unknown, HEAD, master) → floating.
    RELEASE_LIKE  = /\A[vV]?\d+(?:\.\d+)*(?:[-+._~]+[A-Za-z0-9]+)*\z/
    RANGE_MARK    = /[<>!,*]|\A[~^]/
    NOT_A_RELEASE = %w[latest unknown head master main dev devel nightly snapshot stable current trunk none null
                       unversioned].freeze
    NOT_A_RELEASE_TOKEN = /\A(?:#{NOT_A_RELEASE.join('|')})\d*\z/i
    IMAGE_DIGEST  = /@sha256:[0-9a-f]{64}/i

    module_function

    # @param np [NormalizedProvenance]
    # @return [Hash] string keys, JSON-native values: predicate_version,
    #   pin_strength_version, outputs_digest_rule, grade_overall,
    #   grades{category}, coverage ("own/total", what the claim carries),
    #   stages[] (the per-stage environment), reference{…}, workflow_ref{…},
    #   seed{…}, counts{…}, items[] (per-item grade with its reason; for
    #   people and for gc_prov_check — the record signs versions, grades and
    #   counts, not items)
    def grade(np)
      sw = np.software.map { |s| item('software', s['name'], s['locator'], *software_grade(s), s['stage']) }
      ct = np.containers.map { |c| item('container', c['name'], c['ref'], *PS.container(c['ref']), c['stage']) }
      stages = stage_environments(np, sw, ct)
      external = np.inputs_external
      inp = external.map { |i| item('inputs', i['name'], i['locator'], *input_grade(i)) }
      wf = item('workflow', np.workflow['name'], np.workflow['repository'] || np.workflow['script'],
                *workflow_grade(np.workflow))
      rt = item('runtime', np.runtime && np.runtime['engine'], np.runtime && np.runtime['locator'],
                *runtime_grade(np.runtime))
      ref = external.select { |i| i['reference_hint'] }
                    .map { |i| item('reference', i['name'], i['locator'], *input_grade(i)) }

      grades = {
        'software' => category(sw),
        'container' => category(ct),
        'environment' => stages.empty? ? 'absent' : weakest(stages.map { |s| s['grade'] }),
        'inputs' => category(inp),
        'workflow' => wf['grade'],
        'runtime' => rt['grade']
      }
      c = counts(np, sw, ct, inp, stages)

      {
        'predicate_version' => PREDICATE_VERSION,
        'pin_strength_version' => PIN_STRENGTH_VERSION,
        'outputs_digest_rule' => OUTPUTS_DIGEST_RULE,
        'grade_overall' => weakest(grades.values_at(*CATEGORIES)),
        'grades' => grades,
        'coverage' => "#{c['stages_with_own_environment']}/#{c['stages_total']}",
        'stages' => stages,
        'reference' => { 'grade' => ref.empty? ? nil : category(ref), 'detection' => 'heuristic', 'count' => ref.length },
        'workflow_ref' => workflow_ref(np.workflow),
        # A parameter whose NAME contains "seed" — a guess, so it is reported
        # here and not in the signed counts (review round 2; §5).
        'seed' => { 'recorded' => np.seed_recorded ? true : false, 'detection' => 'heuristic' },
        'counts' => c,
        'items' => sw + ct + inp + [wf, rt] + ref
      }
    end

    # --- per-item rules ---------------------------------------------------------

    # A tool is graded by what its own entry says: a checksum names bytes; a
    # release-shaped version names a release; a bare name names whatever is
    # current at fetch time. The image it may also name is graded in the
    # container route, never here — otherwise naming the `:latest` image that
    # actually ran would lower the grade below not naming it (review round 1).
    def software_grade(s)
      return ['immutable', 'carries a checksum'] if s['checksum']
      return version_grade(s['name'], s['version']) if s['version']

      ['floating', 'a bare name — no version, no checksum']
    end

    def version_grade(name, version)
      raw = version.to_s.strip
      return ['ranged', "version #{raw.inspect} admits more than one release"] if raw =~ RANGE_MARK

      v = release_token(raw)
      return ['floating', "version #{raw.inspect} names no release"] if v.nil?

      tokens = v.split(/[-+._~]+/)
      return ['ranged', "version #{raw.inspect} admits more than one release (.x)"] if tokens.any? { |t| t =~ /\A[xX]\z/ }
      if tokens.any? { |t| t =~ NOT_A_RELEASE_TOKEN }
        return ['floating', "version #{raw.inspect} names no release"]
      end
      return ['versioned', "#{name} #{v} — a release name; stable by convention only"] if v =~ RELEASE_LIKE

      ['floating', "version #{raw.inspect} names no release"]
    end

    # Steps 1–3 of the rule above. nil when no token carries a digit.
    def release_token(raw)
      t = raw.split(/\s+/).drop_while { |x| x !~ /\d/ }.first
      t&.sub(/\A\d+:/, '')
    end

    # An input is `immutable` only through a checksum field. PinStrength's
    # data_locator reads a hash-like substring in a locator as a content hash
    # — right for a config value inside a repository, wrong here: the locator
    # is a string the producer chooses, and `inputs_with_checksum` would still
    # say 0 (review round 2, reproduced). The locator alone tops out at
    # versioned (a DOI), floating (a URL) or local_path.
    def input_grade(i)
      return ['immutable', 'carries a checksum'] if i['checksum']

      level, reason = PS.data_locator(i['locator'])
      return [level, reason] unless level == 'immutable'

      note = 'a hash inside the locator string is not a checksum field'
      v = i['locator'].to_s
      return ['versioned', "DOI — #{note}"] if v =~ PS::DOI
      return ['floating', "URL — #{note}"] if v =~ PS::URL

      ['local_path', "a filesystem path — #{note}"]
    end

    # A commit hash names the tree by its own hash. Anything symbolic is
    # `floating`: a BCO does not say whether a name is a tag or a branch, and a
    # guess by shape does not enter the signed grade — it is reported beside
    # it in workflow_ref (review round 1).
    def workflow_grade(w)
      if w['repository'].nil? && w['commit'].nil? && w['script'].nil?
        return ['absent', 'no repository, no commit, no script location']
      end

      case w['ref_kind']
      when 'commit' then ['immutable', 'commit hash — the tree is named by its own hash']
      when 'symbolic' then ['floating', "ref #{w['commit']} — a name; the bundle does not say whether it is a tag or a branch"]
      else ['floating', 'a repository or script location with no commit']
      end
    end

    def workflow_ref(w)
      symbolic = w['ref_kind'] == 'symbolic'
      { 'kind' => w['ref_kind'], 'tag_like' => symbolic ? (w['commit'].to_s =~ RELEASE_LIKE ? true : false) : nil,
        'detection' => 'heuristic' }
    end

    def runtime_grade(r)
      return ['absent', 'no runtime named'] if r.nil?
      return ['immutable', 'runtime carries a checksum'] if r['checksum']
      return ['immutable', 'runtime image is digest-pinned'] if r['locator'].to_s =~ IMAGE_DIGEST
      return version_grade(r['engine'], r['version']) if r['version']

      ['absent', "#{r['engine']} without a version"]
    end

    # --- aggregation ------------------------------------------------------------

    # One entry per stage, keyed by the stage id the adapter assigned
    # (position after sorting on step_number). A stage that declares a tool or
    # an image of its own is graded on that declaration only; a stage that
    # declares nothing falls back to the workflow-level items (stage nil).
    # `source` says which: own / inherited / none. No stages → no entries.
    def stage_environments(np, sw, ct)
      inherited_sw = sw.select { |i| i['stage'].nil? }
      inherited_ct = ct.select { |i| i['stage'].nil? }
      np.stages.map do |st|
        id = st['id']
        own_sw = sw.select { |i| i['stage'] == id }
        own_ct = ct.select { |i| i['stage'] == id }
        own = !(own_sw.empty? && own_ct.empty?)
        env_sw = own ? own_sw : inherited_sw
        env_ct = own ? own_ct : inherited_ct
        s_grade = category(env_sw)
        c_grade = category(env_ct)
        { 'id' => id, 'software' => s_grade, 'container' => c_grade, 'grade' => strongest([s_grade, c_grade]),
          'items' => env_sw.length + env_ct.length,
          'own_items' => own_sw.length + own_ct.length,
          'source' => own ? 'own' : ((env_sw + env_ct).empty? ? 'none' : 'inherited') }
      end
    end

    def category(items)
      return 'absent' if items.empty?

      weakest(items.map { |i| i['grade'] })
    end

    def weakest(levels)
      levels.max_by { |l| LEVELS.index(l) }
    end

    def strongest(levels)
      levels.min_by { |l| LEVELS.index(l) }
    end

    def counts(np, sw, ct, inp, stages)
      c = { 'stages_total' => np.stages.length,
            'stages_with_environment' => stages.count { |s| s['items'].positive? },
            'stages_with_own_environment' => stages.count { |s| s['own_items'].positive? },
            'software_total' => sw.length }
      LEVELS.each { |l| c["software_#{l}"] = sw.count { |i| i['grade'] == l } }
      c['containers_total'] = ct.length
      LEVELS.each { |l| c["containers_#{l}"] = ct.count { |i| i['grade'] == l } }
      c['inputs_total'] = inp.length
      c['inputs_with_checksum'] = np.inputs_external.count { |i| i['checksum'] }
      c['inputs_internal'] = np.inputs_internal.length
      c['outputs_total'] = np.outputs.length
      c['outputs_with_checksum'] = np.outputs.count { |o| o['checksum'] }
      c['outputs_digest'] = outputs_digest(np.outputs)
      c['params_total'] = np.params_total
      c['params_count'] = np.params_count
      c
    end

    # OUTPUTS_DIGEST_RULE: sha256 over the sorted [name, algorithm, hex] rows
    # of every output that carries a checksum; nil when none does. Output
    # values never enter the record — this one digest binds the whole column
    # (design §6). The checksums are taken as written in the bundle; nothing
    # here recomputes them. A nil name sorts as "" rather than raising.
    def outputs_digest(outputs)
      rows = outputs.flat_map do |o|
        next [] unless o['checksum']

        o['checksum'].keys.sort.map { |algo| [o['name'].to_s, algo, o['checksum'][algo].to_s] }
      end.sort
      rows.empty? ? nil : Digest::SHA256.hexdigest(JSON.generate(rows))
    end

    def item(category, name, locator, grade, reason, stage = nil)
      { 'category' => category, 'name' => name, 'locator' => locator, 'grade' => grade, 'reason' => reason,
        'stage' => stage }
    end
  end
end
