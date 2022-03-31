#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'markaby'
require 'sinatra/activerecord'
require 'rlp-ruby'
require 'base64'

require './models/block'
require './models/tx'

require './proof'
require './utils'
require './tree'

if development?
  also_reload './models/block.rb'
  also_reload './models/tx.rb'
  also_reload './proof.rb'
  also_reload './tree.rb'
  also_reload './utils.rb'
end

cfg = YAML.safe_load(File.read('config.yml'))

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

def generate_prestate_png(tree, number)
  prestate_file_name = "verkle-#{number}"
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
  tree_base64_png
end

def get_block(params)
  db_block = case params[:number_or_hash]
             when /[a-fA-F0-9]{64}/ # Block hash
               Block.find_by(block_hash: from_hex(params[:number_or_hash]))
             when /\d+/ # Block number
               Block.find_by(number: params[:number_or_hash].to_i)
             else
               raise 'invalid input'
             end
  raise Sinatra::NotFound if db_block.nil?

  db_block
end

# Show a block
get '/blocks/:number_or_hash' do
  db_block = get_block(params)
  db_block.txes.load

  # Get the number of the last block
  last_block_num = Block.count.zero? ? 0 : Block.order('number DESC').first.number

  proof = db_block.verkle_proof

  # Get the state root commitment from the
  # previous block
  prev_root = Block.find_by!(number: db_block.number - 1).root
  tree_base64_png = ''
  tree_rendering_error = nil
  begin
    tree = proof.to_tree(prev_root,
                         db_block.witness_keyvals.map { |(k, _)| k },
                         db_block.witness_keyvals.map { |(_, v)| v })
    tree_base64_png = generate_prestate_png(tree, db_block.number)
  rescue => e
    tree_rendering_error = e
  end

  markaby do
    a "< Block #{db_block.number - 1}", href: "/blocks/#{db_block.number - 1}" if db_block.number.positive?
    span ' | '
    a 'Home', href: '/'
    span ' | '
    a "Block #{db_block.number + 1} >", href: "/blocks/#{db_block.number + 1}" if db_block.number < last_block_num

    h1 "Block #{db_block.number}"

    a "download raw block", href: "/blocks/#{db_block.number}/download"

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

    h3 'Pre-state tree'

    p 'Note: ∅ denotes a key missing from the pre-state (corresponding to a proof of absence),'\
    ' and 00... means that the leading 0s (in little endian form) are not printed.'

    if tree_rendering_error.nil?
      img src: "data:image/png;base64,#{tree_base64_png}", width: '100%'
    else
      p "error rendering tree: #{tree_rendering_error.inspect}"
    end

    unless proof.poas.empty?
      h3 'Proof of absence stems'

      ul do
        proof.poas.each do |stem|
          li to_hex(stem)
        end
      end
    end

    h3 'Commitments'

    table do
      tr do
        th 'Commitment'
        th 'Path'
      end
      tree.each_node do |comm, path|
        tr do
          td to_hex comm
          td to_hex path
        end
      end if tree_rendering_error.nil?
    end

    h3 '(key, value) list'

    table do
      tr do
        th 'Key'
        th 'Value'
      end
      db_block.witness_keyvals.each do |(key, value)|
        tr do
          td to_hex(key)
          td to_hex(value)
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
  end
end

get '/blocks/:number_or_hash/download' do
  block = get_block(params)
  content_type 'application/octet-stream'
  headers['Content-disposition'] = "attachment;filename=block_#{block.number}.rlp"
  block.raw_rlp.map(&:chr).join
end

post '/search' do
  redirect "/blocks/#{params['searchterm']}"
end

get '/chain/unverified' do
  blocks = Block.where('rust_verified IS NULL OR tree_verified IS NULL')
  puts blocks

  markaby {
    table do
      tr do
        th 'Number'
        th 'rust-verkle verified?'
        th 'picture generated?'
      end
      blocks.each do |block|
        tr do
          td { a block.number, href: "/blocks/#{block.number}" }
          td block.rust_verified ? '✔️' : '❌'
          td block.tree_verified ? '✔️' : '❌'
        end
      end
    end
  }
end
