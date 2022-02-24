#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'sinatra/activerecord'
require 'rlp-ruby'

require './models/block'
require './models/tx'

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

# Get the latest block found
last_block_num = Block.count == 0 ? 0 : Block.order('number DESC').first.number

count = 0
(last_block_num + 1..num).each do |bnum|
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

  # Process the transactions
  _, txs = RLP.decoder(block.rlp.bytes)
  txs.each do |tx_hash|
    block.txs << Tx.new do |db_tx|
      db_tx.tx_hash= tx_hash
    end
  end
 
  # save the content
  block.save

  # only grab a maximum of 1000 blocks at a time
  break if count == 1000
  count += 1
end
