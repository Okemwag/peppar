defmodule LinkedinAi.Repo.Migrations.CreateUsageRecordsTable do
  use Ecto.Migration

  def change do
    create table(:usage_records) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :feature_type, :string, null: false
      add :usage_count, :integer, default: 0
      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:usage_records, [:user_id])
    create index(:usage_records, [:feature_type])
    create index(:usage_records, [:period_start, :period_end])
    create unique_index(:usage_records, [:user_id, :feature_type, :period_start])
  end
end
