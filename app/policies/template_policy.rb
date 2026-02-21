class TemplatePolicy < ApplicationPolicy
  def index?   = user.present?
  def show?    = user.present?
  def create?  = user.present?
  def update?  = record.created_by == user
  def destroy? = record.created_by == user

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end
end
