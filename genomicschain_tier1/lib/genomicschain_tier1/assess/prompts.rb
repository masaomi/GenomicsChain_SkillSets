# frozen_string_literal: true

require 'json'

module KairosMcp
  module SkillSets
    module GenomicschainTier1
      module Assess
        # Phase 2 of gc_tier1_assess (spec v0.2 §5).
        #
        # The system prompts are PORTED from the assessor prompts that produced the
        # corpus — stage1_assessor_prompt.md (201 runs) and stage2_assessor_prompt.md
        # (6 runs) — not composed afresh from the rubric. Two things are removed on
        # porting, both of them removals only:
        #
        #   1. Retrieval. The originals tell the assessor to curl / gh api / git clone.
        #      Here the caller supplies `sources`, so the assessor never fetches. That
        #      deletes the originals' largest hazard: on 2026-07-27 two concurrent
        #      assessors shared /tmp/p.xml and one overwrote the other's paper, nearly
        #      producing a schema-valid report describing the WRONG paper under the
        #      right canonical id — invisible to every downstream validator.
        #   2. Tool-derived fields. counts / headline / levers / stage2_candidate /
        #      rubric_hash / manifest / human_signoff / assessor_stack / funnel_stage
        #      are all produced by phases 1, 3 and 4.
        module Prompts
          module_function

          def system_for(funnel_stage)
            funnel_stage.to_s == PreCommit::STAGE2 ? STAGE2_SYSTEM : STAGE1_SYSTEM
          end

          # Sources are labelled so the assessor can tell prose from code — the whole
          # stage-1/stage-2 distinction rests on that difference.
          def user_for(sources:, prior_report: nil)
            parts = sources.each_with_index.map do |src, i|
              body = src['content'].to_s
              digest = src['sha256'] ? " sha256=#{src['sha256']}" : ''
              "=== SOURCE #{i + 1} [#{src['kind']}] ref=#{src['ref']}#{digest} ===\n#{body}"
            end

            if prior_report
              parts << "=== PRIOR STAGE-1 REPORT (revise these steps; keep the granularity) ===\n" \
                       "#{JSON.pretty_generate(prior_report.slice('steps', 'paper_type', 'step_source',
                                                                  'granularity_note', 'capture_claim'))}"
            end

            parts.join("\n\n")
          end

          STAGE1_SYSTEM = <<~PROMPT
            You are a Tier-1 computational-reproducibility READINESS assessor (rubric v0.2.5).
            This is Stage-1 prose triage: you assess from the supplied paper text, repo landing
            page and README PROSE ONLY. You do NOT run code and you do NOT read workflow source
            line by line (that is Stage-2). You have no network access — assess only the sources
            given to you. Output a JSON object ONLY, no prose around it.

            STEPS
            1. Read the sources for Abstract, Methods, Data availability, Code availability. If no
               methods text is present, set assessable.is_assessable=false with reason_if_not and
               STILL emit the JSON — an unassessable paper is a scored outcome, never a silent drop.
            2. Route the paper (rubric Step 0): pure-computational | mixed | pure-wet-lab |
               tool-methods | hybrid. A pure-wet-lab paper with no computational reproduction target
               is assessable=true but has no C-steps.
            3. Find artifacts and record VERBATIM liveness — do not pre-interpret. Code repos
               (GitHub/GitLab/Bitbucket/Zenodo/Software Heritage) and data accessions
               (GEO/SRA/ENA/ArrayExpress/dbGaP/EGA/figshare/Zenodo). Note presence and a coarse
               status: stated-in-paper / URL-present / none.
            4. Build a COARSE step list from the Methods prose: one step per named tool or analysis
               invocation (rubric Step 1). Prefer FEWER, larger steps: |S| is the denominator of
               every ratio in the report, so splitting one tool invocation into its sub-commands
               changes the numbers without adding information. Give each step a stable step_id of
               the form C1, C2 ... for computational steps and W1, W2 ... for wet-lab steps, and set
               layer accordingly (W is out of scope and is not scored). Score each C-step's axes 0/1/2:
                 - data:    2 public+accessible or legitimately controlled-access; 1 accidental
                            gating or missing id; 0 absent.
                 - code:    2 public+exact; 1 reconstructable; 0 absent or private.
                 - version: PROSE PINS ONLY. A lockfile, container or conda env is only a CLAIM at
                            Stage 1, so version is AT MOST 1 for every step. Exact pins without
                            environment closure are 1. Unknown is 0.
                 - params:  2 all; 1 partial; 0 none.
               Set verdict from the axis minimum, capped below R: at Stage 1 the top verdict is RI.
               Use NI when a 0 axis is recoverable and X when it is not.
               Set env_capture_class to "n/a" for every step.
               Set version_subtier ONLY on steps whose version axis is 1, and only to one of
               release_snapshot | exact_pins_partial | floating. Omit the key otherwise.
            5. Set capture_claim to exactly one of:
               none | floating | exact_pins_partial | release_snapshot | env_lock_claimed |
               container_digest_claimed
               This is what the paper or README CLAIMS, not what you verified.
            6. Tag gaps against the 13-type dictionary and record them with where / missing.

            Emit ONLY these keys. Anything else is discarded by the caller:
            paper_type, reproduction_target, step_source, granularity_note, steps, gaps, liveness,
            assessable, capture_claim, contested_corrected.
          PROMPT

          STAGE2_SYSTEM = <<~PROMPT
            You are a Tier-1 computational-reproducibility READINESS assessor (rubric v0.2.5),
            Stage-2 code check. This is a CODE-INSPECTION task, not an execution task. You do NOT
            run pipelines and you do NOT read genomic data. You have no network access — inspect
            only the repository files supplied to you. Output a JSON object ONLY.

            Your job is to resolve, from the actual repository contents, the two orthogonal
            paper-level levers, and to promote steps to R only where the code and environment
            evidence justifies it.

            LEVER 1 — software environment lock
            TRUE only for a statically complete lock closing interpreter + channels + platform +
            transitive deps. Accept: conda-lock.yml, pixi.lock, renv.lock, poetry.lock,
            Pipfile.lock, requirements.txt WITH hashes, a Docker image pinned by DIGEST
            (@sha256:...) on a pinned base, a Singularity image pinned by content digest, or
            `conda env export` output carrying exact build strings (=h...) for every dependency.
            FALSE for: a bare environment.yml with top-level pins only and no build strings or
            transitive closure; an image pinned by a mutable TAG (:1.0, :latest); exact versions
            given only in prose or README; a release_snapshot of scripts or data (that is not a
            software environment lock).
            Report platform_coverage (e.g. "linux-64 only"). A declared but uncovered platform is
            a finding, not a disqualifier.

            LEVER 2 — in-code reference-DB pinning
            TRUE only if the executable workflow obtains EVERY external DB or reference via a
            pinned accession, release tag or checksum resolved IN CODE. A single resource pinned
            only in prose, or fetched as "latest"/rolling, makes this FALSE.

            PER-STEP RE-SCORING (from code, not prose)
            Keep the prior stage-1 step list and its granularity. If the code shows a step was
            mis-identified, say so in granularity_note rather than silently re-splitting.
            For each C-step set env_capture_class to exactly one of:
              A_verified_in_code  — the version or DB pin is verified in the repo (lockfile entry,
                                    pinned accession in code). Cite the file and snippet.
              B_pin_prose_only    — pinned in paper or README prose but NOT enforced in code.
                                    Caps the step at RI.
              C_mutable_latest    — code fetches latest / rolling / a master-branch raw file /
                                    a :latest tag. Fatal below R; poisons downstream consumers.
              n/a                 — pure compute on workflow-internal intermediates.
            Set the version axis to 2 only when env_capture_class is A_verified_in_code AND
            Lever 1's lock covers this step's toolchain; otherwise 1 or 0.
            Set lock_covers_toolchain true only when you can cite the lock entries covering that
            step's tools. The caller refuses R without it.
            Set version_subtier ONLY on steps whose version axis is 1.

            R (R-star) means declared-environment closure, UNEXECUTED. A step qualifies only when
            data>=1 AND code=2 AND version=2 AND env_capture_class=A_verified_in_code AND the lock
            covers its toolchain. If data is embargoed or absent, R stays blocked even when the
            environment and code are complete — record that as a gap.

            Emit ONLY these keys. Anything else is discarded by the caller:
            paper_type, reproduction_target, step_source, granularity_note, steps, gaps, liveness,
            assessable, capture_claim, contested_corrected, lever_evidence.
            lever_evidence is {software_env_lock, lock_cite, platform_coverage,
            in_code_db_pin_classA, db_pin_cite}.
          PROMPT

          # Constrains the assessor to the fields it is allowed to author (spec §5d).
          # Deliberately NOT the report schema: counts, headline, levers, manifest,
          # human_signoff, assessor_stack, funnel_stage and rubric_hash are absent
          # because the tool produces them.
          def output_schema(funnel_stage)
            step = {
              'type' => 'object',
              'required' => %w[step_id layer axes verdict],
              'properties' => {
                'step_id' => { 'type' => 'string' },
                'label' => { 'type' => 'string' },
                'layer' => { 'enum' => %w[C W] },
                'axes' => {
                  'type' => 'object',
                  'required' => Derivation::AXES,
                  'properties' => Derivation::AXES.to_h do |a|
                    [a, { 'type' => 'integer', 'minimum' => 0, 'maximum' => 2 }]
                  end
                },
                'verdict' => { 'enum' => %w[R RI NI X OOS] },
                'env_capture_class' => { 'enum' => Derivation::ENV_CAPTURE_CLASSES },
                'version_subtier' => { 'enum' => Derivation::VERSION_SUBTIERS },
                'subflags' => { 'type' => 'array', 'items' => { 'type' => 'string' } }
              }
            }
            step['properties']['lock_covers_toolchain'] = { 'type' => 'boolean' } if funnel_stage.to_s == PreCommit::STAGE2

            schema = {
              'type' => 'object',
              'required' => %w[paper_type steps gaps liveness assessable capture_claim],
              'properties' => {
                'paper_type' => { 'enum' => %w[pure-computational mixed pure-wet-lab tool-methods hybrid] },
                'reproduction_target' => { 'type' => 'string' },
                'step_source' => {
                  'enum' => %w[snakefile cwl nextflow wdl makefile prose-methods shared-canonical]
                },
                'granularity_note' => { 'type' => 'string' },
                'capture_claim' => { 'enum' => Derivation::CAPTURE_CLAIMS },
                'steps' => { 'type' => 'array', 'items' => step },
                'gaps' => { 'type' => 'array', 'items' => { 'type' => 'object' } },
                'liveness' => { 'type' => 'array', 'items' => { 'type' => 'object' } },
                'assessable' => {
                  'type' => 'object',
                  'required' => %w[is_assessable],
                  'properties' => {
                    'is_assessable' => { 'type' => 'boolean' },
                    'reason_if_not' => { 'type' => 'string' }
                  }
                },
                'contested_corrected' => { 'type' => 'array' }
              }
            }

            if funnel_stage.to_s == PreCommit::STAGE2
              schema['properties']['lever_evidence'] = {
                'type' => 'object',
                'properties' => {
                  'software_env_lock' => { 'type' => 'boolean' },
                  'lock_cite' => { 'type' => 'string' },
                  'platform_coverage' => { 'type' => 'string' },
                  'in_code_db_pin_classA' => { 'type' => 'boolean' },
                  'db_pin_cite' => { 'type' => 'string' }
                }
              }
              schema['required'] << 'lever_evidence'
            end

            schema
          end
        end
      end
    end
  end
end
