# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch

  add_filter '/spec/'
  add_filter '_spec.rb'
end

# https://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
end
