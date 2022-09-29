# syntax=docker/dockerfile:1
FROM ruby:3.1.1
RUN apt-get update -qq && apt install -y graphviz
WORKDIR /verkle-explorer
COPY . .
RUN bundle install
RUN bundle update --bundler
EXPOSE 4567
# Configure the main process to run when running the image
CMD []
