# Node represents a stateless node
class Node
  attr_reader :children, :commitment, :values, :extension

  def initialize(depth, leaf, extension)
    if leaf
      @values = {}
    else
      @children = {}
    end
    @depth = depth
    @extension = extension
  end

  def insert_node(stem, stem_info, comms, poas)
    child_index = key[@depth]

    raise 'ext-and-suffix node should never be inserted into directly' if @children.nil?

    # if the child already exists, recurse
    return @children[child_index].insert_node(stem, stem_info, comms, poas) if @children.key?(child_index)

    if @depth == stem_info.depth - 1
      # Reached the point where the stem should be inserted (depending
      # on the stem type, though).
      case stem_info.ext_status
      when VerkleProof::StemInfo::PRESENT
        # Insert a new stem
        @children[child_index] = new(@depth + 1, true, stem)
        @children[child_index].insert_into_leaf(stem, stem_info, comms)
      when VerkleProof::StemInfo::ABSENT
        # Stem doesn't exist, leave as is
      else # OTHER
        # Insert from the missing POA stems
        @children[child_index] = new(@depth + 1, true, poastems.shift)
        @children[child_index].commitment = comms.shift
        @children[child_index].insert_into_leaf(stem, stem_info, comms)
      end
    else
      # Insert an internal node and recurse
      @children[child_index] = new(@depth + 1, false, nil)
      @children[child_index].commitment = comms.shift
      @children[child_index].insert_node(stem, stem_info, comms, poas)
    end
  end

  def insert_into_leaf(stem_info, comms)
    @commitment = comms.shift
    @c1 = comms.shift if stem_info.has_c1
    @c2 = comms.shift if stem_info.has_c2
  end

  def insert(key, value)
    path_element = key[@depth]
    if @children.nil? # leaf node
      if key[@depth..30] == @extension
        # insert into extension
        values[key[31]] = value
      else
        # break into two nodes
        old_element, *old_extension = @extension
        @extension = nil
        @children = { old_element => Node.new(@depth + 1, true, old_extension) }
        @children[old_element].values = @values
        @children[path_element] = Node.new(@depth + 1, true, key[@depth + 1..-1]) if old_element != path_element
        @children[path_element].insert(key, value)
        @values = nil
      end
    else # internal node
      if @children.key?(path_element)
        # existing child
        @children[path_element].insert(key, value)
      else
        # create missing child
        @children[path_element] = Node.new(@depth + 1, true, key[@depth + 1..-2])
        @children[path_element].values[key[31]] = value
      end
    end
  end

  def leaf?
    @children.nil?
  end

  # Associate the list of commitments from the proof, to a
  # rebuilt tree.
  def set_comms(comms)
    @commitment, *rest = comms

    if leaf?
      # Associate a commitment to C1 and/or C2, if present
      @values.keys.sort.each do |suffix|
        # Capture the commitment of a suffix tree the
        # first time a new value 'opens' that suffix
        # tree.
        @c1, *rest = rest if suffix < 128 && @c1.nil?
        @c2, *rest = rest if suffix >= 128 && @c2.nil?
      end
    else
      @children.keys.sort.each do |key|
        # Recurse into children nodes.
        rest = @children[key].set_comms rest
      end
    end
    rest
  end

  def to_dot(path, parent)
    ret = ''
    if leaf?
      name = "ext_#{path}_#{to_hex @extension, true}"
      ret += parent.empty? ? '' : "#{parent} -> #{name} [label=\"#{path[-2..-1]}\"]\n"
      ret += "#{name} [label=\"ext=#{to_hex(@extension)}\\ncomm=#{to_hex(@commitment)}\"]\n"
      ret += "#{name}_c1 [label=\"#{to_hex(@c1)}\"]\n#{name} -> #{name}_c1 [label=\"2\"]\n" if @c1
      ret += "#{name}_c2 [label=\"#{to_hex(@c2)}\"]\n#{name} -> #{name}_c2 [label=\"3\"]\n" if @c2
      @values.each do |suffix, value|
        ret += <<~LEAF
          val_#{path}_#{to_hex(@extension, true)}_#{suffix} [label=\"#{hex_label value}\"]
          #{name}_c#{1 + suffix / 128} -> val_#{path}_#{to_hex(@extension, true)}_#{suffix} [label="#{suffix}"]
        LEAF
      end
    else
      name = parent.empty? ? 'root' : "int_#{path}"
      ret += "#{name} [label=\"#{to_hex(@commitment)}\"]\n"
      ret += parent.empty? ? '' : "#{parent} -> #{name} [label=\"#{path[-2..-1]}\"]\n"
      @children.each do |num, node|
        ret += node.to_dot("#{path}#{format '%02x', num}", name)
      end
    end
    ret
  end

  private

  # displays a label containing a hex number, and perform
  # some extra formatting:
  #  * replaces trailing 0s with 0...
  #  * replaces `NULL` values with `∅`
  def hex_label(item)
    if item.nil? || item.empty?
      '∅'
    else
      to_hex(item, false).gsub(/00(0{2})+$/, '00...')
    end
  end
end
