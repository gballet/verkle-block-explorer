#!/bin/sh

rm -rf db/explorer.sqlite
bundle exec rake db:migrate
bundle exec ./crawler.rb
bundle exec ./verifier.rb --log
