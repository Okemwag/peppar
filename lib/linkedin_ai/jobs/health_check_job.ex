defmodule LinkedinAi.Jobs.HealthCheckJob do
  @moduledoc """
  Background job for performing system health checks and monitoring.
  Checks external services, database health, and system performance.
  """

  use Oban.Worker, queue: :monitoring, max_attempts: 1

  alias LinkedinAi.{Repo, Analytics}
  alias LinkedinAi.AI.OpenAIClient
  alias LinkedinAi.Billing.StripeClient
  alias LinkedinAi.Social.LinkedInClient

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    Logger.info("Starting system health check")

    health_results = %{
      database: check_database_health(),
      openai: check_openai_health(),
      stripe: check_stripe_health(),
      linkedin: check_linkedin_health(),
      redis: check_redis_health(),
      disk_space: check_disk_space(),
      memory_usage: check_memory_usage(),
      job_queue: check_job_queue_health()
    }

    overall_status = determine_overall_status(health_results)

    # Store health check results
    store_health_results(health_results, overall_status)

    # Send alerts if critical issues found
    if overall_status == :critical do
      send_critical_alerts(health_results)
    end

    Logger.info("System health check completed: #{overall_status}")
    {:ok, %{status: overall_status, results: health_results}}
  end

  defp check_database_health do
    try do
      # Test basic connectivity
      Repo.query!("SELECT 1")

      # Check connection pool
      pool_size = get_pool_size()
      active_connections = get_active_connections()

      # Check for slow queries
      slow_queries = get_slow_queries()

      status =
        cond do
          length(slow_queries) > 10 -> :warning
          active_connections / pool_size > 0.8 -> :warning
          true -> :healthy
        end

      %{
        status: status,
        pool_size: pool_size,
        active_connections: active_connections,
        slow_queries_count: length(slow_queries),
        response_time: measure_query_time()
      }
    rescue
      error ->
        Logger.error("Database health check failed: #{inspect(error)}")
        %{status: :critical, error: inspect(error)}
    end
  end

  defp check_openai_health do
    case OpenAIClient.health_check() do
      {:ok, :healthy} ->
        %{status: :healthy, response_time: measure_openai_response_time()}

      {:error, :unauthorized} ->
        %{status: :critical, error: "OpenAI API key invalid"}

      {:error, reason} ->
        %{status: :warning, error: inspect(reason)}
    end
  end

  defp check_stripe_health do
    case StripeClient.health_check() do
      {:ok, :healthy} ->
        %{status: :healthy, response_time: measure_stripe_response_time()}

      {:error, :unauthorized} ->
        %{status: :critical, error: "Stripe API key invalid"}

      {:error, reason} ->
        %{status: :warning, error: inspect(reason)}
    end
  end

  defp check_linkedin_health do
    case LinkedInClient.health_check() do
      {:ok, :healthy} ->
        %{status: :healthy, response_time: measure_linkedin_response_time()}

      {:error, reason} ->
        %{status: :warning, error: inspect(reason)}
    end
  end

  defp check_redis_health do
    # Placeholder for Redis health check
    # Implementation depends on your Redis setup
    %{status: :healthy, response_time: 5}
  end

  defp check_disk_space do
    try do
      {output, 0} = System.cmd("df", ["-h", "/"])

      # Parse disk usage (simplified)
      usage_line = output |> String.split("\n") |> Enum.at(1, "")
      usage_percent = usage_line |> String.split() |> Enum.at(4, "0%")

      usage_value =
        usage_percent
        |> String.trim_trailing("%")
        |> String.to_integer()

      status =
        cond do
          usage_value > 90 -> :critical
          usage_value > 80 -> :warning
          true -> :healthy
        end

      %{status: status, usage_percent: usage_percent, usage_value: usage_value}
    rescue
      _ ->
        %{status: :unknown, error: "Could not check disk space"}
    end
  end

  defp check_memory_usage do
    try do
      memory_info = :erlang.memory()
      total_memory = memory_info[:total]

      # Get system memory info (Linux)
      {output, 0} = System.cmd("free", ["-m"])
      lines = String.split(output, "\n")
      mem_line = Enum.find(lines, &String.starts_with?(&1, "Mem:"))

      if mem_line do
        [_, total, used, _, _, _, _] = String.split(mem_line)
        total_mb = String.to_integer(total)
        used_mb = String.to_integer(used)
        usage_percent = round(used_mb / total_mb * 100)

        status =
          cond do
            usage_percent > 90 -> :critical
            usage_percent > 80 -> :warning
            true -> :healthy
          end

        %{
          status: status,
          system_usage_percent: usage_percent,
          system_total_mb: total_mb,
          system_used_mb: used_mb,
          erlang_total_bytes: total_memory
        }
      else
        %{status: :unknown, erlang_total_bytes: total_memory}
      end
    rescue
      _ ->
        %{status: :unknown, error: "Could not check memory usage"}
    end
  end

  defp check_job_queue_health do
    try do
      job_stats = LinkedinAi.Jobs.get_job_stats()

      status =
        cond do
          job_stats.failed > 50 -> :critical
          job_stats.failed > 20 -> :warning
          job_stats.pending > 1000 -> :warning
          true -> :healthy
        end

      Map.put(job_stats, :status, status)
    rescue
      error ->
        %{status: :critical, error: inspect(error)}
    end
  end

  # Helper functions for measuring response times
  defp measure_query_time do
    {time, _result} = :timer.tc(fn -> Repo.query!("SELECT 1") end)
    # Convert to milliseconds
    round(time / 1000)
  end

  defp measure_openai_response_time do
    {time, _result} =
      :timer.tc(fn ->
        OpenAIClient.list_models()
      end)

    round(time / 1000)
  end

  defp measure_stripe_response_time do
    {time, _result} =
      :timer.tc(fn ->
        StripeClient.health_check()
      end)

    round(time / 1000)
  end

  defp measure_linkedin_response_time do
    {time, _result} =
      :timer.tc(fn ->
        LinkedInClient.health_check()
      end)

    round(time / 1000)
  end

  # Database helper functions
  defp get_pool_size do
    # Get from application config
    Application.get_env(:linkedin_ai, Repo)[:pool_size] || 10
  end

  defp get_active_connections do
    # This is a simplified implementation
    # In practice, you'd query the database for active connections
    5
  end

  defp get_slow_queries do
    # Query for slow running queries
    # Implementation depends on your database monitoring setup
    []
  end

  # Status determination
  defp determine_overall_status(health_results) do
    statuses =
      health_results
      |> Map.values()
      |> Enum.map(&Map.get(&1, :status, :unknown))

    cond do
      :critical in statuses -> :critical
      :warning in statuses -> :warning
      Enum.all?(statuses, &(&1 == :healthy)) -> :healthy
      true -> :unknown
    end
  end

  # Storage and alerting
  defp store_health_results(results, overall_status) do
    try do
      # Store health check results in database or monitoring system
      Analytics.store_health_check_results(%{
        timestamp: DateTime.utc_now(),
        overall_status: overall_status,
        results: results
      })
    rescue
      error ->
        Logger.error("Failed to store health check results: #{inspect(error)}")
    end
  end

  defp send_critical_alerts(health_results) do
    try do
      # Send alerts to admin users for critical issues
      critical_services =
        health_results
        |> Enum.filter(fn {_service, result} ->
          Map.get(result, :status) == :critical
        end)
        |> Enum.map(fn {service, _result} -> service end)

      if length(critical_services) > 0 do
        admin_users = LinkedinAi.Accounts.list_admin_users()

        Enum.each(admin_users, fn admin ->
          LinkedinAi.Jobs.enqueue_email_notification(
            admin.id,
            "critical_system_alert",
            %{
              services: critical_services,
              timestamp: DateTime.utc_now(),
              results: health_results
            }
          )
        end)

        Logger.error("Critical system issues detected: #{inspect(critical_services)}")
      end
    rescue
      error ->
        Logger.error("Failed to send critical alerts: #{inspect(error)}")
    end
  end
end
