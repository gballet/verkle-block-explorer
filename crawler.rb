#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

uri = URI.parse('http://localhost:8545/verkle')
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.request_uri,
                              'Content-Type' => 'application/json')
request.body = '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}'
resp = http.request(request)

raise("request failed #{resp.code.class}") if resp.code.to_i != 200

data = JSON.parse(resp.body)
num = data['result'].hex
puts "latest block number = #{num}"

num.times do |bnum|
  request.body = '{"method":"eth_getBlockNumber","params":["' + format("%#x", bnum) + '"],"id":1,"jsonrpc":"2.0"}'
  next if bnum.zero?

  resp = http.request(request)
end
