class VerkleProof
  attr_reader :poas, :esses, :comms, :depths

  class ExtensionStatus
    ABSENT = 0
    OTHER = 1
    PRESENT = 2
  end

  def initialize(poas, esses, comms)
    @poas = poas
    @esses = esses.map do |es|
      case es & 3
      when 0
        ExtensionStatus::ABSENT
      when 1
        ExtensionStatus::OTHER
      when 2
        ExtensionStatus::PRESENT
      else
        raise 'invalid extension status'
      end
    end
    @comms = comms
    @depths = esses.map do |es|
      es >> 3
    end
  end

  def self.parse(bytes)
    offset = 4

    n_poas = le_bytes bytes[0, 4]
    poas = []
    n_poas.times do
      poas << bytes[offset, 31]
      offset += 31
    end

    n_esses = le_bytes bytes[offset, 4]
    offset += 4
    esses = []
    n_esses.times do
      esses << bytes[offset]
      offset += 1
    end

    n_comms = le_bytes bytes[offset, 4]
    offset += 4
    comms = []
    n_comms.times do
      comms << bytes[offset, 32]
      offset += 32
    end

    VerkleProof.new(poas, esses, comms)
  end
end
