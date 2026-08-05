# M7 hardening (Section 8, ADR-0009 #9): "load script: 300 concurrent
# check-ins < 2 s p95." k6 needs 300 real, distinct, already-activated
# caregivers to POST as — this task seeds them (idempotent per COUNT,
# bypasses the activation-code exchange itself since that flow is already
# covered elsewhere; this only needs the *result* of activation, a
# device token) and writes their tokens + episode ids to
# `backend/tmp/load_test_tokens.json` — inside the bind-mounted
# `backend/` volume (`ops/` is NOT mounted into the backend container, so
# writing there directly from inside the container isn't possible) — for
# `ops/verify_m7.sh` to copy alongside `ops/k6/load_checkins.js` before
# invoking k6.
#
# Deliberately a `rake` task, not a `db/seeds/*.rb` file: this is
# throwaway load-test fixture data (a dedicated site, easy to spot/drop),
# not part of the demo/dev-seed baseline `db/seeds.rb` loads automatically.
namespace :load_test do
  desc "Seed N activated caregivers for ops/k6/load_checkins.js (default 300)"
  task :seed, [ :count ] => :environment do |_t, args|
    count = (args[:count] || ENV["LOAD_TEST_COUNT"] || 300).to_i

    site = Site.find_or_create_by!(name: "M7 Load Test Site") { |s| s.timezone = "Europe/Berlin" }

    tokens = count.times.map do |i|
      pseudonym = "PT-LOADTEST-#{i.to_s.rjust(4, '0')}"
      patient = Patient.find_or_create_by!(pseudonym_code: pseudonym) do |p|
        p.site = site
        p.initials = "L.T."
        p.birth_year = 1950
        p.nyha_class = "II"
      end
      episode = patient.episodes.first || Episode.create!(patient: patient, start_date: Date.current, status: "active")
      caregiver = episode.caregivers.first || Caregiver.create!(episode: episode, display_name: "LoadTest#{i}", relationship: "daughter", language: "en")

      plaintext_token = SecureRandom.hex(Domain::Enrollment::Activator::DEVICE_TOKEN_BYTES)
      caregiver.update!(device_token_digest: Domain::Enrollment::Activator.device_token_digest(plaintext_token))

      { device_token: plaintext_token, episode_id: episode.id }
    end

    out_path = Rails.root.join("tmp/load_test_tokens.json")
    File.write(out_path, JSON.pretty_generate(tokens))
    puts "Wrote #{tokens.size} load-test caregiver tokens to #{out_path}"
  end

  desc "Remove the M7 Load Test Site and every patient/episode/caregiver under it"
  task teardown: :environment do
    site = Site.find_by(name: "M7 Load Test Site")
    if site
      patient_count = site.patients.count
      episode_ids = Episode.joins(:patient).where(patients: { site_ref: site.id }).pluck(:id)

      # No ON DELETE CASCADE on these FKs (Section 5 migrations) — delete
      # child rows in dependency order rather than relying on the DB to
      # do it, same as this app does everywhere else (no `dependent:
      # destroy` declared on Episode's has_many either).
      NotificationAttempt.joins(:caregiver).where(caregivers: { episode_ref: episode_ids }).delete_all
      Intervention.where(flag_ref: Flag.where(episode_ref: episode_ids).select(:id)).delete_all
      Flag.where(episode_ref: episode_ids).delete_all
      Evaluation.where(episode_ref: episode_ids).delete_all
      CheckIn.where(episode_ref: episode_ids).delete_all
      Caregiver.where(episode_ref: episode_ids).delete_all
      Episode.where(id: episode_ids).delete_all
      # `site.patients.delete_all` would try to NULL OUT patients.site_ref
      # instead of deleting (has_many default `delete_all` strategy without
      # `dependent:` configured), violating the NOT NULL constraint —
      # delete through the model directly instead.
      Patient.where(site_ref: site.id).delete_all
      site.destroy!
      puts "Removed M7 Load Test Site, #{patient_count} patients, #{episode_ids.size} episodes."
    else
      puts "No M7 Load Test Site found — nothing to do."
    end
    token_file = Rails.root.join("tmp/load_test_tokens.json")
    File.delete(token_file) if File.exist?(token_file)
  end
end
