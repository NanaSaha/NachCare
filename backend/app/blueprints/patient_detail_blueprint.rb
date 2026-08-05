class PatientDetailBlueprint < PatientBlueprint
  field :episodes do |patient|
    patient.episodes.order(:start_date).map do |episode|
      # Enrollment creates a draft (`active: false`) version-1 plan (see
      # EnrollmentsController#create) that a nurse is meant to review and
      # activate — not an active plan yet. Falling back to the latest
      # version when none is active means the cockpit always has something
      # to show/edit instead of hiding the whole care-plan section, which
      # otherwise left a freshly enrolled patient with no way to create a
      # plan at all. CarePlansController#create always makes a *new*
      # version on save regardless, so surfacing a draft here is safe.
      plan = episode.care_plans.find_by(active: true) || episode.care_plans.order(:version).last
      {
        id: episode.id, status: episode.status, start_date: episode.start_date,
        # ADR-0008 #4/#5: day-90 graduation eligibility + milestones, so the
        # cockpit patient-detail screen can show the "Graduate" action and
        # any already-graduated report without a separate round trip.
        eligible_for_graduation: Domain::Graduation::Eligibility.eligible?(episode: episode),
        milestones: episode.milestones,
        care_plan: plan && {
          id: plan.id, version: plan.version, active: plan.active, diet_rules: plan.diet_rules,
          care_instructions: plan.care_instructions,
          thresholds: plan.thresholds, cadence: plan.cadence,
          medications: plan.medications.map { |m| { id: m.id, name: m.name, critical: m.critical, drug_id: m.drug_ref, schedule: m.schedule } }
        },
        # Nurse requirement #3 (ADR-0010): seeds the cockpit's live activity
        # feed with real history on first load; CareActivityLiveService then
        # prepends anything that arrives after.
        recent_activity: Domain::CareActivity::Feed.recent(episode: episode)
      }
    end
  end
end
