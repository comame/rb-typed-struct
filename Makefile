.PHONY: test lint

test:
	bundle exec rspec --require spec_helper ./

lint:
	bundle exec rubocop
