def from_hex(hex)
  [hex].pack("H*")[1..]
end

def to_hex(ary, noheader=false)
  return 'nil' if ary.nil?

  ary.reduce(noheader ? '' : '0x') { |s, b| s + format('%02x', b) }
end
