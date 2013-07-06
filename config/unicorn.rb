# bundle exec unicorn -p $ PORT -E $RACK_ENV -c ./config/unicorn.rb

rack_env = ENV['RACK_ENV'] || 'production'
worker_processes 10
preload_app true
timeout 25

before_fork do |server, worker|
  if %w(production).include?(rack_env)
    Signal.trap 'TERM' do
      puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
      Process.kill 'QUIT', Process.pid
    end
  end

  Redis.current.quit
end


after_fork do |server, worker|
  if %w(production).include?(rack_env)
    Signal.trap 'TERM' do
      puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
    end
  end
end