defmodule LinkedinAi.Jobs.EmailNotificationJob do
  @moduledoc """
  Background job for sending email notifications to users.
  Handles various email templates and notification types.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias LinkedinAi.{Accounts, Mailer}

  alias LinkedinAi.Emails.{
    WelcomeEmail,
    ContentGeneratedEmail,
    EngagementSummaryEmail,
    WeeklyAdminSummaryEmail,
    SubscriptionEmail
  }

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "template" => template, "data" => data}}) do
    Logger.info("Sending email notification: #{template} to user #{user_id}")

    with {:ok, user} <- get_user(user_id),
         {:ok, email} <- build_email(user, template, data),
         {:ok, _result} <- send_email(email) do
      Logger.info("Email notification sent successfully: #{template} to #{user.email}")
      :ok
    else
      {:error, :user_not_found} ->
        Logger.error("User #{user_id} not found for email notification")
        {:error, "User not found"}

      {:error, :template_not_found} ->
        Logger.error("Email template not found: #{template}")
        {:error, "Template not found"}

      {:error, :email_delivery_failed, reason} ->
        Logger.error("Email delivery failed for user #{user_id}: #{inspect(reason)}")
        {:error, "Email delivery failed"}

      {:error, reason} ->
        Logger.error("Email notification job failed for user #{user_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_user(user_id) do
    case Accounts.get_user(user_id) do
      %Accounts.User{} = user -> {:ok, user}
      nil -> {:error, :user_not_found}
    end
  end

  defp build_email(user, template, data) do
    case template do
      "welcome" ->
        {:ok, WelcomeEmail.build(user, data)}

      "content_generated" ->
        {:ok, ContentGeneratedEmail.build(user, data)}

      "engagement_summary" ->
        {:ok, EngagementSummaryEmail.build(user, data)}

      "weekly_admin_summary" ->
        {:ok, WeeklyAdminSummaryEmail.build(user, data)}

      "subscription_created" ->
        {:ok, SubscriptionEmail.build_created(user, data)}

      "subscription_canceled" ->
        {:ok, SubscriptionEmail.build_canceled(user, data)}

      "subscription_payment_failed" ->
        {:ok, SubscriptionEmail.build_payment_failed(user, data)}

      "trial_ending" ->
        {:ok, SubscriptionEmail.build_trial_ending(user, data)}

      "usage_limit_reached" ->
        {:ok, build_usage_limit_email(user, data)}

      "profile_analysis_complete" ->
        {:ok, build_profile_analysis_email(user, data)}

      _ ->
        {:error, :template_not_found}
    end
  end

  defp send_email(email) do
    case Mailer.deliver(email) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, :email_delivery_failed, reason}
    end
  end

  # Custom email builders for templates not in separate modules
  defp build_usage_limit_email(user, data) do
    import Swoosh.Email

    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from({"LinkedIn AI", "noreply@linkedinai.com"})
    |> subject("Usage Limit Reached - LinkedIn AI")
    |> html_body("""
    <h2>Usage Limit Reached</h2>
    <p>Hi #{user.first_name},</p>
    <p>You've reached your #{data["limit_type"]} usage limit for this billing period.</p>
    <p>To continue using LinkedIn AI, consider upgrading your plan:</p>
    <a href="#{data["upgrade_url"]}" style="background: #0066cc; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Upgrade Plan</a>
    <p>Best regards,<br>The LinkedIn AI Team</p>
    """)
    |> text_body("""
    Usage Limit Reached

    Hi #{user.first_name},

    You've reached your #{data["limit_type"]} usage limit for this billing period.

    To continue using LinkedIn AI, consider upgrading your plan: #{data["upgrade_url"]}

    Best regards,
    The LinkedIn AI Team
    """)
  end

  defp build_profile_analysis_email(user, data) do
    import Swoosh.Email

    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from({"LinkedIn AI", "noreply@linkedinai.com"})
    |> subject("Your LinkedIn Profile Analysis is Ready")
    |> html_body("""
    <h2>Profile Analysis Complete</h2>
    <p>Hi #{user.first_name},</p>
    <p>Your LinkedIn profile analysis is now ready! Here's a quick summary:</p>
    <ul>
      <li><strong>Profile Score:</strong> #{data["score"]}/100</li>
      <li><strong>Recommendations:</strong> #{length(data["recommendations"])} suggestions</li>
      <li><strong>Priority Level:</strong> #{data["priority"]}</li>
    </ul>
    <p>View your complete analysis and recommendations:</p>
    <a href="#{data["analysis_url"]}" style="background: #0066cc; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Analysis</a>
    <p>Best regards,<br>The LinkedIn AI Team</p>
    """)
    |> text_body("""
    Profile Analysis Complete

    Hi #{user.first_name},

    Your LinkedIn profile analysis is now ready! Here's a quick summary:

    - Profile Score: #{data["score"]}/100
    - Recommendations: #{length(data["recommendations"])} suggestions
    - Priority Level: #{data["priority"]}

    View your complete analysis: #{data["analysis_url"]}

    Best regards,
    The LinkedIn AI Team
    """)
  end
end
