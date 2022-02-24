#!/usr/bin/env ruby
require 'sinatra'
require 'sinatra/reloader'
require 'markaby'
require 'sinatra/activerecord'
require 'rlp-ruby'

require './models/block'
require './models/tx'

def le_bytes(ary)
  ary.reverse.reduce(0) { |a,b| a *= 256; a += b; a }
end

def be_bytes(ary)
  ary.reduce(0) { |a,b| a *= 256; a += b; a }
end

def to_hex(ary)
  ary.reduce("0x") { |s,b| s+format("%02x", b) }
end

# Home page
get '/' do
  last_blocks = Block.order("number DESC").limit(10)

  markaby do
    h1 'Condrieu block explorer'

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
          td { a block.hash, href: "/blocks/#{block.hash}" }
        end
      end
    end
  end
end

# Show a block
get '/blocks/:number_or_hash' do
  db_block = case params[:number_or_hash]
             when /[a-fA-F0-9]{64}/ # Block hash
               Block.find_by(hash: params[:number_or_hash])
             when /\d+/ # Block number
               Block.find_by(number: params[:number_or_hash].to_i)
             else
               raise 'invalid input'
             end

  # Get the number of the last block
  last_block_num = Block.count == 0 ? 0 : Block.order('number DESC').first.number

  header, txs = RLP.decoder(db_block.rlp.bytes)

  number = be_bytes(header[8])

  markaby do
    h1 "Block #{db_block.number}"

    #p "Hash: #{block.hash}"

    h2 'Header'

    table do
      tr do
        td 'Parent hash:'
        td to_hex(header[0])
      end

      tr do
        td 'Coinbase:'
        td to_hex(header[2])
      end

      tr do
        td 'Gas Limit:'
        td be_bytes(header[9])
      end

      tr do
        td 'Gas Used:'
        td be_bytes(header[10])
      end
    end

    h2 'Verkle proof'

    p to_hex(header[16])

    h3 '(key, value) list'

    table do
      tr do
        th 'Key'
        th 'Value'
      end
      header[17].each do |(key,value)|
        tr do
          td to_hex(key)
          td le_bytes(value)
        end
      end
    end

    h2 'Transaction List'

    table do
      txs.each do |tx|
        tr do
          td span tx.tx_hash
        end
      end
    end

    a "< Block #{number - 1}", href: "/blocks/#{number - 1}" if number.positive?
    span '|'
    a "Block #{number + 1} >", href: "/blocks/#{number + 1}" if number < last_block_num
  end

end

post '/search' do
  redirect "/blocks/#{params['search']}"
end
