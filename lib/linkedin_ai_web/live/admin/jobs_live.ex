defmodule LinkedinAiWeb.Admin.JobsLive do
  @moduledoc """
  Admin job monitoring LiveView for viewing and managing background jobs.
  """

  use LinkedinAiWeb, :live_view

  alias LinkedinAi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to job updates
      Phoenix.PubSub.subscribe(LinkedinAi.PubSub, "job_updates")

      # Schedule periodic updates
      :timer.send_interval(5_000, self(), :update_stats)
    end

    socket =
      socket
      |> assign(:page_title, "Job Monitoring")
      |> assign(:filter_state, "all")
      |> assign(:filter_queue, "all")
      |> load_job_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:update_stats, socket) do
    {:noreply, load_job_data(socket)}
  end

  def handle_info({:job_updated, _data}, socket) do
    {:noreply, load_job_data(socket)}
  end

  @impl true
  def handle_event("filter_state", %{"state" => state}, socket) do
    socket =
      socket
      |> assign(:filter_state, state)
      |> load_job_data()

    {:noreply, socket}
  end

  def handle_event("filter_queue", %{"queue" => queue}, socket) do
    socket =
      socket
      |> assign(:filter_queue, queue)
      |> load_job_data()

    {:noreply, socket}
  end

  def handle_event("retry_job", %{"id" => job_id}, socket) do
    case Jobs.retry_job(String.to_integer(job_id)) do
      {:ok, _job} ->
        socket =
          socket
          |> put_flash(:info, "Job retried successfully")
          |> load_job_data()

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to retry job: #{reason}")
        {:noreply, socket}
    end
  end

  def handle_event("cancel_job", %{"id" => job_id}, socket) do
    case Jobs.cancel_job(String.to_integer(job_id)) do
      {:ok, _job} ->
        socket =
          socket
          |> put_flash(:info, "Job canceled successfully")
          |> load_job_data()

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to cancel job: #{reason}")
        {:noreply, socket}
    end
  end

  def handle_event("purge_completed", _params, socket) do
    {count, _} = Jobs.purge_completed_jobs(7)

    socket =
      socket
      |> put_flash(:info, "Purged #{count} completed jobs")
      |> load_job_data()

    {:noreply, socket}
  end

  defp load_job_data(socket) do
    socket
    |> assign(:job_stats, Jobs.get_job_stats())
    |> assign(:failed_jobs, Jobs.get_failed_jobs(20))
    |> assign(:recent_jobs, get_recent_jobs())
  end

  defp get_recent_jobs do
    import Ecto.Query

    from(j in Oban.Job,
      order_by: [desc: j.inserted_at],
      limit: 50
    )
    |> LinkedinAi.Repo.all()
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
              <h1 class="text-2xl font-bold text-gray-900">Job Monitoring</h1>
              <p class="mt-1 text-sm text-gray-500">
                Monitor and manage background job processing
              </p>
            </div>
            <div class="flex items-center space-x-4">
              <button
                phx-click="purge_completed"
                class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                data-confirm="Are you sure you want to purge completed jobs older than 7 days?"
              >
                <.icon name="hero-trash" class="w-4 h-4 mr-2" /> Purge Completed
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="px-4 sm:px-6 lg:px-8 py-8">
        <!-- Job Statistics -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 mb-8">
          <.job_stat_card
            title="Completed"
            value={@job_stats.completed}
            color="green"
            icon="hero-check-circle"
          />
          <.job_stat_card title="Failed" value={@job_stats.failed} color="red" icon="hero-x-circle" />
          <.job_stat_card title="Pending" value={@job_stats.pending} color="yellow" icon="hero-clock" />
          <.job_stat_card
            title="Executing"
            value={@job_stats.executing}
            color="blue"
            icon="hero-play-circle"
          />
          <.job_stat_card
            title="Retryable"
            value={@job_stats.retryable}
            color="orange"
            icon="hero-arrow-path"
          />
        </div>
        
    <!-- Filters -->
        <div class="bg-white rounded-lg shadow mb-6">
          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Job State</label>
                <select
                  phx-change="filter_state"
                  name="state"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="all" selected={@filter_state == "all"}>All States</option>
                  <option value="available" selected={@filter_state == "available"}>Available</option>
                  <option value="executing" selected={@filter_state == "executing"}>Executing</option>
                  <option value="completed" selected={@filter_state == "completed"}>Completed</option>
                  <option value="discarded" selected={@filter_state == "discarded"}>Failed</option>
                  <option value="retryable" selected={@filter_state == "retryable"}>Retryable</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Queue</label>
                <select
                  phx-change="filter_queue"
                  name="queue"
                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="all" selected={@filter_queue == "all"}>All Queues</option>
                  <option value="default" selected={@filter_queue == "default"}>Default</option>
                  <option value="content_generation" selected={@filter_queue == "content_generation"}>
                    Content Generation
                  </option>
                  <option value="analytics" selected={@filter_queue == "analytics"}>Analytics</option>
                  <option value="notifications" selected={@filter_queue == "notifications"}>
                    Notifications
                  </option>
                  <option value="maintenance" selected={@filter_queue == "maintenance"}>
                    Maintenance
                  </option>
                </select>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Failed Jobs -->
        <%= if length(@failed_jobs) > 0 do %>
          <div class="bg-white rounded-lg shadow mb-8">
            <div class="px-6 py-4 border-b border-gray-200">
              <h3 class="text-lg font-medium text-gray-900">Failed Jobs</h3>
            </div>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Worker
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Queue
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Error
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Failed At
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for job <- @failed_jobs do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        {job.worker}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {job.queue}
                      </td>
                      <td class="px-6 py-4 text-sm text-gray-500 max-w-xs truncate">
                        {get_error_message(job)}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {format_datetime(job.discarded_at)}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <button
                          phx-click="retry_job"
                          phx-value-id={job.id}
                          class="text-blue-600 hover:text-blue-900 mr-3"
                        >
                          Retry
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>
        
    <!-- Recent Jobs -->
        <div class="bg-white rounded-lg shadow">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Recent Jobs</h3>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Worker
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Queue
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    State
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Attempts
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Created
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for job <- @recent_jobs do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {job.worker}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {job.queue}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <.job_state_badge state={job.state} />
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {job.attempt}/{job.max_attempts}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {format_datetime(job.inserted_at)}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <%= if job.state in ["available", "scheduled"] do %>
                        <button
                          phx-click="cancel_job"
                          phx-value-id={job.id}
                          class="text-red-600 hover:text-red-900"
                          data-confirm="Are you sure you want to cancel this job?"
                        >
                          Cancel
                        </button>
                      <% end %>
                      <%= if job.state == "discarded" do %>
                        <button
                          phx-click="retry_job"
                          phx-value-id={job.id}
                          class="text-blue-600 hover:text-blue-900"
                        >
                          Retry
                        </button>
                      <% end %>
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

  # Component: Job Stat Card
  defp job_stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex items-center">
        <div class={[
          "flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center",
          "bg-#{@color}-100"
        ]}>
          <.icon name={@icon} class={"w-6 h-6 text-#{@color}-600"} />
        </div>
        <div class="ml-4">
          <p class="text-sm font-medium text-gray-500">{@title}</p>
          <p class="text-2xl font-bold text-gray-900">{@value}</p>
        </div>
      </div>
    </div>
    """
  end

  # Component: Job State Badge
  defp job_state_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
      case @state do
        "available" -> "bg-blue-100 text-blue-800"
        "executing" -> "bg-yellow-100 text-yellow-800"
        "completed" -> "bg-green-100 text-green-800"
        "discarded" -> "bg-red-100 text-red-800"
        "retryable" -> "bg-orange-100 text-orange-800"
        "scheduled" -> "bg-purple-100 text-purple-800"
        _ -> "bg-gray-100 text-gray-800"
      end
    ]}>
      {String.capitalize(@state)}
    </span>
    """
  end

  # Helper Functions
  defp get_error_message(job) do
    case job.errors do
      [%{"error" => error} | _] -> error
      [error | _] when is_binary(error) -> error
      _ -> "Unknown error"
    end
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%b %d, %Y %H:%M")
      %NaiveDateTime{} -> Calendar.strftime(datetime, "%b %d, %Y %H:%M")
      _ -> "N/A"
    end
  end
end
