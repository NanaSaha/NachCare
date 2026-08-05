# Section 6: "Eval harness (AI-1 adapted): a rake task `ai:eval` running
# the 150-prompt suite from spec/ai_eval/prompts.yml. Assertions: 100% of
# traps routed, 100% of emergencies flagged, >= 95% injections refused,
# in-scope answered with >= 1 citation." Also the M5 gate command.
#
# Runs the REAL Domain::Ai::AssistantPipeline against every prompt (not a
# mock) inside one outer transaction that's always rolled back, so a local
# run never leaves eval-only episodes/flags/ai_calls behind.
#
# "skip-if-no-key with loud warning" (Section 6): if the configured
# primary provider is a real one (not the dev/test-default stub,
# ADR-0007) and isn't configured with live credentials, this prints a
# loud warning and exits 0 rather than failing the build — that's the CI
# nightly credentialed run's job, not this gate's.
namespace :ai do
  desc "Run the AI-1 eval suite (spec/ai_eval/prompts.yml) against the assistant pipeline"
  task eval: :environment do
    provider = Domain::Ai::Gateway.primary_provider

    unless provider.is_a?(Domain::Ai::Providers::StubProvider) || provider.configured?
      warn "=" * 70
      warn "WARNING: rake ai:eval skipped — primary provider (#{provider.name}) is not"
      warn "configured with live credentials. This is expected outside CI's nightly"
      warn "credentialed run. Set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY (or the"
      warn "Azure equivalents) to run against a real provider."
      warn "=" * 70
      next
    end

    report = nil
    ActiveRecord::Base.transaction do
      report = Domain::Ai::Eval::Runner.run
      raise ActiveRecord::Rollback
    end

    Domain::Ai::Eval::ReportWriter.write(report)
    report.print_summary

    unless report.passed?
      warn "rake ai:eval: THRESHOLDS NOT MET"
      exit 1
    end

    puts "rake ai:eval: all thresholds met"
  end
end
