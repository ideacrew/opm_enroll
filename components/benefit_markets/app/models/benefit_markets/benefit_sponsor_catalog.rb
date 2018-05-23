module BenefitMarkets
  class BenefitSponsorCatalog
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :benefit_application, class_name: "::BenefitSponsors::BenefitApplications::BenefitApplication"

    field :effective_date,          type: Date
    field :effective_period,        type: Range
    field :open_enrollment_period,  type: Range
    field :probation_period_kinds,  type: Array, default: []

    belongs_to  :service_area,
                class_name: "BenefitMarkets::Locations::ServiceArea"

    embeds_one  :sponsor_market_policy,
                class_name: "::BenefitMarkets::MarketPolicies::SponsorMarketPolicy"

    embeds_one  :member_market_policy,
                class_name: "::BenefitMarkets::MarketPolicies::MemberMarketPolicy"

    embeds_many :product_packages, as: :packagable,
                class_name: "::BenefitMarkets::Products::ProductPackage"


    validates_presence_of :effective_date, :probation_period_kinds, :effective_period, :open_enrollment_period,
                          :service_area, :sponsor_market_policy, :member_market_policy, :product_packages

    def product_package_for(sponsored_benefit)
      product_packages.by_package_kind(sponsored_benefit.product_package_kind)
                      .by_product_kind(sponsored_benefit.product_kind)[0]
    end

    # TODO: check for late rate updates

    # def update_product_packages
    #   if is_product_package_update_available?
    #     product_packages.each do |product_package|
    #       product_package.update_products
    #     end
    #   end
    # end

    # def is_product_package_update_available?
    #   product_packages.any?{|product_package| benefit_market_catalog.is_product_package_updated?(product_package) }
    # end

    def comparable_attrs
      [:effective_date, :service_area, :sponsor_market_policy, :member_market_policy]
    end

    # Define Comparable operator
    # If instance attributes are the same, compare ProductPackages
    def <=>(other)
      if comparable_attrs.all? { |attr| send(attr) == other.send(attr)  }
        if product_packages.to_a == other.product_packages.to_a
          0
        else
          product_packages.to_a <=> other.product_packages.to_a
        end
      else
        other.updated_at.blank? || (updated_at < other.updated_at) ? -1 : 1
      end
    end

  end
end
