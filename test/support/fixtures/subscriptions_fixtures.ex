defmodule LinkedinAi.SubscriptionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LinkedinAi.Subscriptions` context.
  """

  alias LinkedinAi.Subscriptions

  def valid_subscription_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      stripe_subscription_id: "sub_#{System.unique_integer()}",
      stripe_customer_id: "cus_#{System.unique_integer()}",
      plan_type: "basic",
      status: "active",
      current_period_start: DateTime.utc_now(),
      current_period_end: DateTime.utc_now() |> DateTime.add(30, :day),
      cancel_at_period_end: false
    })
  end

  def subscription_fixture(attrs \\ %{}) do
    {:ok, subscription} =
      attrs
      |> valid_subscription_attributes()
      |> Subscriptions.create_subscription()

    subscription
  end

  def pro_subscription_fixture(attrs \\ %{}) do
    attrs
    |> Map.put(:plan_type, "pro")
    |> subscription_fixture()
  end

  def canceled_subscription_fixture(attrs \\ %{}) do
    attrs
    |> Map.merge(%{
      status: "canceled",
      cancel_at_period_end: true,
      canceled_at: DateTime.utc_now()
    })
    |> subscription_fixture()
  end

  def valid_usage_record_attributes(attrs \\ %{}) do
    now = DateTime.utc_now()

    Enum.into(attrs, %{
      feature_type: "content_generation",
      usage_count: 1,
      period_start: Timex.beginning_of_month(now),
      period_end: Timex.end_of_month(now)
    })
  end

  def usage_record_fixture(attrs \\ %{}) do
    {:ok, usage_record} =
      attrs
      |> valid_usage_record_attributes()
      |> Subscriptions.create_usage_record()

    usage_record
  end
end
