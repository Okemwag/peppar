defmodule LinkedinAiWeb.Admin.DashboardLiveTest do
  use LinkedinAiWeb.ConnCase

  import Phoenix.LiveViewTest
  import LinkedinAi.AccountsFixtures

  describe "Admin Dashboard" do
    setup do
      admin_user = admin_user_fixture()
      %{admin_user: admin_user}
    end

    test "renders admin dashboard for admin users", %{conn: conn, admin_user: admin_user} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      assert html =~ "Admin Dashboard"
      assert html =~ "System Health"
      assert html =~ "Total Users"
      assert html =~ "Monthly Revenue"
    end

    test "redirects non-admin users", %{conn: conn} do
      user = user_fixture()

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/admin")
    end

    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} =
               conn
               |> live(~p"/admin")
    end

    test "displays system health indicators", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      html = render(index_live)
      
      assert html =~ "Database"
      assert html =~ "OpenAI"
      assert html =~ "Stripe"
      assert html =~ "LinkedIn"
    end

    test "displays key metrics", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      html = render(index_live)
      
      assert html =~ "Total Users"
      assert html =~ "Active Today"
      assert html =~ "Monthly Revenue"
      assert html =~ "Active Subscriptions"
    end

    test "handles refresh metrics event", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      assert index_live
             |> element("button", "Refresh")
             |> render_click() =~ "Admin Dashboard"
    end

    test "displays quick action links", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      html = render(index_live)
      
      assert html =~ "Manage Users"
      assert html =~ "View Subscriptions"
      assert html =~ "Platform Analytics"
    end

    test "updates metrics automatically", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      # Simulate automatic update
      send(index_live.pid, :update_metrics)
      
      html = render(index_live)
      assert html =~ "Admin Dashboard"
    end

    test "handles metric update broadcasts", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      # Simulate broadcast
      send(index_live.pid, {:metric_updated, %{type: "user_count"}})
      
      html = render(index_live)
      assert html =~ "Admin Dashboard"
    end
  end

  describe "Admin Dashboard Components" do
    setup do
      admin_user = admin_user_fixture()
      %{admin_user: admin_user}
    end

    test "health indicator shows healthy status", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      html = render(index_live)
      
      # Should show healthy indicators (mocked as healthy in tests)
      assert html =~ "Healthy"
    end

    test "metric cards display formatted values", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin")

      html = render(index_live)
      
      # Should display metric values
      assert html =~ "vs last month"
    end
  end
end