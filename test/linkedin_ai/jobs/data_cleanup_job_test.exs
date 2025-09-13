defmodule LinkedinAi.Jobs.DataCleanupJobTest do
  use LinkedinAi.DataCase, async: true
  use Oban.Testing, repo: LinkedinAi.Repo

  alias LinkedinAi.Jobs.DataCleanupJob
  alias LinkedinAi.Accounts.UserToken

  import LinkedinAi.AccountsFixtures

  describe "old sessions cleanup" do
    test "cleans up old sessions successfully" do
      # Create old session token
      user = user_fixture()
      old_date = DateTime.add(DateTime.utc_now(), -40, :day)

      {:ok, old_token} =
        %UserToken{}
        |> UserToken.changeset(%{
          user_id: user.id,
          token: :crypto.strong_rand_bytes(32),
          context: "session",
          inserted_at: old_date,
          updated_at: old_date
        })
        |> Repo.insert()

      # Create recent session token
      {:ok, recent_token} =
        %UserToken{}
        |> UserToken.changeset(%{
          user_id: user.id,
          token: :crypto.strong_rand_bytes(32),
          context: "session",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })
        |> Repo.insert()

      job_args = %{"cleanup_type" => "old_sessions", "days_old" => 30}

      assert :ok = perform_job(DataCleanupJob, job_args)

      # Old token should be deleted
      refute Repo.get(UserToken, old_token.id)

      # Recent token should remain
      assert Repo.get(UserToken, recent_token.id)
    end

    test "handles no old sessions gracefully" do
      job_args = %{"cleanup_type" => "old_sessions", "days_old" => 30}

      assert :ok = perform_job(DataCleanupJob, job_args)
    end
  end

  describe "old logs cleanup" do
    test "cleans up old logs successfully" do
      job_args = %{"cleanup_type" => "old_logs", "days_old" => 30}

      assert :ok = perform_job(DataCleanupJob, job_args)
    end
  end

  describe "temp files cleanup" do
    test "cleans up old temporary files" do
      # Create a temporary file
      temp_dir = System.tmp_dir()
      temp_file = Path.join(temp_dir, "linkedin_ai_test_#{System.unique_integer()}")
      File.write!(temp_file, "test content")

      # Set old modification time
      old_time = System.system_time(:second) - 40 * 24 * 60 * 60
      File.touch!(temp_file, old_time)

      job_args = %{"cleanup_type" => "temp_files", "days_old" => 30}

      assert :ok = perform_job(DataCleanupJob, job_args)

      # File should be deleted
      refute File.exists?(temp_file)
    end

    test "preserves recent temporary files" do
      # Create a recent temporary file
      temp_dir = System.tmp_dir()
      temp_file = Path.join(temp_dir, "linkedin_ai_test_#{System.unique_integer()}")
      File.write!(temp_file, "test content")

      job_args = %{"cleanup_type" => "temp_files", "days_old" => 30}

      assert :ok = perform_job(DataCleanupJob, job_args)

      # Recent file should remain
      assert File.exists?(temp_file)

      # Clean up
      File.rm(temp_file)
    end
  end

  describe "completed jobs cleanup" do
    test "cleans up old completed jobs" do
      # Create old completed job
      old_date = DateTime.add(DateTime.utc_now(), -40, :day)

      {:ok, old_job} =
        %Oban.Job{}
        |> Oban.Job.changeset(%{
          worker: "TestWorker",
          queue: "default",
          args: %{},
          state: "completed",
          completed_at: old_date,
          inserted_at: old_date
        })
        |> Repo.insert()

      # Create recent completed job
      {:ok, recent_job} =
        %Oban.Job{}
        |> Oban.Job.changeset(%{
          worker: "TestWorker",
          queue: "default",
          args: %{},
          state: "completed",
          completed_at: DateTime.utc_now(),
          inserted_at: DateTime.utc_now()
        })
        |> Repo.insert()

      job_args = %{"cleanup_type" => "completed_jobs", "days_old" => 30}

      assert :ok = perform_job(DataCleanupJob, job_args)

      # Old job should be deleted
      refute Repo.get(Oban.Job, old_job.id)

      # Recent job should remain
      assert Repo.get(Oban.Job, recent_job.id)
    end
  end

  describe "analytics data cleanup" do
    test "cleans up old analytics data successfully" do
      job_args = %{"cleanup_type" => "analytics_data", "days_old" => 365}

      assert :ok = perform_job(DataCleanupJob, job_args)
    end
  end

  describe "user tokens cleanup" do
    test "cleans up expired user tokens" do
      # Create old reset password token
      user = user_fixture()
      old_date = DateTime.add(DateTime.utc_now(), -10, :day)

      {:ok, old_token} =
        %UserToken{}
        |> UserToken.changeset(%{
          user_id: user.id,
          token: :crypto.strong_rand_bytes(32),
          context: "reset_password",
          inserted_at: old_date,
          updated_at: old_date
        })
        |> Repo.insert()

      # Create recent confirm token
      {:ok, recent_token} =
        %UserToken{}
        |> UserToken.changeset(%{
          user_id: user.id,
          token: :crypto.strong_rand_bytes(32),
          context: "confirm",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })
        |> Repo.insert()

      job_args = %{"cleanup_type" => "user_tokens", "days_old" => 7}

      assert :ok = perform_job(DataCleanupJob, job_args)

      # Old token should be deleted
      refute Repo.get(UserToken, old_token.id)

      # Recent token should remain
      assert Repo.get(UserToken, recent_token.id)
    end
  end

  describe "comprehensive cleanup" do
    test "runs all cleanup operations" do
      # Create test data
      user = user_fixture()
      old_date = DateTime.add(DateTime.utc_now(), -40, :day)

      # Old session token
      {:ok, _old_token} =
        %UserToken{}
        |> UserToken.changeset(%{
          user_id: user.id,
          token: :crypto.strong_rand_bytes(32),
          context: "session",
          inserted_at: old_date,
          updated_at: old_date
        })
        |> Repo.insert()

      # Old completed job
      {:ok, _old_job} =
        %Oban.Job{}
        |> Oban.Job.changeset(%{
          worker: "TestWorker",
          queue: "default",
          args: %{},
          state: "completed",
          completed_at: old_date,
          inserted_at: old_date
        })
        |> Repo.insert()

      job_args = %{"cleanup_type" => "all", "days_old" => 30}

      assert :ok = perform_job(DataCleanupJob, job_args)
    end

    test "handles partial failures gracefully" do
      job_args = %{"cleanup_type" => "all", "days_old" => 30}

      # Should complete even if some operations fail
      assert :ok = perform_job(DataCleanupJob, job_args)
    end
  end

  describe "error handling" do
    test "returns error for unknown cleanup type" do
      job_args = %{"cleanup_type" => "unknown", "days_old" => 30}

      assert {:error, "Unknown cleanup type"} = perform_job(DataCleanupJob, job_args)
    end

    test "handles database errors gracefully" do
      job_args = %{"cleanup_type" => "old_sessions", "days_old" => 30}

      # Should not crash even if database operations fail
      assert :ok = perform_job(DataCleanupJob, job_args)
    end
  end

  describe "database optimization" do
    test "optimizes database successfully" do
      assert :ok = DataCleanupJob.optimize_database()
    end

    test "checks database health" do
      assert :ok = DataCleanupJob.check_database_health()
    end
  end
end
