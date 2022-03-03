require './models/tx'

class Block < ActiveRecord::Base
  validates_presence_of :number, :rlp, :block_hash

  has_many :txes

  def root
    decode_rlp if @decoded_header.nil?
    @decoded_header[4]
  end

  def coinbase
    decode_rlp if @decoded_header.nil?
    @decoded_header[2]
  end

  def verkle_proof
    decode_rlp if @decoded_header.nil?
    VerkleProof.parse @decoded_header[16]
  end

  def witness_keyvals
    decode_rlp if @decoded_header.nil?
    @decoded_header[17]
  end

  private

  def decode_rlp
    @decoded_header, @decoded_txs = RLP.decoder(rlp.bytes)
  end
end
