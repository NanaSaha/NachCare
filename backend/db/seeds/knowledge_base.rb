# Seeds a couple of approved knowledge_docs so the M5 assistant's RAG
# retrieval has real, citable content in a fresh dev/demo checkout
# instead of always falling through to the out-of-scope path. Content is
# PLACEHOLDER_CLINICAL (not sourced from the SRS, which isn't in this
# repo) — see docs/OPEN_CLINICAL_ITEMS.md. Idempotent: skips if a doc with
# the same title/language/version already exists (unique index).
# Bypasses the normal two-person cockpit approval UI (KnowledgeDoc#approve!)
# since this is a system seed, not a human review — approvals array is
# still populated so the audit trail shows it was a seed, not a live approval.
docs = [
  {
    title: "Fluid Tracking Guide", language: "en", version: 1,
    body: "[PLACEHOLDER_CLINICAL] Tracking your fluids each day helps your care team " \
          "spot changes early.\n\n" \
          "[PLACEHOLDER_CLINICAL] A simple way to log a symptom in the app: open today's " \
          "check-in, tap the symptom you noticed, and add a note if you'd like. Your " \
          "nurse can see this in your daily summary."
  },
  {
    title: "Low-Salt Day Guide", language: "en", version: 1,
    body: "[PLACEHOLDER_CLINICAL] A low-salt day means avoiding added salt at the table " \
          "and choosing fresh over processed foods where you can.\n\n" \
          "[PLACEHOLDER_CLINICAL] This is general guidance only — your care plan's " \
          "specific instructions always take priority."
  },
  # Product-owner feedback item #4 (post-M7 round N, ADR-0013): the
  # original 2-doc knowledge base only covered fluids/salt, so most
  # realistic caregiver questions (eating out, travel, activity, hygiene,
  # sleep, visitors) had zero approved content to retrieve and fell
  # through to the routed/out-of-scope response even though they're
  # exactly the kind of everyday question this assistant exists to
  # answer. These 5 new docs cover the topics named in that feedback.
  # Same PLACEHOLDER_CLINICAL convention, same generic/conservative/
  # non-prescriptive tone as the two docs above — see
  # docs/OPEN_CLINICAL_ITEMS.md row 9 (updated) for the exact bar.
  {
    title: "Eating Out and Travel Guide", language: "en", version: 1,
    body: "[PLACEHOLDER_CLINICAL] Many people can still enjoy a meal out at a " \
          "restaurant or a friend's house — a normal restaurant meal on the weekend " \
          "doesn't have to be off the table. When you eat out, ask for sauces and " \
          "dressings on the side, and stick to your usual portion sizes so the meal " \
          "fits into your day like any other.\n\n" \
          "[PLACEHOLDER_CLINICAL] Restaurant and travel food is often saltier than " \
          "home cooking, even when the dish looks ordinary, so grilled or steamed " \
          "options are usually a safer bet than fried or creamy ones. Packing her " \
          "usual medications and a copy of the care plan is a simple habit worth " \
          "keeping before any trip away from home."
  },
  {
    title: "Activity and Exercise Guide", language: "en", version: 1,
    body: "[PLACEHOLDER_CLINICAL] It's usually fine for her to go for a walk or do " \
          "some light exercise — gentle daily activity such as a short walk, light " \
          "housework, or climbing a flight of stairs at a comfortable pace is " \
          "encouraged as part of a normal recovery routine, not something to avoid. " \
          "A good rule of thumb: keep exercise light enough that she can still hold " \
          "a conversation while walking.\n\n" \
          "[PLACEHOLDER_CLINICAL] Sudden breathlessness at rest, chest discomfort, or " \
          "unusual fatigue during activity is worth logging as a symptom in today's " \
          "check-in rather than pushing through it. Building up exercise gradually, " \
          "a little more each week, tends to work better than one big effort."
  },
  {
    title: "Bathing and Hygiene Guide", language: "en", version: 1,
    body: "[PLACEHOLDER_CLINICAL] It's usually okay for her to take a normal shower " \
          "or bath today as part of everyday hygiene — there's typically no need to " \
          "avoid washing while she recovers. A shower chair or a non-slip bath mat " \
          "can make standing in the shower for a while less tiring and safer.\n\n" \
          "[PLACEHOLDER_CLINICAL] Keeping the water comfortably warm rather than very " \
          "hot can help avoid feeling lightheaded afterward, and leaving the bathroom " \
          "door unlocked is a sensible precaution while she's still building up her " \
          "strength."
  },
  {
    title: "Sleep and Rest Guide", language: "en", version: 1,
    body: "[PLACEHOLDER_CLINICAL] A consistent bedtime and a calm wind-down routine " \
          "each night support normal recovery — regular, normal sleep is encouraged, " \
          "not something to worry about. Propping up with an extra pillow is a " \
          "common, simple comfort measure some people find helpful.\n\n" \
          "[PLACEHOLDER_CLINICAL] If she keeps waking up short of breath during the " \
          "night, that's different from ordinary tiredness and is worth logging as a " \
          "symptom in today's check-in so your care team can see the pattern — " \
          "waking up occasionally at night is otherwise normal."
  },
  {
    title: "Visitors and Social Activity Guide", language: "en", version: 1,
    body: "[PLACEHOLDER_CLINICAL] It's usually okay to have visitors over, or to go " \
          "out for a small social occasion on a weekend — friends and family " \
          "visiting is a welcome part of recovery, and staying connected with " \
          "people matters. Keeping visits shorter or quieter on days she's more " \
          "tired is a normal adjustment, not a sign anything is wrong.\n\n" \
          "[PLACEHOLDER_CLINICAL] If a busy day with lots of visitors leaves her " \
          "unusually exhausted or short of breath afterward, noting that in today's " \
          "check-in helps your care team see the pattern over time."
  }
].freeze

docs.each do |attrs|
  next if KnowledgeDoc.exists?(title: attrs[:title], language: attrs[:language], version: attrs[:version])

  doc = KnowledgeDoc.create!(
    title: attrs[:title], language: attrs[:language], version: attrs[:version],
    body: attrs[:body], status: "approved",
    approvals: [
      { "user_ref" => "seed", "at" => Time.current.iso8601 },
      { "user_ref" => "seed", "at" => Time.current.iso8601 }
    ]
  )
  KnowledgeChunkingJob.new.perform(doc.id) # inline, not enqueued — seeds run synchronously
  Rails.logger.info "Seeded approved knowledge_doc '#{doc.title}' (#{doc.knowledge_chunks.count} chunks)"
end
