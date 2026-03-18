# frozen_string_literal: true

require "test_helper"

module Admin
  class ConversationPolicyTest < ActiveSupport::TestCase
    setup do
      @admin_user = User.create!(
        email: "admin@test.com",
        password: "password123",
        display_name: "Admin",
        role: :admin
      )
      @regular_user = User.create!(
        email: "regular@test.com",
        password: "password123",
        display_name: "Regular",
        role: :regular
      )
      @company = Company.create!(
        name: "Test Co",
        nickname: "testco",
        owner: @admin_user,
        status: :active
      )
      @supervisor_user = User.create!(
        email: "supervisor@test.com",
        password: "password123",
        display_name: "Supervisor",
        role: :regular
      )
      CompanyAttendant.create!(
        company: @company,
        user: @supervisor_user,
        role_name: "Support",
        is_supervisor: true,
        status: :available
      )
      @conversation = Conversation.create!(conversation_type: :direct)
      @conversation.participants.create!(user: @admin_user, role: :admin)
      @conversation.participants.create!(user: @regular_user, role: :member)
      @company_conversation = Conversation.create!(
        conversation_type: :direct,
        is_company_conversation: true,
        company: @company
      )
      @company_conversation.participants.create!(user: @company.owner, role: :admin)
      @company_conversation.participants.create!(user: @regular_user, role: :member)
      ConversationAssignment.create!(
        conversation: @company_conversation,
        company: @company,
        status: :active
      )
    end

    teardown do
      [ConversationAssignment, Conversation, CompanyAttendant, Company, User].each do |model|
        model.delete_all
      end
    end

    test "admin can index" do
      policy = Admin::ConversationPolicy.new(@admin_user, @conversation)
      assert policy.index?
    end

    test "supervisor can index" do
      policy = Admin::ConversationPolicy.new(@supervisor_user, @conversation)
      assert policy.index?
    end

    test "regular user cannot index" do
      policy = Admin::ConversationPolicy.new(@regular_user, @conversation)
      assert_not policy.index?
    end

    test "admin can show any conversation" do
      policy = Admin::ConversationPolicy.new(@admin_user, @conversation)
      assert policy.show?
      policy = Admin::ConversationPolicy.new(@admin_user, @company_conversation)
      assert policy.show?
    end

    test "supervisor can show only conversation of their company" do
      policy = Admin::ConversationPolicy.new(@supervisor_user, @company_conversation)
      assert policy.show?
      policy = Admin::ConversationPolicy.new(@supervisor_user, @conversation)
      assert_not policy.show?
    end

    test "regular user cannot show" do
      policy = Admin::ConversationPolicy.new(@regular_user, @conversation)
      assert_not policy.show?
    end

    test "only admin can destroy" do
      assert Admin::ConversationPolicy.new(@admin_user, @conversation).destroy?
      assert_not Admin::ConversationPolicy.new(@supervisor_user, @conversation).destroy?
      assert_not Admin::ConversationPolicy.new(@regular_user, @conversation).destroy?
    end
  end
end
