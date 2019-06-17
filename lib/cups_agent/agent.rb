# frozen_string_literal: true

require 'English'

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
      check_params
    end

    def poll_cycle
      begin
        poll_data
      rescue StandardError => e
        puts e.message
        return
      end
      report_completed_jobs
      cleanup_completed_jobs
      report_queue_size
    end

    private

    def host
      @host ||= Socket.gethostname.sub(/\..*/, '')
    end

    def poll_data
      log_data(error_log_path).each_line do |line|
        PrintJob.match(line) do |job_id, match_data|
          @print_jobs[job_id] ||= PrintJob.new(job_id)
          @print_jobs[job_id].update(match_data)
        end
      end
    end

    # Gets log lines since last poll cycle.
    def log_data(path)
      @last_length ||= 0

      current_length = `wc -l "#{path}"`.split(' ').first.to_i

      # Check if file is rotated. If so, reset `last_length` to start reading
      # from the beginning of the rotated file.
      @last_length = 0 if current_length < @last_length
      read_length = current_length - @last_length
      return '' if read_length.zero?

      data = `tail -n +#{@last_length + 1} "#{path}" | head -n #{read_length}`
      @last_length = current_length
      data
    end

    def check_params
      raise ErrorLogPathNotSet if error_log_path.empty?

      `test -e #{error_log_path}`

      raise NoErrorLogFileFound(error_log_path) unless $CHILD_STATUS.success?
    end

    def report_completed_jobs
      @print_jobs.each do |_job_id, job|
        next unless job.completed?

        puts "Reporting job metrics for: #{job}"
        report_job_metrics(job, 'host', host)
        report_job_metrics(job, 'user', job.user)
        report_job_metrics(job, 'queue', job.queue)
      end
    end

    def cleanup_completed_jobs
      @print_jobs.delete_if do |_job_id, job|
        job.completed?
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

  # Exception class for error log file not found
  class NoErrorLogFileFound < StandardError
    def initialize(error_log_path)
      super("The log file could not be found at: `#{error_log_path}`. " \
            'Please ensure the full path is correct.')
    end
  end

  # Exception class for log path not set
  class ErrorLogPathNotSet < StandardError
    def initialize
      super('Please provide a path to the CUPS error log file.')
    end
  end
end
