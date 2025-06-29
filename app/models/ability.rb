# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user.present?

    case user.role
    when 'system_admin'
      can :manage, :all
      can :access, :admin_dashboard
      can :access, :system_monitoring
      can :access, :user_management
    when 'admin'
      can :manage, Festival
      can :manage, Task
      can :manage, VendorApplication
      can :manage, User, role: ['resident', 'volunteer', 'vendor', 'committee_member']
      can :read, User
    when 'committee_member'
      can :manage, Festival
      can :manage, Task
      can :manage, VendorApplication
      can :read, User
      can :update, User, id: user.id
    when 'vendor'
      can :read, Festival, status: 'published'
      can :create, VendorApplication
      can :manage, VendorApplication, user_id: user.id
      can :read, Task, festival: { vendor_applications: { user_id: user.id, status: 'approved' } }
      can :update, User, id: user.id
    when 'volunteer'
      can :read, Festival, status: 'published'
      can :read, Task
      can :update, Task, user_id: user.id
      can :update, User, id: user.id
    when 'platform_visitor'
      can :read, Festival, status: 'published'
      can :read, Task, festival: { status: 'published' }
      can :update, User, id: user.id
    else # resident
      can :read, Festival
      can :read, Task, user_id: user.id
      can :create, Task
      can :update, Task, user_id: user.id
      can :destroy, Task, user_id: user.id
      can :update, User, id: user.id
    end

    # Special restrictions
    cannot :destroy, User unless user.system_admin?
    cannot :update, User, role: ['admin', 'system_admin'] unless user.system_admin?
  end
end
