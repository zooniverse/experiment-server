require 'mongoid'
require 'pry'

Mongoid.load!("config/mongoid.yml" )

#Load in models
Dir.glob("models/*.rb").each do |file|
  require_relative file
end

#Load in experiments
Dir[File.dirname(__FILE__) + '/experiments/*.rb'].each {|file| require file }
