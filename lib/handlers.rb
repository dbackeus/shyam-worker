require "active_support/json"
require "active_support/core_ext/object/json"
require "active_support/core_ext/string/inflections"

require_relative "bitmex"
require_relative "handlers/handler"

Dir.glob("#{File.dirname(__FILE__)}/handlers/*_handler.rb") do |handler|
  # remove the bin in "bin/../app/message_handlers/enter_position_handler.rb"
  # handler = handler.split("/")[1..-1].join("/")
  require_relative handler
end
