# frozen_string_literal: true

module GenomicsChainProv
  # NormalizedProvenance — the seven recorded conditions, read out of a bundle
  # (design v0.1 §4). The bundle stays the digest subject; this structure
  # exists only so the predicate (§5) can grade without knowing which format
  # the bundle came in.
  #
  # Every value is a String, Integer, true/false, nil, or a Hash/Array of those
  # with string keys, so `to_h` round-trips through JSON unchanged and two
  # parses of the same bytes compare equal. The predicate's determinism —
  # "the customer can run it and get the same answer" — rests on that.
  #
  # Two fields the design's sketch did not have, both forced by U0 (2026-09-20):
  #   software / containers at the top level — a BCO names tools per workflow
  #     (`execution_domain.software_prerequisites`), not per step, so per-step
  #     lists alone would be empty for every nf-prov bundle;
  #   inputs[]['internal'] — nf-prov lists the run's own temp files and its own
  #     versions.yml as workflow inputs; the rule that separates them from
  #     supplied inputs is Adapters::Bco.internal_locators (produced by an
  #     earlier step than every consumer) and is re-derivable from the bundle
  #     alone.
  NormalizedProvenance = Struct.new(
    :format,          # 'bco' | 'wrroc'
    :format_version,  # BCO spec_version URL / WRROC conformsTo profile
    :producer,        # {'name','version'} or nil when the bundle does not say
    :workflow,        # {'name','version','repository','commit','ref_kind','path','script','scripts_total','scripts_with_checksum','checksum'}
                      #   checksum: set only when every script[] entry joins an extension sha256 (the first script's), else nil
    :runtime,         # {'engine','version','locator','checksum'} or nil — checksum / digest let it grade immutable
    :software,        # [{'name','version','locator','checksum','stage'}] every tool named, runtime excluded
    :containers,      # [{'ref','name','stage'}] the software entries whose locator is an OCI image reference
    :stages,          # [{'id','step_number','name','description','inputs','outputs','software','container'}] — id is the position after sorting on step_number
    :inputs,          # [{'name','locator','checksum','internal','reference_hint'}]
    :outputs,         # [{'name','locator','checksum','mediatype'}]
    :params_total,    # entries in the parameter list
    :params_count,    # of those, entries carrying a value (not null / empty)
    :seed_recorded,   # true when a parameter whose name contains "seed" carries a value
    :platform,        # {'cpu_architecture','os_name','os_release'} or nil — the producer's statement (v0.1.12)
    :zk_receipts,     # [{'receipt_sha256','image_id','zkvm_name','zkvm_version','step_number','stage',
                      #   'journal_convention','input_uri','output_uri','input_sha256','output_sha256','defects'}]
                      #   declared ZK receipts as the bundle alone can read them (v0.1.12); [] when none
                      #   v0.1.16 adds 'input_hmac_sha256','output_hmac_sha256' (what a 0.2 journal is compared with)
    :commitment,      # {'state' => 'none'|'ok'|'unreadable'|'conflict', 'key_id'} — the gc-commitment-0.1
                      #   declaration (v0.1.16 §6.1). Never leaves the process that parsed the bundle (C5)
    :refusals,        # [String] codes the anchor refuses the bundle for (v0.1.16 §6.1, S2); [] when none
    :notes,           # [String] what the adapter saw and refused to invent a value for
    keyword_init: true
  ) do
    def to_h
      super.transform_keys(&:to_s)
    end

    def inputs_external
      inputs.reject { |i| i['internal'] }
    end

    def inputs_internal
      inputs.select { |i| i['internal'] }
    end
  end
end
