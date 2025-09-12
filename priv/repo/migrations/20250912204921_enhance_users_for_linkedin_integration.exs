defmodule LinkedinAi.Repo.Migrations.EnhanceUsersForLinkedinIntegration do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # LinkedIn integration fields
      add :linkedin_id, :string
      add :linkedin_access_token, :text
      add :linkedin_refresh_token, :text
      add :linkedin_token_expires_at, :utc_datetime
      add :linkedin_profile_url, :string
      add :linkedin_headline, :text
      add :linkedin_summary, :text
      add :linkedin_industry, :string
      add :linkedin_location, :string
      add :linkedin_connections_count, :integer
      add :linkedin_profile_picture_url, :string
      add :linkedin_last_synced_at, :utc_datetime

      # User profile fields
      add :first_name, :string
      add :last_name, :string
      add :company, :string
      add :job_title, :string
      add :phone, :string
      add :timezone, :string, default: "UTC"

      # Role and permissions
      add :role, :string, default: "user", null: false
      add :is_admin, :boolean, default: false, null: false

      # Onboarding and preferences
      add :onboarding_completed, :boolean, default: false, null: false
      add :onboarding_step, :string, default: "welcome"
      add :email_notifications, :boolean, default: true, null: false
      add :marketing_emails, :boolean, default: false, null: false

      # Account status
      add :account_status, :string, default: "active", null: false
      add :last_login_at, :utc_datetime
      add :login_count, :integer, default: 0, null: false

      # Subscription trial tracking
      add :trial_ends_at, :utc_datetime
      add :has_used_trial, :boolean, default: false, null: false
    end

    # Add indexes for performance
    create index(:users, [:role])
    create index(:users, [:account_status])
    create index(:users, [:onboarding_completed])
    create index(:users, [:trial_ends_at])
    create index(:users, [:last_login_at])

    # Unique constraint for LinkedIn ID
    create unique_index(:users, [:linkedin_id], where: "linkedin_id IS NOT NULL")
  end
end
