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

  def set_comms(comms)
    @commitment, *rest = comms
    if leaf?
      @values.keys.sort.each do |suffix|
        @c1, *rest = rest if suffix < 128 && @c1.nil?
        @c2, *rest = rest if suffix >= 128 && @c2.nil?
      end
    else
      @children.keys.sort.each do |key|
        rest = @children[key].set_comms rest
      end
      rest
    end
  end

  def to_dot(path, parent)
    ret = ''
    if leaf?
      name = "ext_#{path}_#{to_hex @extension, true}"
      ret += parent.empty? ? '' : "#{parent} -> #{name} [label=\"#{path[-2..-1]}\"]\n"
      ret += "#{name} [label=\"#{to_hex(@extension)} #{to_hex(@commitment)}\"]\n"
      ret += "#{name}_c1 [label=\"#{to_hex(@c1)}\"]\n#{name} -> #{name}_c1 [label=\"2\"]\n" if @c1
      ret += "#{name}_c2 [label=\"#{to_hex(@c2)}\"]\n#{name} -> #{name}_c2 [label=\"3\"]\n" if @c2
      @values.each do |suffix, value|
        ret += <<~LEAF
          val_#{path}_#{to_hex(@extension, true)}_#{suffix} [label=\"#{to_hex(value)}\"]
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
end
