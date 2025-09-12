defmodule LinkedinAiWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use LinkedinAiWeb, :controller` and
  `use LinkedinAiWeb, :live_view`.
  """
  use LinkedinAiWeb, :html

  alias LinkedinAi.Accounts.User
  alias LinkedinAi.Billing

  embed_templates "layouts/*"

  @doc """
  Renders the sidebar content with navigation links.
  """
  def sidebar_content(assigns) do
    ~H"""
    <div class="flex h-16 shrink-0 items-center">
      <div class="flex items-center space-x-2">
        <div class="w-8 h-8 bg-gradient-to-r from-blue-500 to-indigo-600 rounded-lg flex items-center justify-center">
          <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
            <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
          </svg>
        </div>
        <span class="text-xl font-bold bg-gradient-to-r from-blue-600 to-indigo-600 bg-clip-text text-transparent">
          LinkedIn AI
        </span>
      </div>
    </div>

    <nav class="flex flex-1 flex-col">
      <ul role="list" class="flex flex-1 flex-col gap-y-7">
        <li>
          <ul role="list" class="-mx-2 space-y-1">
            <.nav_item href="/dashboard" icon="hero-home" current={@current_path == "/dashboard"}>
              Dashboard
            </.nav_item>
            <.nav_item href="/content" icon="hero-document-text" current={@current_path == "/content"}>
              Content Generation
            </.nav_item>
            <.nav_item href="/profile" icon="hero-user-circle" current={@current_path == "/profile"}>
              Profile Optimization
            </.nav_item>
            <.nav_item href="/analytics" icon="hero-chart-bar" current={@current_path == "/analytics"}>
              Analytics
            </.nav_item>
            <.nav_item
              href="/templates"
              icon="hero-document-duplicate"
              current={@current_path == "/templates"}
            >
              Templates
            </.nav_item>
          </ul>
        </li>

        <li>
          <div class="text-xs font-semibold leading-6 text-gray-400">Account</div>
          <ul role="list" class="-mx-2 mt-2 space-y-1">
            <.nav_item
              href="/subscription"
              icon="hero-credit-card"
              current={@current_path == "/subscription"}
            >
              Subscription
            </.nav_item>
            <.nav_item
              href="/users/settings"
              icon="hero-cog-6-tooth"
              current={@current_path == "/users/settings"}
            >
              Settings
            </.nav_item>
          </ul>
        </li>
        
    <!-- Admin section (if user is admin) -->
        <%= if User.admin?(@current_user) do %>
          <li>
            <div class="text-xs font-semibold leading-6 text-gray-400">Admin</div>
            <ul role="list" class="-mx-2 mt-2 space-y-1">
              <.nav_item href="/admin" icon="hero-shield-check" current={@current_path == "/admin"}>
                Admin Panel
              </.nav_item>
              <.nav_item
                href="/admin/users"
                icon="hero-users"
                current={@current_path == "/admin/users"}
              >
                Users
              </.nav_item>
              <.nav_item
                href="/admin/analytics"
                icon="hero-chart-pie"
                current={@current_path == "/admin/analytics"}
              >
                Platform Analytics
              </.nav_item>
            </ul>
          </li>
        <% end %>
        
    <!-- User info at bottom -->
        <li class="mt-auto">
          <div class="flex items-center gap-x-4 px-6 py-3 text-sm font-semibold leading-6 text-gray-900 bg-gray-50 rounded-lg">
            <div class="h-8 w-8 rounded-full bg-gradient-to-r from-blue-500 to-indigo-600 flex items-center justify-center">
              <span class="text-sm font-medium text-white">
                {String.first(User.display_name(@current_user))}
              </span>
            </div>
            <span class="sr-only">Your profile</span>
            <span aria-hidden="true">{User.display_name(@current_user)}</span>
          </div>
        </li>
      </ul>
    </nav>
    """
  end

  @doc """
  Renders a navigation item.
  """
  def nav_item(assigns) do
    ~H"""
    <li>
      <.link
        href={@href}
        class={[
          "group flex gap-x-3 rounded-md p-2 text-sm leading-6 font-semibold transition-colors duration-200",
          if(@current,
            do: "bg-blue-50 text-blue-700",
            else: "text-gray-700 hover:text-blue-700 hover:bg-gray-50"
          )
        ]}
      >
        <.icon
          name={@icon}
          class={"h-6 w-6 shrink-0 transition-colors duration-200 #{if @current, do: "text-blue-700", else: "text-gray-400 group-hover:text-blue-700"}"}
        />
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end

  @doc """
  Renders breadcrumbs based on current path.
  """
  def breadcrumbs(assigns) do
    current_path = assigns[:current_path] || "/"
    breadcrumbs = build_breadcrumbs(current_path)
    assigns = assign(assigns, :breadcrumbs, breadcrumbs)

    ~H"""
    <nav class="flex" aria-label="Breadcrumb">
      <ol role="list" class="flex items-center space-x-4">
        <li>
          <div>
            <.link href="/dashboard" class="text-gray-400 hover:text-gray-500">
              <.icon name="hero-home" class="h-5 w-5 flex-shrink-0" />
              <span class="sr-only">Home</span>
            </.link>
          </div>
        </li>
        <%= for {name, path, is_current} <- @breadcrumbs do %>
          <li>
            <div class="flex items-center">
              <svg class="h-5 w-5 flex-shrink-0 text-gray-300" fill="currentColor" viewBox="0 0 20 20">
                <path d="M5.555 17.776l8-16 .894.448-8 16-.894-.448z" />
              </svg>
              <%= if is_current do %>
                <span class="ml-4 text-sm font-medium text-gray-500">{name}</span>
              <% else %>
                <.link href={path} class="ml-4 text-sm font-medium text-gray-500 hover:text-gray-700">
                  {name}
                </.link>
              <% end %>
            </div>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  @doc """
  Renders subscription status indicator.
  """
  def subscription_indicator(assigns) do
    subscription = Billing.get_current_subscription(assigns.current_user)
    has_active = Billing.has_active_subscription?(assigns.current_user)

    assigns = assign(assigns, :subscription, subscription)
    assigns = assign(assigns, :has_active, has_active)

    ~H"""
    <div class="flex items-center gap-x-2">
      <%= if @has_active do %>
        <div class="flex items-center gap-x-1.5">
          <div class="flex-none rounded-full bg-emerald-500/20 p-1">
            <div class="h-1.5 w-1.5 rounded-full bg-emerald-500"></div>
          </div>
          <p class="text-xs leading-5 text-gray-500">
            {String.capitalize(@subscription.plan_type)} Plan
          </p>
        </div>
      <% else %>
        <div class="flex items-center gap-x-1.5">
          <div class="flex-none rounded-full bg-yellow-500/20 p-1">
            <div class="h-1.5 w-1.5 rounded-full bg-yellow-500"></div>
          </div>
          <p class="text-xs leading-5 text-gray-500">Free Trial</p>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders profile dropdown menu.
  """
  def profile_dropdown(assigns) do
    ~H"""
    <div class="relative">
      <button type="button" class="-m-1.5 flex items-center p-1.5" id="user-menu-button">
        <span class="sr-only">Open user menu</span>
        <div class="h-8 w-8 rounded-full bg-gradient-to-r from-blue-500 to-indigo-600 flex items-center justify-center">
          <span class="text-sm font-medium text-white">
            {String.first(User.display_name(@current_user))}
          </span>
        </div>
        <span class="hidden lg:flex lg:items-center">
          <span class="ml-4 text-sm font-semibold leading-6 text-gray-900">
            {User.display_name(@current_user)}
          </span>
          <svg class="ml-2 h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
            <path
              fill-rule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
              clip-rule="evenodd"
            />
          </svg>
        </span>
      </button>
      
    <!-- Dropdown menu (hidden by default) -->
      <div
        class="absolute right-0 z-10 mt-2.5 w-32 origin-top-right rounded-md bg-white py-2 shadow-lg ring-1 ring-gray-900/5 hidden"
        id="user-menu"
      >
        <.link
          href="/users/settings"
          class="block px-3 py-1 text-sm leading-6 text-gray-900 hover:bg-gray-50"
        >
          Settings
        </.link>
        <.link
          href="/users/log_out"
          method="delete"
          class="block px-3 py-1 text-sm leading-6 text-gray-900 hover:bg-gray-50"
        >
          Sign out
        </.link>
      </div>
    </div>

    <script>
      document.addEventListener('DOMContentLoaded', function() {
        const menuButton = document.getElementById('user-menu-button');
        const menu = document.getElementById('user-menu');

        if (menuButton && menu) {
          menuButton.addEventListener('click', function() {
            menu.classList.toggle('hidden');
          });

          // Close menu when clicking outside
          document.addEventListener('click', function(event) {
            if (!menuButton.contains(event.target) && !menu.contains(event.target)) {
              menu.classList.add('hidden');
            }
          });
        }
      });
    </script>
    """
  end

  # Helper function to build breadcrumbs based on current path
  defp build_breadcrumbs(path) do
    case path do
      "/dashboard" ->
        []

      "/content" ->
        [{"Content Generation", "/content", true}]

      "/content/new" ->
        [{"Content Generation", "/content", false}, {"New Content", "/content/new", true}]

      "/profile" ->
        [{"Profile Optimization", "/profile", true}]

      "/analytics" ->
        [{"Analytics", "/analytics", true}]

      "/templates" ->
        [{"Templates", "/templates", true}]

      "/subscription" ->
        [{"Subscription", "/subscription", true}]

      "/users/settings" ->
        [{"Settings", "/users/settings", true}]

      "/admin" ->
        [{"Admin Panel", "/admin", true}]

      "/admin/users" ->
        [{"Admin Panel", "/admin", false}, {"Users", "/admin/users", true}]

      "/admin/analytics" ->
        [{"Admin Panel", "/admin", false}, {"Analytics", "/admin/analytics", true}]

      _ ->
        []
    end
  end
end
