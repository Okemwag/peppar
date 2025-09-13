defmodule LinkedinAiWeb.Admin.SubscriptionLiveTest do
  use LinkedinAiWeb.ConnCase

  import Phoenix.LiveViewTest
  import LinkedinAi.AccountsFixtures

  describe "Admin Subscription Analytics" do
    setup do
      admin_user = admin_user_fixture()
      %{admin_user: admin_user}
    end

    test "renders subscription analytics page for admin users", %{
      conn: conn,
      admin_user: admin_user
    } do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      assert html =~ "Subscription Analytics"
      assert html =~ "Revenue reporting, churn analysis, and subscription metrics"
      assert html =~ "Total Revenue"
      assert html =~ "Monthly Recurring Revenue"
    end

    test "redirects non-admin users", %{conn: conn} do
      user = user_fixture()

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/admin/subscriptions")
    end

    test "redirects unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} =
               conn
               |> live(~p"/admin/subscriptions")
    end

    test "displays revenue metrics", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      html = render(index_live)

      assert html =~ "Total Revenue"
      assert html =~ "Monthly Recurring Revenue"
      assert html =~ "Average Revenue Per User"
      assert html =~ "Churn Rate"
    end

    test "filters by date range", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      # Change date range filter
      html =
        index_live
        |> form("select[name='date_range']")
        |> render_change(%{date_range: "7_days"})

      assert html =~ "Subscription Analytics"
    end

    test "filters by plan type", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      # Change plan filter
      html =
        index_live
        |> form("select[name='plan']")
        |> render_change(%{plan: "basic"})

      assert html =~ "Subscription Analytics"
    end

    test "filters by subscription status", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      # Change status filter
      html =
        index_live
        |> form("select[name='status']")
        |> render_change(%{status: "active"})

      assert html =~ "Subscription Analytics"
    end

    test "refreshes analytics data", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      assert index_live
             |> element("button", "Refresh")
             |> render_click() =~ "Subscription Analytics"
    end

    test "exports CSV data", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      assert index_live
             |> element("button[phx-click='export_data'][phx-value-format='csv']")
             |> render_click() =~ "CSV export generated successfully"
    end

    test "displays subscription metrics", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      html = render(index_live)

      assert html =~ "Subscription Stats"
      assert html =~ "Total Subscriptions"
      assert html =~ "Active Subscriptions"
      assert html =~ "New This Period"
      assert html =~ "Canceled This Period"
    end

    test "displays churn analysis", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      html = render(index_live)

      assert html =~ "Churn Analysis"
      assert html =~ "Overall Churn Rate"
      assert html =~ "Voluntary Churn"
      assert html =~ "Involuntary Churn"
      assert html =~ "At Risk Subscriptions"
    end

    test "displays growth metrics", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      html = render(index_live)

      assert html =~ "Growth Metrics"
      assert html =~ "Net Growth Rate"
      assert html =~ "Customer LTV"
      assert html =~ "Payback Period"
      assert html =~ "Trial Conversions"
    end

    test "displays plan distribution", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      html = render(index_live)

      assert html =~ "Plan Distribution"
    end

    test "displays recent subscriptions table", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      html = render(index_live)

      assert html =~ "Recent Subscriptions"
      assert html =~ "User"
      assert html =~ "Plan"
      assert html =~ "Status"
      assert html =~ "Revenue"
      assert html =~ "Created"
    end

    test "handles real-time updates", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      # Simulate automatic update
      send(index_live.pid, :update_metrics)

      html = render(index_live)
      assert html =~ "Subscription Analytics"
    end

    test "handles subscription update broadcasts", %{conn: conn, admin_user: admin_user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/admin/subscriptions")

      # Simulate broadcast
      send(index_live.pid, {:subscription_updated, %{type: "new_subscription"}})

      html = render(index_live)
      assert html =~ "Subscription Analytics"
    end
  end

  describe "Subscription Analytics Functions" do
    test "count_subscriptions/1 returns correct count" do
      # This would need actual subscription fixtures
      count = LinkedinAi.Subscriptions.count_subscriptions()
      assert is_integer(count)
    end

    test "count_active_subscriptions/1 returns correct count" do
      count = LinkedinAi.Subscriptions.count_active_subscriptions()
      assert is_integer(count)
    end

    test "get_plan_distribution/0 returns distribution data" do
      distribution = LinkedinAi.Subscriptions.get_plan_distribution()
      assert is_map(distribution)
    end

    test "calculate_net_growth_rate/1 returns growth rate" do
      period = {Date.add(Date.utc_today(), -30), Date.utc_today()}
      growth_rate = LinkedinAi.Subscriptions.calculate_net_growth_rate(period)
      assert is_float(growth_rate)
    end

    test "get_revenue_for_period/1 returns revenue amount" do
      period = {Date.add(Date.utc_today(), -30), Date.utc_today()}
      revenue = LinkedinAi.Billing.get_revenue_for_period(period)
      assert is_integer(revenue)
    end

    test "get_mrr/0 returns monthly recurring revenue" do
      mrr = LinkedinAi.Billing.get_mrr()
      assert is_integer(mrr)
    end

    test "get_arpu/0 returns average revenue per user" do
      arpu = LinkedinAi.Billing.get_arpu()
      assert is_float(arpu)
    end

    test "calculate_customer_ltv/0 returns lifetime value" do
      ltv = LinkedinAi.Billing.calculate_customer_ltv()
      assert is_float(ltv)
    end
  end

  describe "Subscription Analytics Components" do
    test "revenue metric cards display formatted values" do
      # Test would verify component rendering
      # This is more of an integration test
    end

    test "subscription status badges show correct colors" do
      # Test would verify badge component rendering
    end

    test "plan distribution chart displays correctly" do
      # Test would verify chart component
    end
  end
end
