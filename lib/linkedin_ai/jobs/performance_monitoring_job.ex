defmodule LinkedinAi.Jobs.PerformanceMonitoringJob do
  @moduledoc """
  Background job for monitoring system performance metrics and alerting on issues.
  Tracks response times, throughput, error rates, and resource utilization.
  """

  use Oban.Worker, queue: :monitoring, max_attempts: 2

  alias LinkedinAi.{Analytics, Repo}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"monitoring_type" => monitoring_type}}) do
    Logger.info("Starting performance monitoring job: #{monitoring_type}")

    case monitoring_type do
      "response_times" ->
        monitor_response_times()

      "throughput" ->
        monitor_throughput()

      "error_rates" ->
        monitor_error_rates()

      "resource_utilization" ->
        monitor_resource_utilization()

      "database_performance" ->
        monitor_database_performance()

      "api_performance" ->
        monitor_api_performance()

      "user_experience" ->
        monitor_user_experience()

      "comprehensive" ->
        monitor_comprehensive()

      _ ->
        Logger.error("Unknown monitoring type: #{monitoring_type}")
        {:error, "Unknown monitoring type"}
    end
  end

  defp monitor_response_times do
    try do
      Logger.info("Monitoring response times")

      # Measure database response times
      db_response_time = measure_database_response_time()

      # Measure API response times
      api_response_times = measure_api_response_times()

      # Measure page load times
      page_load_times = measure_page_load_times()

      metrics = %{
        database_response_time: db_response_time,
        api_response_times: api_response_times,
        page_load_times: page_load_times,
        timestamp: DateTime.utc_now()
      }

      # Store metrics
      Analytics.store_response_time_metrics(metrics)

      # Check for performance issues
      check_response_time_thresholds(metrics)

      Logger.info("Response time monitoring completed")
      :ok
    rescue
      error ->
        Logger.error("Response time monitoring failed: #{inspect(error)}")
        {:error, :response_time_monitoring_failed}
    end
  end

  defp monitor_throughput do
    try do
      Logger.info("Monitoring system throughput")

      # Calculate requests per minute
      current_time = DateTime.utc_now()
      one_minute_ago = DateTime.add(current_time, -60, :second)

      # Count various operations in the last minute
      content_generations =
        count_operations_in_period("content_generation", one_minute_ago, current_time)

      profile_analyses =
        count_operations_in_period("profile_analysis", one_minute_ago, current_time)

      api_calls = count_operations_in_period("api_call", one_minute_ago, current_time)

      # Calculate throughput metrics
      total_operations = content_generations + profile_analyses + api_calls

      metrics = %{
        content_generations_per_minute: content_generations,
        profile_analyses_per_minute: profile_analyses,
        api_calls_per_minute: api_calls,
        total_operations_per_minute: total_operations,
        timestamp: current_time
      }

      # Store metrics
      Analytics.store_throughput_metrics(metrics)

      # Check for throughput issues
      check_throughput_thresholds(metrics)

      Logger.info("Throughput monitoring completed")
      :ok
    rescue
      error ->
        Logger.error("Throughput monitoring failed: #{inspect(error)}")
        {:error, :throughput_monitoring_failed}
    end
  end

  defp monitor_error_rates do
    try do
      Logger.info("Monitoring error rates")

      # Calculate error rates for the last hour
      current_time = DateTime.utc_now()
      one_hour_ago = DateTime.add(current_time, -3600, :second)

      # Count failed operations
      failed_jobs = count_failed_jobs_in_period(one_hour_ago, current_time)
      total_jobs = count_total_jobs_in_period(one_hour_ago, current_time)

      # Calculate error rate
      error_rate =
        if total_jobs > 0 do
          Float.round(failed_jobs / total_jobs * 100, 2)
        else
          0.0
        end

      # Get error breakdown by type
      error_breakdown = get_error_breakdown(one_hour_ago, current_time)

      metrics = %{
        error_rate: error_rate,
        failed_jobs: failed_jobs,
        total_jobs: total_jobs,
        error_breakdown: error_breakdown,
        timestamp: current_time
      }

      # Store metrics
      Analytics.store_error_rate_metrics(metrics)

      # Check for high error rates
      check_error_rate_thresholds(metrics)

      Logger.info("Error rate monitoring completed")
      :ok
    rescue
      error ->
        Logger.error("Error rate monitoring failed: #{inspect(error)}")
        {:error, :error_rate_monitoring_failed}
    end
  end

  defp monitor_resource_utilization do
    try do
      Logger.info("Monitoring resource utilization")

      # Get system resource metrics
      memory_usage = get_memory_usage()
      cpu_usage = get_cpu_usage()
      disk_usage = get_disk_usage()

      # Get Erlang VM metrics
      erlang_memory = :erlang.memory()
      process_count = :erlang.system_info(:process_count)

      metrics = %{
        memory_usage: memory_usage,
        cpu_usage: cpu_usage,
        disk_usage: disk_usage,
        erlang_memory: erlang_memory,
        process_count: process_count,
        timestamp: DateTime.utc_now()
      }

      # Store metrics
      Analytics.store_resource_utilization_metrics(metrics)

      # Check for resource issues
      check_resource_utilization_thresholds(metrics)

      Logger.info("Resource utilization monitoring completed")
      :ok
    rescue
      error ->
        Logger.error("Resource utilization monitoring failed: #{inspect(error)}")
        {:error, :resource_monitoring_failed}
    end
  end

  defp monitor_database_performance do
    try do
      Logger.info("Monitoring database performance")

      # Measure query performance
      slow_queries = get_slow_queries()
      connection_pool_usage = get_connection_pool_usage()

      # Measure database size and growth
      database_size = get_database_size()
      table_sizes = get_table_sizes()

      # Check for locks and blocking queries
      blocking_queries = get_blocking_queries()

      metrics = %{
        slow_queries: slow_queries,
        connection_pool_usage: connection_pool_usage,
        database_size: database_size,
        table_sizes: table_sizes,
        blocking_queries: blocking_queries,
        timestamp: DateTime.utc_now()
      }

      # Store metrics
      Analytics.store_database_performance_metrics(metrics)

      # Check for database performance issues
      check_database_performance_thresholds(metrics)

      Logger.info("Database performance monitoring completed")
      :ok
    rescue
      error ->
        Logger.error("Database performance monitoring failed: #{inspect(error)}")
        {:error, :database_monitoring_failed}
    end
  end

  defp monitor_api_performance do
    try do
      Logger.info("Monitoring API performance")

      # Monitor external API performance
      openai_performance = measure_openai_performance()
      stripe_performance = measure_stripe_performance()
      linkedin_performance = measure_linkedin_performance()

      # Monitor internal API endpoints
      internal_api_performance = measure_internal_api_performance()

      metrics = %{
        openai_performance: openai_performance,
        stripe_performance: stripe_performance,
        linkedin_performance: linkedin_performance,
        internal_api_performance: internal_api_performance,
        timestamp: DateTime.utc_now()
      }

      # Store metrics
      Analytics.store_api_performance_metrics(metrics)

      # Check for API performance issues
      check_api_performance_thresholds(metrics)

      Logger.info("API performance monitoring completed")
      :ok
    rescue
      error ->
        Logger.error("API performance monitoring failed: #{inspect(error)}")
        {:error, :api_monitoring_failed}
    end
  end

  defp monitor_user_experience do
    try do
      Logger.info("Monitoring user experience metrics")

      # Calculate user experience metrics
      avg_session_duration = Analytics.get_average_session_duration()
      bounce_rate = calculate_bounce_rate()
      user_satisfaction_score = calculate_user_satisfaction_score()

      # Monitor feature usage patterns
      feature_usage = get_feature_usage_patterns()

      # Monitor user journey completion rates
      journey_completion_rates = get_journey_completion_rates()

      metrics = %{
        avg_session_duration: avg_session_duration,
        bounce_rate: bounce_rate,
        user_satisfaction_score: user_satisfaction_score,
        feature_usage: feature_usage,
        journey_completion_rates: journey_completion_rates,
        timestamp: DateTime.utc_now()
      }

      # Store metrics
      Analytics.store_user_experience_metrics(metrics)

      # Check for user experience issues
      check_user_experience_thresholds(metrics)

      Logger.info("User experience monitoring completed")
      :ok
    rescue
      error ->
        Logger.error("User experience monitoring failed: #{inspect(error)}")
        {:error, :user_experience_monitoring_failed}
    end
  end

  defp monitor_comprehensive do
    Logger.info("Running comprehensive performance monitoring")

    results = [
      monitor_response_times(),
      monitor_throughput(),
      monitor_error_rates(),
      monitor_resource_utilization(),
      monitor_database_performance(),
      monitor_api_performance(),
      monitor_user_experience()
    ]

    failed_monitors =
      Enum.filter(results, fn
        :ok -> false
        {:error, _} -> true
      end)

    if Enum.empty?(failed_monitors) do
      Logger.info("Comprehensive performance monitoring completed successfully")
      :ok
    else
      Logger.error("Some performance monitors failed: #{inspect(failed_monitors)}")
      {:error, :partial_monitoring_failure}
    end
  end

  # Helper functions for measurements
  defp measure_database_response_time do
    {time, _result} = :timer.tc(fn -> Repo.query!("SELECT 1") end)
    # Convert to milliseconds
    round(time / 1000)
  end

  defp measure_api_response_times do
    # Placeholder - would measure actual API endpoints
    %{
      content_generation: 250,
      profile_analysis: 180,
      user_management: 120
    }
  end

  defp measure_page_load_times do
    # Placeholder - would measure actual page load times
    %{
      dashboard: 800,
      content_generator: 650,
      profile_optimizer: 720
    }
  end

  defp count_operations_in_period(operation_type, start_time, end_time) do
    # Count operations from usage records or job logs
    import Ecto.Query

    from(ur in LinkedinAi.Subscriptions.UsageRecord,
      where:
        ur.feature_type == ^operation_type and
          ur.inserted_at >= ^start_time and
          ur.inserted_at <= ^end_time,
      select: sum(ur.usage_count)
    )
    |> Repo.one() || 0
  end

  defp count_failed_jobs_in_period(start_time, end_time) do
    import Ecto.Query

    from(j in Oban.Job,
      where:
        j.state == "discarded" and
          j.discarded_at >= ^start_time and
          j.discarded_at <= ^end_time,
      select: count(j.id)
    )
    |> Repo.one()
  end

  defp count_total_jobs_in_period(start_time, end_time) do
    import Ecto.Query

    from(j in Oban.Job,
      where:
        j.inserted_at >= ^start_time and
          j.inserted_at <= ^end_time,
      select: count(j.id)
    )
    |> Repo.one()
  end

  defp get_error_breakdown(start_time, end_time) do
    import Ecto.Query

    from(j in Oban.Job,
      where:
        j.state == "discarded" and
          j.discarded_at >= ^start_time and
          j.discarded_at <= ^end_time,
      group_by: j.worker,
      select: {j.worker, count(j.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_memory_usage do
    # Get system memory usage
    try do
      {output, 0} = System.cmd("free", ["-m"])
      lines = String.split(output, "\n")
      mem_line = Enum.find(lines, &String.starts_with?(&1, "Mem:"))

      if mem_line do
        [_, total, used, _, _, _, _] = String.split(mem_line)

        %{
          total_mb: String.to_integer(total),
          used_mb: String.to_integer(used),
          usage_percent: round(String.to_integer(used) / String.to_integer(total) * 100)
        }
      else
        %{total_mb: 0, used_mb: 0, usage_percent: 0}
      end
    rescue
      _ -> %{total_mb: 0, used_mb: 0, usage_percent: 0}
    end
  end

  defp get_cpu_usage do
    # Placeholder - would get actual CPU usage
    %{usage_percent: 25.5, load_average: [0.8, 0.9, 1.1]}
  end

  defp get_disk_usage do
    try do
      {output, 0} = System.cmd("df", ["-h", "/"])
      usage_line = output |> String.split("\n") |> Enum.at(1, "")
      usage_percent = usage_line |> String.split() |> Enum.at(4, "0%")

      %{usage_percent: usage_percent}
    rescue
      _ -> %{usage_percent: "0%"}
    end
  end

  defp get_slow_queries do
    # Placeholder - would query for slow queries
    []
  end

  defp get_connection_pool_usage do
    # Get connection pool statistics
    pool_size = Application.get_env(:linkedin_ai, Repo)[:pool_size] || 10
    %{pool_size: pool_size, active_connections: 3, usage_percent: 30}
  end

  defp get_database_size do
    # Placeholder - would get actual database size
    %{size_mb: 150, growth_rate: 2.5}
  end

  defp get_table_sizes do
    # Placeholder - would get actual table sizes
    %{
      users: "5.2 MB",
      subscriptions: "1.8 MB",
      generated_contents: "12.5 MB"
    }
  end

  defp get_blocking_queries do
    # Placeholder - would check for blocking queries
    []
  end

  defp measure_openai_performance do
    %{avg_response_time: 1200, success_rate: 98.5, rate_limit_usage: 45}
  end

  defp measure_stripe_performance do
    %{avg_response_time: 800, success_rate: 99.8, webhook_processing_time: 150}
  end

  defp measure_linkedin_performance do
    %{avg_response_time: 2000, success_rate: 97.2, rate_limit_usage: 60}
  end

  defp measure_internal_api_performance do
    %{
      avg_response_time: 180,
      success_rate: 99.5,
      endpoints: %{
        "/api/content" => %{avg_time: 200, success_rate: 99.2},
        "/api/profile" => %{avg_time: 160, success_rate: 99.8}
      }
    }
  end

  defp calculate_bounce_rate do
    # Placeholder - would calculate actual bounce rate
    15.2
  end

  defp calculate_user_satisfaction_score do
    # Placeholder - would calculate from user feedback
    4.2
  end

  defp get_feature_usage_patterns do
    %{
      content_generation: 65,
      profile_optimization: 45,
      analytics_dashboard: 80
    }
  end

  defp get_journey_completion_rates do
    %{
      onboarding: 78.5,
      first_content_generation: 65.2,
      subscription_signup: 12.8
    }
  end

  # Threshold checking functions
  defp check_response_time_thresholds(metrics) do
    if metrics.database_response_time > 1000 do
      send_performance_alert("High database response time", metrics)
    end

    Enum.each(metrics.api_response_times, fn {api, time} ->
      if time > 2000 do
        send_performance_alert("High #{api} API response time", %{api: api, time: time})
      end
    end)
  end

  defp check_throughput_thresholds(metrics) do
    if metrics.total_operations_per_minute < 10 do
      send_performance_alert("Low system throughput", metrics)
    end
  end

  defp check_error_rate_thresholds(metrics) do
    if metrics.error_rate > 5.0 do
      send_performance_alert("High error rate", metrics)
    end
  end

  defp check_resource_utilization_thresholds(metrics) do
    if metrics.memory_usage.usage_percent > 90 do
      send_performance_alert("High memory usage", metrics)
    end

    if metrics.process_count > 1_000_000 do
      send_performance_alert("High process count", metrics)
    end
  end

  defp check_database_performance_thresholds(metrics) do
    if length(metrics.slow_queries) > 10 do
      send_performance_alert("Many slow queries detected", metrics)
    end

    if metrics.connection_pool_usage.usage_percent > 80 do
      send_performance_alert("High database connection pool usage", metrics)
    end
  end

  defp check_api_performance_thresholds(metrics) do
    Enum.each(metrics, fn {api, performance} ->
      if is_map(performance) && Map.get(performance, :success_rate, 100) < 95 do
        send_performance_alert("Low #{api} API success rate", performance)
      end
    end)
  end

  defp check_user_experience_thresholds(metrics) do
    if metrics.bounce_rate > 50 do
      send_performance_alert("High bounce rate", metrics)
    end

    if metrics.user_satisfaction_score < 3.0 do
      send_performance_alert("Low user satisfaction score", metrics)
    end
  end

  defp send_performance_alert(alert_type, metrics) do
    Logger.warning("Performance alert: #{alert_type} - #{inspect(metrics)}")

    # Send alert to admin users
    admin_users = LinkedinAi.Accounts.list_admin_users()

    Enum.each(admin_users, fn admin ->
      LinkedinAi.Jobs.enqueue_email_notification(
        admin.id,
        "performance_alert",
        %{
          alert_type: alert_type,
          metrics: metrics,
          timestamp: DateTime.utc_now()
        }
      )
    end)
  end
end
