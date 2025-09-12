defmodule LinkedinAi.Repo.Migrations.CreateSubscriptionsTable do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :stripe_subscription_id, :string, null: false
      add :stripe_customer_id, :string, null: false
      add :plan_type, :string, null: false # "basic" or "pro"
      add :status, :string, null: false # "active", "canceled", "past_due", "unpaid"
      add :current_period_start, :utc_datetime, null: false
      add :current_period_end, :utc_datetime, null: false
      add :cancel_at_period_end, :boolean, default: false
      add :canceled_at, :utc_datetime
      add :trial_start, :utc_datetime
      add :trial_end, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscriptions, [:user_id])
    create unique_index(:subscriptions, [:stripe_subscription_id])
    create index(:subscriptions, [:stripe_customer_id])
    create index(:subscriptions, [:plan_type])
    create index(:subscriptions, [:status])
    create index(:subscriptions, [:current_period_end])
  end
end
