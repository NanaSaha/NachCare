class FlagDetailBlueprint < FlagBlueprint
  # UC-23 step 5: the AI WATCH rationale panel's raw material — component
  # breakdown, not just the score. The frontend renders the plain-language
  # rationale text (Domain::Ai::Tasks::AiWatchRationale), never a bare
  # number, from this alongside the copilot-generated explanation.
  field :ai_watch_meta do |flag|
    flag.subtype == "ai_watch" ? flag.ai_watch_meta : nil
  end

  field :evaluations do |flag|
    Evaluation.where(id: flag.evaluation_refs).order(:created_at).map do |e|
      { id: e.id, severity: e.severity, ruleset_version: e.ruleset_version, fired_rules: e.fired_rules, created_at: e.created_at }
    end
  end

  field :interventions do |flag|
    flag.interventions.order(:created_at).map do |i|
      { id: i.id, actor_ref: i.actor_ref, outcome: i.outcome, note_final: i.note_final, created_at: i.created_at }
    end
  end

  # Section 8/M3: "trend chart with flag markers, photos, check-in
  # history" — the last 14 days of check-ins for this episode. `photo_urls`
  # (ADR-0011) fills in the "photos not yet implemented" gap the M3
  # traceability note recorded; `note` surfaces the caregiver's free-text
  # "how is she feeling today" answer (product-owner feedback item #2 —
  # reuses the existing `check_ins.note` column, see ADR-0011).
  field :check_in_history do |flag|
    flag.episode.check_ins.includes(check_in_photos: { image_attachment: :blob })
      .where(effective_date: 14.days.ago.to_date..Date.current).order(:effective_date).map do |ci|
      {
        id: ci.id, effective_date: ci.effective_date, weight_kg: ci.weight_kg, symptoms: ci.symptoms,
        note: ci.note, photo_urls: ci.check_in_photos.map { |p| Domain::Media::Url.for(p.image) }.compact
      }
    end
  end
end
