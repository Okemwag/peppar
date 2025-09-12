defmodule LinkedinAi.Billing.StripeClient do
  @moduledoc """
  Stripe API client for handling payment and subscription operations.
  """

  require Logger

  @base_url "https://api.stripe.com/v1"

  ## Public API

  @doc """
  Creates a Stripe checkout session.

  ## Examples

      iex> create_checkout_session(%{customer: "cus_123", line_items: [...]})
      {:ok, %{"id" => "cs_123", "url" => "https://checkout.stripe.com/..."}}

  """
  def create_checkout_session(params) do
    post("/checkout/sessions", params)
  end

  @doc """
  Creates a Stripe customer portal session.

  ## Examples

      iex> create_portal_session(%{customer: "cus_123", return_url: "https://..."})
      {:ok, %{"url" => "https://billing.stripe.com/..."}}

  """
  def create_portal_session(params) do
    post("/billing_portal/sessions", params)
  end

  @doc """
  Creates a Stripe customer.

  ## Examples

      iex> create_customer(%{email: "user@example.com", name: "John Doe"})
      {:ok, %{"id" => "cus_123", "email" => "user@example.com"}}

  """
  def create_customer(params) do
    post("/customers", params)
  end

  @doc """
  Retrieves a Stripe customer.

  ## Examples

      iex> get_customer("cus_123")
      {:ok, %{"id" => "cus_123", "email" => "user@example.com"}}

  """
  def get_customer(customer_id) do
    get("/customers/#{customer_id}")
  end

  @doc """
  Updates a Stripe customer.

  ## Examples

      iex> update_customer("cus_123", %{name: "Jane Doe"})
      {:ok, %{"id" => "cus_123", "name" => "Jane Doe"}}

  """
  def update_customer(customer_id, params) do
    post("/customers/#{customer_id}", params)
  end

  @doc """
  Retrieves a Stripe subscription.

  ## Examples

      iex> get_subscription("sub_123")
      {:ok, %{"id" => "sub_123", "status" => "active"}}

  """
  def get_subscription(subscription_id) do
    get("/subscriptions/#{subscription_id}")
  end

  @doc """
  Updates a Stripe subscription.

  ## Examples

      iex> update_subscription("sub_123", %{cancel_at_period_end: true})
      {:ok, %{"id" => "sub_123", "cancel_at_period_end" => true}}

  """
  def update_subscription(subscription_id, params) do
    post("/subscriptions/#{subscription_id}", params)
  end

  @doc """
  Cancels a Stripe subscription.

  ## Examples

      iex> cancel_subscription("sub_123")
      {:ok, %{"id" => "sub_123", "status" => "canceled"}}

  """
  def cancel_subscription(subscription_id) do
    delete("/subscriptions/#{subscription_id}")
  end

  @doc """
  Lists Stripe invoices for a customer.

  ## Examples

      iex> list_invoices("cus_123")
      {:ok, %{"data" => [%{"id" => "in_123", ...}]}}

  """
  def list_invoices(customer_id, params \\ %{}) do
    query_params = Map.put(params, :customer, customer_id)
    get("/invoices", query_params)
  end

  @doc """
  Verifies a Stripe webhook signature.

  ## Examples

      iex> verify_webhook_signature(payload, signature, endpoint_secret)
      {:ok, %{"type" => "customer.subscription.created", ...}}

  """
  def verify_webhook_signature(payload, signature, endpoint_secret) do
    case Stripe.Webhook.construct_event(payload, signature, endpoint_secret) do
      {:ok, event} -> {:ok, event}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error ->
      Logger.error("Webhook signature verification failed: #{inspect(error)}")
      {:error, :invalid_signature}
  end

  ## Private HTTP Functions

  defp get(path, params \\ %{}) do
    url = @base_url <> path
    query_string = URI.encode_query(params)
    full_url = if query_string != "", do: url <> "?" <> query_string, else: url

    case HTTPoison.get(full_url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Stripe API error: #{status_code} - #{body}")
        {:error, parse_error_response(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp post(path, params) do
    url = @base_url <> path
    body = URI.encode_query(flatten_params(params))

    case HTTPoison.post(url, body, headers()) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}}
      when status_code in [200, 201] ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("Stripe API error: #{status_code} - #{response_body}")
        {:error, parse_error_response(response_body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp delete(path) do
    url = @base_url <> path

    case HTTPoison.delete(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Stripe API error: #{status_code} - #{body}")
        {:error, parse_error_response(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp headers do
    api_key = get_api_key()
    auth_header = "Bearer #{api_key}"

    [
      {"Authorization", auth_header},
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Stripe-Version", "2023-10-16"}
    ]
  end

  defp get_api_key do
    case Application.get_env(:stripity_stripe, :api_key) do
      nil ->
        raise "Stripe API key not configured. Please set :stripity_stripe, :api_key in your config."

      api_key when is_binary(api_key) ->
        api_key

      {:system, env_var} ->
        System.get_env(env_var) ||
          raise "Stripe API key environment variable #{env_var} not set."
    end
  end

  defp parse_error_response(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} ->
        %{
          type: Map.get(error, "type"),
          code: Map.get(error, "code"),
          message: Map.get(error, "message")
        }

      _ ->
        %{type: "api_error", message: "Unknown error occurred"}
    end
  end

  # Flattens nested maps for Stripe's form-encoded API
  defp flatten_params(params, prefix \\ "") do
    Enum.reduce(params, [], fn {key, value}, acc ->
      new_key = if prefix == "", do: to_string(key), else: "#{prefix}[#{key}]"

      case value do
        %{} = map ->
          flatten_params(map, new_key) ++ acc

        list when is_list(list) ->
          list
          |> Enum.with_index()
          |> Enum.reduce(acc, fn {item, index}, list_acc ->
            item_key = "#{new_key}[#{index}]"

            case item do
              %{} = item_map ->
                flatten_params(item_map, item_key) ++ list_acc

              _ ->
                [{item_key, to_string(item)} | list_acc]
            end
          end)

        _ ->
          [{new_key, to_string(value)} | acc]
      end
    end)
  end

  ## Webhook Helpers

  @doc """
  Constructs a webhook endpoint URL for the application.

  ## Examples

      iex> webhook_endpoint_url()
      "https://myapp.com/webhooks/stripe"

  """
  def webhook_endpoint_url do
    base_url = Application.get_env(:linkedin_ai, :app_url, "http://localhost:4000")
    "#{base_url}/webhooks/stripe"
  end

  @doc """
  Gets the webhook endpoint secret from configuration.

  ## Examples

      iex> get_webhook_secret()
      "whsec_..."

  """
  def get_webhook_secret do
    case Application.get_env(:stripity_stripe, :webhook_secret) do
      nil ->
        raise "Stripe webhook secret not configured. Please set :stripity_stripe, :webhook_secret in your config."

      secret when is_binary(secret) ->
        secret

      {:system, env_var} ->
        System.get_env(env_var) ||
          raise "Stripe webhook secret environment variable #{env_var} not set."
    end
  end
end
