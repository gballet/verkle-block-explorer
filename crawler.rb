#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'sinatra/activerecord'

require './models/block'

uri = URI.parse('http://rpc.condrieu.ethdevops.io:8545')
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
  next if bnum.zero?

  req_body = {
    method: 'debug_getBlockRlp',
    params: [bnum],
    id: 1,
    jsonrpc: '2.0'
  }
  request.body = req_body.to_json

  resp = http.request(request)
  raise("request failed #{resp.code.class}") if resp.code.to_i != 200

  block_rlp = JSON.parse(resp.body)['result'].gsub('0x', '').split('').each_slice(2).map(&:join).map(&:hex).map(&:chr).join('')
  puts block_rlp
  block = Block.new do |b|
    b.number = bnum
    #b.hash = 0
    b.rlp = block_rlp
  end
  block.save
  #puts result.inspect
  #block = RLP.decode(result)
  #puts block
  ##block = RLP.decode(resp.body.split('').each_slice(2).map(&:join).map(&:hex), sedes: RLP::Sedes.raw)
  #if block.length >= 17
    #puts "proof=#{block[16]} keys=#{block[17]}"
  #else
    #puts "block #{bnum} doesn't seem to have a proof"
  #end
end
