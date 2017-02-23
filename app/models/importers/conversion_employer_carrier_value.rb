module Importers::ConversionEmployerCarrierValue
  CARRIER_MAPPING = {
    "aetna" => "AHI",
    "carefirst bluecross blueshield" => "GHMSI",
    "kaiser permanente" => "KFMASI",
    "united healthcare" => "UHIC",
    "united health care" => "UHIC",
    "unitedhealthcare" => "UHIC"
  }

  def self.included(base) 
    base.class_eval do
      attr_reader :carrier

      validate :validate_carrier
      validates_presence_of :carrier, :allow_blank => false 
    end
  end

  def carrier=(val)
    if val.blank?
      @carrier = nil
      return val
    end
    @carrier = CARRIER_MAPPING[val.strip.downcase]
  end

  def validate_carrier
    found_carrier = find_carrier
    if found_carrier.nil?
      errors.add(:carrier, "invalid carrier specified (not one of #{CARRIER_MAPPING.keys.join(", ")})")
    end
  end

  def find_carrier
    org = Organization.where("carrier_profile.abbrev" => carrier).first
    return nil unless org
    org.carrier_profile
  end
end
