# Node represents a stateless node
class Node
  attr_accessor :children, :commitment, :values, :extension

  def initialize(depth, leaf, extension)
    if leaf
      @values = {}
    else
      @children = {}
    end
    @depth = depth
    @extension = extension
  end

  # Helper function used to rebuild the tree from a proof. It is
  # expected to be called on an internal node, and will create all
  # the internal nodes along the path from the root to the "extension
  # and suffix" node. It is not concerned with inserting the values
  # (see the insert function).
  def insert_node(stem, stem_info, comms, poas)
    raise 'ext-and-suffix node should never be inserted into directly' if leaf?

    child_index = stem[@depth]


    # if the child already exists, recurse
    return @children[child_index].insert_node(stem, stem_info, comms, poas) if @children.key?(child_index)

    if @depth == stem_info.depth - 1
      # Reached the point where the stem should be inserted (depending
      # on the stem type, though).
      case stem_info.ext_status
      when VerkleProof::ExtensionStatus::PRESENT
        # Insert a new stem
        @children[child_index] = Node.new(@depth + 1, true, stem)
        @children[child_index].insert_leaf_node(stem_info, comms)
      when VerkleProof::ExtensionStatus::ABSENT
        # Stem doesn't exist, leave as is
      else # OTHER
        # Insert from the missing POA stems
        @children[child_index] = Node.new(@depth + 1, true, poas.shift)
        @children[child_index].insert_leaf_node(stem_info, comms)
      end
    else
      # Insert an internal node and recurse
      @children[child_index] = Node.new(@depth + 1, false, nil)
      @children[child_index].insert_node(stem, stem_info, comms, poas)
    end
  end

  def leaf?
    @children.nil?
  end

  def to_dot(path, parent)
    ret = ''
    if leaf?
      name = "ext_#{path}_#{to_hex @extension, true}"
      ret += parent.empty? ? '' : "#{parent} -> #{name} [label=\"#{path[-2..-1]}\"]\n"
      ret += "#{name} [label=\"ext=#{to_hex(@extension)}\\ncomm=#{to_hex(@commitment)}\"]\n"
      ret += "#{name}_c1 [label=\"#{to_hex(@c1)}\"]\n#{name} -> #{name}_c1 [label=\"𝑐₁\"]\n" if @c1
      ret += "#{name}_c2 [label=\"#{to_hex(@c2)}\"]\n#{name} -> #{name}_c2 [label=\"𝑐₂\"]\n" if @c2
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

  protected

  def insert_leaf_node(stem_info, comms)
    @commitment = comms.shift
    @c1 = comms.shift if stem_info.has_c1
    @c2 = comms.shift if stem_info.has_c2
  end
end
