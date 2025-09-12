defmodule LinkedinAiWeb.Plugs.RequireAdminTest do
  use LinkedinAiWeb.ConnCase, async: true

  alias LinkedinAi.AccountsFixtures
  alias LinkedinAiWeb.Plugs.RequireAdmin

  describe "RequireAdmin plug" do
    test "allows admin users to proceed", %{conn: conn} do
      admin_user = AccountsFixtures.admin_user_fixture()
      
      conn =
        conn
        |> assign(:current_user, admin_user)
        |> RequireAdmin.call([])

      refute conn.halted
    end

    test "redirects regular users to dashboard with error", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      
      conn =
        conn
        |> assign(:current_user, user)
        |> RequireAdmin.call([])

      assert conn.halted
      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Access denied. Admin privileges required."
    end

    test "redirects unauthenticated users to login", %{conn: conn} do
      conn = RequireAdmin.call(conn, [])

      assert conn.halted
      assert redirected_to(conn) == "/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Please log in to access this area."
    end

    test "redirects suspended admin users to dashboard", %{conn: conn} do
      admin_user = AccountsFixtures.admin_user_fixture(%{account_status: "suspended"})
      
      conn =
        conn
        |> assign(:current_user, admin_user)
        |> RequireAdmin.call([])

      assert conn.halted
      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Account suspended. Please contact support."
    end
  end
end