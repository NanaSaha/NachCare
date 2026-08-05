module Domain
  module Ai
    module Providers
      # ADR-0007: the dev/test-default provider. Deterministic and
      # network-free — no external call is ever made. `json_schema` is
      # used as an internal contract between our own guardrail callers and
      # this provider (not a strict json-schema-spec object): each
      # guardrail stage passes `{kind: :emergency|:category|:post_check,
      # language:}` and gets back a rule-based classification computed from
      # config/ai_emergency_phrases.yml and config/ai_guardrail_keywords.yml
      # — the same recall-oriented spirit the real LLM prompts ask for,
      # just implemented as keyword matching instead of model inference.
      # Free-text calls (json_schema nil) return a templated response that
      # echoes back any `[[SOURCE: title]]` markers PromptAssembler embeds
      # for retrieved knowledge chunks, so "answered with >= 1 citation"
      # is genuinely exercised in dev/test, not faked.
      class StubProvider < Base
        SOURCE_MARKER_RE = /\[\[SOURCE:\s*(.+?)\]\]/

        def configured?
          true
        end

        def chat(messages:, system:, max_tokens: 512, temperature: 0.3, json_schema: nil)
          if json_schema
            classify(messages:, system:, json_schema:)
          else
            generate(messages:, system:)
          end
        end

        def embed(texts:)
          texts.map { |t| deterministic_vector(t) }
        end

        private

        def classify(messages:, system:, json_schema:)
          text = last_user_content(messages)

          case json_schema[:kind]
          when :emergency
            ChatResult.new(json: { "emergency" => emergency_phrase?(text, json_schema[:language]) }, model: "stub")
          when :category
            ChatResult.new(json: { "category" => classify_category(text, json_schema[:language]) }, model: "stub")
          when :post_check
            flagged, span = post_check(text)
            ChatResult.new(json: { "flagged" => flagged, "span" => span }, model: "stub")
          else
            ChatResult.new(json: {}, model: "stub")
          end
        end

        def generate(messages:, system:)
          sources = (system.to_s + messages.map { |m| m[:content] }.join("\n")).scan(SOURCE_MARKER_RE).flatten.uniq

          text =
            if system.to_s.include?("NachCare AI Assistant")
              stub_assistant_answer(sources)
            elsif system.to_s.include?("T-BRIEF")
              "[stub-brief] Today's result summary is available above. Keep up the daily check-ins."
            elsif system.to_s.include?("T-TRIAGE")
              "[stub-triage] Draft note: review the fired rules above and confirm next action with the caregiver."
            elsif system.to_s.include?("T-CALLNOTE")
              "[stub-callnote] Draft call note: discussed current flag with caregiver; confirm follow-up."
            elsif system.to_s.include?("T-REPORT")
              "[stub-report] Overview: episode summary generated from structured data (see attached record)."
            elsif system.to_s.include?("T-TRANSLATE")
              last_user_content(messages)
            elsif system.to_s.include?("T-EXPLAIN")
              stub_explain_answer(system)
            else
              "[stub] response"
            end

          ChatResult.new(text: text, model: "stub", json: nil)
        end

        # Echoes the ITEM/DETAIL the prompt template embedded (see
        # config/prompts/explain_care_plan_item.md) rather than a fixed
        # canned string, the same "genuinely exercise groundedness in
        # dev/test" spirit as #stub_assistant_answer echoing SOURCE
        # markers above — proves the task's data actually reached the
        # provider without needing real model inference.
        def stub_explain_answer(system)
          item = system[/^ITEM: (.+)$/, 1]
          detail = system[/^DETAIL \(from the nurse, verbatim.*?\): (.+)$/, 1]
          return "[stub-explain] Here's what your nurse set up." if item.blank?

          "[stub-explain] About #{item}: #{detail}"
        end

        def stub_assistant_answer(sources)
          if sources.any?
            "Here's what the guide says: #{sources.first}. " \
              "#{sources.map { |s| "(Source: #{s})" }.join(' ')}"
          else
            "I don't have an approved source for that yet, so I can't answer confidently — " \
              "I'll let the care team know you asked."
          end
        end

        def last_user_content(messages)
          messages.reverse.find { |m| m[:role].to_s == "user" }&.fetch(:content, "").to_s
        end

        def emergency_phrase?(text, language)
          phrases = Domain::Ai::GuardrailConfig.emergency_phrases(language)
          normalized = text.downcase
          phrases.any? { |p| normalized.include?(p.downcase) }
        end

        def classify_category(text, language)
          normalized = text.downcase
          return "medication_or_dosage" if Domain::Ai::GuardrailConfig.medication_terms(language).any? { |k| normalized.include?(k.downcase) }
          return "diagnosis_or_prognosis" if Domain::Ai::GuardrailConfig.diagnosis_terms(language).any? { |k| normalized.include?(k.downcase) }
          return "out_of_scope" if Domain::Ai::GuardrailConfig.injection_phrases(language).any? { |k| normalized.include?(k.downcase) }
          return "out_of_scope" if text.blank? || text.length < 2

          "in_scope"
        end

        def post_check(drafted_answer)
          normalized = drafted_answer.to_s.downcase
          hit = Domain::Ai::GuardrailConfig.medication_terms("en").find { |k| normalized.include?(k.downcase) } ||
                Domain::Ai::GuardrailConfig.diagnosis_terms("en").find { |k| normalized.include?(k.downcase) }
          [ hit.present?, hit ]
        end

        # Feature hashing ("the hashing trick", à la scikit-learn's
        # HashingVectorizer / Vowpal Wabbit) rather than whole-string or
        # per-token-random-direction hashing: each token deterministically
        # hashes to one of 1024 buckets and increments it, then the vector
        # is L2-normalized. Two texts sharing vocabulary land weight in
        # the same buckets, so cosine similarity genuinely tracks word
        # overlap (unlike averaging independent random per-token
        # directions, which washes out to near-zero similarity
        # regardless of overlap at this dimensionality) — needed for
        # `rake ai:eval`'s in-scope/citation assertion to be meaningful
        # against the network-free stub. Still not real semantic
        # embedding (no synonyms, no cross-language relation) — see
        # docs/AI_EVAL_REPORT.md's noted limitation for the local
        # stub-provider run.
        # A tiny stopword list so extremely common words (which appear in
        # nearly every chunk) don't drown out the content words that
        # actually distinguish one chunk from another — without this,
        # two unrelated texts that both happen to contain "a"/"the"/"in"
        # score deceptively high.
        # ADR-0013: "she"/"her"/"he"/"him" added when the knowledge base grew
        # past 2 docs — every doc in this single-patient-narrative KB refers
        # to the patient by pronoun in nearly every sentence, so (like
        # "today"/"todays" above) they carry zero discriminative signal and
        # were measurably drowning out the topic-specific words that
        # actually distinguish e.g. "Bathing and Hygiene Guide" from
        # "Activity and Exercise Guide" — see docs/adr/0013 for the
        # before/after similarity scores that motivated this.
        STOPWORDS = %w[
          a an the is are was were be to of and or for on with you your this
          that it me my at as how do does did i in s d today todays whats
          what will would can could should if like just about
          she her he him his hers
        ].to_set.freeze

        def deterministic_vector(text)
          tokens = text.to_s.downcase.scan(/\w+/).reject { |t| STOPWORDS.include?(t) }
          tokens = text.to_s.downcase.scan(/\w+/) if tokens.empty?
          tokens = [ text.to_s ] if tokens.empty?

          vector = Array.new(1024, 0.0)
          tokens.each { |t| vector[bucket_for(t)] += 1.0 }

          norm = Math.sqrt(vector.sum { |v| v * v })
          norm.zero? ? vector : vector.map { |v| v / norm }
        end

        def bucket_for(token)
          Digest::SHA256.hexdigest(token).to_i(16) % 1024
        end
      end
    end
  end
end
