defmodule LinkedinAi.AccountsAdminTest do
  use LinkedinAi.DataCase

  alias LinkedinAi.Accounts
  alias LinkedinAi.AccountsFixtures

  describe "admin authorization helpers" do
    test "admin?/1 returns true for admin users" do
      admin_user = AccountsFixtures.admin_user_fixture()
      assert Accounts.admin?(admin_user)
    end

    test "admin?/1 returns false for regular users" do
      user = AccountsFixtures.user_fixture()
      refute Accounts.admin?(user)
    end

    test "admin?/1 returns false for nil" do
      refute Accounts.admin?(nil)
    end

    test "can_access_admin?/1 returns true for active admin users" do
      admin_user = AccountsFixtures.admin_user_fixture(%{account_status: "active"})
      assert Accounts.can_access_admin?(admin_user)
    end

    test "can_access_admin?/1 returns false for suspended admin users" do
      admin_user = AccountsFixtures.admin_user_fixture(%{account_status: "suspended"})
      refute Accounts.can_access_admin?(admin_user)
    end

    test "can_access_admin?/1 returns false for regular users" do
      user = AccountsFixtures.user_fixture()
      refute Accounts.can_access_admin?(user)
    end

    test "list_admin_users/0 returns only active admin users" do
      admin1 = AccountsFixtures.admin_user_fixture(%{email: "admin1@test.com"})
      admin2 = AccountsFixtures.admin_user_fixture(%{email: "admin2@test.com"})
      _suspended_admin = AccountsFixtures.admin_user_fixture(%{
        email: "suspended@test.com", 
        account_status: "suspended"
      })
      _regular_user = AccountsFixtures.user_fixture()

      admin_users = Accounts.list_admin_users()
      admin_emails = Enum.map(admin_users, & &1.email)

      assert length(admin_users) == 2
      assert admin1.email in admin_emails
      assert admin2.email in admin_emails
    end
  end

  describe "admin user management" do
    test "promote_to_admin/1 successfully promotes a user" do
      user = AccountsFixtures.user_fixture()
      refute Accounts.admin?(user)

      {:ok, admin_user} = Accounts.promote_to_admin(user)

      assert admin_user.role == "admin"
      assert Accounts.admin?(admin_user)
    end

    test "suspend_user/1 suspends a user account" do
      user = AccountsFixtures.user_fixture()
      
      {:ok, suspended_user} = Accounts.suspend_user(user)
      
      assert suspended_user.account_status == "suspended"
    end

    test "activate_user/1 activates a suspended user" do
      user = AccountsFixtures.user_fixture(%{account_status: "suspended"})
      
      {:ok, active_user} = Accounts.activate_user(user)
      
      assert active_user.account_status == "active"
    end
  end

  describe "admin permissions" do
    test "can?/2 allows admin users to manage users" do
      admin_user = AccountsFixtures.admin_user_fixture()
      
      assert Accounts.can?(admin_user, :manage_users)
      assert Accounts.can?(admin_user, :view_admin_panel)
      assert Accounts.can?(admin_user, :manage_subscriptions)
      assert Accounts.can?(admin_user, :view_analytics)
    end

    test "can?/2 denies regular users admin actions" do
      user = AccountsFixtures.user_fixture()
      
      refute Accounts.can?(user, :manage_users)
      refute Accounts.can?(user, :view_admin_panel)
      refute Accounts.can?(user, :manage_subscriptions)
      refute Accounts.can?(user, :view_analytics)
    end

    test "can?/2 allows active users to use platform features" do
      user = AccountsFixtures.user_fixture()
      
      assert Accounts.can?(user, :generate_content)
      assert Accounts.can?(user, :analyze_profile)
    end

    test "can?/2 returns false for unknown actions" do
      admin_user = AccountsFixtures.admin_user_fixture()
      user = AccountsFixtures.user_fixture()
      
      refute Accounts.can?(admin_user, :unknown_action)
      refute Accounts.can?(user, :unknown_action)
    end
  end
end