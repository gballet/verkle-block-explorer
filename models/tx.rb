class Tx < ActiveRecord::Base
  validates_presence_of :tx_hash

  belongs_to :block
end
