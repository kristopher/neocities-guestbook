require 'cgi'
require 'json'
require 'newrelic_rpm'
require 'new_relic/agent/instrumentation/rack'
require 'redis'
require './config/redis.rb'

class Entry
  attr_accessor :subdomain, :name, :message, :created_at

  def self.per_page
    10
  end

  def self.get(subdomain, page = 1)
    start =
      if page <= 1
        0
      else
        ((page - 1) * 10) - 1
      end
    Redis.current.lrange(subdomain, start, start + per_page)
  end

  def initialize(attrs)
    attrs.each do |attr, value|
      send("#{attr}=", value)
    end
    self.created_at = Time.now
  end

  def valid?
    if !subdomain.nil? && !subdomain.empty?
      if subdomain.length > 255
        errors['subdomain'] = 'Cannot be more than 255 characters'
      end
    else
      errors['subdomain'] = 'Cannot be blank'
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
    Redis.current.lpush(subdomain, as_json.to_json)
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

  def not_found
    [404, {}, []]
  end

  def params
    @request.params
  end

  def referer
    @request.referer || @env['HTTP_REFERER']
  end

  def subdomain
    @subdomain ||=
      if referer && (matches = referer.scan(/http(s)?\:\/\/(.+)\.neocities\.org/i)[0]) && matches[1]
        matches[1]
      elsif !params['subdomain'].nil? && !params['subdomain'].empty?
        params['subdomain']
      elsif !params['key'].nil? && !params['key'].empty?
        params['key']
      end
  end

  def with_callback(body)
    if params['callback']
      params['callback'] + "(#{body});"
    else
      body
    end
  end

  def dispatch
    unless subdomain
      return not_found
    end

    headers ||= {
      'Content-Type' => 'application/json'
    }

    if @env['HTTP_ORIGIN'] && @env['HTTP_ORIGIN'] =~ /http(s)?\:\/\/.+\.neocities\.org/i
      headers['Access-Control-Allow-Origin'] = @env['HTTP_ORIGIN']
    end

    if @request.get?
      [200, headers, [
          with_callback("[" + Entry.get(subdomain, (params['page'] || 1).to_i).join(',') + "]")
        ]
      ]
    elsif @request.post?
      @entry = Entry.new({
        subdomain: subdomain,
        name: params['name'],
        message: params['message'],
      })
      if @entry.valid?
        @entry.save
        if params['return_to']
          [302, { 'Location' => params['return_to'] }, []]
        else
          [201, headers, [with_callback(@entry.as_json.to_json)]]
        end
      else
        [422, headers, [with_callback({ errors: @entry.errors }.to_json)]]
      end
    else
      [404, {}, []]
    end
  end
end