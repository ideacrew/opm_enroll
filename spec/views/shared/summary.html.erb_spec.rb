require 'rails_helper'

describe "shared/_summary.html.erb" do
  let(:mock_carrier_profile) { instance_double("CarrierProfile", :dba => "a carrier name") }
  let(:mock_hbx_enrollment) { instance_double("HbxEnrollment", :hbx_enrollment_members => [], :id => "3241251524") }
  let(:mock_plan) { double(
      :name => "A Plan Name",
      :carrier_profile_id => "a carrier profile id",
      :carrier_profile => mock_carrier_profile,
      :metal_level => "Silver",
      :plan_type => "A plan type",
      :nationwide => true,
      :deductible => 0,
      :total_premium => 0,
      :total_employer_contribution => 0,
      :total_employee_cost => 0,
      :id => "1234234234",
      :sbc_file => "THE SBC FILE.PDF"
      ) }
  let(:mock_qhp) { instance_double("Products::Qhp", :qhp_benefits => []) }

  before :each do
    assign :plan, mock_plan
    assign :hbx_enrollment, mock_hbx_enrollment
    render "shared/summary", :qhp => mock_qhp
  end

  it "should have a link to download the sbc pdf" do
    expect(rendered).to have_selector("a[href='#{root_path + "sbc/THE SBC FILE.PDF"}']")
  end
end