require 'cgi'
require 'json'
require 'newrelic_rpm'
require 'new_relic/agent/instrumentation/rack'
require 'redis'
require './config/redis.rb'

class Entry
  attr_accessor :key, :name, :message, :created_at

  def self.per_page
    10
  end

  def self.get(key, page = 1)
    start =
      if page <= 1
        0
      else
        ((page - 1) * 10) - 1
      end
    Redis.current.lrange(key, start, start + per_page)
  end

  def initialize(attrs)
    attrs.each do |attr, value|
      send("#{attr}=", value)
    end
    self.created_at = Time.now
  end

  def valid?
    if !key.nil? && !key.empty?
      if key.length > 36
        errors['key'] = 'Cannot be more than 36 characters'
      end
    else
      errors['key'] = 'Cannot be blank'
    end
    if !name.nil? && !name.empty?
      if name.length > 100
        errors['name'] = 'Cannot be more than 100 characters'
      end
    else
      errors['name'] = 'Cannot be blank'
    end
    if !message.nil? && !message.empty?
      if message.length > 140
        errors['message'] = 'Cannot be more than 140 characters'
      end
    else
      errors['message'] = 'Cannot be blank'
    end
    errors.empty?
  end

  def errors
    @errors ||= {}
  end

  def save
    Redis.current.lpush(key, as_json.to_json)
  end

  def as_json
    {
      name: name,
      message: message,
      created_at: created_at,
    }
  end
end

class Application
  def self.call(env)
    Application.new(env).dispatch
  end

  def initialize(env)
    @env = env
    @request = Rack::Request.new(env)
  end

  def params
    @request.params
  end

  def headers
    @headers = {
      'Content-Type' => 'application/json'
    }
  end

  def dispatch
    if @env['HTTP_ORIGIN'] && @env['HTTP_ORIGIN'] =~ /http(s)?\:\/\/.+\.neocities\.org/i
      headers['Access-Control-Allow-Origin'] = @env['HTTP_ORIGIN']
    end

    puts @env
    puts @env['HTTP_ORIGIN']
    puts headers

    if @request.get?
      body = "[" + Entry.get(params['key'], (params['page'] || 1).to_i).join(',') + "]"
      if params['callback']
        body = params['callback'] + "(#{body});"
      end
      [200, headers, [body]]
    elsif @request.post?
      @entry = Entry.new({
        key: params['key'],
        name: params['name'],
        message: params['message'],
      })
      if @entry.valid?
        @entry.save
        if params['return_to']
          [302, { 'Location' => params['return_to'] }, []]
        else
          body = @entry.as_json.to_json
          if params['callback']
            body = params['callback'] + "(#{body})"
          end
          [201, headers, [body]]
        end
      else
        body = { errors: @entry.errors }.to_json
        if params['callback']
          body = params['callback'] + "(#{body})"
        end
        [422, headers, [body]]
      end
    else
      [404, {}, []]
    end
  end
end