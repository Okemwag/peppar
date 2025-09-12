defmodule LinkedinAi.Subscriptions.Subscription do
  @moduledoc """
  Subscription schema for managing user subscriptions with Stripe integration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "subscriptions" do
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string
    field :plan_type, :string
    field :status, :string
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false
    field :canceled_at, :utc_datetime
    field :trial_start, :utc_datetime
    field :trial_end, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :user, LinkedinAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :user_id,
      :stripe_subscription_id,
      :stripe_customer_id,
      :plan_type,
      :status,
      :current_period_start,
      :current_period_end,
      :cancel_at_period_end,
      :canceled_at,
      :trial_start,
      :trial_end,
      :metadata
    ])
    |> validate_required([
      :user_id,
      :stripe_subscription_id,
      :stripe_customer_id,
      :plan_type,
      :status
    ])
    |> validate_inclusion(:plan_type, ["basic", "pro"])
    |> validate_inclusion(:status, ["active", "canceled", "past_due", "unpaid", "trialing"])
    |> unique_constraint(:user_id)
    |> unique_constraint(:stripe_subscription_id)
    |> validate_period_dates()
    |> validate_trial_dates()
  end

  defp validate_period_dates(changeset) do
    start_date = get_field(changeset, :current_period_start)
    end_date = get_field(changeset, :current_period_end)

    if start_date && end_date && DateTime.compare(start_date, end_date) != :lt do
      add_error(changeset, :current_period_end, "must be after current period start")
    else
      changeset
    end
  end

  defp validate_trial_dates(changeset) do
    trial_start = get_field(changeset, :trial_start)
    trial_end = get_field(changeset, :trial_end)

    cond do
      trial_start && trial_end && DateTime.compare(trial_start, trial_end) != :lt ->
        add_error(changeset, :trial_end, "must be after trial start")

      trial_start && !trial_end ->
        add_error(changeset, :trial_end, "is required when trial start is set")

      !trial_start && trial_end ->
        add_error(changeset, :trial_start, "is required when trial end is set")

      true ->
        changeset
    end
  end

  @doc """
  Checks if the subscription is active.
  """
  def active?(%__MODULE__{status: "active"}), do: true
  def active?(_), do: false

  @doc """
  Checks if the subscription is canceled.
  """
  def canceled?(%__MODULE__{status: "canceled"}), do: true
  def canceled?(_), do: false

  @doc """
  Checks if the subscription is in trial period.
  """
  def in_trial?(%__MODULE__{status: "trialing"}), do: true
  def in_trial?(%__MODULE__{trial_start: nil}), do: false
  def in_trial?(%__MODULE__{trial_end: nil}), do: false

  def in_trial?(%__MODULE__{trial_start: trial_start, trial_end: trial_end}) do
    now = DateTime.utc_now()
    DateTime.compare(now, trial_start) != :lt && DateTime.compare(now, trial_end) == :lt
  end

  @doc """
  Checks if the subscription will be canceled at period end.
  """
  def will_cancel?(%__MODULE__{cancel_at_period_end: true}), do: true
  def will_cancel?(_), do: false

  @doc """
  Gets the subscription price based on plan type.
  """
  def get_price(%__MODULE__{plan_type: "basic"}), do: Decimal.new("25.00")
  def get_price(%__MODULE__{plan_type: "pro"}), do: Decimal.new("45.00")
  def get_price(_), do: Decimal.new("0.00")

  @doc """
  Gets days remaining in current period.
  """
  def days_remaining(%__MODULE__{current_period_end: nil}), do: 0

  def days_remaining(%__MODULE__{current_period_end: period_end}) do
    now = DateTime.utc_now()

    case DateTime.compare(period_end, now) do
      :gt -> DateTime.diff(period_end, now, :day)
      _ -> 0
    end
  end

  @doc """
  Checks if subscription is past due.
  """
  def past_due?(%__MODULE__{status: "past_due"}), do: true
  def past_due?(_), do: false

  @doc """
  Gets subscription display name.
  """
  def display_name(%__MODULE__{plan_type: "basic"}), do: "Basic Plan"
  def display_name(%__MODULE__{plan_type: "pro"}), do: "Pro Plan"
  def display_name(_), do: "Unknown Plan"
end
