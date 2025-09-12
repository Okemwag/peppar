defmodule LinkedinAiWeb.Admin.SubscriptionLive do
  @moduledoc """
  Admin subscription analytics LiveView for revenue reporting, churn analysis, and subscription lifecycle metrics.
  """

  use LinkedinAiWeb, :live_view

  alias LinkedinAi.{Billing, Analytics, Subscriptions}
  alias LinkedinAi.Subscriptions.Subscription

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(LinkedinAi.PubSub, "subscription_metrics")
      
      # Schedule periodic updates
      :timer.send_interval(60_000, self(), :update_metrics)
    end

    socket =
      socket
      |> assign(:page_title, "Subscription Analytics")
      |> assign(:date_range, "30_days")
      |> assign(:selected_plan, "all")
      |> assign(:selected_status, "all")
      |> load_analytics_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    {:noreply, load_analytics_data(socket)}
  end

  def handle_info({:subscription_updated, _data}, socket) do
    {:noreply, load_analytics_data(socket)}
  end

  @impl true
  def handle_event("filter_date_range", %{"date_range" => date_range}, socket) do
    socket =
      socket
      |> assign(:date_range, date_range)
      |> load_analytics_data()

    {:noreply, socket}
  end

  def handle_event("filter_plan", %{"plan" => plan}, socket) do
    socket =
      socket
      |> assign(:selected_plan, plan)
      |> load_analytics_data()

    {:noreply, socket}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:selected_status, status)
      |> load_analytics_data()

    {:noreply, socket}
  end

  def handle_event("refresh_analytics", _params, socket) do
    {:noreply, load_analytics_data(socket)}
  end

  def handle_event("export_data", %{"format" => format}, socket) do
    case format do
      "csv" ->
        csv_data = generate_csv_export(socket.assigns)
        
        socket =
          socket
          |> put_flash(:info, "CSV export generated successfully")
          |> push_event("download", %{
            filename: "subscription_analytics_#{Date.utc_today()}.csv",
            content: csv_data,
            content_type: "text/csv"
          })

        {:noreply, socket}

      "pdf" ->
        socket = put_flash(socket, :info, "PDF export feature coming soon")
        {:noreply, socket}

      _ ->
        socket = put_flash(socket, :error, "Invalid export format")
        {:noreply, socket}
    end
  end

  defp load_analytics_data(socket) do
    date_range = socket.assigns.date_range
    plan_filter = socket.assigns.selected_plan
    status_filter = socket.assigns.selected_status

    socket
    |> assign(:revenue_metrics, get_revenue_metrics(date_range))
    |> assign(:subscription_metrics, get_subscription_metrics(date_range, plan_filter, status_filter))
    |> assign(:churn_metrics, get_churn_metrics(date_range))
    |> assign(:growth_metrics, get_growth_metrics(date_range))
    |> assign(:recent_subscriptions, get_recent_subscriptions())
    |> assign(:plan_distribution, get_plan_distribution())
    |> assign(:revenue_trends, get_revenue_trends(date_range))
    |> assign(:cohort_analysis, get_cohort_analysis())
  end

  defp get_revenue_metrics(date_range) do
    period = parse_date_range(date_range)
    
    %{
      total_revenue: Billing.get_revenue_for_period(period),
      monthly_recurring_revenue: Billing.get_mrr(),
      average_revenue_per_user: Billing.get_arpu(),
      revenue_growth_rate: Billing.get_revenue_growth_rate(period),
      projected_revenue: Billing.get_projected_revenue(period)
    }
  end

  defp get_subscription_metrics(date_range, plan_filter, status_filter) do
    period = parse_date_range(date_range)
    filters = build_subscription_filters(plan_filter, status_filter)
    
    %{
      total_subscriptions: Subscriptions.count_subscriptions(filters),
      active_subscriptions: Subscriptions.count_active_subscriptions(filters),
      new_subscriptions: Subscriptions.count_new_subscriptions(period, filters),
      canceled_subscriptions: Subscriptions.count_canceled_subscriptions(period, filters),
      trial_conversions: Subscriptions.count_trial_conversions(period, filters)
    }
  end

  defp get_churn_metrics(date_range) do
    period = parse_date_range(date_range)
    
    %{
      churn_rate: Analytics.calculate_subscription_churn_rate(period),
      voluntary_churn: Subscriptions.get_voluntary_churn_rate(period),
      involuntary_churn: Subscriptions.get_involuntary_churn_rate(period),
      churn_reasons: Subscriptions.get_churn_reasons(period),
      at_risk_subscriptions: Subscriptions.count_at_risk_subscriptions()
    }
  end

  defp get_growth_metrics(date_range) do
    period = parse_date_range(date_range)
    
    %{
      net_growth_rate: Subscriptions.calculate_net_growth_rate(period),
      expansion_revenue: Billing.get_expansion_revenue(period),
      contraction_revenue: Billing.get_contraction_revenue(period),
      customer_lifetime_value: Billing.calculate_customer_ltv(),
      payback_period: Billing.calculate_payback_period()
    }
  end

  defp get_recent_subscriptions do
    Subscriptions.list_recent_subscriptions(10)
  end

  defp get_plan_distribution do
    Subscriptions.get_plan_distribution()
  end

  defp get_revenue_trends(date_range) do
    period = parse_date_range(date_range)
    Billing.get_revenue_trends(period)
  end

  defp get_cohort_analysis do
    Subscriptions.get_cohort_retention_analysis()
  end

  defp parse_date_range("7_days"), do: {Date.add(Date.utc_today(), -7), Date.utc_today()}
  defp parse_date_range("30_days"), do: {Date.add(Date.utc_today(), -30), Date.utc_today()}
  defp parse_date_range("90_days"), do: {Date.add(Date.utc_today(), -90), Date.utc_today()}
  defp parse_date_range("1_year"), do: {Date.add(Date.utc_today(), -365), Date.utc_today()}
  defp parse_date_range(_), do: {Date.add(Date.utc_today(), -30), Date.utc_today()}

  defp build_subscription_filters("all", "all"), do: %{}
  defp build_subscription_filters(plan, "all") when plan != "all", do: %{plan_type: plan}
  defp build_subscription_filters("all", status) when status != "all", do: %{status: status}
  defp build_subscription_filters(plan, status), do: %{plan_type: plan, status: status}

  defp generate_csv_export(_assigns) do
    headers = ["Date", "Plan", "Status", "Revenue", "Subscriptions", "Churn Rate"]
    
    # Generate sample data - in real implementation, this would pull actual data
    rows = [
      ["2024-01-01", "Basic", "Active", "$2,500", "100", "2.5%"],
      ["2024-01-01", "Pro", "Active", "$4,500", "100", "1.8%"],
      ["2024-01-02", "Basic", "Active", "$2,600", "104", "2.3%"],
      ["2024-01-02", "Pro", "Active", "$4,680", "104", "1.7%"]
    ]
    
    ([headers] ++ rows)
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Subscription Analytics</h1>
              <p class="mt-1 text-sm text-gray-500">
                Revenue reporting, churn analysis, and subscription metrics
              </p>
            </div>
            <div class="flex items-center space-x-4">
              <button
                phx-click="refresh_analytics"
                class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" />
                Refresh
              </button>
              <div class="relative">
                <select
                  phx-change="filter_date_range"
                  name="date_range"
                  class="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
                >
                  <option value="7_days" selected={@date_range == "7_days"}>Last 7 days</option>
                  <option value="30_days" selected={@date_range == "30_days"}>Last 30 days</option>
                  <option value="90_days" selected={@date_range == "90_days"}>Last 90 days</option>
                  <option value="1_year" selected={@date_range == "1_year"}>Last year</option>
                </select>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="px-4 sm:px-6 lg:px-8 py-8">
        <!-- Filters -->
        <div class="bg-white rounded-lg shadow mb-6">
          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Plan Type</label>
                <select
                  phx-change="filter_plan"
                  name="plan"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="all" selected={@selected_plan == "all"}>All Plans</option>
                  <option value="basic" selected={@selected_plan == "basic"}>Basic</option>
                  <option value="pro" selected={@selected_plan == "pro"}>Pro</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                <select
                  phx-change="filter_status"
                  name="status"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="all" selected={@selected_status == "all"}>All Status</option>
                  <option value="active" selected={@selected_status == "active"}>Active</option>
                  <option value="trialing" selected={@selected_status == "trialing"}>Trialing</option>
                  <option value="canceled" selected={@selected_status == "canceled"}>Canceled</option>
                </select>
              </div>
              <div class="flex items-end">
                <button
                  phx-click="export_data"
                  phx-value-format="csv"
                  class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" />
                  Export CSV
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Revenue Metrics -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <.revenue_metric_card
            title="Total Revenue"
            value={"$#{format_currency(@revenue_metrics.total_revenue)}"}
            change="+12.5%"
            trend="up"
            icon="hero-banknotes"
            color="green"
          />
          <.revenue_metric_card
            title="Monthly Recurring Revenue"
            value={"$#{format_currency(@revenue_metrics.monthly_recurring_revenue)}"}
            change="+8.3%"
            trend="up"
            icon="hero-arrow-trending-up"
            color="blue"
          />
          <.revenue_metric_card
            title="Average Revenue Per User"
            value={"$#{format_currency(@revenue_metrics.average_revenue_per_user)}"}
            change="+5.2%"
            trend="up"
            icon="hero-user-circle"
            color="purple"
          />
          <.revenue_metric_card
            title="Churn Rate"
            value={"#{@churn_metrics.churn_rate}%"}
            change="-0.8%"
            trend="down"
            icon="hero-arrow-trending-down"
            color="red"
          />
        </div>

        <!-- Charts and Analytics -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <!-- Revenue Trends Chart -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Revenue Trends</h3>
            <div class="h-64 flex items-center justify-center bg-gray-50 rounded-lg">
              <div class="text-center">
                <.icon name="hero-chart-bar" class="w-12 h-12 text-gray-400 mx-auto mb-2" />
                <p class="text-sm text-gray-500">Revenue chart visualization</p>
                <p class="text-xs text-gray-400">Integration with charting library needed</p>
              </div>
            </div>
          </div>

          <!-- Plan Distribution -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Plan Distribution</h3>
            <div class="space-y-4">
              <%= for {plan, data} <- @plan_distribution do %>
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <div class={[
                      "w-4 h-4 rounded-full mr-3",
                      case plan do
                        "basic" -> "bg-blue-500"
                        "pro" -> "bg-purple-500"
                        _ -> "bg-gray-500"
                      end
                    ]}></div>
                    <span class="text-sm font-medium text-gray-900">
                      {String.capitalize(plan)} Plan
                    </span>
                  </div>
                  <div class="text-right">
                    <div class="text-sm font-medium text-gray-900">{data.count}</div>
                    <div class="text-xs text-gray-500">{data.percentage}%</div>
                  </div>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div
                    class={[
                      "h-2 rounded-full",
                      case plan do
                        "basic" -> "bg-blue-500"
                        "pro" -> "bg-purple-500"
                        _ -> "bg-gray-500"
                      end
                    ]}
                    style={"width: #{data.percentage}%"}
                  ></div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Subscription Metrics -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-8">
          <!-- Subscription Stats -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Subscription Stats</h3>
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Total Subscriptions</span>
                <span class="text-lg font-semibold text-gray-900">
                  {@subscription_metrics.total_subscriptions}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Active Subscriptions</span>
                <span class="text-lg font-semibold text-green-600">
                  {@subscription_metrics.active_subscriptions}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">New This Period</span>
                <span class="text-lg font-semibold text-blue-600">
                  {@subscription_metrics.new_subscriptions}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Canceled This Period</span>
                <span class="text-lg font-semibold text-red-600">
                  {@subscription_metrics.canceled_subscriptions}
                </span>
              </div>
            </div>
          </div>

          <!-- Churn Analysis -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Churn Analysis</h3>
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Overall Churn Rate</span>
                <span class="text-lg font-semibold text-red-600">
                  {@churn_metrics.churn_rate}%
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Voluntary Churn</span>
                <span class="text-sm text-gray-900">{@churn_metrics.voluntary_churn}%</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Involuntary Churn</span>
                <span class="text-sm text-gray-900">{@churn_metrics.involuntary_churn}%</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">At Risk Subscriptions</span>
                <span class="text-sm font-medium text-orange-600">
                  {@churn_metrics.at_risk_subscriptions}
                </span>
              </div>
            </div>
          </div>

          <!-- Growth Metrics -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Growth Metrics</h3>
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Net Growth Rate</span>
                <span class="text-lg font-semibold text-green-600">
                  {@growth_metrics.net_growth_rate}%
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Customer LTV</span>
                <span class="text-sm text-gray-900">
                  ${format_currency(@growth_metrics.customer_lifetime_value)}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Payback Period</span>
                <span class="text-sm text-gray-900">{@growth_metrics.payback_period} months</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Trial Conversions</span>
                <span class="text-sm font-medium text-blue-600">
                  {@subscription_metrics.trial_conversions}
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Recent Subscriptions -->
        <div class="bg-white rounded-lg shadow">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Recent Subscriptions</h3>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    User
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Plan
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Revenue
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Created
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for subscription <- @recent_subscriptions do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div class="h-8 w-8 rounded-full bg-gradient-to-r from-blue-500 to-indigo-600 flex items-center justify-center">
                          <span class="text-xs font-medium text-white">
                            {String.first(subscription.user.first_name || "U")}
                          </span>
                        </div>
                        <div class="ml-3">
                          <div class="text-sm font-medium text-gray-900">
                            {subscription.user.first_name} {subscription.user.last_name}
                          </div>
                          <div class="text-sm text-gray-500">{subscription.user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
                        {String.capitalize(subscription.plan_type)}
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <.subscription_status_badge status={subscription.status} />
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      ${format_currency(subscription.amount)}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {format_date(subscription.inserted_at)}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component: Revenue Metric Card
  defp revenue_metric_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex items-center">
        <div class={[
          "flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center",
          "bg-#{@color}-100"
        ]}>
          <.icon name={@icon} class={"w-6 h-6 text-#{@color}-600"} />
        </div>
        <div class="ml-4 flex-1">
          <p class="text-sm font-medium text-gray-500">{@title}</p>
          <p class="text-2xl font-bold text-gray-900">{@value}</p>
        </div>
      </div>
      <div class="mt-4 flex items-center">
        <.icon
          name={if @trend == "up", do: "hero-arrow-trending-up", else: "hero-arrow-trending-down"}
          class={"w-4 h-4 mr-1 #{if @trend == "up", do: "text-green-500", else: "text-red-500"}"}
        />
        <span class={[
          "text-sm font-medium",
          if(@trend == "up", do: "text-green-600", else: "text-red-600")
        ]}>
          {@change}
        </span>
        <span class="text-sm text-gray-500 ml-1">vs last period</span>
      </div>
    </div>
    """
  end

  # Component: Subscription Status Badge
  defp subscription_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
      case @status do
        "active" -> "bg-green-100 text-green-800"
        "trialing" -> "bg-blue-100 text-blue-800"
        "canceled" -> "bg-red-100 text-red-800"
        "past_due" -> "bg-yellow-100 text-yellow-800"
        _ -> "bg-gray-100 text-gray-800"
      end
    ]}>
      {String.capitalize(@status)}
    </span>
    """
  end

  # Helper Functions
  defp format_currency(amount) when is_number(amount) do
    :erlang.float_to_binary(amount / 100, decimals: 2)
  end

  defp format_currency(_), do: "0.00"

  defp format_date(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
      %NaiveDateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
      _ -> "N/A"
    end
  end
end