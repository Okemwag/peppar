defmodule LinkedinAi.Jobs.ContentGenerationJob do
  @moduledoc """
  Background job for processing AI content generation requests.
  Handles async OpenAI API calls, batch processing, and progress tracking.
  """

  use Oban.Worker, queue: :content_generation, max_attempts: 3

  alias LinkedinAi.{ContentGeneration, Accounts, Subscriptions}
  alias LinkedinAi.Jobs.EmailNotificationJob

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{id: job_id, args: %{"type" => "single"} = args}) do
    perform_single_generation(job_id, args)
  end

  def perform(%Oban.Job{id: job_id, args: %{"type" => "batch"} = args}) do
    perform_batch_generation(job_id, args)
  end

  # Backward compatibility for existing jobs without type
  def perform(%Oban.Job{id: job_id, args: args}) do
    perform_single_generation(job_id, Map.put(args, "type", "single"))
  end

  ## Single Content Generation

  defp perform_single_generation(job_id, %{"user_id" => user_id, "params" => params}) do
    Logger.info("Starting single content generation job #{job_id} for user #{user_id}")

    # Update job progress
    update_job_progress(job_id, 0, "Starting content generation...")

    with {:ok, user} <- get_user(user_id),
         :ok <- check_usage_limits(user, params) do
      update_job_progress(job_id, 25, "Generating content with AI...")

      case generate_content(user, params) do
        {:ok, content} ->
          update_job_progress(job_id, 75, "Saving generated content...")

          case save_generated_content(user, content, params) do
            {:ok, record} ->
              update_job_progress(job_id, 90, "Recording usage...")

              # Record usage
              Subscriptions.record_usage(user, "content_generation", 1)

              # Update final progress
              update_job_progress(job_id, 100, "Content generation completed successfully")

              # Notify user if requested
              if params["notify_user"] do
                enqueue_success_notification(user_id, record, params)
              end

              Logger.info(
                "Content generation job #{job_id} completed successfully for user #{user_id}"
              )

              :ok

            {:error, reason} ->
              handle_job_error(
                job_id,
                user_id,
                {:error, reason},
                "Failed to save content: #{inspect(reason)}"
              )
          end

        {:error, :openai_error, reason} ->
          handle_job_error(
            job_id,
            user_id,
            {:error, :openai_error, reason},
            "OpenAI API error: #{inspect(reason)}"
          )
      end
    else
      {:error, :user_not_found} = error ->
        handle_job_error(job_id, user_id, error, "User not found")

      {:error, :usage_limit_exceeded} = error ->
        handle_job_error(job_id, user_id, error, "Usage limit exceeded")

      {:error, :openai_error, reason} = error ->
        handle_job_error(job_id, user_id, error, "OpenAI API error: #{inspect(reason)}")

      {:error, reason} = error ->
        handle_job_error(job_id, user_id, error, "Content generation failed: #{inspect(reason)}")
    end
  end

  ## Batch Content Generation

  defp perform_batch_generation(job_id, %{"user_id" => user_id, "batch_params" => batch_params}) do
    Logger.info("Starting batch content generation job #{job_id} for user #{user_id}")

    batch_size = length(batch_params)
    update_job_progress(job_id, 0, "Starting batch generation of #{batch_size} items...")

    with {:ok, user} <- get_user(user_id),
         :ok <- check_batch_usage_limits(user, batch_size) do
      results = process_batch_items(job_id, user, batch_params)

      successful_count = Enum.count(results, fn {status, _} -> status == :ok end)
      failed_count = batch_size - successful_count

      # Record usage for successful generations
      if successful_count > 0 do
        Subscriptions.record_usage(user, "content_generation", successful_count)
      end

      # Update final progress
      update_job_progress(
        job_id,
        100,
        "Batch completed: #{successful_count} successful, #{failed_count} failed"
      )

      # Send batch completion notification
      enqueue_batch_completion_notification(user_id, successful_count, failed_count, results)

      Logger.info(
        "Batch content generation job #{job_id} completed for user #{user_id}: #{successful_count}/#{batch_size} successful"
      )

      if failed_count == 0 do
        :ok
      else
        {:error, "#{failed_count} items failed in batch"}
      end
    else
      {:error, :user_not_found} = error ->
        handle_job_error(job_id, user_id, error, "User not found")

      {:error, :batch_usage_limit_exceeded} = error ->
        handle_job_error(job_id, user_id, error, "Batch usage limit exceeded")

      {:error, reason} = error ->
        handle_job_error(job_id, user_id, error, "Batch generation failed: #{inspect(reason)}")
    end
  end

  defp process_batch_items(job_id, user, batch_params) do
    total_items = length(batch_params)

    batch_params
    |> Enum.with_index(1)
    |> Enum.map(fn {params, index} ->
      # 10-90% range
      progress = trunc((index - 1) / total_items * 80) + 10
      update_job_progress(job_id, progress, "Processing item #{index}/#{total_items}...")

      case generate_and_save_content(user, params) do
        {:ok, record} ->
          Logger.debug("Batch item #{index} successful for user #{user.id}")
          {:ok, record}

        {:error, reason} ->
          Logger.warning("Batch item #{index} failed for user #{user.id}: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  defp generate_and_save_content(user, params) do
    with {:ok, content} <- generate_content(user, params),
         {:ok, record} <- save_generated_content(user, content, params) do
      {:ok, record}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  ## Helper Functions

  defp get_user(user_id) do
    case Accounts.get_user(user_id) do
      %Accounts.User{} = user -> {:ok, user}
      nil -> {:error, :user_not_found}
    end
  end

  defp check_usage_limits(user, _params) do
    case Subscriptions.usage_limit_exceeded?(user, "content_generation") do
      true -> {:error, :usage_limit_exceeded}
      false -> :ok
    end
  end

  defp check_batch_usage_limits(user, batch_size) do
    current_usage = Subscriptions.get_current_usage(user, "content_generation")
    limit = Subscriptions.get_usage_limit(user, "content_generation")

    if current_usage + batch_size > limit do
      {:error, :batch_usage_limit_exceeded}
    else
      :ok
    end
  end

  defp generate_content(_user, params) do
    content_type = params["content_type"] || "post"
    prompt = params["prompt"] || ""
    tone = params["tone"] || "professional"
    target_audience = params["target_audience"] || "general"

    ai_params = %{
      prompt: prompt,
      content_type: content_type,
      tone: tone,
      target_audience: target_audience
    }

    case ai_module().generate_content(ai_params) do
      {:ok, ai_response} ->
        {:ok, ai_response}

      {:error, reason} ->
        {:error, :openai_error, reason}
    end
  end

  defp save_generated_content(user, ai_response, params) do
    # Map target_audience to valid values
    target_audience =
      case params["target_audience"] do
        "tech professionals" -> "industry"
        "business leaders" -> "executives"
        "colleagues" -> "peers"
        "students" -> "students"
        _ -> "general"
      end

    attrs = %{
      user_id: user.id,
      content_type: params["content_type"] || "post",
      # Use generated_text, not content
      generated_text: ai_response.text,
      prompt: params["prompt"] || "",
      tone: params["tone"] || "professional",
      target_audience: target_audience,
      word_count: count_words(ai_response.text),
      generation_model: ai_response.model,
      generation_tokens_used: ai_response.tokens_used,
      generation_cost: ai_response.cost,
      is_favorite: false,
      is_published: false
    }

    ContentGeneration.create_generated_content(attrs)
  end

  defp generate_title(content) do
    # Extract first line or first 50 characters as title
    content
    |> String.split("\n")
    |> List.first()
    |> String.slice(0, 50)
    |> String.trim()
  end

  defp count_words(content) do
    content
    |> String.split()
    |> length()
  end

  ## Progress Tracking

  defp update_job_progress(job_id, progress, message) do
    # Handle test cases where job_id might be nil or not in database
    if is_nil(job_id) do
      Logger.debug("Skipping progress update for test job: #{progress}% - #{message}")
      {:ok, :test_job}
    else
      case LinkedinAi.Repo.get(Oban.Job, job_id) do
        %Oban.Job{} = job ->
          meta =
            Map.merge(job.meta || %{}, %{
              "progress" => progress,
              "status_message" => message,
              "updated_at" => DateTime.utc_now()
            })

          changeset = Ecto.Changeset.change(job, %{meta: meta})

          case LinkedinAi.Repo.update(changeset) do
            {:ok, updated_job} ->
              Logger.debug("Updated job #{job_id} progress: #{progress}% - #{message}")
              {:ok, updated_job}

            {:error, changeset} ->
              Logger.warning(
                "Failed to update job #{job_id} progress: #{inspect(changeset.errors)}"
              )

              {:error, :progress_update_failed}
          end

        nil ->
          Logger.warning("Job #{job_id} not found for progress update")
          {:error, :job_not_found}
      end
    end
  end

  ## Error Handling and Notifications

  defp handle_job_error(job_id, user_id, error, message) do
    Logger.error("Content generation job #{job_id} failed for user #{user_id}: #{message}")

    # Update job progress with error (ignore if job not found)
    case update_job_progress(job_id, -1, "Error: #{message}") do
      {:ok, _} -> :ok
      # Job might have been deleted
      {:error, :job_not_found} -> :ok
      # Other errors are not critical
      {:error, _} -> :ok
    end

    # Send failure notification
    enqueue_failure_notification(user_id, error, message)

    {:error, message}
  end

  defp enqueue_success_notification(user_id, content_record, params) do
    notification_data = %{
      content_id: content_record.id,
      content_type: params["content_type"] || "post",
      title: content_record.title,
      word_count: content_record.word_count
    }

    EmailNotificationJob.new(%{
      user_id: user_id,
      template: "content_generated",
      data: notification_data
    })
    |> Oban.insert()
  end

  defp enqueue_failure_notification(user_id, error, message) do
    error_type =
      case error do
        {:error, reason} when is_atom(reason) -> Atom.to_string(reason)
        {:error, reason} when is_binary(reason) -> reason
        atom when is_atom(atom) -> Atom.to_string(atom)
        binary when is_binary(binary) -> binary
        _ -> "unknown_error"
      end

    notification_data = %{
      error_type: error_type,
      error_message: message,
      timestamp: DateTime.utc_now()
    }

    EmailNotificationJob.new(%{
      user_id: user_id,
      template: "content_generation_failed",
      data: notification_data
    })
    |> Oban.insert()
  end

  defp enqueue_batch_completion_notification(user_id, successful_count, failed_count, results) do
    successful_items = Enum.filter(results, fn {status, _} -> status == :ok end)
    failed_items = Enum.filter(results, fn {status, _} -> status == :error end)

    notification_data = %{
      total_items: successful_count + failed_count,
      successful_count: successful_count,
      failed_count: failed_count,
      successful_items:
        Enum.map(successful_items, fn {:ok, record} ->
          %{id: record.id, title: record.title, content_type: record.content_type}
        end),
      failed_items:
        Enum.map(failed_items, fn {:error, reason} ->
          %{error: inspect(reason)}
        end)
    }

    EmailNotificationJob.new(%{
      user_id: user_id,
      template: "batch_content_generation_completed",
      data: notification_data
    })
    |> Oban.insert()
  end

  ## Public API for Job Progress Tracking

  @doc """
  Gets the current progress of a content generation job.

  ## Examples

      iex> get_job_progress(123)
      {:ok, %{progress: 75, status_message: "Generating content...", updated_at: ~U[...]}}
      
  """
  def get_job_progress(job_id) do
    case LinkedinAi.Repo.get(Oban.Job, job_id) do
      %Oban.Job{meta: meta} when is_map(meta) ->
        progress_data = %{
          progress: Map.get(meta, "progress", 0),
          status_message: Map.get(meta, "status_message", "Job started"),
          updated_at: Map.get(meta, "updated_at")
        }

        {:ok, progress_data}

      %Oban.Job{} ->
        {:ok, %{progress: 0, status_message: "Job started", updated_at: nil}}

      nil ->
        {:error, :job_not_found}
    end
  end

  ## Configuration

  defp ai_module do
    Application.get_env(:linkedin_ai, :ai_module, LinkedinAi.AI)
  end
end
