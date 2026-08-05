# app/domain holds the core POROs (escalation engine, flags, AI gateway,
# audit spine, ...) per NachCareAI_Agent_Build_Instructions.md Section 4,
# namespaced as Domain::* (e.g. Domain::Audit::Recorder, Domain::Ai::Gateway
# per Section 6). A plain `config.autoload_paths` entry would map
# app/domain/audit/recorder.rb to the unnamespaced Audit::Recorder, so this
# registers it as a Zeitwerk root under an explicit `Domain` namespace
# instead — see the Rails guide on custom root directories with a namespace.
module Domain; end

Rails.autoloaders.main.push_dir(Rails.root.join("app/domain"), namespace: Domain)
