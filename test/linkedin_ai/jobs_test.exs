defmodule LinkedinAi.JobsTest do
  use LinkedinAi.DataCase, async: true
  use Oban.Testing, repo: LinkedinAi.Repo

  alias LinkedinAi.Jobs

  alias LinkedinAi.Jobs.{
    ContentGenerationJob,
    AnalyticsProcessingJob,
    EmailNotificationJob,
    DataCleanupJob,
    HealthCheckJob,
    PerformanceMonitoringJob
  }

  describe "job enqueuing" do
    test "enqueue_content_generation/2 creates a content generation job" do
      user_id = 1
      params = %{content_type: "post", prompt: "Test prompt"}

      assert {:ok, %Oban.Job{}} = Jobs.enqueue_content_generation(user_id, params)

      assert_enqueued(
        worker: ContentGenerationJob,
        args: %{user_id: user_id, params: params}
      )
    end

    test "enqueue_analytics_processing/2 creates an analytics job" do
      type = "daily"
      date = Date.utc_today()

      assert {:ok, %Oban.Job{}} = Jobs.enqueue_analytics_processing(type, date)

      assert_enqueued(
        worker: AnalyticsProcessingJob,
        args: %{type: type, date: date}
      )
    end

    test "enqueue_email_notification/3 creates an email job" do
      user_id = 1
      template = "welcome"
      data = %{name: "John"}

      assert {:ok, %Oban.Job{}} = Jobs.enqueue_email_notification(user_id, template, data)

      assert_enqueued(
        worker: EmailNotificationJob,
        args: %{user_id: user_id, template: template, data: data}
      )
    end

    test "enqueue_data_cleanup/2 creates a cleanup job" do
      cleanup_type = "old_sessions"
      days_old = 30

      assert {:ok, %Oban.Job{}} = Jobs.enqueue_data_cleanup(cleanup_type, days_old)

      assert_enqueued(
        worker: DataCleanupJob,
        args: %{cleanup_type: cleanup_type, days_old: days_old}
      )
    end

    test "enqueue_health_check/0 creates a health check job" do
      assert {:ok, %Oban.Job{}} = Jobs.enqueue_health_check()

      assert_enqueued(worker: HealthCheckJob)
    end

    test "enqueue_performance_monitoring/1 creates a performance monitoring job" do
      monitoring_type = "response_times"

      assert {:ok, %Oban.Job{}} = Jobs.enqueue_performance_monitoring(monitoring_type)

      assert_enqueued(
        worker: PerformanceMonitoringJob,
        args: %{monitoring_type: monitoring_type}
      )
    end
  end

  describe "job statistics" do
    test "get_job_stats/0 returns job statistics" do
      # Create some test jobs
      Jobs.enqueue_content_generation(1, %{})
      Jobs.enqueue_analytics_processing("daily", Date.utc_today())

      stats = Jobs.get_job_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :completed)
      assert Map.has_key?(stats, :failed)
      assert Map.has_key?(stats, :pending)
      assert Map.has_key?(stats, :executing)
      assert Map.has_key?(stats, :retryable)
    end

    test "get_failed_jobs/1 returns failed jobs" do
      failed_jobs = Jobs.get_failed_jobs(10)
      assert is_list(failed_jobs)
    end
  end

  describe "job management" do
    test "retry_job/1 retries a failed job" do
      # This would need a failed job to test properly
      # For now, just test the error case
      assert {:error, :not_found} = Jobs.retry_job(999_999)
    end

    test "cancel_job/1 cancels a scheduled job" do
      # This would need a scheduled job to test properly
      # For now, just test the error case
      assert {:error, :not_found} = Jobs.cancel_job(999_999)
    end

    test "purge_completed_jobs/1 removes old completed jobs" do
      {count, _} = Jobs.purge_completed_jobs(7)
      assert is_integer(count)
    end
  end
end
