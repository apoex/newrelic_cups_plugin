# frozen_string_literal: true

require 'time'

# Represents a print job. Is populated by parsing rows with job info
class PrintJob
  attr_accessor :job_id, :user, :queue, :queued_at,
                :started_at, :completed_at, :rows

  JOB_INFO_REGEX = /
    \A
    (?<log_level>[A-Z])\s
    \[(?<timestamp>[^\]]+)\]\s
    \[Job\s
      (?<job_id>\d+)
    \]\s
    (?<info>.*)
    \z
  /x

  def initialize(job_id)
    self.job_id = job_id
    self.rows = []
  end

  def update(match_data)
    row = Row.new(match_data)
    rows << row
    self.user ||= row.user
    self.queue ||= row.queue
    self.queued_at ||= row.queued_at
    self.started_at ||= row.started_at
    self.completed_at ||= row.completed_at
  end

  def total_time
    return unless queued_at
    return unless completed_at

    completed_at - queued_at
  end

  def queue_time
    return unless queued_at
    return unless started_at

    started_at - queued_at
  end

  def print_time
    return unless started_at
    return unless completed_at

    completed_at - started_at
  end

  def to_s
    [job_id, user, total_time, queue_time, print_time,
     queued_at, completed_at, queue].join("\t")
  end

  def self.match(line)
    line.strip.match(JOB_INFO_REGEX) do |match_data|
      job_id = match_data[:job_id]
      yield job_id, match_data
    end
  end

  # Represents and parses a log file row with job info
  class Row
    attr_accessor :log_level, :raw_timestamp, :job_id, :info

    QUEUE_USER_REGEX = /
      \A
      Queued\ on\ "
        (?<queue>.+)
      "\ by\ "
        (?<user>.*)
      ".
      \z
    /x

    COMPLETED_REGEX = /\AJob completed\./
    STARTED_REGEX = /\AStarted backend\.*/

    def initialize(match_data)
      self.log_level = match_data[:log_level]
      self.raw_timestamp = match_data[:timestamp]
      self.job_id = match_data[:job_id]
      self.info = match_data[:info].strip
    end

    def timestamp
      Time.strptime(raw_timestamp, '%d/%b/%Y:%H:%M:%S %Z')
    end

    def queue
      info.match(QUEUE_USER_REGEX) do |match_data|
        match_data[:queue]
      end
    end

    def user
      info.match(QUEUE_USER_REGEX) do |match_data|
        match_data[:user]
      end
    end

    def queued_at
      info.match(QUEUE_USER_REGEX) do
        timestamp
      end
    end

    def started_at
      info.match(STARTED_REGEX) do
        timestamp
      end
    end

    def completed_at
      info.match(COMPLETED_REGEX) do
        timestamp
      end
    end
  end
end
