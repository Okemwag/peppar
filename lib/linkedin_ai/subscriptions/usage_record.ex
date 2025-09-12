defmodule LinkedinAi.Subscriptions.UsageRecord do
  @moduledoc """
  Usage record schema for tracking feature usage by users.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  schema "usage_records" do
    field :feature_type, :string
    field :usage_count, :integer, default: 0
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :user, LinkedinAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(usage_record, attrs) do
    usage_record
    |> cast(attrs, [:user_id, :feature_type, :usage_count, :period_start, :period_end, :metadata])
    |> validate_required([:user_id, :feature_type, :usage_count, :period_start, :period_end])
    |> validate_inclusion(:feature_type, [
      "content_generation", 
      "profile_analysis", 
      "linkedin_posts", 
      "content_templates",
      "analytics_reports"
    ])
    |> validate_number(:usage_count, greater_than_or_equal_to: 0)
    |> validate_period_dates()
    |> unique_constraint([:user_id, :feature_type, :period_start])
  end

  defp validate_period_dates(changeset) do
    start_date = get_field(changeset, :period_start)
    end_date = get_field(changeset, :period_end)

    if start_date && end_date && DateTime.compare(start_date, end_date) != :lt do
      add_error(changeset, :period_end, "must be after period start")
    else
      changeset
    end
  end

  @doc """
  Gets the feature display name.
  """
  def feature_display_name(%__MODULE__{feature_type: "content_generation"}), do: "Content Generation"
  def feature_display_name(%__MODULE__{feature_type: "profile_analysis"}), do: "Profile Analysis"
  def feature_display_name(%__MODULE__{feature_type: "linkedin_posts"}), do: "LinkedIn Posts"
  def feature_display_name(%__MODULE__{feature_type: "content_templates"}), do: "Content Templates"
  def feature_display_name(%__MODULE__{feature_type: "analytics_reports"}), do: "Analytics Reports"
  def feature_display_name(_), do: "Unknown Feature"

  @doc """
  Checks if the usage record is for the current period.
  """
  def current_period?(%__MODULE__{period_start: period_start, period_end: period_end}) do
    now = DateTime.utc_now()
    DateTime.compare(now, period_start) != :lt && DateTime.compare(now, period_end) == :lt
  end

  @doc """
  Gets usage percentage of a limit.
  """
  def usage_percentage(%__MODULE__{usage_count: usage_count}, limit) when limit > 0 do
    min(100, round(usage_count / limit * 100))
  end
  def usage_percentage(_, _), do: 0

  @doc """
  Checks if usage has exceeded a limit.
  """
  def exceeded_limit?(%__MODULE__{usage_count: usage_count}, limit) when limit > 0 do
    usage_count >= limit
  end
  def exceeded_limit?(_, -1), do: false  # unlimited
  def exceeded_limit?(_, _), do: true    # no limit set means exceeded
end