#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)

require 'rubygems'
require 'bundler/setup'
require 'newrelic_plugin'
require 'dante'
require 'cups_agent/agent'
require 'print_job'

pid_path = File.expand_path('run/newrelic_cups_agent.pid', __dir__)
log_path = File.expand_path('log/newrelic_cups_agent.log', __dir__)

runner = Dante::Runner.new('newrelic_cups_agent',
                           pid_path: pid_path,
                           log_path: log_path)

runner.description = 'New Relic plugin agent for CUPS'

runner.with_options do |opts|
  opts.on('-c', '--config FILE', String,
          'Specify configuration file') do |config|
    options[:config_path] = config
  end
end

runner.execute do |opts|
  cupsplugin_config_path = opts[:config_path]

  if cupsplugin_config_path
    NewRelic::Plugin::Config.config_file = cupsplugin_config_path
  end

  NewRelic::Plugin::Setup.install_agent :cups, CupsAgent
  NewRelic::Plugin::Run.setup_and_run
end
