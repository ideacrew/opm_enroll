require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "define_permissions")

describe DefinePermissions, dbclean: :after_each do
  subject { DefinePermissions.new(given_task_name, double(:current_scope => nil))}
  let(:roles) {%w{hbx_staff hbx_read_only hbx_csr_supervisor hbx_tier3 hbx_csr_tier2 hbx_csr_tier1 developer super_admin} }
  describe 'create permissions' do
    let(:given_task_name) {':initial_hbx'}
    before do
      Person.all.delete
      person= FactoryGirl.create(:person)
      role = FactoryGirl.create(:hbx_staff_role, person: person)
      subject.initial_hbx
    end
    it "creates permissions" do
      expect(Permission.count).to eq(8)
    	expect(Person.first.hbx_staff_role.subrole).to eq 'hbx_staff'
      expect(Permission.all.map(&:name)).to match_array roles
    end

    describe 'update permissions for hbx staff role' do
      let(:given_task_name) {':hbx_admin_can_complete_resident_application'}
      let(:given_task_name) {':hbx_admin_can_access_user_account_tab'}

      before do
        User.all.delete
        Person.all.delete
        person = FactoryGirl.create(:person)
        permission = FactoryGirl.create(:permission, :hbx_staff)
        role = FactoryGirl.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: permission.id)
        subject.hbx_admin_can_complete_resident_application
      end

      it "updates can_complete_resident_application to true" do
        expect(Person.all.count).to eq(1)
        expect(Person.first.hbx_staff_role.permission.can_complete_resident_application).to be true
      end
    end

    describe 'update permissions for hbx staff role to be able to view username and email' do
      let(:given_task_name) {':hbx_admin_can_add_view_username_and_email'}
      let(:given_task_name) {':hbx_admin_can_access_pay_now'}

      before do
        User.all.delete
        Person.all.delete
        @hbx_staff_person = FactoryGirl.create(:person)
        @hbx_tier3_person = FactoryGirl.create(:person)
        @hbx_read_only_person = FactoryGirl.create(:person)
        @hbx_csr_supervisor_person = FactoryGirl.create(:person)
        @hbx_csr_tier1_person = FactoryGirl.create(:person)
        @hbx_csr_tier2_person = FactoryGirl.create(:person)
        @super_admin_person = FactoryGirl.create(:person)
        hbx_staff_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_staff_person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
        hbx_tier3_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_tier3_person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
        hbx_read_only_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_read_only_person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
        hbx_csr_supervisor_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_supervisor_person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
        hbx_csr_tier1_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier1_person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
        hbx_csr_tier2_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier2_person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
        super_admin_person = FactoryGirl.create(:hbx_staff_role, person: @super_admin_person, subrole: "super_admin", permission_id: Permission.super_admin.id)
        subject.hbx_admin_can_view_username_and_email
        subject.hbx_admin_can_access_user_account_tab
      end

      it "updates can_access_pay_now to true" do
        subject.hbx_admin_can_access_pay_now
        expect(Person.all.count).to eq(7)
        expect(@hbx_staff_person.hbx_staff_role.permission.can_access_pay_now).to be true
        expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_access_pay_now).to be true
        expect(@hbx_csr_tier1_person.hbx_staff_role.permission.can_access_pay_now).to be true
        expect(@hbx_csr_tier2_person.hbx_staff_role.permission.can_access_pay_now).to be true
      end

      it "updates can_view_username_and_email to true" do
        expect(Person.all.count).to eq(7)
        expect(@hbx_staff_person.hbx_staff_role.permission.can_view_username_and_email).to be true
        expect(@hbx_read_only_person.hbx_staff_role.permission.can_view_username_and_email).to be true
        expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_view_username_and_email).to be true
        expect(@hbx_csr_tier1_person.hbx_staff_role.permission.can_view_username_and_email).to be true
        expect(@hbx_csr_tier2_person.hbx_staff_role.permission.can_view_username_and_email).to be true
        expect(@super_admin_person.hbx_staff_role.permission.can_view_username_and_email).to be true
        #verifying that the rake task updated only the correct subroles
        expect(Permission.developer.can_add_sep).to be false
      end

      it "updates can_access_user_account_tab to true" do
        expect(Person.all.count).to eq(7)
        expect(@hbx_staff_person.hbx_staff_role.permission.can_access_user_account_tab).to be true
        expect(@hbx_tier3_person.hbx_staff_role.permission.can_access_user_account_tab).to be true
      end
    end

    describe 'update permissions for hbx staff role to be able to view  application types' do
      let(:given_task_name) {':hbx_admin_can_view_application_types'}

      before do
        User.all.delete
        Person.all.delete
        @hbx_staff_person = FactoryGirl.create(:person)
        @hbx_csr_supervisor_person = FactoryGirl.create(:person)
        @hbx_csr_tier1_person = FactoryGirl.create(:person)
        @hbx_csr_tier2_person = FactoryGirl.create(:person)
        hbx_staff_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_staff_person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
        hbx_csr_supervisor_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_supervisor_person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
        hbx_csr_tier1_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier1_person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
        hbx_csr_tier2_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier2_person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
        subject.hbx_admin_can_view_application_types
      end

      it "updates can_view_application_types to true" do
        expect(Person.all.count).to eq(4)
        expect(@hbx_staff_person.hbx_staff_role.permission.can_view_application_types).to be true
        expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_view_application_types).to be false
        expect(@hbx_csr_tier1_person.hbx_staff_role.permission.can_view_application_types).to be false
        expect(@hbx_csr_tier2_person.hbx_staff_role.permission.can_view_application_types).to be false
        #verifying that the rake task updated only the correct subroles
        expect(Permission.developer.can_view_application_types).to be false
      end
    end


    describe 'update permissions for hbx staff role to add sep' do
      let(:given_task_name) {':hbx_admin_can_add_sep'}

      before do
        User.all.delete
        Person.all.delete
        @hbx_staff_person = FactoryGirl.create(:person)
        @hbx_read_only_person = FactoryGirl.create(:person)
        @hbx_csr_supervisor_person = FactoryGirl.create(:person)
        @super_admin_person = FactoryGirl.create(:person)
        hbx_staff_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_staff_person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
        hbx_read_only_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_read_only_person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
        hbx_csr_supervisor_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_supervisor_person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
        super_admin_role = FactoryGirl.create(:hbx_staff_role, person: @super_admin_person, subrole: "super_admin", permission_id: Permission.super_admin.id)
        subject.hbx_admin_can_add_sep
      end

      it "updates can_complete_resident_application to true" do
        expect(Person.all.count).to eq(4)
        expect(@hbx_staff_person.hbx_staff_role.permission.can_add_sep).to be true
        expect(@hbx_read_only_person.hbx_staff_role.permission.can_add_sep).to be false
        expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_add_sep).to be false
        expect(@super_admin_person.hbx_staff_role.permission.can_add_sep).to be true
        #verifying that the rake task updated only the correct subroles
        expect(Permission.hbx_csr_tier1.can_add_sep).to be false
        expect(Permission.hbx_csr_tier2.can_add_sep).to be false
        expect(Permission.developer.can_add_sep).to be false
        expect(Permission.super_admin.can_add_sep).to be true
      end
    end

    describe 'update permissions for hbx staff role to be able transition family members' do
      let(:given_task_name) {':hbx_admin_can_transition_family_members'}

      before do
        User.all.delete
        Person.all.delete
        @hbx_staff_person = FactoryGirl.create(:person)
        @hbx_read_only_person = FactoryGirl.create(:person)
        @hbx_csr_supervisor_person = FactoryGirl.create(:person)
        @hbx_csr_tier1_person = FactoryGirl.create(:person)
        @hbx_csr_tier2_person = FactoryGirl.create(:person)
        @super_admin_person = FactoryGirl.create(:person)
        hbx_staff_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_staff_person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
        hbx_read_only_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_read_only_person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
        hbx_csr_supervisor_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_supervisor_person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
        hbx_csr_tier1_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier1_person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
        hbx_csr_tier2_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier2_person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
        super_admin_role = FactoryGirl.create(:hbx_staff_role, person: @super_admin_person, subrole: "super_admin", permission_id: Permission.super_admin.id)
        subject.hbx_admin_can_transition_family_members
      end

      it "updates can_transition_family_members to true/false based on staff roles" do
        expect(Person.all.count).to eq(6)
        expect(@hbx_staff_person.hbx_staff_role.permission.can_transition_family_members).to be true
        expect(@hbx_read_only_person.hbx_staff_role.permission.can_transition_family_members).to be false
        expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_transition_family_members).to be false
        expect(@hbx_csr_tier1_person.hbx_staff_role.permission.can_transition_family_members).to be false
        expect(@hbx_csr_tier2_person.hbx_staff_role.permission.can_transition_family_members).to be false
        expect(@super_admin_person.hbx_staff_role.permission.can_transition_family_members).to be false
      end
    end

    describe 'update permissions for super admin role to be able to force publish' do
      let(:given_task_name) {':hbx_admin_can_force_publish'}

      before do
        User.all.delete
        Person.all.delete
      end

      context "of an hbx super admin" do
        let(:hbx_super_admin) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "super_admin", permission_id: Permission.super_admin.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_super_admin.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns true' do
            expect(hbx_super_admin.hbx_staff_role.permission.can_force_publish).to be true
          end
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx read only" do
        let(:hbx_read_only) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "hbx_read_only", permission_id: Permission.hbx_read_only.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_read_only.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_read_only.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx csr supervisor" do
        let(:hbx_csr_supervisor) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "hbx_csr_supervisor", permission_id: Permission.hbx_csr_supervisor.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_supervisor.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_csr_supervisor.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx csr tier1" do
        let(:hbx_csr_tier1) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier1", permission_id: Permission.hbx_csr_tier1.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier1.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_csr_tier1.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx csr tier2" do
        let(:hbx_csr_tier2) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "hbx_csr_tier2", permission_id: Permission.hbx_csr_tier2.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_csr_tier2.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_csr_tier2.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx tier3" do
        let(:hbx_tier3) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "hbx_tier3", permission_id: Permission.hbx_tier3.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_tier3.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns true' do
            expect(hbx_tier3.hbx_staff_role.permission.can_force_publish).to be true
          end
        end
      end

      context "of an hbx staff" do
        let(:hbx_staff) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "hbx_staff", permission_id: Permission.hbx_staff.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(hbx_staff.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(hbx_staff.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end

      context "of an hbx staff" do
        let(:developer) do
          FactoryGirl.create(:person).tap do |person|
            FactoryGirl.create(:hbx_staff_role, person: person, subrole: "developer", permission_id: Permission.developer.id)
          end
        end

        it 'returns false before the rake task is ran' do
          expect(developer.hbx_staff_role.permission.can_force_publish).to be false
        end

        context 'after the rake task is run' do
          before do
            subject.hbx_admin_can_force_publish
          end

          it 'returns false' do
            expect(developer.hbx_staff_role.permission.can_force_publish).to be false
          end
        end
      end
    end
  end

  describe 'update permissions for hbx staff role' do
    let(:given_task_name) { "hbx_admin_csr_view_personal_info_page" }

    describe "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    before do
      User.all.delete
      Person.all.delete
      @hbx_staff_person = FactoryGirl.create(:person)
      @hbx_csr_supervisor_person = FactoryGirl.create(:person)
      @hbx_csr_tier1_person = FactoryGirl.create(:person)
      @hbx_csr_tier2_person = FactoryGirl.create(:person)
      permission_hbx_staff = FactoryGirl.create(:permission, :hbx_staff)
      permission_hbx_csr_supervisor = FactoryGirl.create(:permission, :hbx_csr_supervisor)
      permission_hbx_csr_tier2 = FactoryGirl.create(:permission, :hbx_csr_tier2)
      permission_hbx_csr_tier1 = FactoryGirl.create(:permission, :hbx_csr_tier1)
      hbx_staff_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_staff_person, subrole: "hbx_staff", permission_id: permission_hbx_staff.id)
      hbx_csr_supervisor_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_supervisor_person, subrole: "hbx_csr_supervisor", permission_id: permission_hbx_csr_supervisor.id)
      hbx_csr_tier1_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier2_person, subrole: "hbx_csr_tier1", permission_id: permission_hbx_csr_tier2.id)
      hbx_csr_tier2_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier1_person, subrole: "hbx_csr_tier2", permission_id: permission_hbx_csr_tier1.id)

      subject.hbx_admin_csr_view_personal_info_page
    end
    it "updates hbx_admin_csr_view_personal_info_page to true" do
      expect(Person.all.count).to eq(4)
      expect(@hbx_staff_person.hbx_staff_role.permission.view_personal_info_page).to be true
      expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.view_personal_info_page).to be true
      expect(@hbx_csr_tier2_person.hbx_staff_role.permission.view_personal_info_page).to be true
      expect(@hbx_csr_tier1_person.hbx_staff_role.permission.view_personal_info_page).to be true
    end
  end

  describe 'update permissions for hbx staff role' do
    let(:given_task_name) { "hbx_admin_can_access_new_consumer_application_sub_tab" }
    let(:given_task_name) { "hbx_admin_can_access_outstanding_verification_sub_tab" }
    let(:given_task_name) { "hbx_admin_can_access_identity_verification_sub_tab" }
    let(:given_task_name) { "hbx_admin_can_complete_resident_application" }
    let(:given_task_name) { "hbx_admin_can_access_accept_reject_identity_documents" }
    let(:given_task_name) { "hbx_admin_can_access_accept_reject_paper_application_documents" }
    let(:given_task_name) { "hbx_admin_can_delete_identity_application_documents" }

    describe "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    before do
      User.all.delete
      Person.all.delete
      @hbx_staff_person = FactoryGirl.create(:person)
      @hbx_read_only_person = FactoryGirl.create(:person)
      @hbx_csr_supervisor_person = FactoryGirl.create(:person)
      @hbx_csr_tier1_person = FactoryGirl.create(:person)
      @hbx_csr_tier2_person = FactoryGirl.create(:person)
      @super_admin_person = FactoryGirl.create(:person)
      permission_hbx_staff = FactoryGirl.create(:permission, :hbx_staff)
      permission_hbx_read_only = FactoryGirl.create(:permission, :hbx_read_only)
      permission_hbx_csr_supervisor = FactoryGirl.create(:permission, :hbx_csr_supervisor)
      permission_hbx_csr_tier2 = FactoryGirl.create(:permission, :hbx_csr_tier2)
      permission_hbx_csr_tier1 = FactoryGirl.create(:permission, :hbx_csr_tier1)
      permission_super_admin = FactoryGirl.create(:permission, :super_admin)
      hbx_staff_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_staff_person, subrole: "hbx_staff", permission_id: permission_hbx_staff.id)
      hbx_read_only = FactoryGirl.create(:hbx_staff_role, person: @hbx_read_only_person, subrole: "hbx_read_only", permission_id: permission_hbx_staff.id)
      hbx_csr_supervisor_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_supervisor_person, subrole: "hbx_csr_supervisor", permission_id: permission_hbx_csr_supervisor.id)
      hbx_csr_tier1_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier2_person, subrole: "hbx_csr_tier1", permission_id: permission_hbx_csr_tier2.id)
      hbx_csr_tier2_role = FactoryGirl.create(:hbx_staff_role, person: @hbx_csr_tier1_person, subrole: "hbx_csr_tier2", permission_id: permission_hbx_csr_tier1.id)
      super_admin = FactoryGirl.create(:hbx_staff_role, person: @super_admin_person, subrole: "super_admin", permission_id: permission_hbx_staff.id)
    end
    it "updates hbx_admin_can_access_new_consumer_application_sub_tab to true" do
      subject.hbx_admin_can_access_new_consumer_application_sub_tab
      expect(Person.all.count).to eq(6)
      expect(@hbx_staff_person.hbx_staff_role.permission.can_access_new_consumer_application_sub_tab).to be true
      expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_access_new_consumer_application_sub_tab).to be true
      expect(@hbx_csr_tier1_person.hbx_staff_role.permission.can_access_new_consumer_application_sub_tab).to be true
      expect(@hbx_csr_tier2_person.hbx_staff_role.permission.can_access_new_consumer_application_sub_tab).to be true
    end
    it "updates hbx_admin_can_access_identity_verification_sub_tab to true" do
      subject.hbx_admin_can_access_identity_verification_sub_tab
      expect(Person.all.count).to eq(6)
      expect(@hbx_staff_person.hbx_staff_role.permission.can_access_identity_verification_sub_tab).to be true
      expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_access_identity_verification_sub_tab).to be true
      expect(@hbx_csr_tier1_person.hbx_staff_role.permission.can_access_identity_verification_sub_tab).to be true
      expect(@hbx_csr_tier2_person.hbx_staff_role.permission.can_access_identity_verification_sub_tab).to be true
    end
    it "updates hbx_admin_can_access_outstanding_verification_sub_tab to true" do
      subject.hbx_admin_can_access_outstanding_verification_sub_tab
      expect(Person.all.count).to eq(6)
      expect(@hbx_staff_person.hbx_staff_role.permission.can_access_outstanding_verification_sub_tab).to be true
    end
    it "updates hbx_admin_can_complete_resident_application to true" do
      subject.hbx_admin_can_complete_resident_application
      expect(Person.all.count).to eq(6)
      expect(@hbx_staff_person.hbx_staff_role.permission.can_complete_resident_application).to be true
    end
    it "updates hbx_admin_can_access_accept_reject_identity_documents to true" do
      subject.hbx_admin_can_access_accept_reject_identity_documents
      expect(Person.all.count).to eq(6)
      expect(@hbx_staff_person.hbx_staff_role.permission.can_access_accept_reject_identity_documents).to be true
    end
    it "updates hbx_admin_can_access_accept_reject_paper_application_documents to true" do
      subject.hbx_admin_can_access_accept_reject_paper_application_documents
      expect(Person.all.count).to eq(6)
      expect(@hbx_staff_person.hbx_staff_role.permission.can_access_accept_reject_paper_application_documents).to be true
      expect(@hbx_csr_supervisor_person.hbx_staff_role.permission.can_access_accept_reject_paper_application_documents).to be true
      expect(@hbx_csr_tier1_person.hbx_staff_role.permission.can_access_accept_reject_paper_application_documents).to be true
      expect(@hbx_csr_tier2_person.hbx_staff_role.permission.can_access_accept_reject_paper_application_documents).to be true
    end
    it "updates hbx_admin_can_delete_identity_application_documents to true" do
      subject.hbx_admin_can_delete_identity_application_documents
      expect(Person.all.count).to eq(6)
      expect(@hbx_staff_person.hbx_staff_role.permission.can_delete_identity_application_documents).to be true
    end
  end

  describe 'build test roles' do
    let(:given_task_name) {':build_test_roles'}
    before do
      User.all.delete
      Person.all.delete
      hbx_profile = FactoryGirl.create(:hbx_profile)
      allow(Permission).to receive_message_chain('hbx_staff.id'){FactoryGirl.create(:permission, :hbx_staff).id}
      allow(Permission).to receive_message_chain('hbx_read_only.id'){FactoryGirl.create(:permission, :hbx_read_only).id}
      allow(Permission).to receive_message_chain('hbx_csr_supervisor.id'){FactoryGirl.create(:permission, :hbx_csr_supervisor).id}
      allow(Permission).to receive_message_chain('hbx_csr_tier2.id'){FactoryGirl.create(:permission,  :hbx_csr_tier2).id}
      allow(Permission).to receive_message_chain('hbx_csr_tier1.id'){FactoryGirl.create(:permission,  :hbx_csr_tier1).id}
      allow(Permission).to receive_message_chain('hbx_csr_tier1.id'){FactoryGirl.create(:permission,  :developer).id}
      allow(Permission).to receive_message_chain('hbx_tier3.id'){FactoryGirl.create(:permission,  :hbx_tier3).id}
      allow(Permission).to receive_message_chain('super_admin.id'){FactoryGirl.create(:permission, :super_admin).id}
      subject.build_test_roles
    end
    it "creates permissions" do
      expect(User.all.count).to eq(8)
      expect(Person.all.count).to eq(8)
      expect(Person.all.map{|p|p.hbx_staff_role.subrole}).to match_array roles
    end
  end
end
