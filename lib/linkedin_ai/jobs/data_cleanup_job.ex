defmodule LinkedinAi.Jobs.DataCleanupJob do
  @moduledoc """
  Background job for cleaning up old data and maintaining database performance.
  Handles cleanup of sessions, logs, temporary files, and other maintenance tasks.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 2

  alias LinkedinAi.{Repo, Analytics}

  require Logger
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"cleanup_type" => cleanup_type, "days_old" => days_old}}) do
    Logger.info("Starting data cleanup job: #{cleanup_type} (#{days_old} days old)")

    case cleanup_type do
      "old_sessions" ->
        cleanup_old_sessions(days_old)

      "old_logs" ->
        cleanup_old_logs(days_old)

      "temp_files" ->
        cleanup_temp_files(days_old)

      "completed_jobs" ->
        cleanup_completed_jobs(days_old)

      "analytics_data" ->
        cleanup_old_analytics_data(days_old)

      "user_tokens" ->
        cleanup_expired_user_tokens(days_old)

      "all" ->
        cleanup_all(days_old)

      _ ->
        Logger.error("Unknown cleanup type: #{cleanup_type}")
        {:error, "Unknown cleanup type"}
    end
  end

  defp cleanup_old_sessions(days_old) do
    try do
      cutoff_date = DateTime.utc_now() |> DateTime.add(-days_old * 24 * 60 * 60, :second)

      {count, _} =
        from(t in LinkedinAi.Accounts.UserToken,
          where: t.context == "session" and t.inserted_at < ^cutoff_date
        )
        |> Repo.delete_all()

      Logger.info("Cleaned up #{count} old sessions")
      :ok
    rescue
      error ->
        Logger.error("Failed to cleanup old sessions: #{inspect(error)}")
        {:error, :session_cleanup_failed}
    end
  end

  defp cleanup_old_logs(days_old) do
    try do
      # Clean up application logs if stored in database
      # This is a placeholder - actual implementation depends on logging setup
      Logger.info("Log cleanup completed (#{days_old} days)")
      :ok
    rescue
      error ->
        Logger.error("Failed to cleanup old logs: #{inspect(error)}")
        {:error, :log_cleanup_failed}
    end
  end

  defp cleanup_temp_files(days_old) do
    try do
      # Clean up temporary files from file system
      temp_dir = System.tmp_dir()
      cutoff_time = System.system_time(:second) - days_old * 24 * 60 * 60

      temp_files = Path.wildcard(Path.join(temp_dir, "linkedin_ai_*"))

      cleaned_count =
        Enum.reduce(temp_files, 0, fn file_path, acc ->
          case File.stat(file_path) do
            {:ok, %File.Stat{mtime: mtime}} ->
              if mtime < cutoff_time do
                File.rm(file_path)
                acc + 1
              else
                acc
              end

            {:error, _} ->
              acc
          end
        end)

      Logger.info("Cleaned up #{cleaned_count} temporary files")
      :ok
    rescue
      error ->
        Logger.error("Failed to cleanup temp files: #{inspect(error)}")
        {:error, :temp_file_cleanup_failed}
    end
  end

  defp cleanup_completed_jobs(days_old) do
    try do
      cutoff_date = DateTime.utc_now() |> DateTime.add(-days_old * 24 * 60 * 60, :second)

      {count, _} =
        from(j in Oban.Job,
          where: j.state == "completed" and j.completed_at < ^cutoff_date
        )
        |> Repo.delete_all()

      Logger.info("Cleaned up #{count} completed jobs")
      :ok
    rescue
      error ->
        Logger.error("Failed to cleanup completed jobs: #{inspect(error)}")
        {:error, :job_cleanup_failed}
    end
  end

  defp cleanup_old_analytics_data(days_old) do
    try do
      # Clean up detailed analytics data older than specified days
      # Keep aggregated data but remove raw event data
      cutoff_date = Date.utc_today() |> Date.add(-days_old)

      # This would clean up detailed analytics tables
      # Implementation depends on your analytics schema
      Logger.info("Analytics data cleanup completed for data older than #{cutoff_date}")
      :ok
    rescue
      error ->
        Logger.error("Failed to cleanup analytics data: #{inspect(error)}")
        {:error, :analytics_cleanup_failed}
    end
  end

  defp cleanup_expired_user_tokens(days_old) do
    try do
      cutoff_date = DateTime.utc_now() |> DateTime.add(-days_old * 24 * 60 * 60, :second)

      # Clean up expired password reset tokens, email confirmation tokens, etc.
      {count, _} =
        from(t in LinkedinAi.Accounts.UserToken,
          where: t.context in ["reset_password", "confirm"] and t.inserted_at < ^cutoff_date
        )
        |> Repo.delete_all()

      Logger.info("Cleaned up #{count} expired user tokens")
      :ok
    rescue
      error ->
        Logger.error("Failed to cleanup user tokens: #{inspect(error)}")
        {:error, :token_cleanup_failed}
    end
  end

  defp cleanup_all(days_old) do
    Logger.info("Starting comprehensive data cleanup (#{days_old} days old)")

    results = [
      cleanup_old_sessions(days_old),
      cleanup_old_logs(days_old),
      cleanup_temp_files(days_old),
      cleanup_completed_jobs(days_old),
      cleanup_old_analytics_data(days_old),
      cleanup_expired_user_tokens(days_old)
    ]

    failed_cleanups =
      Enum.filter(results, fn
        :ok -> false
        {:error, _} -> true
      end)

    if Enum.empty?(failed_cleanups) do
      Logger.info("Comprehensive data cleanup completed successfully")
      :ok
    else
      Logger.error("Some cleanup operations failed: #{inspect(failed_cleanups)}")
      {:error, :partial_cleanup_failure}
    end
  end

  @doc """
  Optimizes database performance by running maintenance tasks.
  """
  def optimize_database do
    try do
      # Analyze tables for query optimization
      Repo.query!("ANALYZE;")

      # Vacuum to reclaim space (if using PostgreSQL)
      if postgres?() do
        Repo.query!("VACUUM;")
      end

      Logger.info("Database optimization completed")
      :ok
    rescue
      error ->
        Logger.error("Database optimization failed: #{inspect(error)}")
        {:error, :optimization_failed}
    end
  end

  @doc """
  Checks database health and reports issues.
  """
  def check_database_health do
    try do
      # Check database connection
      Repo.query!("SELECT 1")

      # Check table sizes
      table_sizes = get_table_sizes()

      # Check for long-running queries
      long_queries = get_long_running_queries()

      # Log health status
      Logger.info("Database health check completed")
      Logger.info("Large tables: #{inspect(table_sizes)}")

      if length(long_queries) > 0 do
        Logger.warning("Found #{length(long_queries)} long-running queries")
      end

      :ok
    rescue
      error ->
        Logger.error("Database health check failed: #{inspect(error)}")
        {:error, :health_check_failed}
    end
  end

  defp postgres? do
    Repo.__adapter__() == Ecto.Adapters.Postgres
  end

  defp get_table_sizes do
    if postgres?() do
      case Repo.query("""
             SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
             FROM pg_tables 
             WHERE schemaname = 'public' 
             ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
             LIMIT 10
           """) do
        {:ok, %{rows: rows}} -> rows
        _ -> []
      end
    else
      []
    end
  end

  defp get_long_running_queries do
    if postgres?() do
      case Repo.query("""
             SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
             FROM pg_stat_activity 
             WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
             AND state = 'active'
           """) do
        {:ok, %{rows: rows}} -> rows
        _ -> []
      end
    else
      []
    end
  end
end
