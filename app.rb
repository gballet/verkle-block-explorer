#!/usr/bin/env ruby
require 'sinatra'
require 'sinatra/reloader'
require 'markaby'
require 'sinatra/activerecord'

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
          td { a block.number, href: "/block/#{block.number}" }
          td { a block.hash, href: "/block/#{block.hash}" }
        end
      end
    end
  end
end

# Show a block
get '/block/:number_or_hash' do
  block_rlp = case params[:number_or_hash]
              when /[a-fA-F0-9]{64}/ # Block hash
                Block.find_by(hash: params[:number_or_hash])
              when /\d+/ # Block number
                Block.find(params[:number_or_hash].to_i)
              else
                raise 'invalid input'
              end
end
