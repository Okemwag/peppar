defmodule LinkedinAiWeb.Admin.UserLive do
  @moduledoc """
  Admin user management LiveView for searching, filtering, and managing users.
  """

  use LinkedinAiWeb, :live_view

  alias LinkedinAi.{Accounts, Billing, Analytics}
  alias LinkedinAi.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "User Management")
      |> assign(:search_query, "")
      |> assign(:filter_status, "all")
      |> assign(:filter_role, "all")
      |> assign(:filter_subscription, "all")
      |> assign(:sort_by, "inserted_at")
      |> assign(:sort_order, "desc")
      |> assign(:page, 1)
      |> assign(:per_page, 20)
      |> assign(:selected_user, nil)
      |> assign(:show_user_modal, false)
      |> load_users()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => user_id}, _uri, socket) do
    case Accounts.get_user(user_id) do
      %User{} = user ->
        socket =
          socket
          |> assign(:selected_user, user)
          |> assign(:show_user_modal, true)
          |> assign(:page_title, "User: #{User.display_name(user)}")

        {:noreply, socket}

      nil ->
        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: ~p"/admin/users")

        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:page, 1)
      |> load_users()

    {:noreply, socket}
  end

  def handle_event("filter", %{"filter" => filters}, socket) do
    socket =
      socket
      |> assign(:filter_status, Map.get(filters, "status", "all"))
      |> assign(:filter_role, Map.get(filters, "role", "all"))
      |> assign(:filter_subscription, Map.get(filters, "subscription", "all"))
      |> assign(:page, 1)
      |> load_users()

    {:noreply, socket}
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    {sort_by, sort_order} =
      if socket.assigns.sort_by == sort_by do
        {sort_by, if(socket.assigns.sort_order == "asc", do: "desc", else: "asc")}
      else
        {sort_by, "asc"}
      end

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)
      |> load_users()

    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    socket =
      socket
      |> assign(:page, String.to_integer(page))
      |> load_users()

    {:noreply, socket}
  end

  def handle_event("view_user", %{"id" => user_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/users/#{user_id}")}
  end

  def handle_event("close_user_modal", _params, socket) do
    socket =
      socket
      |> assign(:selected_user, nil)
      |> assign(:show_user_modal, false)
      |> push_navigate(to: ~p"/admin/users")

    {:noreply, socket}
  end

  def handle_event("suspend_user", %{"id" => user_id}, socket) do
    case Accounts.get_user(user_id) do
      %User{} = user ->
        case Accounts.suspend_user(user) do
          {:ok, _updated_user} ->
            socket =
              socket
              |> put_flash(:info, "User suspended successfully")
              |> load_users()

            {:noreply, socket}

          {:error, _changeset} ->
            socket = put_flash(socket, :error, "Failed to suspend user")
            {:noreply, socket}
        end

      nil ->
        socket = put_flash(socket, :error, "User not found")
        {:noreply, socket}
    end
  end

  def handle_event("activate_user", %{"id" => user_id}, socket) do
    case Accounts.get_user(user_id) do
      %User{} = user ->
        case Accounts.activate_user(user) do
          {:ok, _updated_user} ->
            socket =
              socket
              |> put_flash(:info, "User activated successfully")
              |> load_users()

            {:noreply, socket}

          {:error, _changeset} ->
            socket = put_flash(socket, :error, "Failed to activate user")
            {:noreply, socket}
        end

      nil ->
        socket = put_flash(socket, :error, "User not found")
        {:noreply, socket}
    end
  end

  def handle_event("promote_to_admin", %{"id" => user_id}, socket) do
    case Accounts.get_user(user_id) do
      %User{} = user ->
        case Accounts.promote_to_admin(user) do
          {:ok, _updated_user} ->
            socket =
              socket
              |> put_flash(:info, "User promoted to admin successfully")
              |> load_users()

            {:noreply, socket}

          {:error, _changeset} ->
            socket = put_flash(socket, :error, "Failed to promote user")
            {:noreply, socket}
        end

      nil ->
        socket = put_flash(socket, :error, "User not found")
        {:noreply, socket}
    end
  end

  defp load_users(socket) do
    filters = build_filters(socket.assigns)
    
    users = Accounts.list_users_admin(
      search: socket.assigns.search_query,
      filters: filters,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order,
      page: socket.assigns.page,
      per_page: socket.assigns.per_page
    )

    total_count = Accounts.count_users_admin(
      search: socket.assigns.search_query,
      filters: filters
    )

    total_pages = ceil(total_count / socket.assigns.per_page)

    socket
    |> assign(:users, users)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp build_filters(assigns) do
    %{}
    |> maybe_add_filter(:status, assigns.filter_status)
    |> maybe_add_filter(:role, assigns.filter_role)
    |> maybe_add_filter(:subscription, assigns.filter_subscription)
  end

  defp maybe_add_filter(filters, _key, "all"), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">User Management</h1>
              <p class="mt-1 text-sm text-gray-500">
                Manage users, subscriptions, and account status
              </p>
            </div>
            <div class="flex items-center space-x-4">
              <span class="text-sm text-gray-500">
                {@total_count} users total
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="px-4 sm:px-6 lg:px-8 py-8">
        <!-- Search and Filters -->
        <div class="bg-white rounded-lg shadow mb-6">
          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <!-- Search -->
              <div class="md:col-span-2">
                <.form for={%{}} phx-submit="search" phx-change="search">
                  <input
                    type="text"
                    name="search[query]"
                    value={@search_query}
                    placeholder="Search users by name or email..."
                    class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </.form>
              </div>

              <!-- Status Filter -->
              <div>
                <.form for={%{}} phx-change="filter">
                  <select
                    name="filter[status]"
                    class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  >
                    <option value="all" selected={@filter_status == "all"}>All Status</option>
                    <option value="active" selected={@filter_status == "active"}>Active</option>
                    <option value="suspended" selected={@filter_status == "suspended"}>Suspended</option>
                    <option value="pending" selected={@filter_status == "pending"}>Pending</option>
                  </select>
                </.form>
              </div>

              <!-- Role Filter -->
              <div>
                <.form for={%{}} phx-change="filter">
                  <select
                    name="filter[role]"
                    class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  >
                    <option value="all" selected={@filter_role == "all"}>All Roles</option>
                    <option value="user" selected={@filter_role == "user"}>User</option>
                    <option value="admin" selected={@filter_role == "admin"}>Admin</option>
                  </select>
                </.form>
              </div>
            </div>
          </div>
        </div>

        <!-- Users Table -->
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <button
                      phx-click="sort"
                      phx-value-sort_by="first_name"
                      class="flex items-center space-x-1 hover:text-gray-700"
                    >
                      <span>User</span>
                      <.sort_icon sort_by="first_name" current_sort={@sort_by} current_order={@sort_order} />
                    </button>
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Role
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Subscription
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <button
                      phx-click="sort"
                      phx-value-sort_by="inserted_at"
                      class="flex items-center space-x-1 hover:text-gray-700"
                    >
                      <span>Joined</span>
                      <.sort_icon sort_by="inserted_at" current_sort={@sort_by} current_order={@sort_order} />
                    </button>
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for user <- @users do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div class="h-10 w-10 rounded-full bg-gradient-to-r from-blue-500 to-indigo-600 flex items-center justify-center">
                          <span class="text-sm font-medium text-white">
                            {String.first(user.first_name || "U")}
                          </span>
                        </div>
                        <div class="ml-4">
                          <div class="text-sm font-medium text-gray-900">
                            {User.display_name(user)}
                          </div>
                          <div class="text-sm text-gray-500">{user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <.status_badge status={user.account_status} />
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <.role_badge role={user.role} />
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <.subscription_info user={user} />
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {format_date(user.inserted_at)}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <div class="flex items-center space-x-2">
                        <button
                          phx-click="view_user"
                          phx-value-id={user.id}
                          class="text-blue-600 hover:text-blue-900"
                        >
                          View
                        </button>
                        <%= if user.account_status == "active" do %>
                          <button
                            phx-click="suspend_user"
                            phx-value-id={user.id}
                            class="text-red-600 hover:text-red-900"
                            data-confirm="Are you sure you want to suspend this user?"
                          >
                            Suspend
                          </button>
                        <% else %>
                          <button
                            phx-click="activate_user"
                            phx-value-id={user.id}
                            class="text-green-600 hover:text-green-900"
                          >
                            Activate
                          </button>
                        <% end %>
                        <%= if user.role != "admin" do %>
                          <button
                            phx-click="promote_to_admin"
                            phx-value-id={user.id}
                            class="text-purple-600 hover:text-purple-900"
                            data-confirm="Are you sure you want to promote this user to admin?"
                          >
                            Promote
                          </button>
                        <% end %>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <!-- Pagination -->
          <%= if @total_pages > 1 do %>
            <div class="bg-white px-4 py-3 border-t border-gray-200 sm:px-6">
              <div class="flex items-center justify-between">
                <div class="flex-1 flex justify-between sm:hidden">
                  <%= if @page > 1 do %>
                    <button
                      phx-click="paginate"
                      phx-value-page={@page - 1}
                      class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                    >
                      Previous
                    </button>
                  <% end %>
                  <%= if @page < @total_pages do %>
                    <button
                      phx-click="paginate"
                      phx-value-page={@page + 1}
                      class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                    >
                      Next
                    </button>
                  <% end %>
                </div>
                <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
                  <div>
                    <p class="text-sm text-gray-700">
                      Showing
                      <span class="font-medium">{(@page - 1) * @per_page + 1}</span>
                      to
                      <span class="font-medium">{min(@page * @per_page, @total_count)}</span>
                      of
                      <span class="font-medium">{@total_count}</span>
                      results
                    </p>
                  </div>
                  <div>
                    <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
                      <%= for page_num <- pagination_range(@page, @total_pages) do %>
                        <%= if page_num == "..." do %>
                          <span class="relative inline-flex items-center px-4 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-700">
                            ...
                          </span>
                        <% else %>
                          <button
                            phx-click="paginate"
                            phx-value-page={page_num}
                            class={[
                              "relative inline-flex items-center px-4 py-2 border text-sm font-medium",
                              if(page_num == @page,
                                do: "z-10 bg-blue-50 border-blue-500 text-blue-600",
                                else: "bg-white border-gray-300 text-gray-500 hover:bg-gray-50"
                              )
                            ]}
                          >
                            {page_num}
                          </button>
                        <% end %>
                      <% end %>
                    </nav>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- User Detail Modal -->
      <%= if @show_user_modal && @selected_user do %>
        <.user_detail_modal user={@selected_user} />
      <% end %>
    </div>
    """
  end

  # Component: Sort Icon
  defp sort_icon(assigns) do
    ~H"""
    <%= if @sort_by == @current_sort do %>
      <%= if @current_order == "asc" do %>
        <.icon name="hero-chevron-up" class="w-4 h-4" />
      <% else %>
        <.icon name="hero-chevron-down" class="w-4 h-4" />
      <% end %>
    <% else %>
      <.icon name="hero-chevron-up-down" class="w-4 h-4 text-gray-400" />
    <% end %>
    """
  end

  # Component: Status Badge
  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
      case @status do
        "active" -> "bg-green-100 text-green-800"
        "suspended" -> "bg-red-100 text-red-800"
        "pending" -> "bg-yellow-100 text-yellow-800"
        _ -> "bg-gray-100 text-gray-800"
      end
    ]}>
      {String.capitalize(@status || "unknown")}
    </span>
    """
  end

  # Component: Role Badge
  defp role_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
      case @role do
        "admin" -> "bg-purple-100 text-purple-800"
        "user" -> "bg-blue-100 text-blue-800"
        _ -> "bg-gray-100 text-gray-800"
      end
    ]}>
      {String.capitalize(@role || "user")}
    </span>
    """
  end

  # Component: Subscription Info
  defp subscription_info(assigns) do
    subscription = Billing.get_current_subscription(assigns.user)

    assigns = assign(assigns, :subscription, subscription)

    ~H"""
    <%= if @subscription do %>
      <span class={[
        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
        case @subscription.status do
          "active" -> "bg-green-100 text-green-800"
          "trialing" -> "bg-blue-100 text-blue-800"
          "canceled" -> "bg-red-100 text-red-800"
          _ -> "bg-gray-100 text-gray-800"
        end
      ]}>
        {String.capitalize(@subscription.plan_type)} ({@subscription.status})
      </span>
    <% else %>
      <span class="text-sm text-gray-500">No subscription</span>
    <% end %>
    """
  end

  # Component: User Detail Modal
  defp user_detail_modal(assigns) do
    user_analytics = Analytics.get_user_analytics(assigns.user)
    subscription = Billing.get_current_subscription(assigns.user)

    assigns =
      assigns
      |> assign(:user_analytics, user_analytics)
      |> assign(:subscription, subscription)

    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="close_user_modal"></div>
        
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
        
        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div class="flex items-start justify-between mb-4">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                User Details: {User.display_name(@user)}
              </h3>
              <button
                phx-click="close_user_modal"
                class="bg-white rounded-md text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <span class="sr-only">Close</span>
                <.icon name="hero-x-mark" class="h-6 w-6" />
              </button>
            </div>
            
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <!-- User Information -->
              <div class="space-y-4">
                <div>
                  <h4 class="text-sm font-medium text-gray-900 mb-2">Account Information</h4>
                  <dl class="space-y-2">
                    <div class="flex justify-between">
                      <dt class="text-sm text-gray-500">Email:</dt>
                      <dd class="text-sm text-gray-900">{@user.email}</dd>
                    </div>
                    <div class="flex justify-between">
                      <dt class="text-sm text-gray-500">Status:</dt>
                      <dd><.status_badge status={@user.account_status} /></dd>
                    </div>
                    <div class="flex justify-between">
                      <dt class="text-sm text-gray-500">Role:</dt>
                      <dd><.role_badge role={@user.role} /></dd>
                    </div>
                    <div class="flex justify-between">
                      <dt class="text-sm text-gray-500">Joined:</dt>
                      <dd class="text-sm text-gray-900">{format_date(@user.inserted_at)}</dd>
                    </div>
                    <%= if @user.last_login_at do %>
                      <div class="flex justify-between">
                        <dt class="text-sm text-gray-500">Last Login:</dt>
                        <dd class="text-sm text-gray-900">{format_date(@user.last_login_at)}</dd>
                      </div>
                    <% end %>
                  </dl>
                </div>

                <!-- Subscription Information -->
                <%= if @subscription do %>
                  <div>
                    <h4 class="text-sm font-medium text-gray-900 mb-2">Subscription</h4>
                    <dl class="space-y-2">
                      <div class="flex justify-between">
                        <dt class="text-sm text-gray-500">Plan:</dt>
                        <dd class="text-sm text-gray-900">{String.capitalize(@subscription.plan_type)}</dd>
                      </div>
                      <div class="flex justify-between">
                        <dt class="text-sm text-gray-500">Status:</dt>
                        <dd><.status_badge status={@subscription.status} /></dd>
                      </div>
                      <%= if @subscription.current_period_end do %>
                        <div class="flex justify-between">
                          <dt class="text-sm text-gray-500">Next Billing:</dt>
                          <dd class="text-sm text-gray-900">{format_date(@subscription.current_period_end)}</dd>
                        </div>
                      <% end %>
                    </dl>
                  </div>
                <% end %>
              </div>

              <!-- Usage Analytics -->
              <div class="space-y-4">
                <div>
                  <h4 class="text-sm font-medium text-gray-900 mb-2">Usage Statistics</h4>
                  <div class="grid grid-cols-2 gap-4">
                    <div class="bg-blue-50 rounded-lg p-3">
                      <div class="text-2xl font-bold text-blue-600">
                        {@user_analytics.content.total_generated}
                      </div>
                      <div class="text-sm text-blue-600">Content Generated</div>
                    </div>
                    <div class="bg-green-50 rounded-lg p-3">
                      <div class="text-2xl font-bold text-green-600">
                        {@user_analytics.profile.total_analyses}
                      </div>
                      <div class="text-sm text-green-600">Profile Analyses</div>
                    </div>
                    <div class="bg-purple-50 rounded-lg p-3">
                      <div class="text-2xl font-bold text-purple-600">
                        {@user_analytics.content.favorites_count}
                      </div>
                      <div class="text-sm text-purple-600">Favorites</div>
                    </div>
                    <div class="bg-orange-50 rounded-lg p-3">
                      <div class="text-2xl font-bold text-orange-600">
                        {@user_analytics.profile.avg_score}
                      </div>
                      <div class="text-sm text-orange-600">Avg Profile Score</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <%= if @user.account_status == "active" do %>
              <button
                phx-click="suspend_user"
                phx-value-id={@user.id}
                class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:ml-3 sm:w-auto sm:text-sm"
                data-confirm="Are you sure you want to suspend this user?"
              >
                Suspend User
              </button>
            <% else %>
              <button
                phx-click="activate_user"
                phx-value-id={@user.id}
                class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-green-600 text-base font-medium text-white hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 sm:ml-3 sm:w-auto sm:text-sm"
              >
                Activate User
              </button>
            <% end %>
            <%= if @user.role != "admin" do %>
              <button
                phx-click="promote_to_admin"
                phx-value-id={@user.id}
                class="mt-3 w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-purple-600 text-base font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                data-confirm="Are you sure you want to promote this user to admin?"
              >
                Promote to Admin
              </button>
            <% end %>
            <button
              phx-click="close_user_modal"
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

  # Helper Functions
  defp format_date(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
      %NaiveDateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
      _ -> "N/A"
    end
  end

  defp pagination_range(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        1..total_pages |> Enum.to_list()

      current_page <= 4 ->
        [1, 2, 3, 4, 5, "...", total_pages]

      current_page >= total_pages - 3 ->
        [1, "...", total_pages - 4, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

      true ->
        [1, "...", current_page - 1, current_page, current_page + 1, "...", total_pages]
    end
  end
end