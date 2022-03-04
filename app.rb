#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'markaby'
require 'sinatra/activerecord'
require 'rlp-ruby'
require 'base64'

require './models/block'
require './models/tx'

require './proof'
require './utils'
require './tree'

cfg = YAML.load(File.read('config.yml'))

def le_bytes(ary)
  be_bytes ary.reverse
end

def be_bytes(ary)
  ary.reduce(0) do |a, b|
    a *= 256
    a += b
    a
  end
end

# Home page
get '/' do
  last_blocks = Block.order('number DESC').limit(10)

  markaby do
    h1 "#{cfg['network_name'].capitalize} block explorer"

    form action: 'search', method: 'POST' do
      input id: 'searchterm', type: 'text', placeholder: 'Enter a block number or hash'
      input type: :submit, value: 'Search'
    end

    table do
      tr do
        th 'Block number'
        th 'Block hash'
      end

      last_blocks.each do |block|
        tr do
          td { a block.number, href: "/blocks/#{block.number}" }
          td { a to_hex(block.block_hash.bytes), href: "/blocks/#{to_hex(block.block_hash.bytes)}" }
        end
      end
    end
  end
end

# Show a block
get '/blocks/:number_or_hash' do
  db_block = case params[:number_or_hash]
             when /[a-fA-F0-9]{64}/ # Block hash
               Block.find_by(block_hash: from_hex(params[:number_or_hash]))
             when /\d+/ # Block number
               Block.find_by(number: params[:number_or_hash].to_i)
             else
               raise 'invalid input'
             end
  raise Sinatra::NotFound if db_block.nil?

  db_block.txes.load

  # Get the number of the last block
  last_block_num = Block.count.zero? ? 0 : Block.order('number DESC').first.number

  proof = db_block.verkle_proof

  # The list of stems
  stems = db_block
          .witness_keyvals
          .map { |(key, _)| key[0, 31] }
          .uniq

  # The list of the paths to every single node in the tree
  paths = stems
          .zip(proof.depths)
          .map { |(stem, depth)| depth.times.map { |i| stem[0, i + 1] } }
          .uniq
          .sort

  # Find the list of stems that are present in the tree
  stems_and_statuses = stems.zip(proof.esses)
  present_stems = stems_and_statuses
                  .filter { |(_, es)| es == VerkleProof::ExtensionStatus::PRESENT }
                  .map { |(stem, _)| stem }

  # Insert the values in the tree that correspond to a
  # stem that is present in the tree.
  tree = Node.new(0, false, nil)
  db_block.witness_keyvals.each do |key, value|
    tree.insert(key, value) if present_stems.include?(key[..-2])
  end

  # Get the state root commitment from the
  # previous block
  prev_root = Block.find_by!(number: last_block_num).root
  tree.set_comms([prev_root] + proof.comms)
  prestate_file_name = "verkle-#{db_block.number}"
  File.write "#{prestate_file_name}.dot", <<~TREEDOT
    digraph D {
      node [shape=rect]
      #{tree.to_dot('', '')}
    }
  TREEDOT
  system "dot -Tpng #{prestate_file_name}.dot -o #{prestate_file_name}.png"
  File.delete "#{prestate_file_name}.dot"
  tree_base64_png = Base64.encode64 File.read("#{prestate_file_name}.png")
  File.delete "#{prestate_file_name}.png"

  markaby do
    h1 "Block #{db_block.number}"


    h2 'Header'

    table do
      tr do
        td 'Parent hash:'
        td { a to_hex(db_block.parent_hash), href: "/blocks/#{to_hex db_block.parent_hash}" }
      end

      tr do
        td 'Coinbase:'
        td to_hex(db_block.coinbase)
      end

      tr do
        td 'Gas Limit:'
        td be_bytes(db_block.gas_limit)
      end

      tr do
        td 'Gas Used:'
        td be_bytes(db_block.gas_used)
      end
    end

    h2 'Verkle proof'

    img src: "data:image/png;base64,#{tree_base64_png}"

    p "extension statuses: #{proof.esses}"
    p "depths: #{proof.depths}"
    p "poas: #{proof.poas}"
    p "commitments: #{proof.comms.map { |c| be_bytes c }}"

    h3 '(key, value) list'

    table do
      tr do
        th 'Key'
        th 'Value'
      end
      db_block.witness_keyvals.each do |(key, value)|
        tr do
          td to_hex(key)
          td le_bytes(value)
        end
      end
    end

    h2 'Transaction List'

    table do
      db_block.txes.each do |tx|
        tr do
          td to_hex(tx.tx_hash.bytes)
        end
      end
    end

    a "< Block #{db_block.number - 1}", href: "/blocks/#{db_block.number - 1}" if db_block.number.positive?
    span ' | '
    a 'Home', href: '/'
    span ' | '
    a "Block #{db_block.number + 1} >", href: "/blocks/#{db_block.number + 1}" if db_block.number < last_block_num
  end
end

post '/search' do
  redirect "/blocks/#{params['searchterm']}"
end
