require 'cgi'
require 'json'
require 'redis'
require './config/redis.rb'

class Application
  def self.call(env)
    raise env.inspect
    Application.new(env)
  end

  def initialize(env)
    @env = env
    @path = env['REQUEST_PATH']
    @method = env['REQUEST_METHOD']
    @params = CGI.parse(env['QUERY_STRING'])
  end
end