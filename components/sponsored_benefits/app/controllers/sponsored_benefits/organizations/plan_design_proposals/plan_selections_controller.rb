module SponsoredBenefits
  module Organizations
    class PlanDesignProposals::PlanSelectionsController < ApplicationController
      before_action :published_plans_are_view_only

      def new
        plan_design_form.for_new
      end

      private
      helper_method :plan_design_form, :plan_design_organization, :plan_design_proposal, :plan_design_proposal_benefit_group, :kind, :has_dental_benefits?

      def published_plans_are_view_only
        if plan_design_proposal.published?
          redirect_to organizations_plan_design_proposal_path(plan_design_proposal)
        end
      end

      def plan_design_proposal
        @plan_design_proposal ||= SponsoredBenefits::Organizations::PlanDesignProposal.find(params[:plan_design_proposal_id])
      end

      def plan_design_organization
        @plan_design_organization ||= plan_design_proposal.plan_design_organization
      end

      def plan_design_form
        SponsoredBenefits::Forms::PlanDesignProposal.new(organization: plan_design_organization, proposal_id: params[:plan_design_proposal_id], kind: kind)
      end

      def plan_design_application
        plan_design_proposal.profile.benefit_application
      end

      def plan_design_proposal_benefit_group
        plan_design_application.benefit_groups.first
      end

      def kind
        if params[:kind] == "dental"
          "dental"
        else
          "health"
        end
      end

      def has_dental_benefits?
        plan_design_proposal.active_benefit_group.dental_reference_plan_id.present?
      end
    end
  end
end
