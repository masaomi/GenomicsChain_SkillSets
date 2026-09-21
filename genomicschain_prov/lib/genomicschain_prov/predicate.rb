# frozen_string_literal: true

require 'json'
require 'digest'
require_relative 'normalized'

# PinStrength — and the tier2 package version, which the record signs as
# pin_strength_version because the six-level rule lives there — ship with the
# code-reading tier (design §7: prov depends on genomicschain_tier2 for the
# rule only). In a dev clone the packages sit side by side; installed, they
# sit side by side under .kairos/skillsets/. Both resolve through
# ../../../genomicschain_tier2/lib when the caller did not put it on the load
# path already.
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
  # revised after review round 1 on 2026-09-20).
  #
  # Deterministic on purpose, like the Tier-2 rubric it borrows its six levels
  # from: the same normalised bundle gives the same grade, so the customer can
  # run it and get the anchor's answer, and can argue with the RULE rather
  # than with a verdict. Nothing here reads a clock, a file or the network,
  # and no name heuristic enters a signed grade: the reference-genome guess
  # and the tag-likeness of a symbolic ref are reported BESIDE the grades.
  #
  # Aggregation:
  #   item      → one of six levels (PinStrength for images and locators;
  #               release-shaped version strings; checksums)
  #   stage     → environment = the STRONGER of its two routes, a container
  #               image or a package list — one route suffices (§10-8) — over
  #               the items declared for that stage plus the items declared
  #               for the whole workflow (a BCO's software_prerequisites apply
  #               to every step)
  #   category  → environment = the WEAKEST stage; inputs / workflow / runtime
  #               = the weakest item. A category with nothing in it is
  #               `absent`, not skipped: declaring nothing never outgrades
  #               declaring a floating URL
  #   overall   → the weakest of environment, inputs, workflow, runtime
  #
  # Why per stage (review round 1, three seats concordant): at category level
  # one digest-pinned image made the whole environment `immutable` while other
  # stages named nothing. The stage count that the claim carries beside the
  # grade (`stages_with_environment/stages_total`) says how much of the
  # pipeline the grade actually covers.
  #
  # What the grade says: how far the locators in the bundle let a stranger go.
  # What it does not say: whether those locators still resolve, whether the
  # bundle tells the truth about the run, or whether the checksums it carries
  # were recomputed — all `not_checked` on the record.
  module Predicate
    PREDICATE_VERSION = 'prov-predicate-0.2.0'
    # The rule that grades images and locators is tier2's; its package version
    # is part of the procedure and is signed with the grade (review round 1).
    PIN_STRENGTH_VERSION = GenomicsChainTier2::VERSION
    PS = GenomicsChainTier2::PinStrength
    LEVELS = PS::LEVELS
    # The categories the overall grade is the weakest of. software and
    # container are reported beside them and enter through `environment`.
    CATEGORIES = %w[environment inputs workflow runtime].freeze
    REPORTED = %w[software container environment inputs workflow runtime].freeze
    # A version string that names a release: 0.12.1, 1.4-r122, 2024.06, v1.2.0.
    # A BCO `version` is free text, so `latest`, `unknown`, `HEAD` must not pass
    # as a release; PinStrength.conda_spec cannot tell, because in its own
    # contract (a conda dependency line) `tool=latest` does not occur.
    RELEASE_LIKE = /\Av?\d+(?:\.\d+)*(?:[-+._][A-Za-z0-9]+)*\z/
    # Admits more than one release: a constraint, a wildcard, a trailing .x.
    RANGED = /[<>~!,*]|\.x\z/i
    IMAGE_DIGEST = /@sha256:[0-9a-f]{64}/i

    module_function

    # @param np [NormalizedProvenance]
    # @return [Hash] string keys, JSON-native values: predicate_version,
    #   pin_strength_version, grade_overall, grades{category}, stages[] (the
    #   per-stage environment), reference{…}, workflow_ref{…}, counts{…},
    #   items[] (per-item grade with its reason; for people and for
    #   gc_prov_check — the record signs versions, grades and counts, not items)
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
        'environment' => weakest(stages.map { |s| s['grade'] }),
        'inputs' => category(inp),
        'workflow' => wf['grade'],
        'runtime' => rt['grade']
      }

      {
        'predicate_version' => PREDICATE_VERSION,
        'pin_strength_version' => PIN_STRENGTH_VERSION,
        'grade_overall' => weakest(grades.values_at(*CATEGORIES)),
        'grades' => grades,
        'stages' => stages,
        'reference' => { 'grade' => ref.empty? ? nil : category(ref), 'detection' => 'heuristic', 'count' => ref.length },
        'workflow_ref' => workflow_ref(np.workflow),
        'counts' => counts(np, sw, ct, inp, stages),
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
      v = version.to_s.strip
      return ['ranged', "version #{v.inspect} admits more than one release"] if v =~ RANGED
      return ['versioned', "#{name} #{v} — a release name; stable by convention only"] if v =~ RELEASE_LIKE

      ['floating', "version #{v.inspect} names no release"]
    end

    def input_grade(i)
      return ['immutable', 'carries a checksum'] if i['checksum']

      PS.data_locator(i['locator'])
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

    # One entry per stage: the items declared for that stage plus the
    # workflow-level items (stage nil) it inherits; the stronger of the two
    # routes. A bundle with no steps is graded as one implicit stage carrying
    # the workflow-level items.
    def stage_environments(np, sw, ct)
      ids = np.stages.map { |s| s['id'] }
      ids = [nil] if ids.empty?
      ids.map do |id|
        env_sw = sw.select { |i| i['stage'].nil? || i['stage'] == id }
        env_ct = ct.select { |i| i['stage'].nil? || i['stage'] == id }
        s_grade = category(env_sw)
        c_grade = category(env_ct)
        { 'id' => id, 'software' => s_grade, 'container' => c_grade, 'grade' => strongest([s_grade, c_grade]),
          'items' => env_sw.length + env_ct.length,
          'own_items' => id.nil? ? 0 : (env_sw + env_ct).count { |i| i['stage'] == id } }
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
            'stages_with_environment' => np.stages.empty? ? 0 : stages.count { |s| s['items'].positive? },
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
      c['seed_recorded'] = np.seed_recorded ? true : false
      c
    end

    # sha256 over the sorted (name, algorithm, hex) rows of every output that
    # carries a checksum; nil when none does. Output values never enter the
    # record — this one digest binds the whole column (design §6). The
    # checksums are taken as written in the bundle; nothing here recomputes them.
    def outputs_digest(outputs)
      rows = outputs.flat_map do |o|
        next [] unless o['checksum']

        o['checksum'].keys.sort.map { |algo| [o['name'], algo, o['checksum'][algo]] }
      end.sort
      rows.empty? ? nil : Digest::SHA256.hexdigest(JSON.generate(rows))
    end

    def item(category, name, locator, grade, reason, stage = nil)
      { 'category' => category, 'name' => name, 'locator' => locator, 'grade' => grade, 'reason' => reason,
        'stage' => stage }
    end
  end
end
