module Api
  module V1
    class HealthController < ActionController::API
      def show
        db_ok = database_ok?
        redis_ok = redis_ok?

        render json: { status: db_ok && redis_ok ? "ok" : "degraded", db: db_ok, redis: redis_ok },
               status: db_ok && redis_ok ? :ok : :service_unavailable
      end

      private

      def database_ok?
        ActiveRecord::Base.connection.select_value("SELECT 1") == 1
      rescue StandardError
        false
      end

      def redis_ok?
        Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).ping == "PONG"
      rescue StandardError
        false
      end
    end
  end
end
