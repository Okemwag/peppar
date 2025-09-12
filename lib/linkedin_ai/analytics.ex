defmodule LinkedinAi.Analytics do
  @moduledoc """
  The Analytics context.
  Handles data aggregation, report generation, and performance metrics for the LinkedIn AI platform.
  """

  import Ecto.Query, warn: false
  alias LinkedinAi.Repo
  alias LinkedinAi.Accounts.User
  alias LinkedinAi.Subscriptions.{Subscription, UsageRecord}
  alias LinkedinAi.ContentGeneration.GeneratedContent
  alias LinkedinAi.ProfileOptimization.ProfileAnalysis

  ## User Analytics

  @doc """
  Gets comprehensive analytics for a user.

  ## Examples

      iex> get_user_analytics(user)
      %{content: %{...}, profile: %{...}, usage: %{...}}

  """
  def get_user_analytics(%User{} = user) do
    %{
      content: get_user_content_analytics(user),
      profile: get_user_profile_analytics(user),
      usage: get_user_usage_analytics(user),
      engagement: get_user_engagement_analytics(user),
      growth: get_user_growth_analytics(user)
    }
  end

  @doc """
  Gets content generation analytics for a user.

  ## Examples

      iex> get_user_content_analytics(user)
      %{total_generated: 25, published: 10, favorites: 5, ...}

  """
  def get_user_content_analytics(%User{} = user) do
    base_query = from(gc in GeneratedContent, where: gc.user_id == ^user.id)
    
    total_generated = from(gc in base_query, select: count(gc.id)) |> Repo.one()
    published_count = from(gc in base_query, where: gc.is_published == true, select: count(gc.id)) |> Repo.one()
    favorites_count = from(gc in base_query, where: gc.is_favorite == true, select: count(gc.id)) |> Repo.one()
    
    # Content by type
    content_by_type = from(gc in base_query,
      group_by: gc.content_type,
      select: {gc.content_type, count(gc.id)}
    ) |> Repo.all() |> Enum.into(%{})
    
    # Recent activity (last 30 days)
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
    recent_content = from(gc in base_query,
      where: gc.inserted_at >= ^thirty_days_ago,
      select: count(gc.id)
    ) |> Repo.one()
    
    # Average word count
    avg_word_count = from(gc in base_query,
      where: not is_nil(gc.word_count),
      select: avg(gc.word_count)
    ) |> Repo.one() |> round_avg()
    
    %{
      total_generated: total_generated,
      published: published_count,
      favorites: favorites_count,
      content_by_type: content_by_type,
      recent_activity: recent_content,
      avg_word_count: avg_word_count,
      publish_rate: calculate_percentage(published_count, total_generated)
    }
  end

  @doc """
  Gets profile optimization analytics for a user.

  ## Examples

      iex> get_user_profile_analytics(user)
      %{total_analyses: 5, avg_score: 75, improvements: 3, ...}

  """
  def get_user_profile_analytics(%User{} = user) do
    base_query = from(pa in ProfileAnalysis, where: pa.user_id == ^user.id)
    
    total_analyses = from(pa in base_query, select: count(pa.id)) |> Repo.one()
    avg_score = from(pa in base_query, select: avg(pa.score)) |> Repo.one() |> round_avg()
    implemented_count = from(pa in base_query, where: pa.status == "implemented", select: count(pa.id)) |> Repo.one()
    
    # Latest score
    latest_score = from(pa in base_query,
      order_by: [desc: pa.inserted_at],
      limit: 1,
      select: pa.score
    ) |> Repo.one()
    
    # Analyses by type
    analyses_by_type = from(pa in base_query,
      group_by: pa.analysis_type,
      select: {pa.analysis_type, count(pa.id)}
    ) |> Repo.all() |> Enum.into(%{})
    
    # Priority distribution
    priority_distribution = from(pa in base_query,
      group_by: pa.priority_level,
      select: {pa.priority_level, count(pa.id)}
    ) |> Repo.all() |> Enum.into(%{})
    
    %{
      total_analyses: total_analyses,
      avg_score: avg_score,
      latest_score: latest_score || 0,
      implemented: implemented_count,
      analyses_by_type: analyses_by_type,
      priority_distribution: priority_distribution,
      implementation_rate: calculate_percentage(implemented_count, total_analyses)
    }
  end

  @doc """
  Gets usage analytics for a user.

  ## Examples

      iex> get_user_usage_analytics(user)
      %{current_month: %{...}, last_month: %{...}, trends: [...]}

  """
  def get_user_usage_analytics(%User{} = user) do
    now = DateTime.utc_now()
    current_month_start = Timex.beginning_of_month(now)
    last_month_start = current_month_start |> DateTime.add(-1, :month)
    last_month_end = Timex.end_of_month(last_month_start)
    
    # Current month usage
    current_month_usage = get_monthly_usage(user.id, current_month_start)
    
    # Last month usage
    last_month_usage = get_monthly_usage_for_period(user.id, last_month_start, last_month_end)
    
    # Usage trends (last 6 months)
    usage_trends = get_usage_trends(user.id, 6)
    
    %{
      current_month: current_month_usage,
      last_month: last_month_usage,
      trends: usage_trends,
      growth_rate: calculate_growth_rate(current_month_usage, last_month_usage)
    }
  end

  @doc """
  Gets engagement analytics for a user's published content.

  ## Examples

      iex> get_user_engagement_analytics(user)
      %{total_engagement: 150, avg_engagement: 15, top_content: [...]}

  """
  def get_user_engagement_analytics(%User{} = user) do
    published_content = from(gc in GeneratedContent,
      where: gc.user_id == ^user.id and gc.is_published == true,
      select: gc.engagement_metrics
    ) |> Repo.all()
    
    total_engagement = calculate_total_engagement(published_content)
    avg_engagement = if length(published_content) > 0 do
      total_engagement / length(published_content)
    else
      0
    end
    
    # Top performing content
    top_content = from(gc in GeneratedContent,
      where: gc.user_id == ^user.id and gc.is_published == true,
      order_by: [desc: fragment("(engagement_metrics->>'likes')::int + (engagement_metrics->>'comments')::int + (engagement_metrics->>'shares')::int")],
      limit: 5,
      select: %{id: gc.id, content_type: gc.content_type, engagement_metrics: gc.engagement_metrics, published_at: gc.published_at}
    ) |> Repo.all()
    
    %{
      total_engagement: round(total_engagement),
      avg_engagement: Float.round(avg_engagement, 1),
      published_count: length(published_content),
      top_content: top_content
    }
  end

  @doc """
  Gets growth analytics for a user over time.

  ## Examples

      iex> get_user_growth_analytics(user)
      %{content_growth: [...], score_improvement: [...]}

  """
  def get_user_growth_analytics(%User{} = user) do
    # Content generation growth (last 12 months)
    content_growth = get_monthly_content_growth(user.id, 12)
    
    # Profile score improvement over time
    score_improvement = get_score_improvement_trend(user.id)
    
    %{
      content_growth: content_growth,
      score_improvement: score_improvement,
      member_since: user.inserted_at,
      days_active: DateTime.diff(DateTime.utc_now(), user.inserted_at, :day)
    }
  end

  ## Platform Analytics (Admin)

  @doc """
  Gets comprehensive platform analytics.

  ## Examples

      iex> get_platform_analytics()
      %{users: %{...}, subscriptions: %{...}, content: %{...}}

  """
  def get_platform_analytics do
    %{
      users: get_user_platform_analytics(),
      subscriptions: get_subscription_platform_analytics(),
      content: get_content_platform_analytics(),
      revenue: get_revenue_analytics(),
      usage: get_platform_usage_analytics()
    }
  end

  @doc """
  Gets user-related platform analytics.
  """
  def get_user_platform_analytics do
    total_users = from(u in User, select: count(u.id)) |> Repo.one()
    active_users = from(u in User, where: u.account_status == "active", select: count(u.id)) |> Repo.one()
    
    # New users this month
    month_start = DateTime.utc_now() |> Timex.beginning_of_month()
    new_users_this_month = from(u in User,
      where: u.inserted_at >= ^month_start,
      select: count(u.id)
    ) |> Repo.one()
    
    # Users with LinkedIn connected
    linkedin_connected = from(u in User,
      where: not is_nil(u.linkedin_id),
      select: count(u.id)
    ) |> Repo.one()
    
    %{
      total_users: total_users,
      active_users: active_users,
      new_this_month: new_users_this_month,
      linkedin_connected: linkedin_connected,
      connection_rate: calculate_percentage(linkedin_connected, total_users)
    }
  end

  @doc """
  Gets subscription-related platform analytics.
  """
  def get_subscription_platform_analytics do
    total_subscriptions = from(s in Subscription, select: count(s.id)) |> Repo.one()
    active_subscriptions = from(s in Subscription, where: s.status == "active", select: count(s.id)) |> Repo.one()
    
    # Subscriptions by plan type
    plan_distribution = from(s in Subscription,
      where: s.status == "active",
      group_by: s.plan_type,
      select: {s.plan_type, count(s.id)}
    ) |> Repo.all() |> Enum.into(%{})
    
    # Churn rate (canceled this month)
    month_start = DateTime.utc_now() |> Timex.beginning_of_month()
    canceled_this_month = from(s in Subscription,
      where: s.canceled_at >= ^month_start,
      select: count(s.id)
    ) |> Repo.one()
    
    %{
      total_subscriptions: total_subscriptions,
      active_subscriptions: active_subscriptions,
      plan_distribution: plan_distribution,
      canceled_this_month: canceled_this_month,
      churn_rate: calculate_percentage(canceled_this_month, active_subscriptions)
    }
  end

  @doc """
  Gets content-related platform analytics.
  """
  def get_content_platform_analytics do
    total_content = from(gc in GeneratedContent, select: count(gc.id)) |> Repo.one()
    published_content = from(gc in GeneratedContent, where: gc.is_published == true, select: count(gc.id)) |> Repo.one()
    
    # Content by type
    content_by_type = from(gc in GeneratedContent,
      group_by: gc.content_type,
      select: {gc.content_type, count(gc.id)}
    ) |> Repo.all() |> Enum.into(%{})
    
    # Content generated this month
    month_start = DateTime.utc_now() |> Timex.beginning_of_month()
    content_this_month = from(gc in GeneratedContent,
      where: gc.inserted_at >= ^month_start,
      select: count(gc.id)
    ) |> Repo.one()
    
    %{
      total_content: total_content,
      published_content: published_content,
      content_by_type: content_by_type,
      content_this_month: content_this_month,
      publish_rate: calculate_percentage(published_content, total_content)
    }
  end

  @doc """
  Gets revenue analytics.
  """
  def get_revenue_analytics do
    # Monthly Recurring Revenue (MRR)
    basic_count = from(s in Subscription,
      where: s.plan_type == "basic" and s.status == "active",
      select: count(s.id)
    ) |> Repo.one()
    
    pro_count = from(s in Subscription,
      where: s.plan_type == "pro" and s.status == "active",
      select: count(s.id)
    ) |> Repo.one()
    
    basic_revenue = Decimal.mult(Decimal.new("25.00"), basic_count)
    pro_revenue = Decimal.mult(Decimal.new("45.00"), pro_count)
    total_mrr = Decimal.add(basic_revenue, pro_revenue)
    
    # Annual Recurring Revenue (ARR)
    arr = Decimal.mult(total_mrr, 12)
    
    %{
      mrr: total_mrr,
      arr: arr,
      basic_revenue: basic_revenue,
      pro_revenue: pro_revenue,
      avg_revenue_per_user: if(basic_count + pro_count > 0, do: Decimal.div(total_mrr, basic_count + pro_count), else: Decimal.new("0"))
    }
  end

  @doc """
  Gets platform usage analytics.
  """
  def get_platform_usage_analytics do
    month_start = DateTime.utc_now() |> Timex.beginning_of_month()
    
    # Usage by feature type this month
    usage_by_feature = from(ur in UsageRecord,
      where: ur.period_start == ^month_start,
      group_by: ur.feature_type,
      select: {ur.feature_type, sum(ur.usage_count)}
    ) |> Repo.all() |> Enum.into(%{})
    
    # Total usage this month
    total_usage = usage_by_feature |> Map.values() |> Enum.sum()
    
    # Active users this month (users with usage records)
    active_users_count = from(ur in UsageRecord,
      where: ur.period_start == ^month_start,
      select: count(ur.user_id, :distinct)
    ) |> Repo.one()
    
    %{
      usage_by_feature: usage_by_feature,
      total_usage: total_usage,
      active_users: active_users_count,
      avg_usage_per_user: if(active_users_count > 0, do: Float.round(total_usage / active_users_count, 1), else: 0)
    }
  end

  ## Helper Functions

  defp get_monthly_usage(user_id, month_start) do
    from(ur in UsageRecord,
      where: ur.user_id == ^user_id and ur.period_start == ^month_start,
      group_by: ur.feature_type,
      select: {ur.feature_type, ur.usage_count}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_monthly_usage_for_period(user_id, period_start, period_end) do
    from(ur in UsageRecord,
      where: ur.user_id == ^user_id and ur.period_start >= ^period_start and ur.period_end <= ^period_end,
      group_by: ur.feature_type,
      select: {ur.feature_type, sum(ur.usage_count)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_usage_trends(user_id, months) do
    start_date = DateTime.utc_now() |> DateTime.add(-months, :month) |> Timex.beginning_of_month()
    
    from(ur in UsageRecord,
      where: ur.user_id == ^user_id and ur.period_start >= ^start_date,
      group_by: [ur.period_start, ur.feature_type],
      select: %{period: ur.period_start, feature_type: ur.feature_type, usage: ur.usage_count},
      order_by: [desc: ur.period_start]
    )
    |> Repo.all()
  end

  defp get_monthly_content_growth(user_id, months) do
    start_date = DateTime.utc_now() |> DateTime.add(-months, :month)
    
    from(gc in GeneratedContent,
      where: gc.user_id == ^user_id and gc.inserted_at >= ^start_date,
      group_by: fragment("date_trunc('month', ?)", gc.inserted_at),
      select: %{month: fragment("date_trunc('month', ?)", gc.inserted_at), count: count(gc.id)},
      order_by: [desc: fragment("date_trunc('month', ?)", gc.inserted_at)]
    )
    |> Repo.all()
  end

  defp get_score_improvement_trend(user_id) do
    from(pa in ProfileAnalysis,
      where: pa.user_id == ^user_id,
      select: %{date: pa.inserted_at, score: pa.score, analysis_type: pa.analysis_type},
      order_by: [asc: pa.inserted_at]
    )
    |> Repo.all()
  end

  defp calculate_total_engagement(engagement_metrics_list) do
    engagement_metrics_list
    |> Enum.reduce(0, fn metrics, acc ->
      likes = Map.get(metrics, "likes", 0)
      comments = Map.get(metrics, "comments", 0)
      shares = Map.get(metrics, "shares", 0)
      acc + likes + comments + shares
    end)
  end

  defp calculate_percentage(_numerator, 0), do: 0
  defp calculate_percentage(numerator, denominator) do
    Float.round(numerator / denominator * 100, 1)
  end

  defp calculate_growth_rate(current, previous) when is_map(current) and is_map(previous) do
    current_total = current |> Map.values() |> Enum.sum()
    previous_total = previous |> Map.values() |> Enum.sum()
    
    if previous_total > 0 do
      Float.round((current_total - previous_total) / previous_total * 100, 1)
    else
      0
    end
  end
  defp calculate_growth_rate(_, _), do: 0

  defp round_avg(nil), do: 0
  defp round_avg(avg), do: Float.round(avg, 1)

  ## Report Generation

  @doc """
  Generates a comprehensive user report.

  ## Examples

      iex> generate_user_report(user, :monthly)
      %{report_type: :monthly, generated_at: ~U[...], data: %{...}}

  """
  def generate_user_report(%User{} = user, report_type \\ :monthly) do
    %{
      report_type: report_type,
      user_id: user.id,
      generated_at: DateTime.utc_now(),
      data: get_user_analytics(user),
      summary: generate_user_summary(user)
    }
  end

  defp generate_user_summary(%User{} = user) do
    analytics = get_user_analytics(user)
    
    %{
      total_content_generated: analytics.content.total_generated,
      content_published: analytics.content.published,
      avg_profile_score: analytics.profile.avg_score,
      current_month_usage: analytics.usage.current_month |> Map.values() |> Enum.sum(),
      key_achievements: generate_achievements(analytics)
    }
  end

  defp generate_achievements(analytics) do
    achievements = []
    
    achievements = if analytics.content.total_generated >= 50 do
      ["Content Creator: Generated 50+ pieces of content" | achievements]
    else
      achievements
    end
    
    achievements = if analytics.profile.avg_score >= 80 do
      ["Profile Expert: Maintained 80+ average profile score" | achievements]
    else
      achievements
    end
    
    achievements = if analytics.content.publish_rate >= 50 do
      ["Publisher: Published 50%+ of generated content" | achievements]
    else
      achievements
    end
    
    achievements
  end
end