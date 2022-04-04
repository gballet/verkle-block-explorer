def from_hex(hex)
  [hex].pack("H*")[1..]
end

def to_hex(ary, noheader=false)
  return 'nil' if ary.nil?

  ary.reduce(noheader ? '' : '0x') { |s, b| s + format('%02x', b) }
end

def le_bytes(ary)
  be_bytes ary.reverse
end

def be_bytes(ary)
  ary.reduce(0) do |a, b|
    a *= 256
    a += b
    a
  end
end
