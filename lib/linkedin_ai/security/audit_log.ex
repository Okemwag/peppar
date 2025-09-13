defmodule LinkedinAi.Security.AuditLog do
  @moduledoc """
  Handles security audit logging for the LinkedIn AI platform.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias LinkedinAi.Repo
  alias LinkedinAi.Accounts.User

  schema "audit_logs" do
    field :event_type, :string
    field :details, :map
    field :ip_address, :string
    field :user_agent, :string
    field :severity, Ecto.Enum, values: [:low, :medium, :high, :critical], default: :medium

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:event_type, :details, :ip_address, :user_agent, :severity, :user_id])
    |> validate_required([:event_type])
    |> validate_length(:event_type, max: 100)
    |> validate_length(:ip_address, max: 45)
    |> validate_length(:user_agent, max: 500)
  end

  @doc """
  Creates a new audit log entry.
  """
  def create_entry(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists audit log entries with optional filtering.
  """
  def list_entries(opts \\ []) do
    query = from(a in __MODULE__, order_by: [desc: a.inserted_at])

    query
    |> maybe_filter_by_user(opts[:user_id])
    |> maybe_filter_by_event_type(opts[:event_type])
    |> maybe_filter_by_severity(opts[:severity])
    |> maybe_filter_by_date_range(opts[:from_date], opts[:to_date])
    |> maybe_limit(opts[:limit])
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Gets audit log entries for a specific user.
  """
  def get_user_entries(user_id, limit \\ 50) do
    from(a in __MODULE__,
      where: a.user_id == ^user_id,
      order_by: [desc: a.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets recent security events of high or critical severity.
  """
  def get_recent_security_alerts(hours \\ 24) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours, :hour)

    from(a in __MODULE__,
      where: a.severity in [:high, :critical] and a.inserted_at >= ^cutoff,
      order_by: [desc: a.inserted_at]
    )
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Cleans up old audit log entries (older than specified days).
  """
  def cleanup_old_entries(days_old \\ 90) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_old, :day)

    from(a in __MODULE__, where: a.inserted_at < ^cutoff)
    |> Repo.delete_all()
  end

  # Private helper functions

  defp maybe_filter_by_user(query, nil), do: query

  defp maybe_filter_by_user(query, user_id) do
    from(a in query, where: a.user_id == ^user_id)
  end

  defp maybe_filter_by_event_type(query, nil), do: query

  defp maybe_filter_by_event_type(query, event_type) do
    from(a in query, where: a.event_type == ^event_type)
  end

  defp maybe_filter_by_severity(query, nil), do: query

  defp maybe_filter_by_severity(query, severity) do
    from(a in query, where: a.severity == ^severity)
  end

  defp maybe_filter_by_date_range(query, nil, nil), do: query

  defp maybe_filter_by_date_range(query, from_date, to_date) do
    query
    |> maybe_filter_from_date(from_date)
    |> maybe_filter_to_date(to_date)
  end

  defp maybe_filter_from_date(query, nil), do: query

  defp maybe_filter_from_date(query, from_date) do
    from(a in query, where: a.inserted_at >= ^from_date)
  end

  defp maybe_filter_to_date(query, nil), do: query

  defp maybe_filter_to_date(query, to_date) do
    from(a in query, where: a.inserted_at <= ^to_date)
  end

  defp maybe_limit(query, nil), do: query

  defp maybe_limit(query, limit) do
    from(a in query, limit: ^limit)
  end
end
