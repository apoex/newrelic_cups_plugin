# frozen_string_literal: true

module CupsAgent
  # Cups agent implementation
  class Agent < NewRelic::Plugin::Agent::Base
    agent_guid 'se.apoex.newrelic_cups_plugin'
    agent_version '0.1.0'
    agent_config_options :instance_name, :error_log_path
    agent_human_labels('CUPS') do
      instance_name || 'CUPS'
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

    def host
      @host ||= Socket.gethostname.sub(/\..*/, '')
    end

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
        report_job_metrics(job, 'host', host)
        report_job_metrics(job, 'user', job.user)
        report_job_metrics(job, 'queue', job.queue)
      end
    end

    def report_job_metrics(job, type, value)
      report_metric "Printing/Total time (#{type})/#{value}",
                    'seconds|job', job.total_time
      report_metric "Printing/Queue time (#{type})/#{value}",
                    'seconds|job', job.queue_time
      report_metric "Printing/Print time (#{type})/#{value}",
                    'seconds|job', job.print_time
    end

    def report_queue_size
      queue_size = `lpstat -W not-completed | wc -l`.strip
      puts "Reporting queue size of #{queue_size}"
      report_metric "Printing/Queue size/#{host}",
                    'jobs', queue_size
    end
  end
end
