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
    attr_reader :depth, :ext_status
    attr_accessor :has_c1, :has_c2, :values, :stem

    def initialize(depth, ext_status)
      @depth = depth
      @ext_status = ext_status
      @has_c1 = false
      @has_c2 = false
      @values = {}
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

    @stem_info = {}
    @stem_to_path = {}
    stem_index = 0
    esses.map(&StemInfo.method(:from_serialized)).each do |info|
      path = stems[stem_index][...info.depth]
      @stem_to_path[stems[stem_index]] = path
      @stem_info[path] = info
      stem_index += 1 # move to next stem
      while stem_index < stems.length && path == stems[stem_index][...info.depth]
        @stem_to_path[stems[stem_index]] = path
        stem_index += 1 
      end
    end

    raise 'error deserializing proof' if @stem_info.has_key?(nil)
  end

  # Rebuild a stateless tree from that proof. Consumes the proof data.
  def to_tree(root_comm, keys, values)
    puts @stem_info.inspect
    puts keys.inspect
    puts values.inspect
    # Using the keys, update @stem_info to see if C1 and C2 are
    # present.
    puts keys.length
    puts values.length
    last_poa = 0
    keys.zip(values).each do |(key, value)|
      stem = key[..-2]
      puts "adding stem info for stem #{stem.inspect}"
      @stem_info[@stem_to_path[stem]].has_c1 |= key[-1] < 128
      @stem_info[@stem_to_path[stem]].has_c2 |= key[-1] >= 128
      @stem_info[@stem_to_path[stem]].values[key[-1]] = value

      # skip stem assignment if multiple keys already have
      # the same stem assigned.
      next unless @stem_info[@stem_to_path[stem]].stem.nil?

      # assign the right stem to the info stem's variable
      case @stem_info[@stem_to_path[stem]].ext_status
      when VerkleProof::ExtensionStatus::PRESENT
        # multiple values can have the same stem, but
        # only one stem is present - the other are missing.
        if @stem_info[@stem_to_path[stem]].stem.nil? && !value.nil?
          @stem_info[@stem_to_path[stem]].stem = key[..-2]
        end
      when VerkleProof::ExtensionStatus::OTHER
        @stem_info[@stem_to_path[stem]].stem = @poas[last_poa]
        last_poa += 1
      else
        # the stem is needed as a path into the tree, but
        # the current key can be used.
        @stem_info[@stem_to_path[stem]].stem = key
      end
    end

    root = Node.new(0, false, nil)
    root.commitment = root_comm

    @stem_info.each do |_, info|
      root.insert_node(info.stem, info, @comms, @poas)
    end

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
