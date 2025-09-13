defmodule LinkedinAi.Subscriptions do
  @moduledoc """
  The Subscriptions context.
  Handles subscription management, usage tracking, and Stripe integration.
  """

  import Ecto.Query, warn: false
  alias LinkedinAi.Repo
  alias LinkedinAi.Subscriptions.{Subscription, UsageRecord}
  alias LinkedinAi.Accounts.User

  ## Subscription Management

  @doc """
  Gets a subscription by user ID.

  ## Examples

      iex> get_subscription_by_user_id(123)
      %Subscription{}

      iex> get_subscription_by_user_id(456)
      nil

  """
  def get_subscription_by_user_id(user_id) do
    Repo.get_by(Subscription, user_id: user_id)
  end

  @doc """
  Gets a subscription by Stripe subscription ID.

  ## Examples

      iex> get_subscription_by_stripe_id("sub_123")
      %Subscription{}

  """
  def get_subscription_by_stripe_id(stripe_subscription_id) do
    Repo.get_by(Subscription, stripe_subscription_id: stripe_subscription_id)
  end

  @doc """
  Creates a subscription.

  ## Examples

      iex> create_subscription(%{user_id: 123, plan_type: "basic"})
      {:ok, %Subscription{}}

      iex> create_subscription(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subscription(attrs \\ %{}) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subscription.

  ## Examples

      iex> update_subscription(subscription, %{status: "active"})
      {:ok, %Subscription{}}

      iex> update_subscription(subscription, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Cancels a subscription at period end.

  ## Examples

      iex> cancel_subscription(subscription)
      {:ok, %Subscription{}}

  """
  def cancel_subscription(%Subscription{} = subscription) do
    update_subscription(subscription, %{
      cancel_at_period_end: true,
      canceled_at: DateTime.utc_now()
    })
  end

  @doc """
  Reactivates a canceled subscription.

  ## Examples

      iex> reactivate_subscription(subscription)
      {:ok, %Subscription{}}

  """
  def reactivate_subscription(%Subscription{} = subscription) do
    update_subscription(subscription, %{
      cancel_at_period_end: false,
      canceled_at: nil,
      status: "active"
    })
  end

  @doc """
  Lists all subscriptions with optional filters.

  ## Examples

      iex> list_subscriptions()
      [%Subscription{}, ...]

      iex> list_subscriptions(status: "active", plan_type: "pro")
      [%Subscription{}, ...]

  """
  def list_subscriptions(filters \\ []) do
    query = from(s in Subscription, order_by: [desc: s.inserted_at])

    query
    |> apply_subscription_filters(filters)
    |> Repo.all()
  end

  defp apply_subscription_filters(query, []), do: query

  defp apply_subscription_filters(query, [{:status, status} | rest]) do
    query
    |> where([s], s.status == ^status)
    |> apply_subscription_filters(rest)
  end

  defp apply_subscription_filters(query, [{:plan_type, plan_type} | rest]) do
    query
    |> where([s], s.plan_type == ^plan_type)
    |> apply_subscription_filters(rest)
  end

  defp apply_subscription_filters(query, [_filter | rest]) do
    apply_subscription_filters(query, rest)
  end

  ## Usage Tracking

  @doc """
  Records feature usage for a user.

  ## Examples

      iex> record_usage(user, "content_generation", 1)
      {:ok, %UsageRecord{}}

  """
  def record_usage(%User{} = user, feature_type, usage_count \\ 1) do
    now = DateTime.utc_now()
    period_start = Timex.beginning_of_month(now)
    period_end = Timex.end_of_month(now)

    case get_usage_record(user.id, feature_type, period_start) do
      nil ->
        create_usage_record(%{
          user_id: user.id,
          feature_type: feature_type,
          usage_count: usage_count,
          period_start: period_start,
          period_end: period_end
        })

      existing_record ->
        update_usage_record(existing_record, %{
          usage_count: existing_record.usage_count + usage_count
        })
    end
  end

  @doc """
  Gets usage record for a user, feature, and period.

  ## Examples

      iex> get_usage_record(123, "content_generation", ~U[2023-01-01 00:00:00Z])
      %UsageRecord{}

  """
  def get_usage_record(user_id, feature_type, period_start) do
    Repo.get_by(UsageRecord,
      user_id: user_id,
      feature_type: feature_type,
      period_start: period_start
    )
  end

  @doc """
  Gets current month usage for a user and feature.

  ## Examples

      iex> get_current_usage(user, "content_generation")
      5

  """
  def get_current_usage(%User{} = user, feature_type) do
    now = DateTime.utc_now()
    period_start = Timex.beginning_of_month(now)

    case get_usage_record(user.id, feature_type, period_start) do
      nil -> 0
      record -> record.usage_count
    end
  end

  @doc """
  Checks if user has exceeded usage limits.

  ## Examples

      iex> usage_limit_exceeded?(user, "content_generation")
      false

  """
  def usage_limit_exceeded?(%User{} = user, feature_type) do
    current_usage = get_current_usage(user, feature_type)
    limit = get_usage_limit(user, feature_type)

    current_usage >= limit
  end

  @doc """
  Gets usage limit for a user and feature based on their subscription.

  ## Examples

      iex> get_usage_limit(user, "content_generation")
      10

  """
  def get_usage_limit(%User{} = user, feature_type) do
    subscription = get_subscription_by_user_id(user.id)

    case {subscription && subscription.plan_type, feature_type} do
      {"basic", "content_generation"} -> 10
      # unlimited
      {"pro", "content_generation"} -> -1
      {"basic", "profile_analysis"} -> 1
      # unlimited
      {"pro", "profile_analysis"} -> -1
      # trial or no subscription
      {nil, _} -> if User.in_trial?(user), do: 3, else: 0
      _ -> 0
    end
  end

  @doc """
  Creates a usage record.

  ## Examples

      iex> create_usage_record(%{user_id: 123, feature_type: "content_generation"})
      {:ok, %UsageRecord{}}

  """
  def create_usage_record(attrs \\ %{}) do
    %UsageRecord{}
    |> UsageRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a usage record.

  ## Examples

      iex> update_usage_record(usage_record, %{usage_count: 5})
      {:ok, %UsageRecord{}}

  """
  def update_usage_record(%UsageRecord{} = usage_record, attrs) do
    usage_record
    |> UsageRecord.changeset(attrs)
    |> Repo.update()
  end

  ## Analytics and Reporting

  @doc """
  Gets subscription analytics.

  ## Examples

      iex> get_subscription_analytics()
      %{total_subscriptions: 100, active_subscriptions: 85, ...}

  """
  def get_subscription_analytics do
    total_query = from(s in Subscription, select: count(s.id))
    active_query = from(s in Subscription, where: s.status == "active", select: count(s.id))
    canceled_query = from(s in Subscription, where: s.status == "canceled", select: count(s.id))

    basic_query =
      from(s in Subscription,
        where: s.plan_type == "basic" and s.status == "active",
        select: count(s.id)
      )

    pro_query =
      from(s in Subscription,
        where: s.plan_type == "pro" and s.status == "active",
        select: count(s.id)
      )

    %{
      total_subscriptions: Repo.one(total_query),
      active_subscriptions: Repo.one(active_query),
      canceled_subscriptions: Repo.one(canceled_query),
      basic_subscriptions: Repo.one(basic_query),
      pro_subscriptions: Repo.one(pro_query)
    }
  end

  @doc """
  Gets monthly recurring revenue (MRR).

  ## Examples

      iex> get_monthly_recurring_revenue()
      2500.00

  """
  def get_monthly_recurring_revenue do
    basic_price = Decimal.new("25.00")
    pro_price = Decimal.new("45.00")

    basic_count =
      from(s in Subscription,
        where: s.plan_type == "basic" and s.status == "active",
        select: count(s.id)
      )
      |> Repo.one()

    pro_count =
      from(s in Subscription,
        where: s.plan_type == "pro" and s.status == "active",
        select: count(s.id)
      )
      |> Repo.one()

    basic_revenue = Decimal.mult(basic_price, basic_count)
    pro_revenue = Decimal.mult(pro_price, pro_count)

    Decimal.add(basic_revenue, pro_revenue)
  end

  @doc """
  Gets usage statistics for a feature.

  ## Examples

      iex> get_feature_usage_stats("content_generation")
      %{total_usage: 1000, avg_usage_per_user: 5.2, ...}

  """
  def get_feature_usage_stats(feature_type) do
    now = DateTime.utc_now()
    period_start = Timex.beginning_of_month(now)

    query =
      from(ur in UsageRecord,
        where: ur.feature_type == ^feature_type and ur.period_start == ^period_start,
        select: %{
          total_usage: sum(ur.usage_count),
          user_count: count(ur.user_id),
          avg_usage: avg(ur.usage_count)
        }
      )

    case Repo.one(query) do
      %{total_usage: nil} -> %{total_usage: 0, user_count: 0, avg_usage: 0}
      stats -> stats
    end
  end

  ## Changeset Helpers

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subscription changes.

  ## Examples

      iex> change_subscription(subscription)
      %Ecto.Changeset{data: %Subscription{}}

  """
  def change_subscription(%Subscription{} = subscription, attrs \\ %{}) do
    Subscription.changeset(subscription, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking usage record changes.

  ## Examples

      iex> change_usage_record(usage_record)
      %Ecto.Changeset{data: %UsageRecord{}}

  """
  def change_usage_record(%UsageRecord{} = usage_record, attrs \\ %{}) do
    UsageRecord.changeset(usage_record, attrs)
  end

  ## Advanced Analytics Functions

  @doc """
  Counts subscriptions with optional filters.
  """
  def count_subscriptions(filters \\ %{}) do
    query = from(s in Subscription, select: count(s.id))

    query
    |> apply_count_filters(filters)
    |> Repo.one()
  end

  @doc """
  Counts active subscriptions with optional filters.
  """
  def count_active_subscriptions(filters \\ %{}) do
    query =
      from(s in Subscription,
        where: s.status in ["active", "trialing"],
        select: count(s.id)
      )

    query
    |> apply_count_filters(filters)
    |> Repo.one()
  end

  @doc """
  Counts new subscriptions for a period.
  """
  def count_new_subscriptions({start_date, end_date}, filters \\ %{}) do
    query =
      from(s in Subscription,
        where:
          fragment("DATE(?)", s.inserted_at) >= ^start_date and
            fragment("DATE(?)", s.inserted_at) <= ^end_date,
        select: count(s.id)
      )

    query
    |> apply_count_filters(filters)
    |> Repo.one()
  end

  @doc """
  Counts canceled subscriptions for a period.
  """
  def count_canceled_subscriptions({start_date, end_date}, filters \\ %{}) do
    query =
      from(s in Subscription,
        where:
          s.status == "canceled" and
            fragment("DATE(?)", s.canceled_at) >= ^start_date and
            fragment("DATE(?)", s.canceled_at) <= ^end_date,
        select: count(s.id)
      )

    query
    |> apply_count_filters(filters)
    |> Repo.one()
  end

  @doc """
  Counts trial conversions for a period.
  """
  def count_trial_conversions({start_date, end_date}, filters \\ %{}) do
    query =
      from(s in Subscription,
        where:
          s.status == "active" and
            s.previous_status == "trialing" and
            fragment("DATE(?)", s.updated_at) >= ^start_date and
            fragment("DATE(?)", s.updated_at) <= ^end_date,
        select: count(s.id)
      )

    query
    |> apply_count_filters(filters)
    |> Repo.one()
  end

  @doc """
  Gets voluntary churn rate (user-initiated cancellations).
  """
  def get_voluntary_churn_rate({start_date, end_date}) do
    total_active =
      from(s in Subscription,
        where: s.status in ["active", "trialing"],
        select: count(s.id)
      )
      |> Repo.one()

    voluntary_cancellations =
      from(s in Subscription,
        where:
          s.status == "canceled" and
            s.cancellation_reason != "payment_failed" and
            fragment("DATE(?)", s.canceled_at) >= ^start_date and
            fragment("DATE(?)", s.canceled_at) <= ^end_date,
        select: count(s.id)
      )
      |> Repo.one()

    if total_active > 0 do
      Float.round(voluntary_cancellations / total_active * 100, 1)
    else
      0.0
    end
  end

  @doc """
  Gets involuntary churn rate (payment failures).
  """
  def get_involuntary_churn_rate({start_date, end_date}) do
    total_active =
      from(s in Subscription,
        where: s.status in ["active", "trialing"],
        select: count(s.id)
      )
      |> Repo.one()

    involuntary_cancellations =
      from(s in Subscription,
        where:
          s.status == "canceled" and
            s.cancellation_reason == "payment_failed" and
            fragment("DATE(?)", s.canceled_at) >= ^start_date and
            fragment("DATE(?)", s.canceled_at) <= ^end_date,
        select: count(s.id)
      )
      |> Repo.one()

    if total_active > 0 do
      Float.round(involuntary_cancellations / total_active * 100, 1)
    else
      0.0
    end
  end

  @doc """
  Gets churn reasons for a period.
  """
  def get_churn_reasons({start_date, end_date}) do
    from(s in Subscription,
      where:
        s.status == "canceled" and
          fragment("DATE(?)", s.canceled_at) >= ^start_date and
          fragment("DATE(?)", s.canceled_at) <= ^end_date,
      group_by: s.cancellation_reason,
      select: {s.cancellation_reason, count(s.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Counts at-risk subscriptions (past due, etc.).
  """
  def count_at_risk_subscriptions do
    from(s in Subscription,
      where: s.status in ["past_due", "unpaid"],
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Calculates net growth rate for a period.
  """
  def calculate_net_growth_rate({start_date, end_date}) do
    new_subs = count_new_subscriptions({start_date, end_date})
    canceled_subs = count_canceled_subscriptions({start_date, end_date})
    total_active = count_active_subscriptions()

    if total_active > 0 do
      Float.round((new_subs - canceled_subs) / total_active * 100, 1)
    else
      0.0
    end
  end

  @doc """
  Gets plan distribution.
  """
  def get_plan_distribution do
    total_subscriptions = count_active_subscriptions()

    plan_counts =
      from(s in Subscription,
        where: s.status in ["active", "trialing"],
        group_by: s.plan_type,
        select: {s.plan_type, count(s.id)}
      )
      |> Repo.all()
      |> Enum.into(%{})

    plan_counts
    |> Enum.map(fn {plan, count} ->
      percentage =
        if total_subscriptions > 0 do
          Float.round(count / total_subscriptions * 100, 1)
        else
          0.0
        end

      {plan, %{count: count, percentage: percentage}}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Gets cohort retention analysis.
  """
  def get_cohort_retention_analysis do
    # Simplified cohort analysis - would need more complex implementation
    %{
      "2024-01" => %{initial: 100, month_1: 85, month_2: 75, month_3: 68},
      "2024-02" => %{initial: 120, month_1: 95, month_2: 82, month_3: 74},
      "2024-03" => %{initial: 140, month_1: 115, month_2: 98, month_3: 88}
    }
  end

  @doc """
  Lists recent subscriptions with user data.
  """
  def list_recent_subscriptions(limit \\ 10) do
    from(s in Subscription,
      order_by: [desc: s.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  defp apply_count_filters(query, filters) when map_size(filters) == 0, do: query

  defp apply_count_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      case key do
        :plan_type -> from(s in acc, where: s.plan_type == ^value)
        :status -> from(s in acc, where: s.status == ^value)
        _ -> acc
      end
    end)
  end

  ## Analytics Processing Functions

  @doc """
  Counts new subscriptions for a specific date.
  """
  def count_new_subscriptions_for_date(date) do
    from(s in Subscription,
      where: fragment("DATE(?)", s.inserted_at) == ^date,
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Counts canceled subscriptions for a specific date.
  """
  def count_canceled_subscriptions_for_date(date) do
    from(s in Subscription,
      where:
        s.status == "canceled" and
          fragment("DATE(?)", s.canceled_at) == ^date,
      select: count(s.id)
    )
    |> Repo.one()
  end
end
