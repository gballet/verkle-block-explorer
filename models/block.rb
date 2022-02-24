require './models/tx'

class Block < ActiveRecord::Base
  validates_presence_of :number, :rlp #, :hash

  has_many :txes
end
