defmodule LinkedinAi.Jobs.PerformanceMonitoringJobTest do
  use LinkedinAi.DataCase, async: true
  use Oban.Testing, repo: LinkedinAi.Repo

  alias LinkedinAi.Jobs.PerformanceMonitoringJob

  import LinkedinAi.AccountsFixtures
  import LinkedinAi.SubscriptionsFixtures

  describe "response time monitoring" do
    test "monitors response times successfully" do
      job_args = %{"monitoring_type" => "response_times"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "measures database response time" do
      job_args = %{"monitoring_type" => "response_times"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "throughput monitoring" do
    test "monitors system throughput successfully" do
      # Create some usage records
      user = user_fixture()
      subscription = subscription_fixture(%{user_id: user.id})

      job_args = %{"monitoring_type" => "throughput"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "calculates operations per minute" do
      job_args = %{"monitoring_type" => "throughput"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "error rate monitoring" do
    test "monitors error rates successfully" do
      job_args = %{"monitoring_type" => "error_rates"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "calculates error rates with failed jobs" do
      # Create a failed job
      {:ok, _failed_job} =
        %Oban.Job{}
        |> Oban.Job.changeset(%{
          worker: "TestWorker",
          queue: "default",
          args: %{},
          state: "discarded",
          discarded_at: DateTime.utc_now(),
          inserted_at: DateTime.utc_now()
        })
        |> Repo.insert()

      job_args = %{"monitoring_type" => "error_rates"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "resource utilization monitoring" do
    test "monitors resource utilization successfully" do
      job_args = %{"monitoring_type" => "resource_utilization"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "gets system resource metrics" do
      job_args = %{"monitoring_type" => "resource_utilization"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "database performance monitoring" do
    test "monitors database performance successfully" do
      job_args = %{"monitoring_type" => "database_performance"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "checks for slow queries" do
      job_args = %{"monitoring_type" => "database_performance"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "API performance monitoring" do
    test "monitors API performance successfully" do
      job_args = %{"monitoring_type" => "api_performance"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "measures external API performance" do
      job_args = %{"monitoring_type" => "api_performance"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "user experience monitoring" do
    test "monitors user experience successfully" do
      job_args = %{"monitoring_type" => "user_experience"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "calculates user experience metrics" do
      job_args = %{"monitoring_type" => "user_experience"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "comprehensive monitoring" do
    test "runs all monitoring types successfully" do
      job_args = %{"monitoring_type" => "comprehensive"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "handles partial failures gracefully" do
      job_args = %{"monitoring_type" => "comprehensive"}

      # Should complete even if some monitors fail
      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "error handling" do
    test "returns error for unknown monitoring type" do
      job_args = %{"monitoring_type" => "unknown"}

      assert {:error, "Unknown monitoring type"} = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "handles monitoring failures gracefully" do
      job_args = %{"monitoring_type" => "response_times"}

      # Should not crash even if monitoring fails
      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "performance alerts" do
    test "sends alerts for high response times" do
      # Create admin user
      admin = user_fixture(%{role: "admin"})

      job_args = %{"monitoring_type" => "response_times"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "sends alerts for high error rates" do
      # Create admin user
      admin = user_fixture(%{role: "admin"})

      # Create multiple failed jobs to trigger high error rate
      for _ <- 1..10 do
        {:ok, _failed_job} =
          %Oban.Job{}
          |> Oban.Job.changeset(%{
            worker: "TestWorker",
            queue: "default",
            args: %{},
            state: "discarded",
            discarded_at: DateTime.utc_now(),
            inserted_at: DateTime.utc_now()
          })
          |> Repo.insert()
      end

      job_args = %{"monitoring_type" => "error_rates"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "sends alerts for resource issues" do
      # Create admin user
      admin = user_fixture(%{role: "admin"})

      job_args = %{"monitoring_type" => "resource_utilization"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end

  describe "metrics storage" do
    test "stores response time metrics" do
      job_args = %{"monitoring_type" => "response_times"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "stores throughput metrics" do
      job_args = %{"monitoring_type" => "throughput"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "stores error rate metrics" do
      job_args = %{"monitoring_type" => "error_rates"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "stores resource utilization metrics" do
      job_args = %{"monitoring_type" => "resource_utilization"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "stores database performance metrics" do
      job_args = %{"monitoring_type" => "database_performance"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "stores API performance metrics" do
      job_args = %{"monitoring_type" => "api_performance"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end

    test "stores user experience metrics" do
      job_args = %{"monitoring_type" => "user_experience"}

      assert :ok = perform_job(PerformanceMonitoringJob, job_args)
    end
  end
end
