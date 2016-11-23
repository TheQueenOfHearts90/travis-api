require "travis/lock"
require "redlock"
require "metriks"

class Travis::Api::App
  module Services
    class ScheduleCronJobs < Travis::Services::Base
      register :schedule_cron_jobs

      def self.run
        loop do
          begin
            Travis::Lock.exclusive("enqueue_cron_jobs", options) do
              Metriks.timer("rake.crons_jobs_enqueue.enqueue").time { enqueue }
            end
          rescue Travis::Lock::Redis::LockError => e
            Travis.logger.error e.message
          end
          sleep(Travis::API::V3::Models::Cron::SCHEDULER_INTERVAL)
        end
      end

      def self.options
        @options ||= {
          strategy:      :redis,
          url:           Travis.config.redis.url,
          retries:       0
        }
      end

      def self.enqueue
        scheduled = Travis::API::V3::Models::Cron.scheduled
        Travis.logger.info "Going to enqueue #{scheduled.count} cron jobs"

        scheduled.each do |cron|
          begin
            cron.needs_new_build? ? cron.enqueue : cron.skip_and_schedule_next_build
          rescue => e
            Metriks.meter("rake.cron_jobs_enqueue.enqueue.error").mark
            Raven.capture_exception(e, tags: { 'cron_id' => cron.try(:id) })
            next
          end
        end
      end
    end
  end
end