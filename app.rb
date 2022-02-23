#!/usr/bin/env ruby
require 'sinatra'
require 'sinatra/reloader'
require 'markaby'
require 'sinatra/activerecord'
require 'rlp-ruby'

require './models/block'

# Home page
get '/' do
  last_blocks = []

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
            Block.find(params[:number_or_hash].to_i)
          else
            raise 'invalid input'
          end

  block, _ = RLP.decoder(db_block.rlp.bytes)

  markaby do
    h1 "Block #{db_block.number}"

    #p "Hash: #{block.hash}"

    h2 'Header'

    table do
      tr do
        td 'Parent hash:'
        td block[0]
      end

      tr do
        td 'Coinbase:'
        td block[2]
      end

      tr do
        td 'Gas Limit:'
        td block[9]
      end

      tr do
        td 'Gas Used:'
        td block[10]
      end
    end

    h2 'Verkle proof'

    p block[16].inspect

    h2 'Transaction List'

    table do
    end
  end
end

post '/search' do
  redirect "/blocks/#{params['search']}"
end
