class Plan
  include Mongoid::Document
  include Mongoid::Timestamps

  COVERAGE_KINDS = %w[health dental].freeze
  METAL_LEVEL_KINDS = %w[bronze silver gold platinum catastrophic dental].freeze
  REFERENCE_PLAN_METAL_LEVELS = %w[bronze silver gold platinum dental].freeze
  MARKET_KINDS = %w[shop individual].freeze
  PLAN_TYPE_KINDS = %w[pos hmo epo ppo].freeze
  DENTAL_METAL_LEVEL_KINDS = %w[high low].freeze


  field :hbx_id, type: Integer
  field :active_year, type: Integer
  field :market, type: String
  field :coverage_kind, type: String
  field :carrier_profile_id, type: BSON::ObjectId
  field :metal_level, type: String
  field :service_area_id, type: String

  field :hios_id, type: String
  field :hios_base_id, type: String
  field :csr_variant_id, type: String

  field :name, type: String

  scope :by_active_year,        ->(active_year = TimeKeeper.date_of_record.year) { where(active_year: active_year) }
  scope :shop_market,           ->{ where(market: "shop") }
  scope :health_coverage,       ->{ where(coverage_kind: "health") }
  scope :dental_coverage,       ->{ where(coverage_kind: "dental") }

end