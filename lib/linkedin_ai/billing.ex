defmodule LinkedinAi.Billing do
  @moduledoc """
  The Billing context.
  Handles Stripe integration for subscription management and payment processing.
  """

  alias LinkedinAi.Subscriptions
  alias LinkedinAi.Accounts.User
  alias LinkedinAi.Subscriptions.Subscription
  alias LinkedinAi.Billing.StripeClient

  require Logger

  ## Subscription Management

  @doc """
  Creates a Stripe checkout session for subscription.

  ## Examples

      iex> create_checkout_session(user, "basic", "http://localhost:4000/success")
      {:ok, %{checkout_url: "https://checkout.stripe.com/...", session_id: "cs_..."}}

      iex> create_checkout_session(user, "invalid_plan", success_url)
      {:error, :invalid_plan}

  """
  def create_checkout_session(%User{} = user, plan_type, success_url, cancel_url \\ nil) do
    cancel_url = cancel_url || success_url

    case validate_plan_type(plan_type) do
      {:ok, price_id} ->
        # Create or get Stripe customer
        case ensure_stripe_customer(user) do
          {:ok, customer_id} ->
            session_params = %{
              customer: customer_id,
              payment_method_types: ["card"],
              line_items: [
                %{
                  price: price_id,
                  quantity: 1
                }
              ],
              mode: "subscription",
              success_url: success_url <> "?session_id={CHECKOUT_SESSION_ID}",
              cancel_url: cancel_url,
              metadata: %{
                user_id: user.id,
                plan_type: plan_type
              },
              subscription_data: %{
                metadata: %{
                  user_id: user.id,
                  plan_type: plan_type
                }
              }
            }

            case StripeClient.create_checkout_session(session_params) do
              {:ok, session} ->
                {:ok,
                 %{
                   checkout_url: session["url"],
                   session_id: session["id"]
                 }}

              {:error, reason} ->
                Logger.error("Failed to create Stripe checkout session: #{inspect(reason)}")
                {:error, :checkout_creation_failed}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a Stripe customer portal session for subscription management.

  ## Examples

      iex> create_portal_session(user, "http://localhost:4000/dashboard")
      {:ok, %{portal_url: "https://billing.stripe.com/..."}}

  """
  def create_portal_session(%User{} = user, return_url) do
    case get_stripe_customer_id(user) do
      {:ok, customer_id} ->
        portal_params = %{
          customer: customer_id,
          return_url: return_url
        }

        case StripeClient.create_portal_session(portal_params) do
          {:ok, session} ->
            {:ok, %{portal_url: session["url"]}}

          {:error, reason} ->
            Logger.error("Failed to create Stripe portal session: #{inspect(reason)}")
            {:error, :portal_creation_failed}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles Stripe webhook events.

  ## Examples

      iex> handle_webhook_event(%{"type" => "customer.subscription.created", "data" => %{...}})
      :ok

  """
  def handle_webhook_event(%{"type" => event_type, "data" => %{"object" => object}}) do
    case event_type do
      "customer.subscription.created" ->
        handle_subscription_created(object)

      "customer.subscription.updated" ->
        handle_subscription_updated(object)

      "customer.subscription.deleted" ->
        handle_subscription_deleted(object)

      "invoice.payment_succeeded" ->
        handle_payment_succeeded(object)

      "invoice.payment_failed" ->
        handle_payment_failed(object)

      _ ->
        Logger.info("Unhandled Stripe webhook event: #{event_type}")
        :ok
    end
  end

  def handle_webhook_event(event) do
    Logger.warning("Invalid webhook event format: #{inspect(event)}")
    :error
  end

  ## Private Functions

  defp validate_plan_type("basic") do
    price_id = Application.get_env(:linkedin_ai, :stripe_basic_price_id) || "price_basic_test"
    {:ok, price_id}
  end

  defp validate_plan_type("pro") do
    price_id = Application.get_env(:linkedin_ai, :stripe_pro_price_id) || "price_pro_test"
    {:ok, price_id}
  end

  defp validate_plan_type(_), do: {:error, :invalid_plan}

  defp ensure_stripe_customer(%User{} = user) do
    case get_stripe_customer_id(user) do
      {:ok, customer_id} ->
        {:ok, customer_id}

      {:error, :no_customer} ->
        create_stripe_customer(user)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_stripe_customer_id(%User{} = user) do
    case Subscriptions.get_subscription_by_user_id(user.id) do
      %Subscription{stripe_customer_id: customer_id} when is_binary(customer_id) ->
        {:ok, customer_id}

      _ ->
        {:error, :no_customer}
    end
  end

  defp create_stripe_customer(%User{} = user) do
    customer_params = %{
      email: user.email,
      name: User.display_name(user),
      metadata: %{
        user_id: user.id
      }
    }

    case StripeClient.create_customer(customer_params) do
      {:ok, customer} ->
        {:ok, customer["id"]}

      {:error, reason} ->
        Logger.error("Failed to create Stripe customer: #{inspect(reason)}")
        {:error, :customer_creation_failed}
    end
  end

  ## Webhook Handlers

  defp handle_subscription_created(subscription) do
    user_id = get_in(subscription, ["metadata", "user_id"])
    plan_type = get_in(subscription, ["metadata", "plan_type"])

    if user_id && plan_type do
      subscription_attrs = %{
        user_id: String.to_integer(user_id),
        stripe_subscription_id: subscription["id"],
        stripe_customer_id: subscription["customer"],
        plan_type: plan_type,
        status: subscription["status"],
        current_period_start: unix_to_datetime(subscription["current_period_start"]),
        current_period_end: unix_to_datetime(subscription["current_period_end"]),
        trial_start: unix_to_datetime(subscription["trial_start"]),
        trial_end: unix_to_datetime(subscription["trial_end"])
      }

      case Subscriptions.create_subscription(subscription_attrs) do
        {:ok, _subscription} ->
          Logger.info("Created subscription for user #{user_id}")
          :ok

        {:error, changeset} ->
          Logger.error("Failed to create subscription: #{inspect(changeset.errors)}")
          :error
      end
    else
      Logger.error("Missing user_id or plan_type in subscription metadata")
      :error
    end
  end

  defp handle_subscription_updated(subscription) do
    case Subscriptions.get_subscription_by_stripe_id(subscription["id"]) do
      %Subscription{} = existing_subscription ->
        update_attrs = %{
          status: subscription["status"],
          current_period_start: unix_to_datetime(subscription["current_period_start"]),
          current_period_end: unix_to_datetime(subscription["current_period_end"]),
          cancel_at_period_end: subscription["cancel_at_period_end"],
          canceled_at: unix_to_datetime(subscription["canceled_at"]),
          trial_start: unix_to_datetime(subscription["trial_start"]),
          trial_end: unix_to_datetime(subscription["trial_end"])
        }

        case Subscriptions.update_subscription(existing_subscription, update_attrs) do
          {:ok, _subscription} ->
            Logger.info("Updated subscription #{subscription["id"]}")
            :ok

          {:error, changeset} ->
            Logger.error("Failed to update subscription: #{inspect(changeset.errors)}")
            :error
        end

      nil ->
        Logger.error("Subscription not found: #{subscription["id"]}")
        :error
    end
  end

  defp handle_subscription_deleted(subscription) do
    case Subscriptions.get_subscription_by_stripe_id(subscription["id"]) do
      %Subscription{} = existing_subscription ->
        update_attrs = %{
          status: "canceled",
          canceled_at: DateTime.utc_now()
        }

        case Subscriptions.update_subscription(existing_subscription, update_attrs) do
          {:ok, _subscription} ->
            Logger.info("Canceled subscription #{subscription["id"]}")
            :ok

          {:error, changeset} ->
            Logger.error("Failed to cancel subscription: #{inspect(changeset.errors)}")
            :error
        end

      nil ->
        Logger.error("Subscription not found for deletion: #{subscription["id"]}")
        :error
    end
  end

  defp handle_payment_succeeded(invoice) do
    subscription_id = invoice["subscription"]

    if subscription_id do
      case Subscriptions.get_subscription_by_stripe_id(subscription_id) do
        %Subscription{} = subscription ->
          # Update subscription status to active if it was past_due
          if subscription.status == "past_due" do
            case Subscriptions.update_subscription(subscription, %{status: "active"}) do
              {:ok, _} ->
                Logger.info(
                  "Reactivated subscription #{subscription_id} after successful payment"
                )

              {:error, changeset} ->
                Logger.error("Failed to reactivate subscription: #{inspect(changeset.errors)}")
            end
          end

          :ok

        nil ->
          Logger.error("Subscription not found for payment: #{subscription_id}")
          :error
      end
    else
      Logger.info("Payment succeeded for non-subscription invoice")
      :ok
    end
  end

  defp handle_payment_failed(invoice) do
    subscription_id = invoice["subscription"]

    if subscription_id do
      case Subscriptions.get_subscription_by_stripe_id(subscription_id) do
        %Subscription{} = subscription ->
          case Subscriptions.update_subscription(subscription, %{status: "past_due"}) do
            {:ok, _} ->
              Logger.info(
                "Marked subscription #{subscription_id} as past_due after failed payment"
              )

            {:error, changeset} ->
              Logger.error("Failed to update subscription status: #{inspect(changeset.errors)}")
          end

          :ok

        nil ->
          Logger.error("Subscription not found for failed payment: #{subscription_id}")
          :error
      end
    else
      Logger.info("Payment failed for non-subscription invoice")
      :ok
    end
  end

  ## Utility Functions

  defp unix_to_datetime(nil), do: nil

  defp unix_to_datetime(unix_timestamp) when is_integer(unix_timestamp) do
    DateTime.from_unix!(unix_timestamp)
  end

  ## Public API Functions

  @doc """
  Gets subscription plans with pricing information.

  ## Examples

      iex> get_subscription_plans()
      [%{id: "basic", name: "Basic Plan", price: 25.00, ...}, ...]

  """
  def get_subscription_plans do
    [
      %{
        id: "basic",
        name: "Basic Plan",
        price: 25.00,
        currency: "USD",
        interval: "month",
        features: [
          "10 AI-generated posts per month",
          "Basic profile analysis",
          "30-day analytics history",
          "Email support"
        ]
      },
      %{
        id: "pro",
        name: "Pro Plan",
        price: 45.00,
        currency: "USD",
        interval: "month",
        features: [
          "Unlimited AI-generated content",
          "Advanced profile optimization",
          "Unlimited analytics history",
          "Competitor analysis",
          "Priority support"
        ]
      }
    ]
  end

  @doc """
  Checks if a user has an active subscription.

  ## Examples

      iex> has_active_subscription?(user)
      true

  """
  def has_active_subscription?(%User{} = user) do
    case Subscriptions.get_subscription_by_user_id(user.id) do
      %Subscription{status: "active"} -> true
      %Subscription{status: "trialing"} -> true
      _ -> false
    end
  end

  @doc """
  Gets the current subscription for a user.

  ## Examples

      iex> get_current_subscription(user)
      %Subscription{}

  """
  def get_current_subscription(%User{} = user) do
    Subscriptions.get_subscription_by_user_id(user.id)
  end
end
