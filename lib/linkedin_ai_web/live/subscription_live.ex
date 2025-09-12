defmodule LinkedinAiWeb.SubscriptionLive do
  @moduledoc """
  Subscription management LiveView for pricing, billing, and plan management.
  """

  use LinkedinAiWeb, :live_view

  alias LinkedinAi.Billing

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "Subscription")
      |> assign(:subscription, Billing.get_current_subscription(user))
      |> assign(:has_active, Billing.has_active_subscription?(user))
      |> assign(:plans, Billing.get_subscription_plans())
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("subscribe", %{"plan" => plan_type}, socket) do
    user = socket.assigns.current_user
    success_url = "#{get_base_url()}/subscription/success"
    cancel_url = "#{get_base_url()}/subscription"

    socket = assign(socket, :loading, true)

    case Billing.create_checkout_session(user, plan_type, success_url, cancel_url) do
      {:ok, %{checkout_url: checkout_url}} ->
        {:noreply, redirect(socket, external: checkout_url)}

      {:error, reason} ->
        message =
          case reason do
            :invalid_plan -> "Invalid subscription plan selected"
            :checkout_creation_failed -> "Failed to create checkout session"
            _ -> "An error occurred. Please try again."
          end

        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(:error, message)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("manage_billing", _params, socket) do
    user = socket.assigns.current_user
    return_url = "#{get_base_url()}/subscription"

    case Billing.create_portal_session(user, return_url) do
      {:ok, %{portal_url: portal_url}} ->
        {:noreply, redirect(socket, external: portal_url)}

      {:error, _reason} ->
        socket = put_flash(socket, :error, "Failed to open billing portal. Please try again.")
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <!-- Header -->
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold text-gray-900">Choose Your Plan</h1>
        <p class="mt-4 text-xl text-gray-600">
          Unlock the full power of AI-driven LinkedIn optimization
        </p>
      </div>

      <%= if @has_active do %>
        <!-- Current Subscription -->
        <.current_subscription_card subscription={@subscription} />
      <% end %>
      
    <!-- Pricing Plans -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 max-w-5xl mx-auto mb-12">
        <%= for plan <- @plans do %>
          <.pricing_card
            plan={plan}
            current_plan={@subscription && @subscription.plan_type}
            has_active={@has_active}
            loading={@loading}
          />
        <% end %>
      </div>
      
    <!-- Features Comparison -->
      <.features_comparison />
      
    <!-- FAQ Section -->
      <.faq_section />
    </div>
    """
  end

  # Component: Current Subscription Card
  defp current_subscription_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6 mb-8">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-lg font-medium text-gray-900">Current Subscription</h2>
          <div class="mt-2 flex items-center space-x-4">
            <span class="text-2xl font-bold text-gray-900">
              {String.capitalize(@subscription.plan_type)} Plan
            </span>
            <span class={[
              "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
              case @subscription.status do
                "active" -> "bg-green-100 text-green-800"
                "trialing" -> "bg-blue-100 text-blue-800"
                "past_due" -> "bg-yellow-100 text-yellow-800"
                "canceled" -> "bg-red-100 text-red-800"
                _ -> "bg-gray-100 text-gray-800"
              end
            ]}>
              {String.capitalize(@subscription.status)}
            </span>
          </div>
          <p class="mt-1 text-sm text-gray-500">
            <%= if @subscription.cancel_at_period_end do %>
              Cancels on {Calendar.strftime(@subscription.current_period_end, "%B %d, %Y")}
            <% else %>
              Renews on {Calendar.strftime(@subscription.current_period_end, "%B %d, %Y")}
            <% end %>
          </p>
        </div>

        <div class="flex space-x-3">
          <button
            phx-click="manage_billing"
            class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-cog-6-tooth" class="h-4 w-4 mr-2" /> Manage Billing
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Component: Pricing Card
  defp pricing_card(assigns) do
    is_current = assigns.current_plan == assigns.plan.id
    is_popular = assigns.plan.id == "pro"

    assigns = assign(assigns, :is_current, is_current)
    assigns = assign(assigns, :is_popular, is_popular)

    ~H"""
    <div class={[
      "relative rounded-2xl border p-8 shadow-sm",
      if(@is_popular, do: "border-blue-500 ring-2 ring-blue-500", else: "border-gray-200"),
      if(@is_current, do: "bg-blue-50", else: "bg-white")
    ]}>
      <%= if @is_popular do %>
        <div class="absolute -top-4 left-1/2 transform -translate-x-1/2">
          <span class="inline-flex items-center px-4 py-1 rounded-full text-sm font-medium bg-blue-500 text-white">
            Most Popular
          </span>
        </div>
      <% end %>

      <%= if @is_current do %>
        <div class="absolute -top-4 right-4">
          <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-500 text-white">
            Current Plan
          </span>
        </div>
      <% end %>

      <div class="text-center">
        <h3 class="text-2xl font-bold text-gray-900">{@plan.name}</h3>
        <div class="mt-4 flex items-center justify-center">
          <span class="text-5xl font-bold text-gray-900">${@plan.price}</span>
          <span class="text-xl text-gray-500 ml-2">/{@plan.interval}</span>
        </div>
      </div>

      <ul class="mt-8 space-y-4">
        <%= for feature <- @plan.features do %>
          <li class="flex items-start">
            <div class="flex-shrink-0">
              <.icon name="hero-check" class="h-5 w-5 text-green-500" />
            </div>
            <span class="ml-3 text-sm text-gray-700">{feature}</span>
          </li>
        <% end %>
      </ul>

      <div class="mt-8">
        <%= if @is_current do %>
          <button
            disabled
            class="w-full py-3 px-4 rounded-md text-sm font-medium text-gray-500 bg-gray-100 cursor-not-allowed"
          >
            Current Plan
          </button>
        <% else %>
          <button
            phx-click="subscribe"
            phx-value-plan={@plan.id}
            disabled={@loading}
            class={[
              "w-full py-3 px-4 rounded-md text-sm font-medium transition-colors duration-200",
              if(@is_popular,
                do:
                  "bg-blue-600 text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
                else:
                  "bg-gray-900 text-white hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
              ),
              if(@loading, do: "opacity-50 cursor-not-allowed", else: "")
            ]}
          >
            <%= if @loading do %>
              <.icon name="hero-arrow-path" class="animate-spin h-4 w-4 mr-2 inline" /> Processing...
            <% else %>
              <%= if @has_active do %>
                Upgrade to {@plan.name}
              <% else %>
                Start {@plan.name} Plan
              <% end %>
            <% end %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # Component: Features Comparison
  defp features_comparison(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-8 mb-12">
      <h2 class="text-2xl font-bold text-gray-900 text-center mb-8">Feature Comparison</h2>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Feature
              </th>
              <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                Basic Plan
              </th>
              <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                Pro Plan
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <.feature_row feature="AI Content Generation" basic="10 posts/month" pro="Unlimited" />
            <.feature_row feature="Profile Analysis" basic="1 analysis/month" pro="Unlimited" />
            <.feature_row feature="Analytics History" basic="30 days" pro="Unlimited" />
            <.feature_row feature="Content Templates" basic="Basic templates" pro="Premium templates" />
            <.feature_row feature="Competitor Analysis" basic={false} pro={true} />
            <.feature_row feature="Priority Support" basic={false} pro={true} />
            <.feature_row feature="Advanced Analytics" basic={false} pro={true} />
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Component: Feature Row
  defp feature_row(assigns) do
    ~H"""
    <tr>
      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
        {@feature}
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
        <%= case @basic do %>
          <% true -> %>
            <.icon name="hero-check" class="h-5 w-5 text-green-500 mx-auto" />
          <% false -> %>
            <.icon name="hero-x-mark" class="h-5 w-5 text-red-500 mx-auto" />
          <% value -> %>
            {value}
        <% end %>
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
        <%= case @pro do %>
          <% true -> %>
            <.icon name="hero-check" class="h-5 w-5 text-green-500 mx-auto" />
          <% false -> %>
            <.icon name="hero-x-mark" class="h-5 w-5 text-red-500 mx-auto" />
          <% value -> %>
            {value}
        <% end %>
      </td>
    </tr>
    """
  end

  # Component: FAQ Section
  defp faq_section(assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-lg p-8">
      <h2 class="text-2xl font-bold text-gray-900 text-center mb-8">Frequently Asked Questions</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div class="space-y-6">
          <.faq_item
            question="Can I change my plan anytime?"
            answer="Yes, you can upgrade or downgrade your plan at any time. Changes will be prorated and reflected in your next billing cycle."
          />

          <.faq_item
            question="What happens if I cancel?"
            answer="You can cancel anytime. Your subscription will remain active until the end of your current billing period, after which you'll have access to the free tier."
          />

          <.faq_item
            question="Do you offer refunds?"
            answer="We offer a 30-day money-back guarantee for all new subscriptions. Contact our support team if you're not satisfied."
          />
        </div>

        <div class="space-y-6">
          <.faq_item
            question="Is my LinkedIn data secure?"
            answer="Absolutely. We use industry-standard encryption and only access the minimum data needed to provide our services. We never post on your behalf without permission."
          />

          <.faq_item
            question="How does the AI content generation work?"
            answer="Our AI analyzes your industry, role, and preferences to generate personalized LinkedIn content that matches your professional voice and goals."
          />

          <.faq_item
            question="Can I use this for multiple LinkedIn accounts?"
            answer="Each subscription is for one LinkedIn account. Contact us for team or enterprise pricing if you need multiple accounts."
          />
        </div>
      </div>
    </div>
    """
  end

  # Component: FAQ Item
  defp faq_item(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-medium text-gray-900 mb-2">{@question}</h3>
      <p class="text-gray-600">{@answer}</p>
    </div>
    """
  end

  # Helper function to get base URL
  defp get_base_url do
    Application.get_env(:linkedin_ai, :app_url, "http://localhost:4000")
  end
end
