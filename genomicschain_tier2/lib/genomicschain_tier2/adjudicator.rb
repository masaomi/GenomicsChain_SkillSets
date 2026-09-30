# frozen_string_literal: true

require_relative 'pin_strength'

module GenomicsChainTier2
  # Layer B: the Tier-1 report read against the code that was scanned.
  #
  # Layer A (Scanner) says what the repository declares. This says what that
  # means for a report written from the prose. The rubric already specifies the
  # shape: `env_capture_class` is defined as "a Stage-2 code-verified
  # classification", and Stage-1 is told in as many words not to assign it —
  # "Without the code-check (Stage-1 prose-only), do NOT assign A/B/C — leave
  # `n/a` and set `funnel_stage: stage1-prose-only`; R★ requires Stage-2
  # verification." This class performs that assignment.
  #
  # The judgement is in the mapping table below, stated once and versioned.
  # APPLYING it is deterministic: same report plus same repository yields the
  # same dispositions, so the party being assessed can re-derive them and argue
  # with the rule rather than with an opaque verdict. That is the whole reason
  # the rule set is data and not prose.
  #
  # It PROPOSES. Nothing here mutates the Tier-1 report, and no verdict is
  # signed: the rubric's human-in-the-loop gate is mandatory, and this is the
  # LLM-free half of the layer that most needs one, because the step linkage it
  # relies on is a name match.
  class Adjudicator
    ADJUDICATION_RUBRIC_VERSION = 'codescan-adjudication-0.1.0'
    RUBRIC_SOURCE = 'repro_tier1_guide (rubric v0.2.5) § fetch-required'

    # A rolling reference: whatever is at that name today. The rubric's own
    # examples are `latest`, current-NCBI-nt, a `master`-branch raw file.
    ROLLING = %r{(?:/(?:master|main|HEAD|latest|current|nightly|dev)/)|:latest\b|(?:^|[^\w])latest([^\w]|$)}i
    # A version-like token inside a URL: v1.2, 2.10.1, or a date stamp.
    VERSIONED_IN_URL = %r{[/_-]v?\d+\.\d+(?:\.\d+)?(?:[/_.-]|\z)|[/_-]20\d{6}(?:[/_.-]|\z)}

    # (class, cap, why). Caps are the rubric's, quoted:
    #   A → "keeps R★-eligibility (subflag fetch-required)"
    #   B → "caps the step at RI (fetch-pin-prose-only)"
    #   C → "fatal below R★ (mutable-fetch-fatal); poisons every downstream consumer"
    CAPS = { 'A_verified_in_code' => nil, 'B_pin_prose_only' => 'RI', 'C_mutable_latest' => 'RI' }.freeze

    def initialize(tier1_report, codescan_report)
      @t1 = normalise_keys(tier1_report)
      @scan = codescan_report
    end

    def adjudicate
      resources = classify_resources
      by_key = resources.each_with_object({}) { |r, h| (h[r[:key]] ||= []) << r }
      steps = dispose_steps(resources, by_key)

      {
        'adjudication_rubric_version' => ADJUDICATION_RUBRIC_VERSION,
        'rubric_source' => RUBRIC_SOURCE,
        'subject' => subject,
        'stage_transition' => stage_transition,
        'resource_classes' => resources,
        'step_dispositions' => steps,
        'levers' => levers(resources),
        'discrepancies' => discrepancies(resources, steps),
        'counts' => counts(steps),
        # Populated during dispose_steps, so it is read AFTER that call above.
        'ambiguous_links' => ambiguous_links,
        'limits' => LIMITS
      }
    end

    private

    # --- resources -------------------------------------------------------

    # Every external reference resource the code names, with its class.
    # Software environments and containers are deliberately NOT given a class:
    # the rubric scores those through the Version axis and Lever 1, and the
    # recorded aMeta assessment (10 B + 3 C = 13 demotions over 30 steps)
    # is only reachable if the repository's one floating container is not
    # counted as a per-step C. Treating it as one would demote every rule.
    def classify_resources
      out = []

      shipped_data.each do |d|
        klass, why = classify(d[:locator], d[:pin], d)
        out << resource(key: d[:name], locator: d[:locator], klass: klass, why: why,
                        source: d[:source], line: d[:line], origin: 'config')
      end

      rules.each do |r|
        Array(r[:urls]).each do |u|
          pin, = PinStrength.data_locator(u)
          klass, why = classify(u, pin, nil)
          out << resource(key: r[:rule], locator: u, klass: klass, why: why,
                          source: r[:source], line: r[:line], origin: 'rule_body')
        end
      end

      # A config key a rule reads that no configuration file declares. The
      # rubric has no class for this, so it is reported and left unclassified
      # rather than being forced into A, B or C.
      declared = shipped_data.map { |d| d[:name] }.to_set
      rules.flat_map { |r| Array(r[:config_keys]) }.uniq.each do |key|
        next if declared.include?(key) || NON_RESOURCE_KEYS.include?(key)

        out << resource(key: key, locator: nil, klass: 'unclassified', origin: 'rule_body',
                        why: 'read by a rule but declared in no configuration file; the rubric ' \
                             'defines no capture class for an undeclared resource',
                        source: nil, line: nil, needs_human_decision: true)
      end

      out
    end

    # Config keys that carry settings, not locations. Kept explicit and short:
    # anything not listed here and not declared becomes a reported gap, which
    # is the failure direction that gets noticed.
    NON_RESOURCE_KEYS = %w[envmodules options samples analyses].freeze

    def classify(locator, pin, decl)
      case pin
      when 'immutable'
        ['A_verified_in_code', 'the locator carries a content hash']
      when 'versioned'
        ['A_verified_in_code', 'the code names a specific versioned artifact (DOI, accession or exact version)']
      when 'floating'
        if locator.to_s =~ ROLLING
          ['C_mutable_latest', 'the code fetches a rolling reference; what it returns changes without notice']
        elsif locator.to_s =~ VERSIONED_IN_URL
          ['A_verified_in_code', 'a version appears in the URL path — inferred from text, not verified']
        else
          ['C_mutable_latest', 'an unversioned URL: nothing fixes which revision is fetched']
        end
      when 'local_path'
        if decl && decl[:present_in_repo]
          ['A_verified_in_code', 'the file ships in the repository, pinned by the repository revision']
        else
          ['B_pin_prose_only', 'the workflow consumes a user-supplied local path; the workflow pins nothing']
        end
      else
        ['unclassified', "no capture class defined for pin strength #{pin.inspect}"]
      end
    end

    def resource(key:, locator:, klass:, why:, source:, line:, origin:, needs_human_decision: false)
      r = { key: key.to_s, locator: locator, env_capture_class: klass, cap: CAPS[klass],
            why: why, source: source, line: line, origin: origin }
      r[:needs_human_decision] = true if needs_human_decision
      # The rubric's B is "the pinned DOI/version lives ONLY in README/paper
      # prose". A path with no prose pin anywhere is not better than that, but
      # the rubric names no class for it, so it is flagged rather than invented.
      r[:subflag] = 'no_prose_pin_either' if klass == 'B_pin_prose_only' && prose_dois.empty?
      r
    end

    # --- steps -----------------------------------------------------------

    # Worst class wins: a rule consuming one class-C resource is class C.
    SEVERITY = { 'A_verified_in_code' => 0, 'unclassified' => 1,
                 'B_pin_prose_only' => 2, 'C_mutable_latest' => 3 }.freeze

    def dispose_steps(_resources, by_key)
      rules.map do |r|
        consumed = (Array(r[:config_keys]) + [r[:rule]]).flat_map { |k| by_key[k] || [] }
        worst = consumed.max_by { |c| SEVERITY.fetch(c[:env_capture_class], 0) }
        klass = worst ? worst[:env_capture_class] : 'n/a'
        cap = CAPS[klass]
        step = link_step(r[:rule])

        d = { rule: r[:rule], source: r[:source], line: r[:line],
              env_capture_class: klass, cap: cap,
              evidence: consumed.map { |c| c.slice(:key, :locator, :env_capture_class, :source, :line) } }
        d[:conditionally_redeclared] = true if r[:conditionally_redeclared]

        if step
          d[:tier1_step_id] = step['step_id']
          d[:tier1_verdict] = step['verdict']
          d[:tier1_env_capture_class] = step['env_capture_class']
          if cap && step['verdict'] == 'R'
            d[:proposed_verdict] = cap
            d[:proposal] = "R★ → #{cap}: #{CAP_REASON[klass]}"
          end
        else
          d[:tier1_step_id] = nil
          d[:unlinked_reason] =
            if ambiguous_links.any? { |a| a[:rule] == r[:rule] }
              'rule name matches more than one Tier-1 step; reported as ambiguous rather than guessed'
            else
              'no Tier-1 step whose id matches, and no label containing this rule name as a whole word'
            end
        end
        d
      end
    end

    CAP_REASON = {
      'B_pin_prose_only' => 'the workflow pins nothing for this resource (fetch-pin-prose-only)',
      'C_mutable_latest' => 'the workflow fetches a rolling resource (mutable-fetch-fatal)'
    }.freeze

    # Rule names that carry no identity: every Snakemake workflow has them, and
    # matching them against prose links a step to whatever it happens to touch.
    GENERIC_RULES = %w[all targets target main run default clean setup test report finalize].freeze
    MIN_NEEDLE = 4
    # Floor for the longest-token fallback; see link_step for why it is 10.
    MIN_TOKEN = 10

    # Link a workflow rule to the Tier-1 step it implements.
    #
    # Equality was the whole test, against `step_id` OR the WHOLE label. That
    # can only ever match a bare id, because assessors write labels as prose:
    #   rule  extractCopies
    #   label "panREPET Step 1: extract TE copies by coverage percentage (extractCopies…"
    # The rule name is right there, and equality could not see it — 0 of 83 steps
    # linked across the six-paper corpus (2026-09-08), including 16 rules in the
    # one workflow-DSL repository.
    #
    # So: exact on `step_id` first (unchanged, and still the strongest signal),
    # then the rule name as a WHOLE WORD inside the label. Whole-word, not
    # substring, so `clique` does not match `cliques`-in-another-sense by
    # accident; generic and very short names are refused outright rather than
    # matched loosely. A rule that matches more than one step is reported as
    # ambiguous instead of silently taking the first.
    def link_step(rule_name)
      raw = rule_name.to_s
      return nil if raw.empty?

      # Strongest signal, and the only one that is not inference: the assessor
      # named the rule in a field meant for it. Everything below this line is
      # recovery from prose, which measured 7 links over 562 steps (2026-09-08).
      # Checked first so that a report carrying hints never falls back at all.
      by_hint = t1_steps.select { |s| s['code_rule_hint'].to_s.downcase == raw.downcase }
      unless by_hint.empty?
        if by_hint.length > 1
          ambiguous_links << { rule: raw, step_ids: by_hint.map { |s| s['step_id'] },
                               via: 'code_rule_hint' }
          return nil
        end
        return by_hint.first
      end

      by_id = t1_steps.find { |s| s['step_id'].to_s.downcase == raw.downcase }
      return by_id if by_id

      needle = raw.downcase.delete('_')
      return nil if needle.length < MIN_NEEDLE || GENERIC_RULES.include?(needle)

      matches = steps_mentioning(needle) { |s| s['label'].to_s.downcase.delete('_') }

      # Fallback: assessors name a rule by its distinctive part, not its full
      # identifier — `run_prioritisation` is written "(skip_uORFs rule
      # `prioritisation`)". So retry on the longest underscore-separated token.
      # The 10-character floor is not taste: at 6 and 8 the same corpus produced
      # as many newly-ambiguous links as new ones, and at 10 it produced 3 new
      # links, all verifiable by hand, with the rest still reported as ambiguous.
      if matches.empty?
        token = raw.downcase.split(/[_\-]/).reject { |t| t.length < MIN_TOKEN }.max_by(&:length)
        matches = token ? steps_mentioning(token) { |s| s['label'].to_s.downcase } : []
      end
      return nil if matches.empty?

      if matches.length > 1
        ambiguous_links << { rule: raw, step_ids: matches.map { |s| s['step_id'] } }
        return nil
      end
      matches.first
    end

    def steps_mentioning(needle)
      t1_steps.select { |s| yield(s) =~ /(?<![a-z0-9])#{Regexp.escape(needle)}(?![a-z0-9])/ }
    end

    def ambiguous_links
      @ambiguous_links ||= []
    end

    # --- levers, discrepancies -------------------------------------------

    # Lever 1: "% papers shipping a statically-complete environment lock
    # (RESOLUTION UNVERIFIED)". Lever 2: "% papers whose workflow obtains ALL
    # external DBs via class A (no B, no C)."
    # A shipped environment declaration counts toward lever 1 if it reaches
    # `level`. Containers are included: a `docker://x@sha256:…` reference names
    # its own bytes, which is what "statically complete" means. Excluding them
    # (kind == 'software_env' only) made a digest-pinned container — the most
    # common way a paper actually locks an environment — score false.
    LOCK_KINDS = %w[software_env container].freeze

    def lock_at?(level)
      order = %w[immutable versioned]
      admitted = order[0..order.index(level)]
      @scan['declarations'].to_a.any? do |d|
        LOCK_KINDS.include?(d[:kind]) && admitted.include?(d[:pin]) && d[:scope] == 'shipped'
      end
    end

    def levers(resources)
      classed = resources.reject { |r| r[:env_capture_class] == 'unclassified' }

      # BOTH readings are published, together, as one two-line finding
      # (author's decision, 2026-09-08). Measured over the 28 scanned papers:
      # 16/28 at `versioned`, 0/28 at `immutable`. Reporting either alone loses
      # the finding, which is the gap between them — "57% ship what they call an
      # environment lock; none ship one whose bytes are fixed."
      #
      # `immutable` is reachable only by a conda-lock explicit URL carrying an
      # md5, or a container digest: a conda environment.yml export, build
      # strings and all, is `versioned` by the rubric and can never satisfy it.
      lock = lock_at?('immutable')
      lock_relaxed = lock_at?('versioned')
      all_a = classed.any? && classed.all? { |r| r[:env_capture_class] == 'A_verified_in_code' }

      claimed = @t1['levers'] || {}
      {
        'code_derived' => { 'software_env_lock' => lock,
                            'software_env_lock_at_versioned' => lock_relaxed,
                            'in_code_db_pin_classA' => all_a },
        'tier1_claimed' => { 'software_env_lock' => claimed['software_env_lock'],
                             'in_code_db_pin_classA' => claimed['in_code_db_pin_classA'] },
        'agree' => { 'software_env_lock' => claimed['software_env_lock'] == lock,
                     'software_env_lock_at_versioned' => claimed['software_env_lock'] == lock_relaxed,
                     'in_code_db_pin_classA' => claimed['in_code_db_pin_classA'] == all_a },
        # The publishable form. `code_derived.software_env_lock` above keeps its
        # original strict meaning for compatibility, and that is exactly why
        # this block exists: an unqualified key that silently means `immutable`
        # invites being quoted as "the" lever-1 number, which would publish 0 %
        # with no sign that a second reading exists. Both readings here carry
        # their threshold and their meaning, so neither can be quoted bare.
        'lever1_environment_lock' => {
          'declared_lock' => {
            'value' => lock_relaxed, 'threshold' => 'versioned',
            'means' => 'an exact conda version or a container tag — a name that should not ' \
                       'move, but nothing enforces that it will not'
          },
          'byte_fixed_lock' => {
            'value' => lock, 'threshold' => 'immutable',
            'means' => 'the bytes are named by their own hash — a conda-lock URL carrying an ' \
                       'md5, or a container digest'
          },
          'headline' => lever1_headline(lock_relaxed, lock),
          'publish' => 'BOTH lines, together. Publishing either alone loses the finding, which ' \
                       'is the distance between them.',
          'resolution' => 'UNVERIFIED for both readings: this is static presence only. Neither ' \
                          'line claims the environment was resolved or installed.'
        },
        'note' => 'Lever 1 is static presence only. The rubric forbids calling it validated: ' \
                  'Tier-1 declines the resolve test, and so does this scan.'
      }
    end

    def lever1_headline(declared, byte_fixed)
      return 'ships a lock whose bytes are fixed' if byte_fixed
      return 'ships a declared lock, but its bytes are not fixed' if declared

      'ships no environment lock at either threshold'
    end

    def discrepancies(resources, steps)
      out = []
      lv = levers(resources)

      %w[software_env_lock in_code_db_pin_classA].each do |k|
        next if lv['agree'][k] || lv['tier1_claimed'][k].nil?

        statement = "The Tier-1 report records #{k}=#{lv['tier1_claimed'][k].inspect}; " \
                    "the code gives #{lv['code_derived'][k].inspect}."
        # Whether the disagreement is about the paper or about the threshold is
        # the first thing a reviewer needs, and only this layer can tell them.
        if k == 'software_env_lock' && lv['agree']['software_env_lock_at_versioned']
          statement += ' At the `versioned` threshold the two AGREE, so this disagreement is ' \
                       'about where lever 1 is set, not about what the repository ships.'
        end
        out << { code: "lever_disagrees_#{k}", statement: statement, claim_source: 'tier1.levers' }
      end

      # The rubric's own precondition, checked rather than assumed.
      awarded = t1_steps.count { |s| s['verdict'] == 'R' }
      if @t1['funnel_stage'] == 'stage1-prose-only' && awarded.positive?
        out << { code: 'r_star_awarded_without_stage2',
                 statement: "#{awarded} step(s) hold R★ while funnel_stage is stage1-prose-only. " \
                            'The rubric requires Stage-2 code verification for R★.',
                 claim_source: 'tier1.funnel_stage + tier1.steps[].verdict' }
      end

      unclassified = resources.select { |r| r[:env_capture_class] == 'unclassified' }
      if unclassified.any?
        out << { code: 'resource_read_but_never_declared',
                 statement: "#{unclassified.length} config key(s) are read by a rule and declared nowhere: " \
                            "#{unclassified.map { |r| r[:key] }.join(', ')}.",
                 claim_source: 'code only', needs_human_decision: true }
      end

      demoted = steps.select { |s| s[:proposed_verdict] }
                     .map { |s| s[:tier1_step_id] || s[:rule] }.uniq.length
      if demoted.positive?
        out << { code: 'steps_proposed_for_demotion',
                 statement: "#{demoted} step(s) hold R★ in the Tier-1 report and consume a resource the " \
                            'workflow does not pin. Each proposal cites the rule and the resource. This ' \
                            'is a LOWER bound: a class-C resource poisons its downstream consumers, and ' \
                            'reaching them needs the dependency graph, which needs evaluation.',
                 claim_source: 'tier1.steps[].verdict vs code' }
      end

      out
    end

    # Counted over Tier-1 STEPS, not over dispositions. A conditionally
    # redeclared rule produces two dispositions for one step, and counting
    # those as two demotions would overstate the result by exactly the number
    # of version-conditional branches in the workflow.
    def counts(steps)
      linked = steps.select { |s| s[:tier1_step_id] }
      demoted = steps.select { |s| s[:proposed_verdict] }
      {
        'rules_in_code' => rules.length,
        'rules_unique' => rules.map { |r| r[:rule] }.uniq.length,
        'tier1_steps' => t1_steps.length,
        'steps_linked' => linked.map { |s| s[:tier1_step_id] }.uniq.length,
        'steps_unlinked' => steps.count { |s| s[:tier1_step_id].nil? },
        'dispositions' => steps.length,
        'by_class' => steps.group_by { |s| s[:env_capture_class] }.transform_values(&:length),
        'proposed_demotions' => demoted.map { |s| s[:tier1_step_id] || s[:rule] }.uniq.length,
        'demotion_proposal_is_a_lower_bound' => true
      }
    end

    def stage_transition
      { 'from' => @t1['funnel_stage'], 'to' => 'stage2-code-verified',
        'applied' => false,
        'note' => 'Proposed. The rubric makes human sign-off mandatory before any attestation, ' \
                  'and nothing here is signed.' }
    end

    def subject
      s = { 'canonical_id' => @t1.dig('canonical_id', 'value') }
      # The kind travels only for a paper with no DOI, so the record can name
      # it "text_sha256:" rather than "doi:" (self-application design O-3).
      # Adjudications of DOI papers keep the exact bytes they had before.
      s['canonical_id_kind'] = 'text_sha256' if @t1.dig('canonical_id', 'kind') == 'text_sha256'
      s.merge(
        'tier1_rubric_version' => @t1['rubric_version'],
        'tier1_report_content_hash' => @t1['report_content_hash'],
        'codescan_evidence_digest' => @scan.dig('target', 'evidence_digest'),
        # No codescan_root here. The adjudication is the digest subject of a
        # signed record (gc_tier2_submit), and a local absolute path in it
        # would make the same reading digest differently on every machine and
        # put an operator's home directory into a public proof. The scan keeps
        # target.root for local use; the record binds the bytes by digest.
        # Two interpreters can be involved: the one that scanned and the one
        # adjudicating. Both are recorded (see Scanner#toolchain for why).
        'codescan_toolchain' => @scan.dig('target', 'toolchain'),
        'adjudication_toolchain' => { 'ruby' => RUBY_VERSION, 'ruby_platform' => RUBY_PLATFORM }
      )
    end

    # --- inputs ----------------------------------------------------------

    def t1_steps = Array(@t1['steps']).map { |s| normalise_keys(s) }
    def rules = Array(@scan['rules'])

    def shipped_data
      Array(@scan['declarations']).select { |d| d[:kind] == 'data' && d[:scope] == 'shipped' }
    end

    def prose_dois
      @prose_dois ||= Array(@scan['prose_locators']).select { |p| PinStrength.doi?(p[:locator]) }
    end

    def normalise_keys(h)
      h.is_a?(Hash) ? h.transform_keys(&:to_s) : h
    end

    LIMITS = [
      'Steps are linked to rules by NAME: exact on step_id, else the rule name as a whole word ' \
        'inside the label. Generic rule names (all, targets, main, ...) and names under 4 ' \
        'characters are refused rather than matched loosely. A rule matching several steps is ' \
        'reported in ambiguous_links, never guessed at.',
      'The rubric says a class-C resource "poisons every downstream consumer". Downstream ' \
        'propagation needs the dependency DAG, which needs workflow evaluation, which this layer ' \
        'refuses. Only DIRECT consumers are demoted, so the proposal is a lower bound.',
      'A rule declared more than once (conditional on a Snakemake version) is flagged: which ' \
        'variant runs cannot be known without evaluating the workflow.',
      'Containers and software environments get no capture class; they are scored through the ' \
        'Version axis and Lever 1. Treating a floating container as a per-step class C would ' \
        'demote every rule in the workflow.',
      'A version read out of a URL path is inferred from text, never verified.',
      'Nothing here is signed and no verdict is issued. Every disposition is a proposal for a ' \
        'human reviewer, per the rubric\'s mandatory sign-off gate.'
    ].freeze
  end
end
