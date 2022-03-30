require './models/tx'

class Block < ActiveRecord::Base
  validates_presence_of :number, :rlp, :block_hash

  has_many :txes

  def root
    decode_rlp if @decoded_header.nil?
    @decoded_header[3]
  end

  def coinbase
    decode_rlp if @decoded_header.nil?
    @decoded_header[2]
  end

  def parent_hash
    decode_rlp if @decoded_header.nil?
    @decoded_header[0]
  end

  def gas_limit
    decode_rlp if @decoded_header.nil?
    @decoded_header[9]
  end

  def gas_used
    decode_rlp if @decoded_header.nil?
    @decoded_header[10]
  end

  def verkle_proof
    decode_rlp if @decoded_header.nil?
    VerkleProof.parse(@decoded_header[16], @decoded_header[17].map { |(k, _)| k })
  end

  def witness_keyvals
    decode_rlp if @decoded_header.nil?
    @decoded_header[17]
  end

  def raw_rlp
    rlp.bytes
  end

  private

  def decode_rlp
    @decoded_header, @decoded_txs = RLP.decoder(rlp.bytes)
  end
end
