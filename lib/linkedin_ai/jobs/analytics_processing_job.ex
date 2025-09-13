defmodule LinkedinAi.Jobs.AnalyticsProcessingJob do
  @moduledoc """
  Background job for processing analytics data aggregation and report generation.
  Handles daily/weekly analytics calculations and data cleanup.
  """

  use Oban.Worker, queue: :analytics, max_attempts: 2

  alias LinkedinAi.{Analytics, Accounts, ContentGeneration, ProfileOptimization, Subscriptions}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => type, "date" => date_string}}) do
    date = Date.from_iso8601!(date_string)
    Logger.info("Starting analytics processing job: #{type} for #{date}")

    case type do
      "daily" ->
        process_daily_analytics(date)

      "weekly" ->
        process_weekly_analytics(date)

      "monthly" ->
        process_monthly_analytics(date)

      "user_summary" ->
        process_user_summary_analytics(date)

      _ ->
        Logger.error("Unknown analytics processing type: #{type}")
        {:error, "Unknown analytics type"}
    end
  end

  defp process_daily_analytics(date) do
    Logger.info("Processing daily analytics for #{date}")

    with :ok <- aggregate_user_metrics(date),
         :ok <- aggregate_content_metrics(date),
         :ok <- aggregate_subscription_metrics(date),
         :ok <- aggregate_usage_metrics(date),
         :ok <- cleanup_old_data(date) do
      Logger.info("Daily analytics processing completed for #{date}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Daily analytics processing failed for #{date}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_weekly_analytics(date) do
    Logger.info("Processing weekly analytics for #{date}")

    week_start = Date.beginning_of_week(date)
    week_end = Date.end_of_week(date)

    with :ok <- generate_weekly_user_report(week_start, week_end),
         :ok <- generate_weekly_content_report(week_start, week_end),
         :ok <- generate_weekly_revenue_report(week_start, week_end),
         :ok <- send_weekly_admin_summary(week_start, week_end) do
      Logger.info("Weekly analytics processing completed for #{date}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Weekly analytics processing failed for #{date}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_monthly_analytics(date) do
    Logger.info("Processing monthly analytics for #{date}")

    month_start = Date.beginning_of_month(date)
    month_end = Date.end_of_month(date)

    with :ok <- generate_monthly_cohort_analysis(month_start, month_end),
         :ok <- generate_monthly_churn_analysis(month_start, month_end),
         :ok <- generate_monthly_revenue_report(month_start, month_end),
         :ok <- archive_old_analytics_data(date) do
      Logger.info("Monthly analytics processing completed for #{date}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Monthly analytics processing failed for #{date}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_user_summary_analytics(date) do
    Logger.info("Processing user summary analytics for #{date}")

    # Process analytics for active users
    active_users = Accounts.list_active_users_for_date(date)

    Enum.each(active_users, fn user ->
      try do
        user_analytics = Analytics.get_user_analytics(user)

        # Store or update user analytics summary
        Analytics.store_user_analytics_summary(user, user_analytics, date)

        # Check if user needs engagement notifications
        if should_send_engagement_notification?(user, user_analytics) do
          LinkedinAi.Jobs.enqueue_email_notification(
            user.id,
            "engagement_summary",
            %{analytics: user_analytics, date: date}
          )
        end
      rescue
        error ->
          Logger.error("Failed to process analytics for user #{user.id}: #{inspect(error)}")
      end
    end)

    :ok
  end

  # Analytics aggregation functions
  defp aggregate_user_metrics(date) do
    try do
      metrics = %{
        new_users: Accounts.count_new_users_for_date(date),
        active_users: Accounts.count_active_users_for_date(date),
        total_users: Accounts.count_users(),
        user_retention: Analytics.calculate_retention_rate_for_date(date)
      }

      Analytics.store_daily_user_metrics(date, metrics)
      :ok
    rescue
      error ->
        Logger.error("Failed to aggregate user metrics: #{inspect(error)}")
        {:error, :user_metrics_failed}
    end
  end

  defp aggregate_content_metrics(date) do
    try do
      metrics = %{
        content_generated: ContentGeneration.count_content_for_date(date),
        content_published: ContentGeneration.count_published_content_for_date(date),
        unique_content_creators: ContentGeneration.count_unique_creators_for_date(date),
        avg_content_quality: ContentGeneration.calculate_avg_quality_for_date(date)
      }

      Analytics.store_daily_content_metrics(date, metrics)
      :ok
    rescue
      error ->
        Logger.error("Failed to aggregate content metrics: #{inspect(error)}")
        {:error, :content_metrics_failed}
    end
  end

  defp aggregate_subscription_metrics(date) do
    try do
      metrics = %{
        new_subscriptions: Subscriptions.count_new_subscriptions_for_date(date),
        canceled_subscriptions: Subscriptions.count_canceled_subscriptions_for_date(date),
        active_subscriptions: Subscriptions.count_active_subscriptions(),
        mrr: LinkedinAi.Billing.get_mrr(),
        churn_rate: Analytics.calculate_subscription_churn_rate_for_date(date)
      }

      Analytics.store_daily_subscription_metrics(date, metrics)
      :ok
    rescue
      error ->
        Logger.error("Failed to aggregate subscription metrics: #{inspect(error)}")
        {:error, :subscription_metrics_failed}
    end
  end

  defp aggregate_usage_metrics(date) do
    try do
      metrics = %{
        api_calls: Analytics.count_api_calls_for_date(date),
        content_generations: ContentGeneration.count_content_for_date(date),
        profile_analyses: ProfileOptimization.count_analyses_for_date(date),
        avg_response_time: Analytics.calculate_avg_response_time_for_date(date)
      }

      Analytics.store_daily_usage_metrics(date, metrics)
      :ok
    rescue
      error ->
        Logger.error("Failed to aggregate usage metrics: #{inspect(error)}")
        {:error, :usage_metrics_failed}
    end
  end

  # Report generation functions
  defp generate_weekly_user_report(start_date, end_date) do
    try do
      Logger.info("Generating weekly user report for #{start_date} to #{end_date}")

      # Calculate user growth metrics
      new_users = Accounts.count_new_users_for_period({start_date, end_date})
      active_users = Accounts.count_active_users_for_date(end_date)
      total_users = Accounts.count_users()

      # Calculate growth rate
      previous_week_start = Date.add(start_date, -7)
      previous_week_end = Date.add(end_date, -7)

      previous_new_users =
        Accounts.count_new_users_for_period({previous_week_start, previous_week_end})

      growth_rate =
        if previous_new_users > 0 do
          Float.round((new_users - previous_new_users) / previous_new_users * 100, 1)
        else
          0.0
        end

      report_data = %{
        period: {start_date, end_date},
        new_users: new_users,
        active_users: active_users,
        total_users: total_users,
        growth_rate: growth_rate,
        generated_at: DateTime.utc_now()
      }

      # Store report (would typically save to database or file)
      Analytics.store_weekly_user_report(report_data)

      Logger.info("Weekly user report generated successfully")
      :ok
    rescue
      error ->
        Logger.error("Failed to generate weekly user report: #{inspect(error)}")
        {:error, :report_generation_failed}
    end
  end

  defp generate_weekly_content_report(start_date, end_date) do
    try do
      Logger.info("Generating weekly content report for #{start_date} to #{end_date}")

      # Calculate content metrics
      content_generated = ContentGeneration.count_content_for_period({start_date, end_date})
      content_published = ContentGeneration.count_published_content({start_date, end_date})
      unique_creators = ContentGeneration.count_unique_users_for_period({start_date, end_date})
      popular_types = ContentGeneration.get_popular_content_types({start_date, end_date})

      # Calculate engagement metrics
      avg_engagement = ContentGeneration.get_content_engagement_stats({start_date, end_date})

      report_data = %{
        period: {start_date, end_date},
        content_generated: content_generated,
        content_published: content_published,
        unique_creators: unique_creators,
        popular_types: popular_types,
        avg_engagement: avg_engagement,
        publish_rate:
          if(content_generated > 0,
            do: Float.round(content_published / content_generated * 100, 1),
            else: 0
          ),
        generated_at: DateTime.utc_now()
      }

      # Store report
      Analytics.store_weekly_content_report(report_data)

      Logger.info("Weekly content report generated successfully")
      :ok
    rescue
      error ->
        Logger.error("Failed to generate weekly content report: #{inspect(error)}")
        {:error, :report_generation_failed}
    end
  end

  defp generate_weekly_revenue_report(start_date, end_date) do
    try do
      Logger.info("Generating weekly revenue report for #{start_date} to #{end_date}")

      # Calculate revenue metrics
      new_subscriptions = Subscriptions.count_new_subscriptions({start_date, end_date})
      canceled_subscriptions = Subscriptions.count_canceled_subscriptions({start_date, end_date})
      current_mrr = LinkedinAi.Billing.get_mrr()

      # Calculate net growth
      net_growth = new_subscriptions - canceled_subscriptions

      # Get plan distribution
      plan_distribution = Subscriptions.get_plan_distribution()

      report_data = %{
        period: {start_date, end_date},
        new_subscriptions: new_subscriptions,
        canceled_subscriptions: canceled_subscriptions,
        net_growth: net_growth,
        current_mrr: current_mrr,
        plan_distribution: plan_distribution,
        generated_at: DateTime.utc_now()
      }

      # Store report
      Analytics.store_weekly_revenue_report(report_data)

      Logger.info("Weekly revenue report generated successfully")
      :ok
    rescue
      error ->
        Logger.error("Failed to generate weekly revenue report: #{inspect(error)}")
        {:error, :report_generation_failed}
    end
  end

  defp generate_monthly_cohort_analysis(start_date, end_date) do
    try do
      Logger.info("Generating monthly cohort analysis for #{start_date} to #{end_date}")

      # Get cohort retention data
      cohort_data = Subscriptions.get_cohort_retention_analysis()

      # Calculate retention rates for the current month
      month_key = Date.to_string(start_date) |> String.slice(0, 7)
      current_cohort = Map.get(cohort_data, month_key, %{})

      report_data = %{
        period: {start_date, end_date},
        cohort_data: cohort_data,
        current_month_cohort: current_cohort,
        analysis_date: DateTime.utc_now()
      }

      # Store analysis
      Analytics.store_monthly_cohort_analysis(report_data)

      Logger.info("Monthly cohort analysis generated successfully")
      :ok
    rescue
      error ->
        Logger.error("Failed to generate monthly cohort analysis: #{inspect(error)}")
        {:error, :analysis_generation_failed}
    end
  end

  defp generate_monthly_churn_analysis(start_date, end_date) do
    try do
      Logger.info("Generating monthly churn analysis for #{start_date} to #{end_date}")

      # Calculate churn metrics
      voluntary_churn = Subscriptions.get_voluntary_churn_rate({start_date, end_date})
      involuntary_churn = Subscriptions.get_involuntary_churn_rate({start_date, end_date})
      total_churn = voluntary_churn + involuntary_churn

      # Get churn reasons
      churn_reasons = Subscriptions.get_churn_reasons({start_date, end_date})

      # Calculate at-risk subscriptions
      at_risk_count = Subscriptions.count_at_risk_subscriptions()

      report_data = %{
        period: {start_date, end_date},
        voluntary_churn_rate: voluntary_churn,
        involuntary_churn_rate: involuntary_churn,
        total_churn_rate: total_churn,
        churn_reasons: churn_reasons,
        at_risk_subscriptions: at_risk_count,
        generated_at: DateTime.utc_now()
      }

      # Store analysis
      Analytics.store_monthly_churn_analysis(report_data)

      Logger.info("Monthly churn analysis generated successfully")
      :ok
    rescue
      error ->
        Logger.error("Failed to generate monthly churn analysis: #{inspect(error)}")
        {:error, :analysis_generation_failed}
    end
  end

  defp generate_monthly_revenue_report(start_date, end_date) do
    try do
      Logger.info("Generating monthly revenue report for #{start_date} to #{end_date}")

      # Calculate comprehensive revenue metrics
      current_mrr = LinkedinAi.Billing.get_mrr()
      current_arr = Decimal.mult(current_mrr, 12)

      # Get subscription metrics
      new_subscriptions = Subscriptions.count_new_subscriptions({start_date, end_date})
      canceled_subscriptions = Subscriptions.count_canceled_subscriptions({start_date, end_date})
      trial_conversions = Subscriptions.count_trial_conversions({start_date, end_date})

      # Calculate growth metrics
      net_growth_rate = Subscriptions.calculate_net_growth_rate({start_date, end_date})

      # Get plan distribution and revenue breakdown
      plan_distribution = Subscriptions.get_plan_distribution()

      report_data = %{
        period: {start_date, end_date},
        mrr: current_mrr,
        arr: current_arr,
        new_subscriptions: new_subscriptions,
        canceled_subscriptions: canceled_subscriptions,
        trial_conversions: trial_conversions,
        net_growth_rate: net_growth_rate,
        plan_distribution: plan_distribution,
        generated_at: DateTime.utc_now()
      }

      # Store comprehensive report
      Analytics.store_monthly_revenue_report(report_data)

      Logger.info("Monthly revenue report generated successfully")
      :ok
    rescue
      error ->
        Logger.error("Failed to generate monthly revenue report: #{inspect(error)}")
        {:error, :report_generation_failed}
    end
  end

  # Notification functions
  defp send_weekly_admin_summary(start_date, end_date) do
    # Send weekly summary to admin users
    admin_users = Accounts.list_admin_users()

    Enum.each(admin_users, fn admin ->
      LinkedinAi.Jobs.enqueue_email_notification(
        admin.id,
        "weekly_admin_summary",
        %{start_date: start_date, end_date: end_date}
      )
    end)

    :ok
  end

  defp should_send_engagement_notification?(_user, analytics) do
    # Logic to determine if user should receive engagement notification
    # Based on activity levels, content performance, etc.
    analytics.content.total_generated > 0 and
      analytics.engagement.total_engagement < 10
  end

  # Cleanup functions
  defp cleanup_old_data(date) do
    # Clean up old temporary data, logs, etc.
    cutoff_date = Date.add(date, -30)

    try do
      # Clean up old session data
      Analytics.cleanup_old_session_data(cutoff_date)

      # Clean up old temporary files
      Analytics.cleanup_old_temp_files(cutoff_date)

      Logger.info("Data cleanup completed for date #{cutoff_date}")
      :ok
    rescue
      error ->
        Logger.error("Data cleanup failed: #{inspect(error)}")
        {:error, :cleanup_failed}
    end
  end

  defp archive_old_analytics_data(date) do
    # Archive analytics data older than 1 year
    archive_cutoff = Date.add(date, -365)

    try do
      Analytics.archive_old_analytics_data(archive_cutoff)
      Logger.info("Analytics data archived for dates before #{archive_cutoff}")
      :ok
    rescue
      error ->
        Logger.error("Analytics data archiving failed: #{inspect(error)}")
        {:error, :archiving_failed}
    end
  end
end
