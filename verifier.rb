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
require './proof'

def log_errors?
  ARGV.include? '--log'
end

log = File.open('log.txt', 'a+') if log_errors?

# Get the latest block found
last_block_num = Block.count.zero? ? 0 : Block.order('number DESC').first.number

last_state_root = '0x00'

(1..last_block_num).each do |bnum|
  next if bnum.zero?

  filename = "block_#{bnum}.rlp"
  block = Block.find_by number: bnum
  next unless block.tree_verified.nil? || block.rust_verified.nil?

  File.write filename, block.raw_rlp.map(&:chr).join

  puts "verifying block #{bnum} with root #{last_state_root}"
  output = `./verkle-block-sample -f #{filename} -p #{last_state_root[2..]}`
  block.rust_verified = $? == 0
  if !block.rust_verified && log_errors?
    log.puts "./verkle-block-sample -f #{filename} -p #{last_state_root[2..]}"
    log.puts output
  end

  output = `./verkle #{filename} #{last_state_root[2..]}`
  block.go_verified = $? == 0
  if !block.go_verified && log_errors?
    log.puts "./verkle #{filename} #{last_state_root[2..]}"
    log.puts output
  end

  last_state_root = to_hex block.root

  File.delete filename

  begin
    proof = block.verkle_proof
    prev_root = Block.find_by!(number: block.number - 1).root
    proof.to_tree(prev_root,
                  block.witness_keyvals.map { |(k, _)| k },
                  block.witness_keyvals.map { |(_, v)| v })
    block.tree_verified = true
  rescue => e
    log.puts "#{block.number} #{e}" if log_errors?
    block.tree_verified = false
  end

  block.save!
end

log.close if log_errors?
