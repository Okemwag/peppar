defmodule LinkedinAiWeb.Admin.DashboardLive do
  @moduledoc """
  Admin dashboard LiveView showing system metrics, user growth, and platform health.
  """

  use LinkedinAiWeb, :live_view

  alias LinkedinAi.{Accounts, Analytics, Billing, ContentGeneration, ProfileOptimization}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(LinkedinAi.PubSub, "admin_metrics")

      # Schedule periodic updates
      :timer.send_interval(30_000, self(), :update_metrics)
    end

    socket =
      socket
      |> assign(:page_title, "Admin Dashboard")
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  def handle_info({:metric_updated, _data}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl true
  def handle_event("refresh_metrics", _params, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  defp load_dashboard_data(socket) do
    socket
    |> assign(:system_metrics, get_system_metrics())
    |> assign(:user_metrics, get_user_metrics())
    |> assign(:revenue_metrics, get_revenue_metrics())
    |> assign(:usage_metrics, get_usage_metrics())
    |> assign(:recent_activity, get_recent_activity())
    |> assign(:system_health, get_system_health())
  end

  defp get_system_metrics do
    %{
      total_users: Accounts.count_users(),
      active_users_today: Accounts.count_active_users_today(),
      new_users_this_week: Accounts.count_new_users_this_week(),
      admin_users: length(Accounts.list_admin_users())
    }
  end

  defp get_user_metrics do
    %{
      growth_rate: Analytics.calculate_user_growth_rate(),
      retention_rate: Analytics.calculate_retention_rate(),
      churn_rate: Analytics.calculate_churn_rate(),
      avg_session_duration: Analytics.get_average_session_duration()
    }
  end

  defp get_revenue_metrics do
    %{
      monthly_revenue: Billing.get_monthly_revenue(),
      total_revenue: Billing.get_total_revenue(),
      active_subscriptions: Billing.count_active_subscriptions(),
      conversion_rate: Billing.calculate_conversion_rate()
    }
  end

  defp get_usage_metrics do
    %{
      content_generated_today: ContentGeneration.count_content_generated_today(),
      profiles_analyzed_today: ProfileOptimization.count_profiles_analyzed_today(),
      api_calls_today: Analytics.count_api_calls_today(),
      avg_response_time: Analytics.get_average_response_time()
    }
  end

  defp get_recent_activity do
    [
      recent_users: Accounts.list_recent_users(5),
      recent_content: ContentGeneration.list_recent_content(5),
      recent_analyses: ProfileOptimization.list_recent_analyses(5),
      recent_subscriptions: Billing.list_recent_subscriptions(5)
    ]
  end

  defp get_system_health do
    %{
      database_status: check_database_health(),
      redis_status: check_redis_health(),
      openai_status: check_openai_health(),
      stripe_status: check_stripe_health(),
      linkedin_status: check_linkedin_health()
    }
  end

  defp check_database_health do
    try do
      LinkedinAi.Repo.query!("SELECT 1")
      :healthy
    rescue
      _ -> :unhealthy
    end
  end

  defp check_redis_health do
    # Placeholder - implement based on your Redis setup
    :healthy
  end

  defp check_openai_health do
    case LinkedinAi.AI.OpenAIClient.health_check() do
      {:ok, :healthy} -> :healthy
      _ -> :unhealthy
    end
  end

  defp check_stripe_health do
    case LinkedinAi.Billing.StripeClient.health_check() do
      {:ok, :healthy} -> :healthy
      _ -> :unhealthy
    end
  end

  defp check_linkedin_health do
    case LinkedinAi.Social.LinkedInClient.health_check() do
      {:ok, :healthy} -> :healthy
      _ -> :unhealthy
    end
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
              <h1 class="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
              <p class="mt-1 text-sm text-gray-500">
                System overview and platform metrics
              </p>
            </div>
            <button
              phx-click="refresh_metrics"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Refresh
            </button>
          </div>
        </div>
      </div>

      <div class="px-4 sm:px-6 lg:px-8 py-8">
        <!-- System Health Status -->
        <div class="mb-8">
          <h2 class="text-lg font-medium text-gray-900 mb-4">System Health</h2>
          <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
            <.health_indicator
              name="Database"
              status={@system_health.database_status}
              icon="hero-circle-stack"
            />
            <.health_indicator name="Redis" status={@system_health.redis_status} icon="hero-bolt" />
            <.health_indicator
              name="OpenAI"
              status={@system_health.openai_status}
              icon="hero-cpu-chip"
            />
            <.health_indicator
              name="Stripe"
              status={@system_health.stripe_status}
              icon="hero-credit-card"
            />
            <.health_indicator
              name="LinkedIn"
              status={@system_health.linkedin_status}
              icon="hero-link"
            />
          </div>
        </div>
        
    <!-- Key Metrics Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <.metric_card
            title="Total Users"
            value={@system_metrics.total_users}
            change="+12%"
            trend="up"
            icon="hero-users"
            color="blue"
          />
          <.metric_card
            title="Active Today"
            value={@system_metrics.active_users_today}
            change="+5%"
            trend="up"
            icon="hero-user-circle"
            color="green"
          />
          <.metric_card
            title="Monthly Revenue"
            value={"$#{format_currency(@revenue_metrics.monthly_revenue)}"}
            change="+18%"
            trend="up"
            icon="hero-banknotes"
            color="emerald"
          />
          <.metric_card
            title="Active Subscriptions"
            value={@revenue_metrics.active_subscriptions}
            change="+8%"
            trend="up"
            icon="hero-credit-card"
            color="purple"
          />
        </div>
        
    <!-- Charts and Analytics -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <!-- User Growth Chart -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">User Growth</h3>
            <div class="space-y-4">
              <.progress_metric
                label="Growth Rate"
                value={@user_metrics.growth_rate}
                max={100}
                color="blue"
              />
              <.progress_metric
                label="Retention Rate"
                value={@user_metrics.retention_rate}
                max={100}
                color="green"
              />
              <.progress_metric
                label="Churn Rate"
                value={@user_metrics.churn_rate}
                max={100}
                color="red"
              />
            </div>
          </div>
          
    <!-- Usage Statistics -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Today's Usage</h3>
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-gray-500">Content Generated</span>
                <span class="text-2xl font-bold text-blue-600">
                  {@usage_metrics.content_generated_today}
                </span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-gray-500">Profiles Analyzed</span>
                <span class="text-2xl font-bold text-green-600">
                  {@usage_metrics.profiles_analyzed_today}
                </span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-gray-500">API Calls</span>
                <span class="text-2xl font-bold text-purple-600">
                  {@usage_metrics.api_calls_today}
                </span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-gray-500">Avg Response Time</span>
                <span class="text-2xl font-bold text-orange-600">
                  {@usage_metrics.avg_response_time}ms
                </span>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Recent Activity -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Recent Users -->
          <div class="bg-white rounded-lg shadow">
            <div class="px-6 py-4 border-b border-gray-200">
              <h3 class="text-lg font-medium text-gray-900">Recent Users</h3>
            </div>
            <div class="divide-y divide-gray-200">
              <%= for user <- @recent_activity[:recent_users] do %>
                <div class="px-6 py-4 flex items-center justify-between">
                  <div class="flex items-center">
                    <div class="h-8 w-8 rounded-full bg-gradient-to-r from-blue-500 to-indigo-600 flex items-center justify-center">
                      <span class="text-sm font-medium text-white">
                        {String.first(user.first_name || "U")}
                      </span>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm font-medium text-gray-900">
                        {user.first_name} {user.last_name}
                      </p>
                      <p class="text-sm text-gray-500">{user.email}</p>
                    </div>
                  </div>
                  <div class="text-sm text-gray-500">
                    {format_relative_time(user.inserted_at)}
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Quick Actions -->
          <div class="bg-white rounded-lg shadow">
            <div class="px-6 py-4 border-b border-gray-200">
              <h3 class="text-lg font-medium text-gray-900">Quick Actions</h3>
            </div>
            <div class="p-6 space-y-4">
              <.link
                navigate="/admin/users"
                class="w-full flex items-center justify-center px-4 py-2 border border-gray-300 rounded-md shadow-sm bg-white text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                <.icon name="hero-users" class="w-4 h-4 mr-2" /> Manage Users
              </.link>
              <.link
                navigate="/admin/subscriptions"
                class="w-full flex items-center justify-center px-4 py-2 border border-gray-300 rounded-md shadow-sm bg-white text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                <.icon name="hero-credit-card" class="w-4 h-4 mr-2" /> View Subscriptions
              </.link>
              <.link
                navigate="/admin/analytics"
                class="w-full flex items-center justify-center px-4 py-2 border border-gray-300 rounded-md shadow-sm bg-white text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                <.icon name="hero-chart-pie" class="w-4 h-4 mr-2" /> Platform Analytics
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component: Health Indicator
  defp health_indicator(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-4">
      <div class="flex items-center">
        <div class={[
          "flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center",
          if(@status == :healthy, do: "bg-green-100", else: "bg-red-100")
        ]}>
          <.icon
            name={@icon}
            class={"w-4 h-4 #{if @status == :healthy, do: "text-green-600", else: "text-red-600"}"}
          />
        </div>
        <div class="ml-3">
          <p class="text-sm font-medium text-gray-900">{@name}</p>
          <p class={[
            "text-xs",
            if(@status == :healthy, do: "text-green-600", else: "text-red-600")
          ]}>
            {if @status == :healthy, do: "Healthy", else: "Unhealthy"}
          </p>
        </div>
      </div>
    </div>
    """
  end

  # Component: Metric Card
  defp metric_card(assigns) do
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
        <span class="text-sm text-gray-500 ml-1">vs last month</span>
      </div>
    </div>
    """
  end

  # Component: Progress Metric
  defp progress_metric(assigns) do
    ~H"""
    <div>
      <div class="flex justify-between text-sm font-medium text-gray-900 mb-1">
        <span>{@label}</span>
        <span>{@value}%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div class={"h-2 rounded-full bg-#{@color}-600"} style={"width: #{@value}%"}></div>
      </div>
    </div>
    """
  end

  # Helper Functions
  defp format_currency(amount) when is_number(amount) do
    :erlang.float_to_binary(amount / 100, decimals: 2)
  end

  defp format_currency(_), do: "0.00"

  defp format_relative_time(datetime) do
    try do
      Timex.from_now(datetime)
    rescue
      _ -> "recently"
    end
  end
end
