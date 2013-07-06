# This file is used by Rack-based servers to start the application.

require './application'

Application.send(:extend, NewRelic::Agent::Instrumentation::Rack)

run Application

