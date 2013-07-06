class Redis
  def self.current
    @current ||= Redis.new(::RedisConfig)
  end
end

::RedisConfig = {}

if %(production).include?(ENV['RACK_ENV'])
  RedisConfig[:url] = ENV["REDISTOGO_URL"]
else
  RedisConfig[:host] = 'localhost'
end

Redis.current

