defmodule LinkedinAi.Jobs do
  @moduledoc """
  Background job processing module using Oban.
  Handles async processing for content generation, analytics, and other long-running tasks.
  """

  alias LinkedinAi.Jobs.{
    ContentGenerationJob,
    AnalyticsProcessingJob,
    EmailNotificationJob,
    DataCleanupJob,
    HealthCheckJob,
    PerformanceMonitoringJob
  }

  @doc """
  Enqueues a single content generation job.

  ## Examples

      iex> enqueue_content_generation(user_id, %{content_type: "post", prompt: "..."})
      {:ok, %Oban.Job{}}

  """
  def enqueue_content_generation(user_id, params) do
    %{type: "single", user_id: user_id, params: params}
    |> ContentGenerationJob.new()
    |> Oban.insert()
  end

  @doc """
  Enqueues a batch content generation job.

  ## Examples

      iex> enqueue_batch_content_generation(user_id, [
      ...>   %{content_type: "post", prompt: "AI trends"},
      ...>   %{content_type: "post", prompt: "Remote work"}
      ...> ])
      {:ok, %Oban.Job{}}

  """
  def enqueue_batch_content_generation(user_id, batch_params) when is_list(batch_params) do
    %{type: "batch", user_id: user_id, batch_params: batch_params}
    |> ContentGenerationJob.new()
    |> Oban.insert()
  end

  @doc """
  Gets the progress of a content generation job.

  ## Examples

      iex> get_content_generation_progress(job_id)
      {:ok, %{progress: 75, status_message: "Generating content...", updated_at: ~U[...]}}

  """
  def get_content_generation_progress(job_id) do
    ContentGenerationJob.get_job_progress(job_id)
  end

  @doc """
  Enqueues an analytics processing job.

  ## Examples

      iex> enqueue_analytics_processing("daily", Date.utc_today())
      {:ok, %Oban.Job{}}

  """
  def enqueue_analytics_processing(type, date) do
    %{type: type, date: date}
    |> AnalyticsProcessingJob.new()
    |> Oban.insert()
  end

  @doc """
  Enqueues an email notification job.

  ## Examples

      iex> enqueue_email_notification(user_id, "welcome", %{name: "John"})
      {:ok, %Oban.Job{}}

  """
  def enqueue_email_notification(user_id, template, data) do
    %{user_id: user_id, template: template, data: data}
    |> EmailNotificationJob.new()
    |> Oban.insert()
  end

  @doc """
  Enqueues a data cleanup job.

  ## Examples

      iex> enqueue_data_cleanup("old_sessions", 30)
      {:ok, %Oban.Job{}}

  """
  def enqueue_data_cleanup(cleanup_type, days_old) do
    %{cleanup_type: cleanup_type, days_old: days_old}
    |> DataCleanupJob.new(schedule_in: {1, :hour})
    |> Oban.insert()
  end

  @doc """
  Enqueues a health check job.

  ## Examples

      iex> enqueue_health_check()
      {:ok, %Oban.Job{}}

  """
  def enqueue_health_check do
    %{}
    |> HealthCheckJob.new()
    |> Oban.insert()
  end

  @doc """
  Enqueues a performance monitoring job.

  ## Examples

      iex> enqueue_performance_monitoring("response_times")
      {:ok, %Oban.Job{}}

  """
  def enqueue_performance_monitoring(monitoring_type) do
    %{monitoring_type: monitoring_type}
    |> PerformanceMonitoringJob.new()
    |> Oban.insert()
  end

  @doc """
  Schedules recurring jobs.
  Called during application startup.
  """
  def schedule_recurring_jobs do
    # Schedule daily analytics processing
    %{type: "daily", date: Date.utc_today()}
    |> AnalyticsProcessingJob.new(schedule_in: {1, :day})
    |> Oban.insert()

    # Schedule weekly data cleanup
    %{cleanup_type: "old_sessions", days_old: 30}
    |> DataCleanupJob.new(schedule_in: {7, :day})
    |> Oban.insert()

    # Schedule health checks every 5 minutes
    %{}
    |> HealthCheckJob.new(schedule_in: {5, :minute})
    |> Oban.insert()

    # Schedule performance monitoring every 10 minutes
    %{monitoring_type: "comprehensive"}
    |> PerformanceMonitoringJob.new(schedule_in: {10, :minute})
    |> Oban.insert()
  end

  @doc """
  Gets job statistics for monitoring.

  ## Examples

      iex> get_job_stats()
      %{completed: 150, failed: 5, pending: 12, ...}

  """
  def get_job_stats do
    import Ecto.Query

    stats =
      from(j in Oban.Job,
        group_by: j.state,
        select: {j.state, count(j.id)}
      )
      |> LinkedinAi.Repo.all()
      |> Enum.into(%{})

    %{
      completed: Map.get(stats, "completed", 0),
      failed: Map.get(stats, "discarded", 0),
      pending: Map.get(stats, "available", 0) + Map.get(stats, "scheduled", 0),
      executing: Map.get(stats, "executing", 0),
      retryable: Map.get(stats, "retryable", 0)
    }
  end

  @doc """
  Gets failed jobs for monitoring and debugging.

  ## Examples

      iex> get_failed_jobs(10)
      [%Oban.Job{}, ...]

  """
  def get_failed_jobs(limit \\ 50) do
    import Ecto.Query

    from(j in Oban.Job,
      where: j.state == "discarded",
      order_by: [desc: j.discarded_at],
      limit: ^limit
    )
    |> LinkedinAi.Repo.all()
  end

  @doc """
  Retries a failed job.

  ## Examples

      iex> retry_job(job_id)
      {:ok, %Oban.Job{}}

  """
  def retry_job(job_id) do
    case LinkedinAi.Repo.get(Oban.Job, job_id) do
      %Oban.Job{} = job ->
        job
        |> Ecto.Changeset.change(%{state: "available", discarded_at: nil, errors: []})
        |> LinkedinAi.Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Cancels a scheduled or available job.

  ## Examples

      iex> cancel_job(job_id)
      {:ok, %Oban.Job{}}

  """
  def cancel_job(job_id) do
    case LinkedinAi.Repo.get(Oban.Job, job_id) do
      %Oban.Job{state: state} = job when state in ["available", "scheduled"] ->
        job
        |> Ecto.Changeset.change(%{state: "cancelled"})
        |> LinkedinAi.Repo.update()

      %Oban.Job{} ->
        {:error, :cannot_cancel}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Purges completed jobs older than specified days.

  ## Examples

      iex> purge_completed_jobs(7)
      {5, nil}

  """
  def purge_completed_jobs(days_old \\ 7) do
    import Ecto.Query

    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_old * 24 * 60 * 60, :second)

    from(j in Oban.Job,
      where: j.state == "completed" and j.completed_at < ^cutoff_date
    )
    |> LinkedinAi.Repo.delete_all()
  end
end
