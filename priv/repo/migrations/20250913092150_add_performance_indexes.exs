defmodule LinkedinAi.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Composite indexes for frequently queried combinations
    
    # Users table - composite indexes for common queries
    create index(:users, [:role, :account_status])
    create index(:users, [:onboarding_completed, :account_status])
    create index(:users, [:trial_ends_at, :has_used_trial])
    create index(:users, [:linkedin_last_synced_at], where: "linkedin_id IS NOT NULL")
    
    # Generated content - composite indexes for dashboard and analytics
    create index(:generated_contents, [:user_id, :content_type, :inserted_at])
    create index(:generated_contents, [:user_id, :is_favorite, :inserted_at])
    create index(:generated_contents, [:user_id, :is_published, :published_at])
    create index(:generated_contents, [:content_type, :is_published, :published_at])
    create index(:generated_contents, [:generation_model, :inserted_at])
    
    # Profile analyses - composite indexes for tracking and reporting
    create index(:profile_analyses, [:user_id, :analysis_type, :inserted_at])
    create index(:profile_analyses, [:user_id, :status, :priority_level])
    create index(:profile_analyses, [:analysis_type, :score, :inserted_at])
    
    # Subscriptions - composite indexes for billing and analytics
    create index(:subscriptions, [:status, :current_period_end])
    create index(:subscriptions, [:plan_type, :status, :current_period_end])
    create index(:subscriptions, [:cancel_at_period_end, :current_period_end])
    
    # Usage records - composite indexes for usage tracking and billing
    create index(:usage_records, [:user_id, :feature_type, :period_start, :period_end])
    create index(:usage_records, [:feature_type, :period_start, :period_end])
    
    # Audit logs - composite indexes for security monitoring
    create index(:audit_logs, [:event_type, :severity, :inserted_at])
    create index(:audit_logs, [:user_id, :event_type, :inserted_at])
    create index(:audit_logs, [:ip_address, :inserted_at])
    
    # Content templates - composite indexes for template management
    create index(:content_templates, [:content_type, :is_public, :usage_count])
    create index(:content_templates, [:is_system_template, :content_type])
    
    # Partial indexes for better performance on filtered queries
    create index(:generated_contents, [:engagement_metrics], 
           where: "engagement_metrics IS NOT NULL AND engagement_metrics != '{}'")
    
    create index(:profile_analyses, [:linkedin_profile_snapshot],
           where: "linkedin_profile_snapshot IS NOT NULL AND linkedin_profile_snapshot != '{}'")
    
    create index(:subscriptions, [:trial_start, :trial_end],
           where: "trial_start IS NOT NULL")
    
    # Indexes for text search (if using PostgreSQL full-text search)
    # Note: These would normally be created CONCURRENTLY in production
    execute "CREATE INDEX IF NOT EXISTS generated_contents_search_idx ON generated_contents USING gin(to_tsvector('english', coalesce(prompt, '') || ' ' || coalesce(generated_text, '')))"
    execute "CREATE INDEX IF NOT EXISTS profile_analyses_search_idx ON profile_analyses USING gin(to_tsvector('english', coalesce(current_content, '')))"
  end
end
