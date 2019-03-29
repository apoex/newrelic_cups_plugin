# frozen_string_literal: true

module CupsAgent
  # Cups agent implementation
  class Agent < NewRelic::Plugin::Agent::Base
    agent_guid 'se.apoex.newrelic_cups_plugin'
    agent_version '0.1.0'
    agent_config_options :instance_name, :error_log_path
    agent_human_labels('CUPS') do
      if instance_name.nil?
        host = Socket.gethostname.sub(/\..*/, '')
        "#{host}:631"
      else
        instance_name.to_s
      end
    end

    def setup_metrics
      @print_jobs = {}
    end

    def poll_cycle
      begin
        poll_data
      rescue StandardError => e
        puts e.message
        return
      end
      report_jobs
      report_queue_size
    end

    private

    def poll_data
      File.foreach(error_log_path) do |line|
        PrintJob.match(line) do |job_id, match_data|
          @print_jobs[job_id] ||= PrintJob.new(job_id)
          @print_jobs[job_id].update(match_data)
        end
      end
    end

    def report_jobs
      @print_jobs.each do |_job_id, job|
        report_user_metrics(job)
        report_queue_metrics(job)
      end
    end

    def report_user_metrics(job)
      report_metric "Printing/Total time (user)/#{job.user}",
                    'seconds|job', job.total_time
      report_metric "Printing/Queue time (user)/#{job.user}",
                    'seconds|job', job.queue_time
      report_metric "Printing/Print time (user)/#{job.user}",
                    'seconds|job', job.print_time
    end

    def report_queue_metrics(job)
      report_metric "Printing/Total time (queue)/#{job.user}/#{job.queue}",
                    'seconds|job', job.total_time
      report_metric "Printing/Queue time (queue)/#{job.user}/#{job.queue}",
                    'seconds|job', job.queue_time
      report_metric "Printing/Print time (queue)/#{job.user}/#{job.queue}",
                    'seconds|job', job.print_time
    end

    def report_queue_size
      queue_size = `lpstat -W not-completed | wc -l`.strip
      report_metric 'Printing/Queue size/',
                    'jobs', queue_size
    end
  end
end
