# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
HubsBackOffice::Application.initialize!

Paperclip.options[:command_path] = "/usr/local/bin/"

#Rails.logger = Logger.new(STDOUT)

#Rails.logger.level = 0
