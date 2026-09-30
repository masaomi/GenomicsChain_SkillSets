# frozen_string_literal: true

# subject_ref — the name a Tier-1 or Tier-2 record gives the paper it is about.
#
# A paper named by a DOI keeps the historical "doi:<value>" form, so every
# record written before text_sha256 existed re-derives the same identity. A
# paper with no DOI (the fictional subject of the self-application
# demonstration, design O-3) is named by the sha256 of its text and written
# "text_sha256:<hex>": a hash labelled "doi:" would name something that does
# not exist.
#
# The other canonical_id kinds (pmid, pdf_sha256, repo_url) still come out as
# "doi:<value>", exactly as before this module; changing that would change the
# identity of records already signed, and is not part of O-3.
module KairosMcp
  module SkillSets
    module GenomicschainCore
      module SubjectRef
        TEXT_SHA256 = 'text_sha256'

        module_function

        def for(value, kind = nil)
          raise ArgumentError, 'canonical_id.value missing' if value.nil? || value.to_s.empty?

          kind.to_s == TEXT_SHA256 ? "#{TEXT_SHA256}:#{value}" : "doi:#{value}"
        end
      end
    end
  end
end
