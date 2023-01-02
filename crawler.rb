#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'sinatra/activerecord'
require 'rlp-ruby'
require 'yaml'

require './models/block'
require './models/tx'
require './utils'

cfg = YAML.safe_load(File.read('config.yml'))

uri = URI.parse(cfg['rpc'])
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.request_uri,
                              'Content-Type' => 'application/json')
request.body = '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}'
resp = http.request(request)

raise("request failed #{resp.code}") if resp.code.to_i != 200

data = JSON.parse(resp.body)
num = data['result'].hex
puts "latest block number = #{num}"

# Get the latest block found
last_block_num = Block.count.zero? ? 0 : Block.order('number DESC').first.number

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

  block_rlp = JSON.parse(resp.body)['result']
                  .gsub('0x', '')
                  .split('')
                  .each_slice(2)
                  .map(&:join)
                  .map(&:hex)
                  .map(&:chr)
                  .join('')
  block = Block.new do |b|
    b.number = bnum
    b.rlp = block_rlp
  end

  # Get the block hash as well
  req_body = {
    method: 'eth_getBlockByNumber',
    params: [format('%#x', bnum), false],
    id: 1,
    jsonrpc: '2.0'
  }
  request.body = req_body.to_json
  resp = http.request(request)
  raise("request failed #{resp.code.class}") if resp.code.to_i != 200

  result = JSON.parse(resp.body)['result']
  block.block_hash = from_hex(result['hash'])
  txs = result['transactions']

  # Process the transactions
  txs.each do |tx|
    block.txes << Tx.new do |db_tx|
      db_tx.tx_hash = from_hex(tx)
    end
  end

  # save the content
  block.save

  # only grab a maximum of 500 blocks at a time
  # to avoid being refused connections.
  break if count == 500

  count += 1
end
