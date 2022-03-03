def from_hex(hex)
  [hex].pack("H*")[1..]
end
