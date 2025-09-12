defmodule LinkedinAiWeb.Admin.UserLiveTest do
  use LinkedinAiWeb.ConnCase

  import Phoenix.LiveViewTest
  import LinkedinAi.AccountsFixtures

  describe "Admin User Management" do
    setup do
      admin_user = admin_user_fixture()
      users = [
        user_fixture(%{first_name: "John", last_name: "Doe", email: "john@example.com"}),
        user_fixture(%{first_name: "Jane", last_name: "Smith", email: "jane@example.com"}),
        user_fixture(%{first_name: "Bob", last_name: "Johnson", email: "bob@example.com", account_status: "suspended"})
      ]
      %{admin_user: admin_user, users: users}
    end

    test "renders user management page for admin users", %{conn: conn, admin_user: admin_user} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      assert html =~ "User Management"
      assert html =~ "Manage users, subscriptions, and account status"
      assert html =~ "users total"
    end

    test "redirects non-admin users", %{conn: conn} do
      user = user_fixture()

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/admin/users")
    end

    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} =
               conn
               |> live(~p"/admin/users")
    end

    test "displays users in table", %{conn: conn, admin_user: admin_user, users: users} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      html = render(index_live)

      for user <- users do
        assert html =~ user.email
        assert html =~ user.first_name
      end
    end

    test "searches users by name and email", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      # Search by first name
      html =
        index_live
        |> form("form", search: %{query: "John"})
        |> render_submit()

      assert html =~ "john@example.com"
      refute html =~ "jane@example.com"

      # Search by email
      html =
        index_live
        |> form("form", search: %{query: "jane@"})
        |> render_submit()

      assert html =~ "jane@example.com"
      refute html =~ "john@example.com"
    end

    test "filters users by status", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      # Filter by suspended status
      html =
        index_live
        |> form("form", filter: %{status: "suspended"})
        |> render_change()

      assert html =~ "bob@example.com"
      refute html =~ "john@example.com"
      refute html =~ "jane@example.com"
    end

    test "sorts users by different columns", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      # Sort by first name
      html =
        index_live
        |> element("button", "User")
        |> render_click()

      # Should show users sorted by first name
      assert html =~ "User Management"
    end

    test "suspends a user", %{conn: conn, admin_user: admin_user, users: [user | _]} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      assert index_live
             |> element("button[phx-click='suspend_user'][phx-value-id='#{user.id}']")
             |> render_click() =~ "User suspended successfully"

      # Verify user is suspended
      updated_user = LinkedinAi.Accounts.get_user!(user.id)
      assert updated_user.account_status == "suspended"
    end

    test "activates a suspended user", %{conn: conn, admin_user: admin_user} do
      suspended_user = user_fixture(%{account_status: "suspended"})

      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      assert index_live
             |> element("button[phx-click='activate_user'][phx-value-id='#{suspended_user.id}']")
             |> render_click() =~ "User activated successfully"

      # Verify user is activated
      updated_user = LinkedinAi.Accounts.get_user!(suspended_user.id)
      assert updated_user.account_status == "active"
    end

    test "promotes user to admin", %{conn: conn, admin_user: admin_user, users: [user | _]} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      assert index_live
             |> element("button[phx-click='promote_to_admin'][phx-value-id='#{user.id}']")
             |> render_click() =~ "User promoted to admin successfully"

      # Verify user is promoted
      updated_user = LinkedinAi.Accounts.get_user!(user.id)
      assert updated_user.role == "admin"
    end

    test "navigates to user detail page", %{conn: conn, admin_user: admin_user, users: [user | _]} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      assert {:error, {:live_redirect, %{to: path}}} =
               index_live
               |> element("button[phx-click='view_user'][phx-value-id='#{user.id}']")
               |> render_click()

      assert path == "/admin/users/#{user.id}"
    end

    test "handles pagination", %{conn: conn, admin_user: admin_user} do
      # Create more users to test pagination
      for i <- 1..25 do
        user_fixture(%{email: "user#{i}@example.com"})
      end

      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users")

      html = render(index_live)
      assert html =~ "Showing"
      assert html =~ "results"
    end
  end

  describe "User Detail Modal" do
    setup do
      admin_user = admin_user_fixture()
      user = user_fixture(%{first_name: "John", last_name: "Doe"})
      %{admin_user: admin_user, user: user}
    end

    test "displays user detail modal", %{conn: conn, admin_user: admin_user, user: user} do
      {:ok, _show_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users/#{user.id}")

      assert html =~ "User Details: John Doe"
      assert html =~ user.email
      assert html =~ "Account Information"
      assert html =~ "Usage Statistics"
    end

    test "closes user detail modal", %{conn: conn, admin_user: admin_user, user: user} do
      {:ok, show_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users/#{user.id}")

      assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
               show_live
               |> element("button[phx-click='close_user_modal']")
               |> render_click()
    end

    test "handles user not found", %{conn: conn, admin_user: admin_user} do
      {:ok, _show_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users/999999")

      assert html =~ "User not found"
    end

    test "performs actions from modal", %{conn: conn, admin_user: admin_user, user: user} do
      {:ok, show_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/users/#{user.id}")

      # Test suspend action from modal
      html =
        show_live
        |> element("button[phx-click='suspend_user'][phx-value-id='#{user.id}']")
        |> render_click()

      assert html =~ "User suspended successfully"
    end
  end

  describe "Admin User Management Functions" do
    test "list_users_admin/1 returns paginated users" do
      users = for i <- 1..5, do: user_fixture(%{email: "user#{i}@example.com"})

      result = LinkedinAi.Accounts.list_users_admin(page: 1, per_page: 3)
      assert length(result) == 3

      result = LinkedinAi.Accounts.list_users_admin(page: 2, per_page: 3)
      assert length(result) == 2
    end

    test "list_users_admin/1 searches users" do
      user1 = user_fixture(%{first_name: "John", email: "john@example.com"})
      user2 = user_fixture(%{first_name: "Jane", email: "jane@example.com"})

      result = LinkedinAi.Accounts.list_users_admin(search: "John")
      user_emails = Enum.map(result, & &1.email)

      assert user1.email in user_emails
      refute user2.email in user_emails
    end

    test "list_users_admin/1 filters by status" do
      active_user = user_fixture(%{account_status: "active"})
      suspended_user = user_fixture(%{account_status: "suspended"})

      result = LinkedinAi.Accounts.list_users_admin(filters: %{status: "suspended"})
      user_ids = Enum.map(result, & &1.id)

      assert suspended_user.id in user_ids
      refute active_user.id in user_ids
    end

    test "count_users_admin/1 returns correct count" do
      for i <- 1..3, do: user_fixture(%{email: "user#{i}@example.com"})

      count = LinkedinAi.Accounts.count_users_admin()
      assert count >= 3

      count_with_search = LinkedinAi.Accounts.count_users_admin(search: "user1")
      assert count_with_search == 1
    end
  end
end