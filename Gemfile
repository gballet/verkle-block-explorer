# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "rlp-ruby", git: 'https://github.com/gballet/rlp-ruby', branch: 'fix-block-decoding'

gem "sinatra", "~> 4.1"
gem "sinatra-contrib", "~> 4.1"
gem "sinatra-activerecord", "~> 2.0"

gem "thin", "~> 2.0"
gem "rackup", "~> 2.2"
gem "rake", "~> 13.0"
gem "markaby", "~> 0.9.0"

gem "sqlite3", "~> 1.4"

group :development, optional: true do
  gem 'irb', '~> 1.4', require: false
end

gem "digest-keccak", "~> 0.0.5"
