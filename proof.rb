require './tree'

class VerkleProof
  attr_reader :poas, :comms, :stem_info

  class ExtensionStatus
    ABSENT = 0
    OTHER = 1
    PRESENT = 2
  end

  # Gather all the information about a stem, that are required
  # to rebuild a stateless tree.
  class StemInfo
    attr_reader :depth, :ext_status,  :stem_info
    attr_accessor :has_c1, :has_c2

    def initialize(depth, ext_status)
      @depth = depth
      @ext_status = ext_status
      @has_c1 = false
      @has_c2 = false
    end

    def self.from_serialized(byte)
      new(byte >> 3, byte & 3)
    end
  end

  def initialize(poas, esses, comms, keys)
    @poas = poas
    @comms = comms

    # Compute stems
    stems = keys
            .map { |key| key[0, 31] }
            .uniq

    # Associate stems and its info into a hash table
    @stem_info = esses.map(&StemInfo.method(:from_serialized))
                      .zip(stems)
                      .map(&:reverse)
                      .to_h
  end

  # Rebuild a stateless tree from that proof. Consumes the proof data.
  def to_tree(root_comm, keys)
    # Using the keys, update @stem_info to see if C1 and C2 are
    # present.
    keys.each do |key|
      @stem_info[key[..-2]].has_c1 |= key[-1] < 128
      @stem_info[key[..-2]].has_c2 |= key[-1] >= 128
    end

    root = Node.new(0, false, nil)
    root.commitment = root_comm

    @stem_info.each { |stem, info| root.insert_node(stem, info, @comms, @poas) }

    root
  end

  def self.parse(bytes, keyvals)
    poas, offset = deserialize_array(bytes, 0, 31)
    esses, offset = deserialize_array(bytes, offset, 1)
    esses.flatten!
    comms, = deserialize_array(bytes, offset, 32)

    VerkleProof.new(poas, esses, comms, keyvals)
  end

  def self.deserialize_array(bytes, offset, pitch)
    count = le_bytes bytes[offset, 4]
    offset += 4
    ary = []
    count.times do
      ary << bytes[offset, pitch]
      offset += pitch
    end

    [ary, offset]
  end

  private_class_method :deserialize_array
end
