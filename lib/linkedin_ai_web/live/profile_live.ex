defmodule LinkedinAiWeb.ProfileLive do
  @moduledoc """
  Profile optimization LiveView for LinkedIn profile analysis and improvement.
  """
  
  use LinkedinAiWeb, :live_view
  
  alias LinkedinAi.ProfileOptimization
  alias LinkedinAi.ProfileOptimization.ProfileAnalysis
  alias LinkedinAi.Social
  alias LinkedinAi.Subscriptions
  alias LinkedinAi.Billing
  alias LinkedinAi.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    socket =
      socket
      |> assign(:page_title, "Profile Optimization")
      |> assign(:linkedin_status, Social.get_connection_status(user))
      |> assign(:analyses, [])
      |> assign(:analyzing, false)
      |> assign(:selected_analysis, nil)
    
    if connected?(socket) do
      analyses = ProfileOptimization.list_user_analyses(user, [])
      socket = assign(socket, :analyses, analyses)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("connect_linkedin", _params, socket) do
    # Redirect to LinkedIn OAuth
    redirect_url = Social.get_authorization_url("/auth/linkedin/callback")
    {:noreply, redirect(socket, external: redirect_url)}
  end

  @impl true
  def handle_event("sync_profile", _params, socket) do
    user = socket.assigns.current_user
    
    case Social.sync_profile_data(user) do
      {:ok, _updated_user} ->
        linkedin_status = Social.get_connection_status(user)
        
        socket =
          socket
          |> assign(:linkedin_status, linkedin_status)
          |> put_flash(:info, "LinkedIn profile synced successfully")
        
        {:noreply, socket}
      
      {:error, reason} ->
        message = case reason do
          :not_connected_or_expired -> "LinkedIn account not connected or token expired"
          _ -> "Failed to sync LinkedIn profile"
        end
        
        socket = put_flash(socket, :error, message)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("analyze_profile", %{"type" => analysis_type}, socket) do
    user = socket.assigns.current_user
    
    # Check usage limits
    if Subscriptions.usage_limit_exceeded?(user, "profile_analysis") do
      socket = put_flash(socket, :error, "You've reached your monthly profile analysis limit. Please upgrade your plan.")
      {:noreply, socket}
    else
      socket = assign(socket, :analyzing, true)
      
      # Start analysis asynchronously
      send(self(), {:analyze_profile, analysis_type})
      
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("view_analysis", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    
    case ProfileOptimization.get_user_analysis(user, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Analysis not found")}
      
      analysis ->
        socket = assign(socket, :selected_analysis, analysis)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_analysis", _params, socket) do
    socket = assign(socket, :selected_analysis, nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("mark_implemented", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    
    case ProfileOptimization.get_user_analysis(user, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Analysis not found")}
      
      analysis ->
        case ProfileOptimization.mark_as_implemented(analysis) do
          {:ok, _updated_analysis} ->
            analyses = ProfileOptimization.list_user_analyses(user, [])
            
            socket =
              socket
              |> assign(:analyses, analyses)
              |> put_flash(:info, "Marked as implemented")
            
            {:noreply, socket}
          
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update analysis")}
        end
    end
  end

  @impl true
  def handle_event("dismiss_analysis", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    
    case ProfileOptimization.get_user_analysis(user, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Analysis not found")}
      
      analysis ->
        case ProfileOptimization.dismiss_analysis(analysis) do
          {:ok, _updated_analysis} ->
            analyses = ProfileOptimization.list_user_analyses(user, [])
            
            socket =
              socket
              |> assign(:analyses, analyses)
              |> put_flash(:info, "Analysis dismissed")
            
            {:noreply, socket}
          
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to dismiss analysis")}
        end
    end
  end

  @impl true
  def handle_info({:analyze_profile, analysis_type}, socket) do
    user = socket.assigns.current_user
    
    case ProfileOptimization.analyze_profile(user, analysis_type) do
      {:ok, _analysis} ->
        analyses = ProfileOptimization.list_user_analyses(user, [])
        
        socket =
          socket
          |> assign(:analyzing, false)
          |> assign(:analyses, analyses)
          |> put_flash(:info, "Profile analysis completed successfully!")
        
        {:noreply, socket}
      
      {:error, :usage_limit_exceeded} ->
        socket =
          socket
          |> assign(:analyzing, false)
          |> put_flash(:error, "You've reached your monthly analysis limit")
        
        {:noreply, socket}
      
      {:error, :not_connected_or_expired} ->
        socket =
          socket
          |> assign(:analyzing, false)
          |> put_flash(:error, "Please connect your LinkedIn account first")
        
        {:noreply, socket}
      
      {:error, _reason} ->
        socket =
          socket
          |> assign(:analyzing, false)
          |> put_flash(:error, "Failed to analyze profile. Please try again.")
        
        {:noreply, socket}
    end
  end  
@impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <!-- Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Profile Optimization</h1>
        <p class="mt-2 text-gray-600">
          Get AI-powered insights to optimize your LinkedIn profile
        </p>
      </div>

      <%= if @linkedin_status.connected do %>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Main Content -->
          <div class="lg:col-span-2 space-y-8">
            <!-- Profile Overview -->
            <.profile_overview_card linkedin_status={@linkedin_status} />

            <!-- Analysis Actions -->
            <.analysis_actions_card analyzing={@analyzing} />

            <!-- Analysis History -->
            <.analysis_history_card analyses={@analyses} />
          </div>

          <!-- Sidebar -->
          <div class="space-y-6">
            <!-- LinkedIn Status -->
            <.linkedin_connection_card linkedin_status={@linkedin_status} />

            <!-- Usage Stats -->
            <.analysis_usage_card current_user={@current_user} />

            <!-- Quick Tips -->
            <.optimization_tips_card />
          </div>
        </div>

        <!-- Analysis Detail Modal -->
        <%= if @selected_analysis do %>
          <.analysis_detail_modal analysis={@selected_analysis} />
        <% end %>
      <% else %>
        <!-- LinkedIn Connection Required -->
        <.linkedin_connect_prompt />
      <% end %>
    </div>
    """
  end

  # Component: LinkedIn Connect Prompt
  defp linkedin_connect_prompt(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-blue-100">
        <svg class="w-12 h-12 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
          <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
        </svg>
      </div>
      <h2 class="mt-6 text-2xl font-bold text-gray-900">Connect Your LinkedIn Account</h2>
      <p class="mt-2 text-gray-600 max-w-md mx-auto">
        To analyze and optimize your LinkedIn profile, we need access to your LinkedIn account.
      </p>
      <div class="mt-8">
        <button
          phx-click="connect_linkedin"
          class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 24 24">
            <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
          </svg>
          Connect LinkedIn Account
        </button>
      </div>
      <div class="mt-6 text-sm text-gray-500">
        <p>We only access your public profile information to provide optimization suggestions.</p>
      </div>
    </div>
    """
  end

  # Component: Profile Overview Card
  defp profile_overview_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-lg font-medium text-gray-900">LinkedIn Profile Overview</h2>
        <button
          phx-click="sync_profile"
          class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <.icon name="hero-arrow-path" class="h-4 w-4 mr-2" />
          Sync Profile
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h3 class="text-sm font-medium text-gray-500 mb-2">Current Status</h3>
          <div class="space-y-2">
            <div class="flex items-center">
              <span class="text-sm text-gray-700">Connection Status:</span>
              <span class={[
                "ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                if(@linkedin_status.connected, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
              ]}>
                {if @linkedin_status.connected, do: "Connected", else: "Disconnected"}
              </span>
            </div>
            <%= if @linkedin_status.last_synced do %>
              <div class="flex items-center">
                <span class="text-sm text-gray-700">Last Synced:</span>
                <span class="ml-2 text-sm text-gray-500">
                  {Timex.from_now(@linkedin_status.last_synced)}
                </span>
              </div>
            <% end %>
          </div>
        </div>

        <div>
          <h3 class="text-sm font-medium text-gray-500 mb-2">Profile Health</h3>
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-700">Overall Score</span>
              <span class="text-sm font-medium text-gray-900">
                {get_latest_score(@analyses) || "Not analyzed"}
              </span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-700">Analyses Completed</span>
              <span class="text-sm font-medium text-gray-900">{length(@analyses)}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component: Analysis Actions Card
  defp analysis_actions_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h2 class="text-lg font-medium text-gray-900 mb-6">Profile Analysis</h2>
      
      <%= if @analyzing do %>
        <div class="text-center py-8">
          <div class="inline-flex items-center px-4 py-2 font-semibold leading-6 text-sm shadow rounded-md text-blue-500 bg-blue-100">
            <.icon name="hero-arrow-path" class="animate-spin -ml-1 mr-3 h-5 w-5" />
            Analyzing your profile...
          </div>
          <p class="mt-2 text-sm text-gray-500">This may take a few moments</p>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <.analysis_type_card
            type="headline"
            title="Headline Analysis"
            description="Optimize your professional headline"
            icon="hero-identification"
          />
          <.analysis_type_card
            type="summary"
            title="Summary Analysis"
            description="Improve your about section"
            icon="hero-document-text"
          />
          <.analysis_type_card
            type="overall"
            title="Overall Profile"
            description="Complete profile review"
            icon="hero-user-circle"
          />
        </div>
      <% end %>
    </div>
    """
  end

  # Component: Analysis Type Card
  defp analysis_type_card(assigns) do
    ~H"""
    <button
      phx-click="analyze_profile"
      phx-value-type={@type}
      class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-blue-500 rounded-lg border border-gray-200 hover:border-gray-300 transition-colors duration-200"
    >
      <div>
        <span class="rounded-lg inline-flex p-3 bg-blue-50 text-blue-700 ring-4 ring-white">
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
      <span class="pointer-events-none absolute top-6 right-6 text-gray-300 group-hover:text-gray-400" aria-hidden="true">
        <.icon name="hero-arrow-top-right-on-square" class="h-6 w-6" />
      </span>
    </button>
    """
  end

  # Component: Analysis History Card
  defp analysis_history_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h2 class="text-lg font-medium text-gray-900 mb-6">Analysis History</h2>
      
      <%= if Enum.empty?(@analyses) do %>
        <div class="text-center py-8">
          <.icon name="hero-chart-bar" class="mx-auto h-12 w-12 text-gray-400" />
          <h3 class="mt-2 text-sm font-medium text-gray-900">No analyses yet</h3>
          <p class="mt-1 text-sm text-gray-500">Start by analyzing your profile above.</p>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for analysis <- Enum.take(@analyses, 10) do %>
            <.analysis_item analysis={analysis} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Component: Analysis Item
  defp analysis_item(assigns) do
    {status_text, status_color} = ProfileAnalysis.status_display(assigns.analysis)
    {priority_text, priority_color} = ProfileAnalysis.priority_display(assigns.analysis)
    
    assigns = assign(assigns, :status_text, status_text)
    assigns = assign(assigns, :status_color, status_color)
    assigns = assign(assigns, :priority_text, priority_text)
    assigns = assign(assigns, :priority_color, priority_color)

    ~H"""
    <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
      <div class="flex items-center space-x-4">
        <div class="flex-shrink-0">
          <div class={[
            "w-10 h-10 rounded-full flex items-center justify-center",
            ProfileAnalysis.score_color(@analysis) |> String.replace("text-", "bg-") |> String.replace("-600", "-100")
          ]}>
            <span class={["text-sm font-medium", ProfileAnalysis.score_color(@analysis)]}>
              {ProfileAnalysis.score_grade(@analysis)}
            </span>
          </div>
        </div>
        <div>
          <h3 class="text-sm font-medium text-gray-900">
            {ProfileAnalysis.analysis_type_display_name(@analysis)}
          </h3>
          <div class="flex items-center space-x-4 mt-1">
            <span class="text-xs text-gray-500">
              Score: {@analysis.score}/100
            </span>
            <span class={["text-xs", @status_color]}>
              {@status_text}
            </span>
            <span class={["text-xs", @priority_color]}>
              {@priority_text} Priority
            </span>
          </div>
        </div>
      </div>
      
      <div class="flex items-center space-x-2">
        <button
          phx-click="view_analysis"
          phx-value-id={@analysis.id}
          class="text-sm text-blue-600 hover:text-blue-500 font-medium"
        >
          View Details
        </button>
        <%= if @analysis.status == "pending" do %>
          <button
            phx-click="mark_implemented"
            phx-value-id={@analysis.id}
            class="text-sm text-green-600 hover:text-green-500 font-medium"
          >
            Mark Done
          </button>
          <button
            phx-click="dismiss_analysis"
            phx-value-id={@analysis.id}
            class="text-sm text-gray-600 hover:text-gray-500 font-medium"
          >
            Dismiss
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # Component: LinkedIn Connection Card
  defp linkedin_connection_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">LinkedIn Connection</h3>
      
      <div class="flex items-center space-x-3 mb-4">
        <div class="flex-shrink-0">
          <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
            <svg class="w-6 h-6 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
              <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
            </svg>
          </div>
        </div>
        <div>
          <p class="text-sm font-medium text-gray-900">
            {if @linkedin_status.connected, do: "Connected", else: "Not Connected"}
          </p>
          <%= if @linkedin_status.last_synced do %>
            <p class="text-xs text-gray-500">
              Last synced {Timex.from_now(@linkedin_status.last_synced)}
            </p>
          <% end %>
        </div>
      </div>

      <%= if @linkedin_status.expired do %>
        <div class="bg-yellow-50 border border-yellow-200 rounded-md p-3 mb-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-yellow-400" />
            </div>
            <div class="ml-3">
              <p class="text-sm text-yellow-700">
                Your LinkedIn token has expired. Please reconnect to continue analyzing your profile.
              </p>
            </div>
          </div>
        </div>
      <% end %>

      <button
        phx-click="sync_profile"
        class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
      >
        <.icon name="hero-arrow-path" class="h-4 w-4 mr-2" />
        Sync Profile Data
      </button>
    </div>
    """
  end

  # Component: Analysis Usage Card
  defp analysis_usage_card(assigns) do
    current_usage = Subscriptions.get_current_usage(assigns.current_user, "profile_analysis")
    limit = get_analysis_limit(assigns.current_user)
    percentage = if limit > 0, do: min(100, current_usage / limit * 100), else: 0
    
    assigns = assign(assigns, :current_usage, current_usage)
    assigns = assign(assigns, :limit, limit)
    assigns = assign(assigns, :percentage, percentage)

    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Monthly Usage</h3>
      
      <div class="space-y-4">
        <div>
          <div class="flex justify-between text-sm mb-2">
            <span class="text-gray-700">Profile Analysis</span>
            <span class="text-gray-500">
              {@current_usage}<%= if @limit > 0 do %>/{@limit}<% else %>/∞<% end %>
            </span>
          </div>
          <div class="bg-gray-200 rounded-full h-2">
            <div
              class={[
                "h-2 rounded-full transition-all duration-300",
                if(@percentage >= 90, do: "bg-red-500", else: if(@percentage >= 70, do: "bg-yellow-500", else: "bg-green-500"))
              ]}
              style={"width: #{@percentage}%"}
            >
            </div>
          </div>
        </div>

        <%= if @percentage >= 90 do %>
          <div class="bg-red-50 border border-red-200 rounded-md p-3">
            <div class="flex">
              <div class="flex-shrink-0">
                <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-red-400" />
              </div>
              <div class="ml-3">
                <p class="text-sm text-red-700">
                  You're approaching your monthly limit.
                  <.link href="/subscription" class="font-medium underline">
                    Upgrade your plan
                  </.link>
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Component: Optimization Tips Card
  defp optimization_tips_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Optimization Tips</h3>
      
      <div class="space-y-4">
        <div class="flex items-start space-x-3">
          <div class="flex-shrink-0">
            <div class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center">
              <span class="text-xs font-medium text-blue-600">1</span>
            </div>
          </div>
          <div>
            <p class="text-sm font-medium text-gray-900">Keep it updated</p>
            <p class="text-sm text-gray-500">Regularly sync your profile to get the latest analysis.</p>
          </div>
        </div>
        
        <div class="flex items-start space-x-3">
          <div class="flex-shrink-0">
            <div class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center">
              <span class="text-xs font-medium text-blue-600">2</span>
            </div>
          </div>
          <div>
            <p class="text-sm font-medium text-gray-900">Act on suggestions</p>
            <p class="text-sm text-gray-500">Implement the AI recommendations to improve your profile score.</p>
          </div>
        </div>
        
        <div class="flex items-start space-x-3">
          <div class="flex-shrink-0">
            <div class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center">
              <span class="text-xs font-medium text-blue-600">3</span>
            </div>
          </div>
          <div>
            <p class="text-sm font-medium text-gray-900">Monitor progress</p>
            <p class="text-sm text-gray-500">Re-analyze after making changes to track improvements.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_latest_score(analyses) do
    case Enum.find(analyses, &(&1.analysis_type == "overall")) do
      nil -> nil
      analysis -> analysis.score
    end
  end

  # Component: Analysis Detail Modal
  defp analysis_detail_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="close_analysis"></div>
        
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
        
        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div class="flex items-start justify-between mb-4">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Analysis Details
              </h3>
              <button
                phx-click="close_analysis"
                class="bg-white rounded-md text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <span class="sr-only">Close</span>
                <.icon name="hero-x-mark" class="h-6 w-6" />
              </button>
            </div>
            
            <div class="space-y-6">
              <div class="bg-gray-50 rounded-lg p-4">
                <h4 class="text-sm font-medium text-gray-900 mb-2">Analysis Summary</h4>
                <p class="text-sm text-gray-700">{@analysis.summary}</p>
              </div>
              
              <div>
                <h4 class="text-sm font-medium text-gray-900 mb-2">Recommendations</h4>
                <div class="space-y-2">
                  <%= for recommendation <- @analysis.recommendations do %>
                    <div class="bg-blue-50 border border-blue-200 rounded-md p-3">
                      <p class="text-sm text-blue-800">{recommendation}</p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          
          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <button
              phx-click="mark_implemented"
              phx-value-id={@analysis.id}
              class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-green-600 text-base font-medium text-white hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 sm:ml-3 sm:w-auto sm:text-sm"
            >
              Mark as Implemented
            </button>
            <button
              phx-click="dismiss_analysis"
              phx-value-id={@analysis.id}
              class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
            >
              Dismiss
            </button>
            <button
              phx-click="close_analysis"
              class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:mt-0 sm:w-auto sm:text-sm"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_analysis_limit(user) do
    case Billing.get_current_subscription(user) do
      %{plan_type: "basic"} -> 1
      %{plan_type: "pro"} -> -1  # unlimited
      _ -> if User.in_trial?(user), do: 1, else: 0
    end
  end
end