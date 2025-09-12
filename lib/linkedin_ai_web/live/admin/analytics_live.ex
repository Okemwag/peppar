defmodule LinkedinAiWeb.Admin.AnalyticsLive do
  @moduledoc """
  Admin platform analytics LiveView for comprehensive platform performance metrics.
  """

  use LinkedinAiWeb, :live_view

  import Ecto.Query, warn: false
  alias LinkedinAi.{Analytics, Accounts, ContentGeneration, ProfileOptimization, Repo}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(LinkedinAi.PubSub, "platform_analytics")
      
      # Schedule periodic updates
      :timer.send_interval(120_000, self(), :update_analytics)
    end

    socket =
      socket
      |> assign(:page_title, "Platform Analytics")
      |> assign(:date_range, "30_days")
      |> assign(:metric_type, "all")
      |> load_platform_analytics()

    {:ok, socket}
  end

  @impl true
  def handle_info(:update_analytics, socket) do
    {:noreply, load_platform_analytics(socket)}
  end

  def handle_info({:analytics_updated, _data}, socket) do
    {:noreply, load_platform_analytics(socket)}
  end

  @impl true
  def handle_event("filter_date_range", %{"date_range" => date_range}, socket) do
    socket =
      socket
      |> assign(:date_range, date_range)
      |> load_platform_analytics()

    {:noreply, socket}
  end

  def handle_event("filter_metric_type", %{"metric_type" => metric_type}, socket) do
    socket =
      socket
      |> assign(:metric_type, metric_type)
      |> load_platform_analytics()

    {:noreply, socket}
  end

  def handle_event("refresh_analytics", _params, socket) do
    {:noreply, load_platform_analytics(socket)}
  end

  def handle_event("export_report", %{"format" => format}, socket) do
    case format do
      "pdf" ->
        socket = put_flash(socket, :info, "PDF report generation started")
        {:noreply, socket}

      "csv" ->
        csv_data = generate_analytics_csv(socket.assigns)
        
        socket =
          socket
          |> put_flash(:info, "CSV report generated successfully")
          |> push_event("download", %{
            filename: "platform_analytics_#{Date.utc_today()}.csv",
            content: csv_data,
            content_type: "text/csv"
          })

        {:noreply, socket}

      _ ->
        socket = put_flash(socket, :error, "Invalid export format")
        {:noreply, socket}
    end
  end

  defp load_platform_analytics(socket) do
    date_range = socket.assigns.date_range
    _metric_type = socket.assigns.metric_type

    socket
    |> assign(:platform_overview, get_platform_overview(date_range))
    |> assign(:user_analytics, get_user_analytics_summary(date_range))
    |> assign(:content_analytics, get_content_analytics_summary(date_range))
    |> assign(:engagement_metrics, get_engagement_metrics(date_range))
    |> assign(:performance_metrics, get_performance_metrics(date_range))
    |> assign(:geographic_data, get_geographic_distribution())
    |> assign(:feature_usage, get_feature_usage_stats(date_range))
    |> assign(:growth_trends, get_growth_trends(date_range))
  end

  defp get_platform_overview(date_range) do
    period = parse_date_range(date_range)
    
    %{
      total_users: Accounts.count_users(),
      active_users: get_active_users_count(period),
      total_content: ContentGeneration.count_total_content(),
      total_analyses: ProfileOptimization.count_total_analyses(),
      platform_uptime: get_platform_uptime(),
      api_requests: Analytics.count_api_calls_for_period(period)
    }
  end

  defp get_user_analytics_summary(date_range) do
    period = parse_date_range(date_range)
    
    %{
      new_registrations: Accounts.count_new_users_for_period(period),
      user_retention_rate: Analytics.calculate_retention_rate(),
      daily_active_users: get_daily_active_users(period),
      user_engagement_score: calculate_user_engagement_score(),
      top_user_segments: get_top_user_segments()
    }
  end

  defp get_content_analytics_summary(date_range) do
    period = parse_date_range(date_range)
    
    %{
      content_generated: ContentGeneration.count_content_for_period(period),
      content_published: ContentGeneration.count_published_content(period),
      avg_content_quality: ContentGeneration.get_average_quality_score(),
      popular_content_types: ContentGeneration.get_popular_content_types(period),
      content_engagement: ContentGeneration.get_content_engagement_stats(period)
    }
  end

  defp get_engagement_metrics(date_range) do
    period = parse_date_range(date_range)
    
    %{
      session_duration: Analytics.get_average_session_duration(),
      page_views: get_total_page_views(period),
      bounce_rate: get_bounce_rate(period),
      feature_adoption: get_feature_adoption_rates(),
      user_satisfaction: get_user_satisfaction_score()
    }
  end

  defp get_performance_metrics(date_range) do
    period = parse_date_range(date_range)
    
    %{
      api_response_time: Analytics.get_average_response_time(),
      error_rate: get_error_rate(period),
      system_load: get_system_load_average(),
      database_performance: get_database_performance(),
      cache_hit_rate: get_cache_hit_rate()
    }
  end

  defp get_geographic_distribution do
    # Sample geographic data - would come from user analytics
    %{
      "United States" => %{users: 1250, percentage: 45.2},
      "United Kingdom" => %{users: 680, percentage: 24.6},
      "Canada" => %{users: 420, percentage: 15.2},
      "Australia" => %{users: 280, percentage: 10.1},
      "Germany" => %{users: 135, percentage: 4.9}
    }
  end

  defp get_feature_usage_stats(date_range) do
    period = parse_date_range(date_range)
    
    %{
      content_generation: ContentGeneration.get_usage_stats(period),
      profile_optimization: ProfileOptimization.get_usage_stats(period),
      linkedin_integration: get_linkedin_usage_stats(period),
      subscription_management: get_subscription_usage_stats(period)
    }
  end

  defp get_growth_trends(date_range) do
    period = parse_date_range(date_range)
    
    %{
      user_growth: Analytics.calculate_user_growth_rate(),
      revenue_growth: get_revenue_growth_rate(period),
      engagement_growth: get_engagement_growth_rate(period),
      feature_adoption_growth: get_feature_adoption_growth(period)
    }
  end

  # Helper functions with placeholder implementations
  defp parse_date_range("7_days"), do: {Date.add(Date.utc_today(), -7), Date.utc_today()}
  defp parse_date_range("30_days"), do: {Date.add(Date.utc_today(), -30), Date.utc_today()}
  defp parse_date_range("90_days"), do: {Date.add(Date.utc_today(), -90), Date.utc_today()}
  defp parse_date_range("1_year"), do: {Date.add(Date.utc_today(), -365), Date.utc_today()}
  defp parse_date_range(_), do: {Date.add(Date.utc_today(), -30), Date.utc_today()}

  defp get_active_users_count({_start_date, _end_date}) do
    from(u in LinkedinAi.Accounts.User,
      where: fragment("DATE(?)", u.last_login_at) >= fragment("DATE(?)", ^Date.add(Date.utc_today(), -30)) and
             fragment("DATE(?)", u.last_login_at) <= fragment("DATE(?)", ^Date.utc_today()),
      select: count(u.id)
    )
    |> Repo.one()
  end

  defp get_platform_uptime, do: 99.8
  defp get_daily_active_users(_period), do: 450
  defp calculate_user_engagement_score, do: 7.8
  defp get_top_user_segments, do: ["Content Creators", "LinkedIn Professionals", "Marketing Teams"]
  defp get_total_page_views(_period), do: 125_000
  defp get_bounce_rate(_period), do: 23.5
  defp get_feature_adoption_rates, do: %{content_gen: 78.5, profile_opt: 65.2, linkedin_sync: 45.8}
  defp get_user_satisfaction_score, do: 4.2
  defp get_error_rate(_period), do: 0.8
  defp get_system_load_average, do: 2.1
  defp get_database_performance, do: %{avg_query_time: 45, slow_queries: 12}
  defp get_cache_hit_rate, do: 94.2
  defp get_linkedin_usage_stats(_period), do: %{connections: 1250, posts: 890, analyses: 670}
  defp get_subscription_usage_stats(_period), do: %{upgrades: 45, downgrades: 12, cancellations: 23}
  defp get_revenue_growth_rate(_period), do: 15.8
  defp get_engagement_growth_rate(_period), do: 12.3
  defp get_feature_adoption_growth(_period), do: 8.7

  defp generate_analytics_csv(assigns) do
    headers = ["Metric", "Value", "Period", "Change"]
    
    rows = [
      ["Total Users", "#{assigns.platform_overview.total_users}", assigns.date_range, "+12%"],
      ["Active Users", "#{assigns.platform_overview.active_users}", assigns.date_range, "+8%"],
      ["Content Generated", "#{assigns.platform_overview.total_content}", assigns.date_range, "+25%"],
      ["Profile Analyses", "#{assigns.platform_overview.total_analyses}", assigns.date_range, "+18%"]
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
              <h1 class="text-2xl font-bold text-gray-900">Platform Analytics</h1>
              <p class="mt-1 text-sm text-gray-500">
                Comprehensive platform performance and usage metrics
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
              <button
                phx-click="export_report"
                phx-value-format="csv"
                class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" />
                Export
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="px-4 sm:px-6 lg:px-8 py-8">
        <!-- Platform Overview -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <.overview_metric_card
            title="Total Users"
            value={@platform_overview.total_users}
            icon="hero-users"
            color="blue"
            change="+12%"
          />
          <.overview_metric_card
            title="Active Users"
            value={@platform_overview.active_users}
            icon="hero-user-circle"
            color="green"
            change="+8%"
          />
          <.overview_metric_card
            title="Content Generated"
            value={@platform_overview.total_content}
            icon="hero-document-text"
            color="purple"
            change="+25%"
          />
          <.overview_metric_card
            title="Platform Uptime"
            value={"#{@platform_overview.platform_uptime}%"}
            icon="hero-signal"
            color="emerald"
            change="+0.2%"
          />
        </div>

        <!-- Analytics Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <!-- User Analytics -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">User Analytics</h3>
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">New Registrations</span>
                <span class="text-lg font-semibold text-blue-600">
                  {@user_analytics.new_registrations}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Retention Rate</span>
                <span class="text-lg font-semibold text-green-600">
                  {@user_analytics.user_retention_rate}%
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Daily Active Users</span>
                <span class="text-lg font-semibold text-purple-600">
                  {@user_analytics.daily_active_users}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Engagement Score</span>
                <span class="text-lg font-semibold text-orange-600">
                  {@user_analytics.user_engagement_score}/10
                </span>
              </div>
            </div>
          </div>

          <!-- Content Analytics -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Content Analytics</h3>
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Content Generated</span>
                <span class="text-lg font-semibold text-blue-600">
                  {@content_analytics.content_generated}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Content Published</span>
                <span class="text-lg font-semibold text-green-600">
                  {@content_analytics.content_published}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Avg Quality Score</span>
                <span class="text-lg font-semibold text-purple-600">
                  {@content_analytics.avg_content_quality}/10
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Engagement Rate</span>
                <span class="text-lg font-semibold text-orange-600">
                  {@content_analytics.content_engagement}%
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Performance & Geographic -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <!-- Performance Metrics -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Performance Metrics</h3>
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">API Response Time</span>
                <span class="text-sm text-gray-900">{@performance_metrics.api_response_time}ms</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Error Rate</span>
                <span class="text-sm text-gray-900">{@performance_metrics.error_rate}%</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">System Load</span>
                <span class="text-sm text-gray-900">{@performance_metrics.system_load}</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Cache Hit Rate</span>
                <span class="text-sm text-gray-900">{@performance_metrics.cache_hit_rate}%</span>
              </div>
            </div>
          </div>

          <!-- Geographic Distribution -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Geographic Distribution</h3>
            <div class="space-y-3">
              <%= for {country, data} <- @geographic_data do %>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-gray-900">{country}</span>
                  <div class="flex items-center space-x-2">
                    <span class="text-sm text-gray-500">{data.users}</span>
                    <div class="w-16 bg-gray-200 rounded-full h-2">
                      <div
                        class="h-2 bg-blue-600 rounded-full"
                        style={"width: #{data.percentage}%"}
                      ></div>
                    </div>
                    <span class="text-xs text-gray-400 w-8">{data.percentage}%</span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Feature Usage & Growth Trends -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <!-- Feature Usage -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Feature Usage</h3>
            <div class="space-y-4">
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="text-gray-600">Content Generation</span>
                  <span class="text-gray-900">{@feature_usage.content_generation.usage_count}</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div class="h-2 bg-blue-600 rounded-full" style="width: 78%"></div>
                </div>
              </div>
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="text-gray-600">Profile Optimization</span>
                  <span class="text-gray-900">{@feature_usage.profile_optimization.usage_count}</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div class="h-2 bg-green-600 rounded-full" style="width: 65%"></div>
                </div>
              </div>
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="text-gray-600">LinkedIn Integration</span>
                  <span class="text-gray-900">{@feature_usage.linkedin_integration.connections}</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div class="h-2 bg-purple-600 rounded-full" style="width: 46%"></div>
                </div>
              </div>
            </div>
          </div>

          <!-- Growth Trends -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Growth Trends</h3>
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">User Growth</span>
                <div class="flex items-center">
                  <.icon name="hero-arrow-trending-up" class="w-4 h-4 text-green-500 mr-1" />
                  <span class="text-sm font-medium text-green-600">{@growth_trends.user_growth}%</span>
                </div>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Revenue Growth</span>
                <div class="flex items-center">
                  <.icon name="hero-arrow-trending-up" class="w-4 h-4 text-green-500 mr-1" />
                  <span class="text-sm font-medium text-green-600">{@growth_trends.revenue_growth}%</span>
                </div>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Engagement Growth</span>
                <div class="flex items-center">
                  <.icon name="hero-arrow-trending-up" class="w-4 h-4 text-green-500 mr-1" />
                  <span class="text-sm font-medium text-green-600">{@growth_trends.engagement_growth}%</span>
                </div>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500">Feature Adoption</span>
                <div class="flex items-center">
                  <.icon name="hero-arrow-trending-up" class="w-4 h-4 text-green-500 mr-1" />
                  <span class="text-sm font-medium text-green-600">{@growth_trends.feature_adoption_growth}%</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Engagement Metrics -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Engagement Metrics</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6">
            <div class="text-center">
              <div class="text-2xl font-bold text-blue-600">{@engagement_metrics.session_duration}</div>
              <div class="text-sm text-gray-500">Avg Session (min)</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-green-600">{format_number(@engagement_metrics.page_views)}</div>
              <div class="text-sm text-gray-500">Page Views</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-purple-600">{@engagement_metrics.bounce_rate}%</div>
              <div class="text-sm text-gray-500">Bounce Rate</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-orange-600">{@engagement_metrics.user_satisfaction}</div>
              <div class="text-sm text-gray-500">Satisfaction Score</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-red-600">{@performance_metrics.error_rate}%</div>
              <div class="text-sm text-gray-500">Error Rate</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component: Overview Metric Card
  defp overview_metric_card(assigns) do
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
          <p class="text-2xl font-bold text-gray-900">{format_number(@value)}</p>
        </div>
      </div>
      <div class="mt-4 flex items-center">
        <.icon name="hero-arrow-trending-up" class="w-4 h-4 text-green-500 mr-1" />
        <span class="text-sm font-medium text-green-600">{@change}</span>
        <span class="text-sm text-gray-500 ml-1">vs last period</span>
      </div>
    </div>
    """
  end

  # Helper Functions
  defp format_number(number) when is_integer(number) and number >= 1000 do
    cond do
      number >= 1_000_000 -> "#{Float.round(number / 1_000_000, 1)}M"
      number >= 1_000 -> "#{Float.round(number / 1_000, 1)}K"
      true -> "#{number}"
    end
  end

  defp format_number(number), do: "#{number}"
end