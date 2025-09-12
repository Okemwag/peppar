defmodule LinkedinAi.Repo.Migrations.CreateContentGenerationTables do
  use Ecto.Migration

  def change do
    # Generated content table
    create table(:generated_contents) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :content_type, :string, null: false # "post", "comment", "message", "article"
      add :prompt, :text, null: false
      add :generated_text, :text, null: false
      add :tone, :string # "professional", "casual", "enthusiastic", "informative"
      add :target_audience, :string # "general", "executives", "peers", "industry"
      add :hashtags, {:array, :string}, default: []
      add :word_count, :integer
      add :is_favorite, :boolean, default: false, null: false
      add :is_published, :boolean, default: false, null: false
      add :published_at, :utc_datetime
      add :linkedin_post_id, :string
      add :engagement_metrics, :map, default: %{} # likes, comments, shares, views
      add :generation_model, :string, default: "gpt-3.5-turbo"
      add :generation_tokens_used, :integer
      add :generation_cost, :decimal, precision: 10, scale: 4
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    # Profile analysis table
    create table(:profile_analyses) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :analysis_type, :string, null: false # "headline", "summary", "overall", "skills"
      add :current_content, :text
      add :analysis_results, :map, null: false # AI analysis results
      add :improvement_suggestions, {:array, :map}, default: []
      add :score, :integer # 1-100 score
      add :priority_level, :string, default: "medium" # "low", "medium", "high", "critical"
      add :status, :string, default: "pending" # "pending", "reviewed", "implemented", "dismissed"
      add :implemented_at, :utc_datetime
      add :linkedin_profile_snapshot, :map, default: %{} # snapshot of LinkedIn data at analysis time
      add :analysis_model, :string, default: "gpt-3.5-turbo"
      add :analysis_tokens_used, :integer
      add :analysis_cost, :decimal, precision: 10, scale: 4
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    # Content templates table for reusable prompts
    create table(:content_templates) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :name, :string, null: false
      add :description, :text
      add :content_type, :string, null: false
      add :template_prompt, :text, null: false
      add :default_tone, :string
      add :default_audience, :string
      add :is_public, :boolean, default: false, null: false
      add :is_system_template, :boolean, default: false, null: false
      add :usage_count, :integer, default: 0, null: false
      add :tags, {:array, :string}, default: []
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    # Add indexes for performance
    create index(:generated_contents, [:user_id])
    create index(:generated_contents, [:content_type])
    create index(:generated_contents, [:is_favorite])
    create index(:generated_contents, [:is_published])
    create index(:generated_contents, [:published_at])
    create index(:generated_contents, [:inserted_at])

    create index(:profile_analyses, [:user_id])
    create index(:profile_analyses, [:analysis_type])
    create index(:profile_analyses, [:status])
    create index(:profile_analyses, [:priority_level])
    create index(:profile_analyses, [:score])
    create index(:profile_analyses, [:inserted_at])

    create index(:content_templates, [:user_id])
    create index(:content_templates, [:content_type])
    create index(:content_templates, [:is_public])
    create index(:content_templates, [:is_system_template])
    create index(:content_templates, [:usage_count])

    # Unique constraints
    create unique_index(:generated_contents, [:linkedin_post_id], where: "linkedin_post_id IS NOT NULL")
    create unique_index(:content_templates, [:user_id, :name], where: "user_id IS NOT NULL")
  end
end
