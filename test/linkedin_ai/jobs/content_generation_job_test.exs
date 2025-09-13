defmodule LinkedinAi.Jobs.ContentGenerationJobTest do
  use LinkedinAi.DataCase, async: true
  use Oban.Testing, repo: LinkedinAi.Repo

  import Mox
  import LinkedinAi.AccountsFixtures
  import LinkedinAi.SubscriptionsFixtures

  alias LinkedinAi.Jobs.ContentGenerationJob
  alias LinkedinAi.{Accounts, ContentGeneration, Subscriptions}
  alias LinkedinAi.Accounts.User
  alias LinkedinAi.Subscriptions.Subscription

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "single content generation" do
    setup do
      user = user_fixture()

      subscription =
        subscription_fixture(%{user_id: user.id, plan_type: "basic", status: "active"})

      %{user: user, subscription: subscription}
    end

    test "successfully generates content for valid user and params", %{user: user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Write about artificial intelligence trends",
        "tone" => "professional",
        # This will be mapped to "industry"
        "target_audience" => "tech professionals"
      }

      job_args = %{
        "type" => "single",
        "user_id" => user.id,
        "params" => params
      }

      # Mock the AI response
      expect_ai_generation_success()

      assert :ok = perform_job(ContentGenerationJob, job_args)

      # Verify content was created
      contents = ContentGeneration.list_user_contents(user)
      assert length(contents) == 1

      content = List.first(contents)
      assert content.content_type == "post"
      assert content.prompt == "Write about artificial intelligence trends"
      assert content.tone == "professional"
      # Mapped from "tech professionals"
      assert content.target_audience == "industry"
      assert content.user_id == user.id
      assert content.word_count > 0
      assert content.generated_text != nil
    end

    test "handles user not found error", %{user: _user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt"
      }

      job_args = %{
        "type" => "single",
        "user_id" => 999_999,
        "params" => params
      }

      assert {:error, "User not found"} = perform_job(ContentGenerationJob, job_args)
    end

    test "handles usage limit exceeded", %{user: user} do
      # Exhaust the user's usage limit
      exhaust_usage_limit(user, "content_generation")

      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt"
      }

      job_args = %{
        "type" => "single",
        "user_id" => user.id,
        "params" => params
      }

      assert {:error, "Usage limit exceeded"} = perform_job(ContentGenerationJob, job_args)
    end

    test "handles OpenAI API errors", %{user: user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt"
      }

      job_args = %{
        "type" => "single",
        "user_id" => user.id,
        "params" => params
      }

      # Mock AI failure
      expect_ai_generation_failure()

      assert {:error, error_message} = perform_job(ContentGenerationJob, job_args)
      assert String.contains?(error_message, "OpenAI API error")
    end

    test "sends notification when requested", %{user: user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt",
        "notify_user" => true
      }

      job_args = %{
        "type" => "single",
        "user_id" => user.id,
        "params" => params
      }

      expect_ai_generation_success()

      assert :ok = perform_job(ContentGenerationJob, job_args)

      # Check that notification job was enqueued
      assert_enqueued(
        worker: LinkedinAi.Jobs.EmailNotificationJob,
        args: %{
          "user_id" => user.id,
          "template" => "content_generated"
        }
      )
    end

    test "records usage after successful generation", %{user: user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt"
      }

      job_args = %{
        "type" => "single",
        "user_id" => user.id,
        "params" => params
      }

      expect_ai_generation_success()

      initial_usage = Subscriptions.get_current_usage(user, "content_generation")

      assert :ok = perform_job(ContentGenerationJob, job_args)

      final_usage = Subscriptions.get_current_usage(user, "content_generation")
      assert final_usage == initial_usage + 1
    end
  end

  describe "batch content generation" do
    setup do
      user = user_fixture()
      subscription = subscription_fixture(%{user_id: user.id, plan_type: "pro", status: "active"})

      %{user: user, subscription: subscription}
    end

    test "successfully generates batch content", %{user: user} do
      batch_params = [
        %{
          "content_type" => "post",
          "prompt" => "AI trends in 2024",
          "tone" => "professional"
        },
        %{
          "content_type" => "post",
          "prompt" => "Remote work benefits",
          "tone" => "casual"
        },
        %{
          "content_type" => "comment",
          "prompt" => "Great insights on productivity",
          "tone" => "friendly"
        }
      ]

      job_args = %{
        "type" => "batch",
        "user_id" => user.id,
        "batch_params" => batch_params
      }

      expect_ai_generation_success(3)

      assert :ok = perform_job(ContentGenerationJob, job_args)

      # Verify all content was created
      contents = ContentGeneration.list_user_contents(user)
      assert length(contents) == 3

      # Verify different content types were created
      content_types = Enum.map(contents, & &1.content_type)
      assert "post" in content_types
      assert "comment" in content_types
    end

    test "handles partial batch failures", %{user: user} do
      batch_params = [
        %{
          "content_type" => "post",
          "prompt" => "Valid prompt",
          "tone" => "professional"
        },
        %{
          "content_type" => "post",
          # This should fail
          "prompt" => "",
          "tone" => "professional"
        }
      ]

      job_args = %{
        "type" => "batch",
        "user_id" => user.id,
        "batch_params" => batch_params
      }

      expect_ai_generation_mixed_results()

      assert {:error, error_message} = perform_job(ContentGenerationJob, job_args)
      assert String.contains?(error_message, "failed in batch")

      # Verify partial success - one content should be created
      contents = ContentGeneration.list_user_contents(user)
      assert length(contents) == 1
    end

    test "handles batch usage limit exceeded", %{user: user} do
      # Set up a basic subscription with limited usage
      subscription = Subscriptions.get_subscription_by_user_id(user.id)
      Subscriptions.update_subscription(subscription, %{plan_type: "basic"})

      batch_params = [
        %{"content_type" => "post", "prompt" => "Test 1"},
        %{"content_type" => "post", "prompt" => "Test 2"},
        %{"content_type" => "post", "prompt" => "Test 3"},
        %{"content_type" => "post", "prompt" => "Test 4"},
        %{"content_type" => "post", "prompt" => "Test 5"},
        %{"content_type" => "post", "prompt" => "Test 6"},
        %{"content_type" => "post", "prompt" => "Test 7"},
        %{"content_type" => "post", "prompt" => "Test 8"},
        %{"content_type" => "post", "prompt" => "Test 9"},
        %{"content_type" => "post", "prompt" => "Test 10"},
        # This exceeds basic limit of 10
        %{"content_type" => "post", "prompt" => "Test 11"}
      ]

      job_args = %{
        "type" => "batch",
        "user_id" => user.id,
        "batch_params" => batch_params
      }

      assert {:error, "Batch usage limit exceeded"} = perform_job(ContentGenerationJob, job_args)
    end

    test "sends batch completion notification", %{user: user} do
      batch_params = [
        %{"content_type" => "post", "prompt" => "Test 1"},
        %{"content_type" => "post", "prompt" => "Test 2"}
      ]

      job_args = %{
        "type" => "batch",
        "user_id" => user.id,
        "batch_params" => batch_params
      }

      expect_ai_generation_success(2)

      assert :ok = perform_job(ContentGenerationJob, job_args)

      # Check that batch completion notification was enqueued
      assert_enqueued(
        worker: LinkedinAi.Jobs.EmailNotificationJob,
        args: %{
          "user_id" => user.id,
          "template" => "batch_content_generation_completed"
        }
      )
    end

    test "records correct usage for batch generation", %{user: user} do
      batch_params = [
        %{"content_type" => "post", "prompt" => "Test 1"},
        %{"content_type" => "post", "prompt" => "Test 2"},
        %{"content_type" => "post", "prompt" => "Test 3"}
      ]

      job_args = %{
        "type" => "batch",
        "user_id" => user.id,
        "batch_params" => batch_params
      }

      expect_ai_generation_success(3)

      initial_usage = Subscriptions.get_current_usage(user, "content_generation")

      assert :ok = perform_job(ContentGenerationJob, job_args)

      final_usage = Subscriptions.get_current_usage(user, "content_generation")
      assert final_usage == initial_usage + 3
    end
  end

  describe "job progress tracking" do
    setup do
      user = user_fixture()

      subscription =
        subscription_fixture(%{user_id: user.id, plan_type: "basic", status: "active"})

      %{user: user, subscription: subscription}
    end

    test "tracks progress during single content generation", %{user: user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt"
      }

      job_args = %{
        "type" => "single",
        "user_id" => user.id,
        "params" => params
      }

      expect_ai_generation_success()

      # Perform job and get the job ID
      {:ok, job} = ContentGenerationJob.new(job_args) |> Oban.insert()

      # Perform the job
      assert :ok = perform_job(ContentGenerationJob, job_args)

      # Check final progress
      {:ok, progress} = ContentGenerationJob.get_job_progress(job.id)
      assert progress.progress == 100
      assert String.contains?(progress.status_message, "completed successfully")
    end

    test "tracks progress during batch generation", %{user: user} do
      batch_params = [
        %{"content_type" => "post", "prompt" => "Test 1"},
        %{"content_type" => "post", "prompt" => "Test 2"}
      ]

      job_args = %{
        "type" => "batch",
        "user_id" => user.id,
        "batch_params" => batch_params
      }

      expect_ai_generation_success(2)

      # Perform job and get the job ID
      {:ok, job} = ContentGenerationJob.new(job_args) |> Oban.insert()

      # Perform the job
      assert :ok = perform_job(ContentGenerationJob, job_args)

      # Check final progress
      {:ok, progress} = ContentGenerationJob.get_job_progress(job.id)
      assert progress.progress == 100
      assert String.contains?(progress.status_message, "Batch completed")
    end

    test "handles progress tracking for non-existent job" do
      assert {:error, :job_not_found} = ContentGenerationJob.get_job_progress(999_999)
    end
  end

  describe "error handling and notifications" do
    setup do
      user = user_fixture()

      subscription =
        subscription_fixture(%{user_id: user.id, plan_type: "basic", status: "active"})

      %{user: user, subscription: subscription}
    end

    test "sends failure notification on error", %{user: user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt"
      }

      job_args = %{
        "type" => "single",
        "user_id" => user.id,
        "params" => params
      }

      expect_ai_generation_failure()

      assert {:error, _} = perform_job(ContentGenerationJob, job_args)

      # Check that failure notification was enqueued
      assert_enqueued(
        worker: LinkedinAi.Jobs.EmailNotificationJob,
        args: %{
          "user_id" => user.id,
          "template" => "content_generation_failed"
        }
      )
    end

    test "updates job progress with error information", %{user: user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt"
      }

      job_args = %{
        "type" => "single",
        "user_id" => user.id,
        "params" => params
      }

      expect_ai_generation_failure()

      # Perform job and get the job ID
      {:ok, job} = ContentGenerationJob.new(job_args) |> Oban.insert()

      # Perform the job
      assert {:error, _} = perform_job(ContentGenerationJob, job_args)

      # Check error progress
      {:ok, progress} = ContentGenerationJob.get_job_progress(job.id)
      assert progress.progress == -1
      assert String.contains?(progress.status_message, "Error:")
    end
  end

  describe "backward compatibility" do
    setup do
      user = user_fixture()

      subscription =
        subscription_fixture(%{user_id: user.id, plan_type: "basic", status: "active"})

      %{user: user, subscription: subscription}
    end

    test "handles legacy job format without type", %{user: user} do
      params = %{
        "content_type" => "post",
        "prompt" => "Test prompt"
      }

      # Legacy job format without "type" field
      job_args = %{
        "user_id" => user.id,
        "params" => params
      }

      expect_ai_generation_success()

      assert :ok = perform_job(ContentGenerationJob, job_args)

      # Verify content was created
      contents = ContentGeneration.list_user_contents(user)
      assert length(contents) == 1
    end
  end

  # Test helper functions

  defp expect_ai_generation_success(count \\ 1) do
    # Mock successful AI generation
    LinkedinAi.AI.Mock
    |> expect(:generate_content, count, fn _params ->
      {:ok,
       %{
         text: "Generated LinkedIn content about the topic.",
         model: "gpt-3.5-turbo",
         tokens_used: 50,
         cost: Decimal.new("0.001")
       }}
    end)
  end

  defp expect_ai_generation_failure do
    # Mock AI generation failure
    LinkedinAi.AI.Mock
    |> expect(:generate_content, 1, fn _params ->
      {:error, :rate_limit_exceeded}
    end)
  end

  defp expect_ai_generation_mixed_results do
    # Mock mixed results for batch processing
    LinkedinAi.AI.Mock
    |> expect(:generate_content, 1, fn _params ->
      {:ok,
       %{
         text: "Generated content",
         model: "gpt-3.5-turbo",
         tokens_used: 50,
         cost: Decimal.new("0.001")
       }}
    end)
    |> expect(:generate_content, 1, fn _params ->
      {:error, :prompt_too_short}
    end)
  end

  defp exhaust_usage_limit(user, feature_type) do
    limit = Subscriptions.get_usage_limit(user, feature_type)

    if limit > 0 do
      Subscriptions.record_usage(user, feature_type, limit)
    end
  end
end
