# Seeds a small Learn curriculum so a fresh dev/demo checkout has real,
# unlockable content instead of an empty screen. Content is
# PLACEHOLDER_CLINICAL (not sourced from the SRS, which isn't in this
# repo) — see docs/OPEN_CLINICAL_ITEMS.md. Idempotent: skips if an item
# with the same kind/week_no already exists. Bypasses the normal
# two-person cockpit approval (ContentItem#approve!) since this is a
# system seed, not a human review — approvals array still records it as
# a seed, not a live approval (same convention as db/seeds/knowledge_base.rb).
items = [
  {
    kind: "article", week_no: 1,
    language_variants: {
      "en" => { "title" => "Getting started", "body" => "[PLACEHOLDER_CLINICAL] Welcome to your first week. " \
        "Your daily check-in takes about three minutes — weight, medications, and how you're feeling." },
      "de" => { "title" => "Erste Schritte", "body" => "[PLACEHOLDER_CLINICAL] Willkommen in Ihrer ersten Woche. " \
        "Ihre tägliche Eingabe dauert etwa drei Minuten." }
    }
  },
  {
    kind: "tip", week_no: 2,
    language_variants: {
      "en" => { "title" => "Reading your weight trend", "body" => "[PLACEHOLDER_CLINICAL] Small day-to-day changes " \
        "are normal. Your care team looks at the trend over several days, not any single number." }
    }
  },
  {
    kind: "article", week_no: 4,
    language_variants: {
      "en" => { "title" => "Staying on track with medications", "body" => "[PLACEHOLDER_CLINICAL] Marking a dose " \
        "as missed helps your nurse understand your week — it's not a judgment, just information." }
    }
  },
  {
    kind: "article", week_no: 8,
    language_variants: {
      "en" => { "title" => "Looking ahead to day 90", "body" => "[PLACEHOLDER_CLINICAL] Around day 90, your care " \
        "team will review your progress with you and discuss what monitoring looks like next." }
    }
  }
].freeze

items.each do |attrs|
  next if ContentItem.exists?(kind: attrs[:kind], week_no: attrs[:week_no])

  item = ContentItem.create!(
    kind: attrs[:kind], week_no: attrs[:week_no], language_variants: attrs[:language_variants],
    status: "approved",
    approvals: [
      { "user_ref" => "seed", "at" => Time.current.iso8601 },
      { "user_ref" => "seed", "at" => Time.current.iso8601 }
    ]
  )
  Rails.logger.info "Seeded approved content_item '#{item.kind}/week_#{item.week_no}'"
end
