redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  config.on(:startup) do
    schedule_path = Rails.root.join("config/schedule.yml")
    Sidekiq::Cron::Job.load_from_hash(YAML.load_file(schedule_path)) if File.exist?(schedule_path)
  end
end

Sidekiq.configure_client { |config| config.redis = { url: redis_url } }
