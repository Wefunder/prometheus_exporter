# frozen_string_literal: true

# collects stats from GoodJob
module PrometheusExporter::Instrumentation
  class GoodJob < PeriodicStats
    def self.start(client: nil, frequency: 30, collect_by_queue: false)
      good_job_collector = new
      client ||= PrometheusExporter::Client.default

      worker_loop do
        client.send_json(good_job_collector.collect(collect_by_queue))
      end

      super
    end

    def collect(by_queue = false)
      queue_names = by_queue ? ::GoodJob::Job.distinct.pluck(:queue_name) : nil
      {
        type: "good_job",
        by_queue: by_queue,
        scheduled: compute_stats(::GoodJob::Job.scheduled, by_queue, queue_names),
        retried: compute_stats(::GoodJob::Job.retried, by_queue, queue_names),
        queued: compute_stats(::GoodJob::Job.queued, by_queue, queue_names),
        running: compute_stats(::GoodJob::Job.running, by_queue, queue_names),
        finished: compute_stats(::GoodJob::Job.finished, by_queue, queue_names),
        succeeded: compute_stats(::GoodJob::Job.succeeded, by_queue, queue_names),
        discarded: compute_stats(::GoodJob::Job.discarded, by_queue, queue_names)
      }
    end

    private

    def compute_stats(scope, by_queue, queue_names)
      return scope.size unless by_queue

      result = scope.group(:queue_name).size
      queue_names.each do |queue|
        result[queue] ||= 0
      end
      result
    end
  end
end
