class Block < ActiveRecord::Base
  validates_presence_of :number, :hash, :rlp

  # has_and_belongs_to_many :txs
end
