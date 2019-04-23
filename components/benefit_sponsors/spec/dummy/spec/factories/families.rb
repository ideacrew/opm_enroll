FactoryGirl.define do
  factory :family do
    association :person
    sequence(:e_case_id) {|n| "abc#{n}12xyz#{n}"}
    renewal_consent_through_year  2017
    submitted_at Time.now
    updated_at "user"

    transient do
      people []
    end

    trait :with_primary_family_member do
      family_members { [FactoryGirl.build(:family_member, family: self,
          is_primary_applicant: true, is_active: true, person: person)] }
    end

    trait :with_family_members do
      family_members { people.map{|person| FactoryGirl.build(:family_member, family: self, is_primary_applicant: (self.person == person), is_active: true, person: person) }}
    end

    after(:create) do |f, evaluator|
      f.households.first.add_household_coverage_member(f.family_members.first)
      f.save
    end

    trait :with_primary_family_member_and_dependent do
      family_members {
        [
          FactoryGirl.build(:family_member, family: self, is_primary_applicant: true, is_active: true, person: person),
          FactoryGirl.build(:family_member, family: self, is_primary_applicant: false, is_active: true, person: FactoryGirl.create(:person, first_name: "John", last_name: "Doe")),
          FactoryGirl.build(:family_member, family: self, is_primary_applicant: false, is_active: true, person:  FactoryGirl.create(:person, first_name: "Alex", last_name: "Doe"))
        ]
      }
      before(:create)  do |family, evaluator|
        family.dependents.each do |dependent|
          family.relate_new_member(dependent.person, "child")
        end
      end
    end
  end
end
