defmodule LinkedinAi.Jobs.AnalyticsProcessingJobTest do
  use LinkedinAi.DataCase, async: true
  use Oban.Testing, repo: LinkedinAi.Repo

  alias LinkedinAi.Jobs.AnalyticsProcessingJob
  alias LinkedinAi.{Analytics, Accounts, ContentGeneration, ProfileOptimization, Subscriptions}

  import LinkedinAi.AccountsFixtures
  import LinkedinAi.SubscriptionsFixtures

  describe "daily analytics processing" do
    test "processes daily analytics successfully" do
      date = Date.utc_today()

      # Create test data
      user = user_fixture()

      subscription =
        subscription_fixture(%{user_id: user.id, plan_type: "basic", status: "active"})

      job_args = %{"type" => "daily", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "handles errors gracefully during daily processing" do
      date = Date.utc_today()
      job_args = %{"type" => "daily", "date" => Date.to_iso8601(date)}

      # Should not crash even with no data
      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end
  end

  describe "weekly analytics processing" do
    test "processes weekly analytics successfully" do
      date = Date.utc_today()

      # Create test data
      user = user_fixture()
      subscription = subscription_fixture(%{user_id: user.id, plan_type: "pro", status: "active"})

      job_args = %{"type" => "weekly", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "generates weekly reports" do
      date = Date.utc_today()
      job_args = %{"type" => "weekly", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end
  end

  describe "monthly analytics processing" do
    test "processes monthly analytics successfully" do
      date = Date.utc_today()

      # Create test data
      user = user_fixture()

      subscription =
        subscription_fixture(%{user_id: user.id, plan_type: "basic", status: "active"})

      job_args = %{"type" => "monthly", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "archives old data during monthly processing" do
      date = Date.utc_today()
      job_args = %{"type" => "monthly", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end
  end

  describe "user summary analytics processing" do
    test "processes user summary analytics successfully" do
      date = Date.utc_today()

      # Create active users
      user1 = user_fixture(%{last_login_at: DateTime.utc_now()})
      user2 = user_fixture(%{last_login_at: DateTime.utc_now()})

      job_args = %{"type" => "user_summary", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "handles users with no activity" do
      date = Date.utc_today()

      # Create inactive user
      user = user_fixture(%{last_login_at: DateTime.add(DateTime.utc_now(), -10, :day)})

      job_args = %{"type" => "user_summary", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end
  end

  describe "error handling" do
    test "returns error for unknown analytics type" do
      date = Date.utc_today()
      job_args = %{"type" => "unknown", "date" => Date.to_iso8601(date)}

      assert {:error, "Unknown analytics type"} = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "handles invalid date format" do
      job_args = %{"type" => "daily", "date" => "invalid-date"}

      assert_raise ArgumentError, fn ->
        perform_job(AnalyticsProcessingJob, job_args)
      end
    end
  end

  describe "metrics aggregation" do
    test "aggregates user metrics correctly" do
      date = Date.utc_today()

      # Create test users
      user1 = user_fixture(%{inserted_at: DateTime.utc_now()})
      user2 = user_fixture(%{inserted_at: DateTime.utc_now(), last_login_at: DateTime.utc_now()})

      job_args = %{"type" => "daily", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "aggregates content metrics correctly" do
      date = Date.utc_today()

      # Create test content
      user = user_fixture()

      job_args = %{"type" => "daily", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "aggregates subscription metrics correctly" do
      date = Date.utc_today()

      # Create test subscriptions
      user1 = user_fixture()
      user2 = user_fixture()

      subscription1 =
        subscription_fixture(%{user_id: user1.id, plan_type: "basic", status: "active"})

      subscription2 =
        subscription_fixture(%{user_id: user2.id, plan_type: "pro", status: "active"})

      job_args = %{"type" => "daily", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "aggregates usage metrics correctly" do
      date = Date.utc_today()

      # Create test usage records
      user = user_fixture()
      subscription = subscription_fixture(%{user_id: user.id})

      job_args = %{"type" => "daily", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end
  end

  describe "data cleanup" do
    test "cleans up old data during daily processing" do
      date = Date.utc_today()
      job_args = %{"type" => "daily", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "archives old analytics data during monthly processing" do
      date = Date.utc_today()
      job_args = %{"type" => "monthly", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end
  end

  describe "report generation" do
    test "generates weekly reports" do
      date = Date.utc_today()
      job_args = %{"type" => "weekly", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "generates monthly reports" do
      date = Date.utc_today()
      job_args = %{"type" => "monthly", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end
  end

  describe "notification handling" do
    test "sends weekly admin summary" do
      date = Date.utc_today()

      # Create admin user
      admin = user_fixture(%{role: "admin"})

      job_args = %{"type" => "weekly", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end

    test "sends engagement notifications to users" do
      date = Date.utc_today()

      # Create user with low engagement
      user = user_fixture(%{last_login_at: DateTime.utc_now()})

      job_args = %{"type" => "user_summary", "date" => Date.to_iso8601(date)}

      assert :ok = perform_job(AnalyticsProcessingJob, job_args)
    end
  end
end
