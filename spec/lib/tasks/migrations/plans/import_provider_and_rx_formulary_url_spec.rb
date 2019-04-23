require 'rails_helper'

describe "import_provider_and_rx_formulary_url" do
  before :all do
    Rake.application.rake_require"tasks/migrations/plans/import_provider_and_rx_formulary_url"
    Rake::Task.define_task(:environment)

    @files = Dir.glob(File.join(Rails.root, "spec/test_data/plan_data/master_xml/2018","*.xlsx"))
    year = @files.first.split("/")[-2].to_i

    read_excel(@files.first)

    @plan = FactoryGirl.create(:plan, hios_id: "59763MA0030014-01", active_year: year,
                               rx_formulary_url: nil,
                               provider_directory_url:nil,
                               is_standard_plan: nil,
                               network_information: nil,
                               is_sole_source: nil,
                               is_horizontal: nil,
                               is_vertical: nil)

    @plan2 = FactoryGirl.create(:plan, hios_id: "42690MA1300103-01", active_year: year,
                                rx_formulary_url: nil,
                                provider_directory_url:nil,
                                is_standard_plan: nil,
                                network_information: nil,
                                is_sole_source: nil,
                                is_horizontal: nil,
                                is_vertical: nil)

    @health_product = FactoryGirl.create(:benefit_markets_products_health_products_health_product, hios_id: "59763MA0030014-01",
                                         application_period: Date.new(year, 1, 1)..Date.new(year, 12, 31),
                                         rx_formulary_url: nil,
                                         provider_directory_url:nil,
                                         is_standard_plan: nil,
                                         network_information: nil,
                                         product_package_kinds: nil)

    @health_product2 = FactoryGirl.create(:benefit_markets_products_health_products_health_product, hios_id: "42690MA1300103-01",
                                          application_period: Date.new(year, 1, 1)..Date.new(year, 12, 31),
                                          rx_formulary_url: nil,
                                          provider_directory_url:nil,
                                          is_standard_plan: nil,
                                          network_information: nil,
                                          product_package_kinds: nil)



  end

  context "common_data_from_master_xml" do
    it "should be nil for plan" do
      expect(@plan.rx_formulary_url).to eq nil
      expect(@plan.provider_directory_url).to eq nil
      expect(@plan.network_information).to eq nil
    end

    it "should be nil for product"do
      expect(@health_product2.rx_formulary_url).to eq nil
      expect(@health_product2.provider_directory_url).to eq nil
    end

    it "should run task" do
      invoke_url_tasks
      @plan.reload
      @health_product2.reload
    end

    it "should update plan attributes" do
      expect(@plan.rx_formulary_url).to eq "http://#{@row_info[13]}"
      expect(@plan.provider_directory_url).to eq @row_info[14]
      expect(@plan.network_information).to eq @row_info[11]
    end

    it "should update product attributes" do
      expect(@health_product2.rx_formulary_url).to eq "http://#{@row_info[13]}"
      expect(@health_product2.provider_directory_url).to eq @row_info[14]
      expect(@health_product2.product_package_kinds).to eq [:metal_level, :single_issuer, :single_product]
    end
  end
end

def invoke_url_tasks
 Rake::Task["import:common_data_from_master_xml"].invoke(@files.first)
end

def read_excel(file)
  result = Roo::Spreadsheet.open(file)
  sheet_data = result.sheet("2018_QHP")
  @row_info = sheet_data.row(2)
end