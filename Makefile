.PHONY: test lint

test:
	bundle exec rspec --require ./spec/spec_helper ./spec

lint:
	bundle exec rubocop
