#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'yaml'

cfg = YAML.load(File.read('config.yml'))

raise 'need a master account' if ARGV.empty?

uri = URI.parse(cfg['rpc'])
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.request_uri,
                              'Content-Type' => 'application/json')

master = ARGV[0]
account_list = { master => 200_000 }

# Create 100 accounts
100.times do
  request.body = '{"method":"personal_newAccount","params":["r0x0r"],"id":1,"jsonrpc":"2.0"}'
  resp = http.request(request)

  raise("request failed #{resp.code}") if resp.code.to_i != 200

  data = JSON.parse(resp.body)
  account_list[data['result']] = 0
end

sleep 10

1000.times do
  address = account_list.keys.sample

  request.body = {
    method: 'eth_getBalance',
    params: [address, 'latest'],
    id: 1,
    jsonrpc: '2.0'
  }.to_json
  resp = http.request(request)
  next if resp.code.to_i != 200

  puts resp.body
  balance = JSON.parse(resp.body)['result'].hex
  next if balance.zero?

  request.body = {
    method: 'personal_unlockAccount',
    params: [address, 'r0x0r'],
    id: 1,
    jsonrpc: '2.0'
  }.to_json
  resp = http.request(request)
  next if resp.code.to_i != 200

  to = account_list.keys.sample

  request.body = {
    method: 'personal_sendTransaction',
    params: [
      {
        from: address,
        to: to,
        value: format('%#x', balance / 10)
      },
      'r0x0r'
    ],
    id: 1,
    'jsonrpc': '2.0'
  }.to_json
  resp = http.request(request)
  next if resp.code.to_i != 200

  sleep 5
end
