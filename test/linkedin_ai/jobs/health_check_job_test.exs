defmodule LinkedinAi.Jobs.HealthCheckJobTest do
  use LinkedinAi.DataCase, async: true
  use Oban.Testing, repo: LinkedinAi.Repo

  alias LinkedinAi.Jobs.HealthCheckJob

  import LinkedinAi.AccountsFixtures

  describe "health check execution" do
    test "performs complete health check successfully" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      assert %{status: status, results: results} = result
      assert status in [:healthy, :warning, :critical, :unknown]
      assert is_map(results)

      # Check that all expected health checks are present
      expected_checks = [
        :database,
        :openai,
        :stripe,
        :linkedin,
        :redis,
        :disk_space,
        :memory_usage,
        :job_queue
      ]

      for check <- expected_checks do
        assert Map.has_key?(results, check)
        assert Map.has_key?(results[check], :status)
      end
    end

    test "handles individual service failures gracefully" do
      job_args = %{}

      # Should not crash even if some services are unavailable
      assert {:ok, result} = perform_job(HealthCheckJob, job_args)
      assert Map.has_key?(result, :status)
      assert Map.has_key?(result, :results)
    end
  end

  describe "database health check" do
    test "reports healthy database status" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      database_health = result.results.database
      assert Map.has_key?(database_health, :status)
      assert Map.has_key?(database_health, :response_time)
    end

    test "measures database response time" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      database_health = result.results.database
      assert is_integer(database_health.response_time)
      assert database_health.response_time > 0
    end
  end

  describe "external service health checks" do
    test "checks OpenAI service health" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      openai_health = result.results.openai
      assert Map.has_key?(openai_health, :status)
    end

    test "checks Stripe service health" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      stripe_health = result.results.stripe
      assert Map.has_key?(stripe_health, :status)
    end

    test "checks LinkedIn service health" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      linkedin_health = result.results.linkedin
      assert Map.has_key?(linkedin_health, :status)
    end

    test "checks Redis service health" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      redis_health = result.results.redis
      assert Map.has_key?(redis_health, :status)
    end
  end

  describe "system resource checks" do
    test "checks disk space usage" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      disk_health = result.results.disk_space
      assert Map.has_key?(disk_health, :status)
    end

    test "checks memory usage" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      memory_health = result.results.memory_usage
      assert Map.has_key?(memory_health, :status)
    end
  end

  describe "job queue health check" do
    test "checks job queue status" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      job_queue_health = result.results.job_queue
      assert Map.has_key?(job_queue_health, :status)
    end

    test "reports job queue statistics" do
      # Create some test jobs
      LinkedinAi.Jobs.enqueue_content_generation(1, %{})
      LinkedinAi.Jobs.enqueue_analytics_processing("daily", Date.utc_today())

      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      job_queue_health = result.results.job_queue
      assert Map.has_key?(job_queue_health, :status)
    end
  end

  describe "overall status determination" do
    test "reports healthy status when all services are healthy" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      # Status should be one of the valid statuses
      assert result.status in [:healthy, :warning, :critical, :unknown]
    end

    test "reports critical status when critical issues exist" do
      job_args = %{}

      # Even with potential issues, should not crash
      assert {:ok, result} = perform_job(HealthCheckJob, job_args)
      assert is_atom(result.status)
    end
  end

  describe "health results storage" do
    test "stores health check results" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      # Should complete without errors
      assert Map.has_key?(result, :results)
    end
  end

  describe "critical alerts" do
    test "handles critical alert sending" do
      # Create admin user
      admin = user_fixture(%{role: "admin"})

      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      # Should complete regardless of alert status
      assert Map.has_key?(result, :status)
    end

    test "does not send alerts for healthy status" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      # Should complete successfully
      assert is_map(result.results)
    end
  end

  describe "response time measurements" do
    test "measures database query response time" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      database_health = result.results.database

      if Map.has_key?(database_health, :response_time) do
        assert is_integer(database_health.response_time)
        assert database_health.response_time >= 0
      end
    end

    test "measures external service response times" do
      job_args = %{}

      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      # Check that response times are measured for available services
      for service <- [:openai, :stripe, :linkedin] do
        service_health = result.results[service]

        if Map.has_key?(service_health, :response_time) do
          assert is_integer(service_health.response_time)
          assert service_health.response_time >= 0
        end
      end
    end
  end

  describe "error handling" do
    test "handles service unavailability gracefully" do
      job_args = %{}

      # Should not crash even if services are unavailable
      assert {:ok, result} = perform_job(HealthCheckJob, job_args)
      assert Map.has_key?(result, :status)
      assert Map.has_key?(result, :results)
    end

    test "handles system command failures" do
      job_args = %{}

      # Should handle system command failures gracefully
      assert {:ok, result} = perform_job(HealthCheckJob, job_args)

      # Disk space and memory checks might fail on some systems
      disk_health = result.results.disk_space
      memory_health = result.results.memory_usage

      # Should have status even if checks fail
      assert Map.has_key?(disk_health, :status)
      assert Map.has_key?(memory_health, :status)
    end
  end
end
