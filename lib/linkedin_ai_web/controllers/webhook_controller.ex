defmodule LinkedinAiWeb.WebhookController do
  @moduledoc """
  Controller for handling external webhooks (Stripe, etc.).
  """

  use LinkedinAiWeb, :controller

  alias LinkedinAi.Billing
  alias LinkedinAi.Billing.StripeClient

  require Logger

  @doc """
  Handles Stripe webhook events.
  """
  def stripe(conn, _params) do
    payload = conn.assigns[:raw_body] || ""
    signature = get_req_header(conn, "stripe-signature") |> List.first()

    if signature do
      endpoint_secret = StripeClient.get_webhook_secret()

      case StripeClient.verify_webhook_signature(payload, signature, endpoint_secret) do
        {:ok, event} ->
          Logger.info("Received Stripe webhook: #{event["type"]}")

          case Billing.handle_webhook_event(event) do
            :ok ->
              conn
              |> put_status(:ok)
              |> json(%{received: true})

            :error ->
              Logger.error("Failed to process Stripe webhook: #{event["type"]}")

              conn
              |> put_status(:bad_request)
              |> json(%{error: "Failed to process webhook"})
          end

        {:error, reason} ->
          Logger.error("Stripe webhook signature verification failed: #{inspect(reason)}")

          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid signature"})
      end
    else
      Logger.error("Missing Stripe signature header")

      conn
      |> put_status(:bad_request)
      |> json(%{error: "Missing signature"})
    end
  end
end
