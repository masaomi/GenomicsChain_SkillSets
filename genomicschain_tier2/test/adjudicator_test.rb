# frozen_string_literal: true

# Layer B: a Tier-1 report read against the code. Every case builds its own
# repository and its own report, so the suite needs no gem, no network and no
# corpus.
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'genomicschain_tier2'

class AdjudicatorTest < Minitest::Test
  # A repository shaped like aMeta: a real software lock, databases that are
  # bare local paths, a rolling master-branch fetch, and a README promising
  # DOIs that no value resolves.
  def ameta_shaped(root)
    write(root, 'workflow/Snakefile', %(container: "docker://continuumio/miniconda3"\n))
    write(root, 'workflow/rules/main.smk', <<~SMK)
      rule KrakenUniq:
          params:
              DB=config["krakenuniq_db"],
          shell:
              "krakenuniq --db {params.DB}"

      rule PureCompute:
          shell:
              "sort {input} > {output}"

      if pv.parse(v) >= pv.parse("8.0.0"):
          rule NCBIMapTre:
              output:
                  tre=os.path.join(config["ncbi_db"], "ncbi.tre"),
              input:
                  tre=storage(
                      "https://github.com/husonlab/megan-ce/raw/master/src/megan/resources/files/ncbi.tre",
                  ),
      else:
          rule NCBIMapTre:
              input:
                  tre=HTTP.remote(
                      "github.com/husonlab/megan-ce/raw/master/src/megan/resources/files/ncbi.tre",
                  ),
    SMK
    write(root, 'config/config.yaml', "krakenuniq_db: resources/krakendb\nncbi_db: resources/ncbi\n")
    write(root, 'conda-linux-64.lock', "@EXPLICIT\nhttps://conda.anaconda.org/x/linux-64/zlib-1.2.13-h0_0.tar.bz2##{'a' * 32}\n")
    write(root, 'README.md', "download from https://doi.org/10.17044/scilifelab.20518251\n")
  end

  # As the prose reading produced it: every step R★, stage 1, both levers
  # read optimistically off the repository landing page.
  def prose_report(rules)
    {
      'rubric_version' => '0.2.5', 'funnel_stage' => 'stage1-prose-only',
      'canonical_id' => { 'value' => '10.1186/s13059-023-03083-9', 'kind' => 'doi' },
      'levers' => { 'software_env_lock' => true, 'in_code_db_pin_classA' => true },
      'steps' => rules.map { |r| { 'step_id' => r, 'label' => r, 'layer' => 'C',
                                   'verdict' => 'R', 'env_capture_class' => 'n/a' } }
    }
  end

  def test_local_path_database_caps_its_step_at_ri
    with_ameta do |a|
      k = disposition(a, 'KrakenUniq')
      assert_equal 'B_pin_prose_only', k[:env_capture_class]
      assert_equal 'RI', k[:proposed_verdict]
      assert_match(/fetch-pin-prose-only/, k[:proposal])
      assert_equal 'resources/krakendb', k[:evidence].first[:locator]
    end
  end

  def test_rolling_master_fetch_is_class_c
    with_ameta do |a|
      n = a['step_dispositions'].select { |s| s[:rule] == 'NCBIMapTre' }
      refute_empty n
      assert(n.all? { |s| s[:env_capture_class] == 'C_mutable_latest' })
      assert(n.all? { |s| s[:proposed_verdict] == 'RI' })
      assert_match(/mutable-fetch-fatal/, n.first[:proposal])
    end
  end

  # A step touching no external resource keeps its verdict. Without this the
  # layer would demote everything and say nothing.
  def test_pure_compute_step_is_not_demoted
    with_ameta do |a|
      p = disposition(a, 'PureCompute')
      assert_equal 'n/a', p[:env_capture_class]
      assert_nil p[:proposed_verdict]
    end
  end

  # The rubric's `:latest` container feeds Lever 1 and the Version axis, not a
  # per-step class. Counting it as class C would demote every rule in the
  # workflow — and the recorded aMeta result (13 of 30, not 30 of 30) shows the
  # assessment that produced the ground truth did not count it that way.
  def test_floating_container_does_not_demote_every_step
    with_ameta do |a|
      assert_operator a['counts']['proposed_demotions'], :<, a['counts']['rules_unique']
      refute(a['resource_classes'].any? { |r| r[:locator].to_s.include?('miniconda3') })
    end
  end

  def test_levers_are_recomputed_from_code_and_disagreement_is_reported
    with_ameta do |a|
      assert_equal true,  a['levers']['code_derived']['software_env_lock']
      assert_equal false, a['levers']['code_derived']['in_code_db_pin_classA']
      assert_equal true,  a['levers']['agree']['software_env_lock']
      assert_equal false, a['levers']['agree']['in_code_db_pin_classA']
      assert_includes codes(a), 'lever_disagrees_in_code_db_pin_classA'
      refute_includes codes(a), 'lever_disagrees_software_env_lock'
    end
  end

  # The rubric's own precondition: R★ requires Stage-2 verification.
  def test_r_star_at_stage1_is_reported_as_unverified
    with_ameta { |a| assert_includes codes(a), 'r_star_awarded_without_stage2' }
  end

  def test_stage_transition_is_proposed_not_applied
    with_ameta do |a|
      assert_equal 'stage1-prose-only', a['stage_transition']['from']
      assert_equal 'stage2-code-verified', a['stage_transition']['to']
      assert_equal false, a['stage_transition']['applied']
    end
  end

  # One step, two rule declarations behind a version conditional. Counting the
  # dispositions instead of the steps would overstate the demotion count.
  def test_conditionally_redeclared_rule_counts_once
    with_ameta do |a|
      n = a['step_dispositions'].select { |s| s[:rule] == 'NCBIMapTre' }
      assert_equal 2, n.length
      assert(n.all? { |s| s[:conditionally_redeclared] })
      assert_operator a['counts']['dispositions'], :>, a['counts']['steps_linked']
      assert_equal 2, a['counts']['proposed_demotions'] # KrakenUniq + NCBIMapTre, not 3
    end
  end

  def test_config_key_read_but_never_declared_is_reported_not_classified
    Dir.mktmpdir('adj') do |root|
      write(root, 'workflow/rules/main.smk', %(rule R:\n    params:\n        d=config["krona_db"],\n))
      write(root, 'config/config.yaml', "other: resources/x\n")
      a = adjudicate(root, prose_report(%w[R]))
      d = a['discrepancies'].find { |x| x[:code] == 'resource_read_but_never_declared' }
      refute_nil d
      assert_match(/krona_db/, d[:statement])
      assert_equal true, d[:needs_human_decision]
      # It is reported, not forced into A, B or C.
      assert_equal 'unclassified', a['resource_classes'].find { |r| r[:key] == 'krona_db' }[:env_capture_class]
    end
  end

  # A file that ships in the repository is pinned by the repository revision.
  def test_path_present_in_the_repository_is_class_a
    Dir.mktmpdir('adj') do |root|
      write(root, 'workflow/rules/main.smk', %(rule R:\n    params:\n        s=config["samplesheet"],\n))
      write(root, 'config/config.yaml', "samplesheet: config/samples.tsv\n")
      write(root, 'config/samples.tsv', "sample\n")
      a = adjudicate(root, prose_report(%w[R]))
      assert_equal 'A_verified_in_code', disposition(a, 'R')[:env_capture_class]
      assert_nil disposition(a, 'R')[:proposed_verdict]
      assert_equal true, a['levers']['code_derived']['in_code_db_pin_classA']
    end
  end

  def test_unlinked_rule_is_reported_never_guessed_at
    with_ameta(report: ->(_) { prose_report(%w[SomeOtherName]) }) do |a|
      assert_operator a['counts']['steps_unlinked'], :>, 0
      assert(a['step_dispositions'].select { |s| s[:tier1_step_id].nil? }
                                  .all? { |s| s[:unlinked_reason] })
      # Nothing is proposed for a step that could not be found.
      assert_equal 0, a['counts']['proposed_demotions']
    end
  end

  def test_nothing_is_signed_and_the_bound_is_declared
    with_ameta do |a|
      assert_equal true, a['counts']['demotion_proposal_is_a_lower_bound']
      assert(a['limits'].any? { |l| l.include?('signed') })
      assert(a['limits'].any? { |l| l.include?('lower bound') || l.include?('DIRECT consumers') })
      assert_equal 'codescan-adjudication-0.1.0', a['adjudication_rubric_version']
    end
  end

  def test_subject_carries_both_inputs_identities
    with_ameta do |a|
      assert_equal '10.1186/s13059-023-03083-9', a['subject']['canonical_id']
      assert_equal '0.2.5', a['subject']['tier1_rubric_version']
      assert_match(/\A[0-9a-f]{64}\z/, a['subject']['codescan_evidence_digest'])
      assert_equal RUBY_VERSION, a['subject']['codescan_toolchain']['ruby']
      assert_equal RUBY_VERSION, a['subject']['adjudication_toolchain']['ruby']
      refute a['subject'].key?('canonical_id_kind'), 'a DOI paper keeps the subject it had before O-3'
    end
  end

  # Self-application design O-3: the kind travels only for a paper with no DOI.
  def test_subject_carries_the_kind_only_for_a_text_sha256_paper
    text_report = lambda do |names|
      prose_report(names).merge('canonical_id' => { 'value' => 'c' * 64, 'kind' => 'text_sha256' })
    end
    with_ameta(report: text_report) do |a|
      assert_equal 'c' * 64, a['subject']['canonical_id']
      assert_equal 'text_sha256', a['subject']['canonical_id_kind']
    end
  end

  # --- helpers ---

  def with_ameta(report: nil)
    Dir.mktmpdir('adj') do |root|
      ameta_shaped(root)
      scan = GenomicsChainTier2::Scanner.new(root).scan
      names = scan['rules'].map { |r| r[:rule] }.uniq
      t1 = report ? report.call(names) : prose_report(names)
      yield GenomicsChainTier2::Adjudicator.new(t1, scan).adjudicate
    end
  end

  def adjudicate(root, t1)
    GenomicsChainTier2::Adjudicator.new(t1, GenomicsChainTier2::Scanner.new(root).scan).adjudicate
  end

  # --- step linking (2026-09-08) ---------------------------------------
  #
  # Linking was whole-string equality against step_id OR the entire label, so it
  # could only match a report whose label IS the rule name — which the fixture
  # above happens to be. Real assessors write prose, and the rule name sits
  # inside it: 0 of 83 steps linked across the six-paper corpus, including a
  # repository with 16 Snakemake rules whose names appear verbatim in the labels.
  def prose_label_report(rules)
    prose_report(rules).merge(
      'steps' => rules.each_with_index.map do |r, i|
        { 'step_id' => "C#{i + 1}",
          'label' => "panREPET Step #{i + 1}: extract TE copies by coverage percentage (#{r} in workflow/)",
          'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' }
      end
    )
  end

  def test_rule_name_inside_a_prose_label_links
    with_ameta(report: method(:prose_label_report).to_proc) do |a|
      k = disposition(a, 'KrakenUniq')
      assert_equal 'C1', k[:tier1_step_id], 'rule name appears as a whole word in the C1 label'
      assert_operator a['counts']['steps_linked'], :>, 0
    end
  end

  # code_rule_hint is the upstream fix: the assessor names the rule in a field
  # meant for it, so Tier-2 stops guessing from prose. It must win over the
  # label, including when the label points somewhere else — the structured
  # field is a statement, the prose is an inference.
  def test_code_rule_hint_links_and_beats_the_label
    report = lambda do |rules|
      prose_report(rules).merge(
        'steps' => [{ 'step_id' => 'C1', 'label' => 'unrelated prose mentioning krakenuniq',
                      'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' },
                    { 'step_id' => 'C2', 'label' => 'the step that actually runs it',
                      'code_rule_hint' => rules.first,
                      'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' }]
      )
    end
    with_ameta(report: report) do |a|
      assert_equal 'C2', disposition(a, 'KrakenUniq')[:tier1_step_id],
                   'the hint must win over a label that names the same rule'
    end
  end

  def test_two_steps_hinting_the_same_rule_are_ambiguous_not_guessed
    report = lambda do |rules|
      prose_report(rules).merge(
        'steps' => %w[C1 C2].map do |id|
          { 'step_id' => id, 'label' => "step #{id}", 'code_rule_hint' => rules.first,
            'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' }
        end
      )
    end
    with_ameta(report: report) do |a|
      amb = a['ambiguous_links'].find { |x| x[:rule] == 'KrakenUniq' }
      refute_nil amb
      assert_equal 'code_rule_hint', amb[:via]
      assert_nil disposition(a, 'KrakenUniq')[:tier1_step_id]
    end
  end

  # Assessors name a rule by its distinctive part: `run_prioritisation` is
  # written "(skip_uORFs rule `prioritisation`)". Measured on the corpus, a
  # 10-character token floor added 3 links, all hand-verifiable; at 6 and 8 it
  # added as many newly-ambiguous links as real ones.
  def test_longest_token_links_when_the_full_rule_name_does_not
    report = lambda do |rules|
      prose_report(rules).merge(
        'steps' => [{ 'step_id' => 'C1',
                      'label' => 'Automated prioritisation of targets (rule `krakenuniq` variant)',
                      'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' }]
      )
    end
    Dir.mktmpdir('adj') do |root|
      write(root, 'workflow/rules/main.smk', "rule run_prioritisation:\n    shell:\n        \"true\"\n")
      write(root, 'config/config.yaml', "x: 1\n")
      scan = GenomicsChainTier2::Scanner.new(root).scan
      names = scan['rules'].map { |r| r[:rule] }.uniq
      a = GenomicsChainTier2::Adjudicator.new(report.call(names), scan).adjudicate
      d = a['step_dispositions'].find { |s| s[:rule] == 'run_prioritisation' }
      assert_equal 'C1', d[:tier1_step_id],
                   'longest token `prioritisation` appears in the label as a whole word'
    end
  end

  # The floor is what keeps the fallback from matching on common words.
  def test_short_tokens_do_not_trigger_the_fallback
    report = lambda do |rules|
      prose_report(rules).merge(
        'steps' => [{ 'step_id' => 'C1', 'label' => 'we ran the sort step over the reads',
                      'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' }]
      )
    end
    Dir.mktmpdir('adj') do |root|
      write(root, 'workflow/rules/main.smk', "rule do_sort_reads:\n    shell:\n        \"true\"\n")
      write(root, 'config/config.yaml', "x: 1\n")
      scan = GenomicsChainTier2::Scanner.new(root).scan
      names = scan['rules'].map { |r| r[:rule] }.uniq
      a = GenomicsChainTier2::Adjudicator.new(report.call(names), scan).adjudicate
      d = a['step_dispositions'].find { |s| s[:rule] == 'do_sort_reads' }
      assert_nil d[:tier1_step_id], '"sort" and "reads" are below the token floor'
    end
  end

  def test_generic_and_short_rule_names_are_refused_not_matched_loosely
    report = lambda do |rules|
      prose_report(rules).merge(
        'steps' => [{ 'step_id' => 'C1', 'label' => 'run all the main targets for the test setup',
                      'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' }]
      )
    end
    with_ameta(report: report) do |a|
      # None of the fixture's rules should attach to that grab-bag label.
      assert_equal 0, a['counts']['steps_linked']
    end
  end

  def test_a_rule_matching_several_steps_is_reported_not_guessed
    report = lambda do |rules|
      prose_report(rules).merge(
        'steps' => [{ 'step_id' => 'C1', 'label' => "first pass of #{rules.first} over the reads",
                      'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' },
                    { 'step_id' => 'C2', 'label' => "second pass of #{rules.first} over the contigs",
                      'layer' => 'C', 'verdict' => 'R', 'env_capture_class' => 'n/a' }]
      )
    end
    with_ameta(report: report) do |a|
      amb = a['ambiguous_links'].find { |x| x[:rule] == 'KrakenUniq' }
      refute_nil amb, 'a rule matching two steps must be reported as ambiguous'
      assert_equal %w[C1 C2], amb[:step_ids]
      assert_nil disposition(a, 'KrakenUniq')[:tier1_step_id]
      assert_match(/ambiguous/, disposition(a, 'KrakenUniq')[:unlinked_reason])
    end
  end

  # --- lever 1 (2026-09-08) --------------------------------------------
  #
  # A digest-pinned container names its own bytes, which is exactly what
  # "statically complete" means, but lever 1 required kind == 'software_env'
  # and containers are kind == 'container'. Combined with conda_spec never
  # returning `immutable`, the lever was satisfiable only by a conda-lock file.
  def test_digest_pinned_container_satisfies_lever_one
    Dir.mktmpdir('adj') do |root|
      write(root, 'workflow/Snakefile',
            %(container: "docker://biocontainers/fastqc@sha256:#{'b' * 64}"\n))
      write(root, 'workflow/rules/main.smk', "rule Solo:\n    shell:\n        \"true\"\n")
      scan = GenomicsChainTier2::Scanner.new(root).scan
      a = GenomicsChainTier2::Adjudicator.new(prose_report(['Solo']), scan).adjudicate
      assert a['levers']['code_derived']['software_env_lock'],
             'a digest-pinned container is a statically-complete environment lock'
    end
  end

  # Both thresholds are published together (author's decision, 2026-09-08):
  # 16/28 declared vs 0/28 byte-fixed, and the finding is the gap between them.
  def test_both_lock_thresholds_are_reported
    Dir.mktmpdir('adj') do |root|
      write(root, 'environment.yml', "dependencies:\n  - samtools=1.17=h6899075_1\n")
      write(root, 'workflow/rules/main.smk', "rule Solo:\n    shell:\n        \"true\"\n")
      scan = GenomicsChainTier2::Scanner.new(root).scan
      lv = GenomicsChainTier2::Adjudicator.new(prose_report(['Solo']), scan).adjudicate['levers']
      refute lv['code_derived']['software_env_lock'],
             'a conda export is `versioned`, never `immutable`'
      assert lv['code_derived']['software_env_lock_at_versioned'],
             'the same export does satisfy the relaxed reading'

      l1 = lv['lever1_environment_lock']
      assert l1['declared_lock']['value']
      refute l1['byte_fixed_lock']['value']
      assert_equal 'versioned', l1['declared_lock']['threshold']
      assert_equal 'immutable', l1['byte_fixed_lock']['threshold']
      assert_equal 'ships a declared lock, but its bytes are not fixed', l1['headline']
      # Every published reading must carry its own threshold, so neither can be
      # lifted out of the record and quoted as "the" lever-1 number.
      assert(%w[declared_lock byte_fixed_lock].all? { |k| l1[k]['threshold'] && l1[k]['means'] })
    end
  end

  def test_lever1_headline_names_the_three_states
    Dir.mktmpdir('adj') do |root|
      write(root, 'workflow/Snakefile', %(container: "docker://x/y@sha256:#{'c' * 64}"\n))
      write(root, 'workflow/rules/main.smk', "rule Solo:\n    shell:\n        \"true\"\n")
      scan = GenomicsChainTier2::Scanner.new(root).scan
      l1 = GenomicsChainTier2::Adjudicator.new(prose_report(['Solo']), scan)
           .adjudicate['levers']['lever1_environment_lock']
      assert_equal 'ships a lock whose bytes are fixed', l1['headline']
    end

    Dir.mktmpdir('adj') do |root|
      write(root, 'workflow/rules/main.smk', "rule Solo:\n    shell:\n        \"true\"\n")
      scan = GenomicsChainTier2::Scanner.new(root).scan
      l1 = GenomicsChainTier2::Adjudicator.new(prose_report(['Solo']), scan)
           .adjudicate['levers']['lever1_environment_lock']
      assert_equal 'ships no environment lock at either threshold', l1['headline']
    end
  end

  def disposition(a, rule) = a['step_dispositions'].find { |s| s[:rule] == rule }
  def codes(a) = a['discrepancies'].map { |d| d[:code] }

  def write(root, rel, content)
    path = File.join(root, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end
end
