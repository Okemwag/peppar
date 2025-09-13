defmodule LinkedinAi.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :event_type, :string, null: false
      add :details, :map, default: %{}
      add :ip_address, :string, size: 45
      add :user_agent, :string, size: 500
      add :severity, :string, default: "medium"
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:audit_logs, [:event_type])
    create index(:audit_logs, [:severity])
    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:inserted_at])
    create index(:audit_logs, [:ip_address])
  end
end
