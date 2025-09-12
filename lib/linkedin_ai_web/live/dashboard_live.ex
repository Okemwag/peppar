defmodule LinkedinAiWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView for LinkedIn AI platform.
  Shows user analytics, quick actions, and subscription status.
  """

  use LinkedinAiWeb, :live_view

  alias LinkedinAi.Analytics
  alias LinkedinAi.Billing
  alias LinkedinAi.Social
  alias LinkedinAi.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    socket = if connected?(socket) do
      # Load dashboard data
      user = socket.assigns.current_user
      analytics = Analytics.get_user_analytics(user)
      subscription = Billing.get_current_subscription(user)
      linkedin_status = Social.get_connection_status(user)

      socket
      |> assign(:analytics, analytics)
      |> assign(:subscription, subscription)
      |> assign(:linkedin_status, linkedin_status)
      |> assign(:page_title, "Dashboard")
    else
      socket
      |> assign(:analytics, nil)
      |> assign(:subscription, nil)
      |> assign(:linkedin_status, nil)
      |> assign(:page_title, "Dashboard")
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("refresh_data", _params, socket) do
    user = socket.assigns.current_user
    analytics = Analytics.get_user_analytics(user)

    socket =
      socket
      |> assign(:analytics, analytics)
      |> put_flash(:info, "Dashboard data refreshed")

    {:noreply, socket}
  end

  @impl true
  def handle_event("sync_linkedin", _params, socket) do
    user = socket.assigns.current_user

    case Social.sync_profile_data(user) do
      {:ok, _updated_user} ->
        linkedin_status = Social.get_connection_status(user)

        socket =
          socket
          |> assign(:linkedin_status, linkedin_status)
          |> put_flash(:info, "LinkedIn profile synced successfully")

        {:noreply, socket}

      {:error, :not_connected_or_expired} ->
        socket = put_flash(socket, :error, "LinkedIn account not connected or token expired")
        {:noreply, socket}

      {:error, _reason} ->
        socket = put_flash(socket, :error, "Failed to sync LinkedIn profile")
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Welcome Header -->
      <div class="bg-white shadow rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">
              Welcome back, {User.display_name(@current_user)}!
            </h1>
            <p class="mt-1 text-sm text-gray-500">
              Here's what's happening with your LinkedIn AI account today.
            </p>
          </div>
          <div class="flex items-center space-x-3">
            <button
              phx-click="refresh_data"
              class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <.icon name="hero-arrow-path" class="h-4 w-4 mr-2" /> Refresh
            </button>
          </div>
        </div>
      </div>
      
    <!-- Quick Stats -->
      <%= if @analytics do %>
        <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <.stat_card
            title="Content Generated"
            value={@analytics.content.total_generated}
            change="+{@analytics.content.recent_activity} this month"
            icon="hero-document-text"
            color="blue"
          />
          <.stat_card
            title="Published Posts"
            value={@analytics.content.published}
            change="{@analytics.content.publish_rate}% publish rate"
            icon="hero-share"
            color="green"
          />
          <.stat_card
            title="Profile Score"
            value={@analytics.profile.latest_score || 0}
            change="Average: {@analytics.profile.avg_score}"
            icon="hero-user-circle"
            color="purple"
          />
          <.stat_card
            title="Monthly Usage"
            value={get_total_usage(@analytics.usage.current_month)}
            change="Content generations"
            icon="hero-chart-bar"
            color="indigo"
          />
        </div>
      <% end %>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Main Content Area -->
        <div class="lg:col-span-2 space-y-8">
          <!-- Quick Actions -->
          <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Quick Actions</h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.quick_action_card
                title="Generate Content"
                description="Create AI-powered LinkedIn posts"
                href="/content/new"
                icon="hero-plus-circle"
                color="blue"
              />
              <.quick_action_card
                title="Analyze Profile"
                description="Get AI insights on your profile"
                href="/profile/analyze"
                icon="hero-magnifying-glass"
                color="purple"
              />
              <.quick_action_card
                title="View Analytics"
                description="See your performance metrics"
                href="/analytics"
                icon="hero-chart-bar"
                color="green"
              />
              <.quick_action_card
                title="Browse Templates"
                description="Use pre-made content templates"
                href="/templates"
                icon="hero-document-duplicate"
                color="indigo"
              />
            </div>
          </div>
          
    <!-- Recent Activity -->
          <%= if @analytics do %>
            <div class="bg-white shadow rounded-lg p-6">
              <h2 class="text-lg font-medium text-gray-900 mb-4">Recent Activity</h2>
              <.recent_activity_list analytics={@analytics} />
            </div>
          <% end %>
        </div>
        
    <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Subscription Status -->
          <.subscription_status_card subscription={@subscription} current_user={@current_user} />
          
    <!-- LinkedIn Connection Status -->
          <.linkedin_status_card linkedin_status={@linkedin_status} />
          
    <!-- Usage Limits -->
          <%= if @analytics do %>
            <.usage_limits_card analytics={@analytics} current_user={@current_user} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Component: Stat Card
  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class={"w-8 h-8 rounded-md flex items-center justify-center bg-#{@color}-100"}>
              <.icon name={@icon} class={"h-5 w-5 text-#{@color}-600"} />
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">{@title}</dt>
              <dd>
                <div class="text-lg font-medium text-gray-900">{@value}</div>
              </dd>
            </dl>
          </div>
        </div>
      </div>
      <div class="bg-gray-50 px-5 py-3">
        <div class="text-sm">
          <span class="text-gray-500">{@change}</span>
        </div>
      </div>
    </div>
    """
  end

  # Component: Quick Action Card
  defp quick_action_card(assigns) do
    ~H"""
    <.link
      href={@href}
      class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-200 hover:border-gray-300 transition-colors duration-200"
    >
      <div>
        <span class={"rounded-lg inline-flex p-3 bg-#{@color}-50 text-#{@color}-700 ring-4 ring-white"}>
          <.icon name={@icon} class="h-6 w-6" />
        </span>
      </div>
      <div class="mt-8">
        <h3 class="text-lg font-medium">
          <span class="absolute inset-0" aria-hidden="true"></span>
          {@title}
        </h3>
        <p class="mt-2 text-sm text-gray-500">
          {@description}
        </p>
      </div>
      <span
        class="pointer-events-none absolute top-6 right-6 text-gray-300 group-hover:text-gray-400"
        aria-hidden="true"
      >
        <.icon name="hero-arrow-top-right-on-square" class="h-6 w-6" />
      </span>
    </.link>
    """
  end

  # Component: Subscription Status Card
  defp subscription_status_card(assigns) do
    has_active = Billing.has_active_subscription?(assigns.current_user)
    assigns = assign(assigns, :has_active, has_active)

    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Subscription</h3>
      <%= if @has_active do %>
        <div class="flex items-center justify-between">
          <div>
            <p class="text-sm font-medium text-gray-900">
              {String.capitalize(@subscription.plan_type)} Plan
            </p>
            <p class="text-sm text-gray-500">
              Active until {Calendar.strftime(@subscription.current_period_end, "%B %d, %Y")}
            </p>
          </div>
          <div class="flex-shrink-0">
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
              Active
            </span>
          </div>
        </div>
        <div class="mt-4">
          <.link href="/subscription" class="text-sm text-blue-600 hover:text-blue-500 font-medium">
            Manage subscription →
          </.link>
        </div>
      <% else %>
        <div class="text-center">
          <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-yellow-100">
            <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-yellow-600" />
          </div>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No active subscription</h3>
          <p class="mt-1 text-sm text-gray-500">
            Upgrade to unlock all features
          </p>
          <div class="mt-4">
            <.link
              href="/subscription"
              class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              View Plans
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Component: LinkedIn Status Card
  defp linkedin_status_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">LinkedIn Connection</h3>
      <%= if @linkedin_status && @linkedin_status.connected do %>
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
                </svg>
              </div>
            </div>
            <div class="ml-3">
              <p class="text-sm font-medium text-gray-900">Connected</p>
              <%= if @linkedin_status.last_synced do %>
                <p class="text-sm text-gray-500">
                  Last synced {Timex.from_now(@linkedin_status.last_synced)}
                </p>
              <% end %>
            </div>
          </div>
          <%= if @linkedin_status.expired do %>
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
              Expired
            </span>
          <% else %>
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
              Active
            </span>
          <% end %>
        </div>
        <div class="mt-4 flex space-x-2">
          <button
            phx-click="sync_linkedin"
            class="flex-1 text-sm text-blue-600 hover:text-blue-500 font-medium"
          >
            Sync now
          </button>
          <.link
            href="/profile"
            class="flex-1 text-sm text-gray-600 hover:text-gray-500 font-medium text-right"
          >
            View profile →
          </.link>
        </div>
      <% else %>
        <div class="text-center">
          <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-blue-100">
            <svg class="w-6 h-6 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
              <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
            </svg>
          </div>
          <h3 class="mt-2 text-sm font-medium text-gray-900">Connect LinkedIn</h3>
          <p class="mt-1 text-sm text-gray-500">
            Connect your account to enable profile optimization
          </p>
          <div class="mt-4">
            <.link
              href="/auth/linkedin"
              class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Connect LinkedIn
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Component: Usage Limits Card
  defp usage_limits_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Usage This Month</h3>
      <div class="space-y-4">
        <.usage_bar
          label="Content Generation"
          current={Map.get(@analytics.usage.current_month, "content_generation", 0)}
          limit={get_content_limit(@current_user)}
        />
        <.usage_bar
          label="Profile Analysis"
          current={Map.get(@analytics.usage.current_month, "profile_analysis", 0)}
          limit={get_analysis_limit(@current_user)}
        />
      </div>
    </div>
    """
  end

  # Component: Usage Bar
  defp usage_bar(assigns) do
    percentage =
      if assigns.limit > 0, do: min(100, assigns.current / assigns.limit * 100), else: 0

    assigns = assign(assigns, :percentage, percentage)

    ~H"""
    <div>
      <div class="flex justify-between text-sm">
        <span class="text-gray-700">{@label}</span>
        <span class="text-gray-500">
          {@current}
          <%= if @limit > 0 do %>
            /{@limit}
          <% else %>
            /∞
          <% end %>
        </span>
      </div>
      <div class="mt-1 bg-gray-200 rounded-full h-2">
        <div
          class={[
            "h-2 rounded-full transition-all duration-300",
            if(@percentage >= 90,
              do: "bg-red-500",
              else: if(@percentage >= 70, do: "bg-yellow-500", else: "bg-green-500")
            )
          ]}
          style={"width: #{@percentage}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  # Component: Recent Activity List
  defp recent_activity_list(assigns) do
    ~H"""
    <div class="flow-root">
      <ul role="list" class="-mb-8">
        <li class="relative pb-8">
          <div class="relative flex space-x-3">
            <div>
              <span class="h-8 w-8 rounded-full bg-green-500 flex items-center justify-center ring-8 ring-white">
                <.icon name="hero-document-text" class="h-5 w-5 text-white" />
              </span>
            </div>
            <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
              <div>
                <p class="text-sm text-gray-500">
                  Generated
                  <span class="font-medium text-gray-900">
                    {@analytics.content.recent_activity} pieces of content
                  </span>
                  this month
                </p>
              </div>
              <div class="text-right text-sm whitespace-nowrap text-gray-500">
                <time>This month</time>
              </div>
            </div>
          </div>
        </li>

        <%= if @analytics.profile.total_analyses > 0 do %>
          <li class="relative pb-8">
            <div class="relative flex space-x-3">
              <div>
                <span class="h-8 w-8 rounded-full bg-blue-500 flex items-center justify-center ring-8 ring-white">
                  <.icon name="hero-user-circle" class="h-5 w-5 text-white" />
                </span>
              </div>
              <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                <div>
                  <p class="text-sm text-gray-500">
                    Completed
                    <span class="font-medium text-gray-900">
                      {@analytics.profile.total_analyses} profile analyses
                    </span>
                  </p>
                </div>
                <div class="text-right text-sm whitespace-nowrap text-gray-500">
                  <time>All time</time>
                </div>
              </div>
            </div>
          </li>
        <% end %>

        <li class="relative">
          <div class="relative flex space-x-3">
            <div>
              <span class="h-8 w-8 rounded-full bg-purple-500 flex items-center justify-center ring-8 ring-white">
                <.icon name="hero-chart-bar" class="h-5 w-5 text-white" />
              </span>
            </div>
            <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
              <div>
                <p class="text-sm text-gray-500">
                  Published
                  <span class="font-medium text-gray-900">{@analytics.content.published} posts</span>
                  with {@analytics.content.publish_rate}% publish rate
                </p>
              </div>
              <div class="text-right text-sm whitespace-nowrap text-gray-500">
                <time>All time</time>
              </div>
            </div>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  # Helper functions
  defp get_total_usage(usage_map) when is_map(usage_map) do
    usage_map |> Map.values() |> Enum.sum()
  end

  defp get_total_usage(_), do: 0

  defp get_content_limit(user) do
    case Billing.get_current_subscription(user) do
      %{plan_type: "basic"} -> 10
      # unlimited
      %{plan_type: "pro"} -> -1
      _ -> if User.in_trial?(user), do: 3, else: 0
    end
  end

  defp get_analysis_limit(user) do
    case Billing.get_current_subscription(user) do
      %{plan_type: "basic"} -> 1
      # unlimited
      %{plan_type: "pro"} -> -1
      _ -> if User.in_trial?(user), do: 1, else: 0
    end
  end
end
