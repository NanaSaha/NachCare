require "rails_helper"

# AT-10 (Section 8 acceptance test suite): "pilot report exact-match
# against seeded known dataset." Runs the real `db/seeds/ingrid_scenario.rb`
# (Section 8/M7's demo-story seed) inside a transactional spec — its own
# idempotency guard (`Patient.exists?(pseudonym_code: ...)`) makes this
# safe to `load` directly rather than duplicating its scenario — then
# asserts Domain::Analytics::PilotMetrics.compute returns the EXACT
# expected numbers against that known, deterministic dataset (not just
# "some number" or "present").
RSpec.describe "AT-10: pilot metrics exact-match against the seeded Ingrid scenario" do
  before do
    # The real ruleset (with R-4 breathless_at_rest) must be active before
    # the seed's check-ins run through Domain::Escalation::Processor —
    # db/seeds/rulesets.rb's own loading logic, reused here rather than
    # duplicated, since test DBs don't run db/seeds.rb automatically.
    unless Ruleset.active.present?
      body = JSON.parse(File.read(Rails.root.join("config/rulesets/ruleset_v0_1.json")))
      Ruleset.create!(version: body.fetch("version"), body: body, status: "active")
    end

    load Rails.root.join("db/seeds/ingrid_scenario.rb")
  end

  it "computes exact, deterministic pilot metrics for the seeded site" do
    site = Site.find_by!(name: "NachCare Demo Site")
    episode = Patient.find_by!(pseudonym_code: "PT-INGRID-DEMO").episodes.first

    # `to:` is yesterday, not today: the seed populates check-ins through
    # day 89 (yesterday, relative to the 90-days-ago start date) and
    # deliberately leaves "today" (day 90) unseeded for a live demo
    # check-in — see ingrid_scenario.rb's own comment. Including today in
    # the window would correctly show 90/91 adherence, not a bug, just
    # not what this exact-match assertion is scoped to.
    metrics = Domain::Analytics::PilotMetrics.compute(site: site, from: episode.start_date, to: Date.current - 1.day).to_h

    # Exactly one RED flag (day-17), resolved same day within SLA (default
    # `sla_red_minutes`) — see ingrid_scenario.rb's `day17_flag`, actioned
    # 9h after open and resolved 40 min after that.
    expect(metrics[:red_flag_sla_compliance_rate]).to eq(1.0)
    expect(metrics[:red_flag_median_time_to_first_action_minutes]).to eq(60.0)

    # 90 check-ins submitted (day 0 through day 89) against 90 expected
    # days for a 90-day-old episode — full adherence.
    expect(metrics[:checkin_adherence_rate]).to eq(1.0)

    # The episode is 90 days old and still "active" (graduation is a
    # staff-initiated action the seed deliberately leaves for the demo
    # walkthrough) — eligible but not yet graduated.
    expect(metrics[:program_completion_rate]).to eq(0.0)
  end
end
