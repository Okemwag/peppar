defmodule LinkedinAi.ProfileOptimization.ProfileAnalysis do
  @moduledoc """
  Profile analysis schema for LinkedIn profile optimization suggestions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "profile_analyses" do
    field :analysis_type, :string
    field :current_content, :string
    field :analysis_results, :map
    field :improvement_suggestions, {:array, :map}, default: []
    field :score, :integer
    field :priority_level, :string, default: "medium"
    field :status, :string, default: "pending"
    field :implemented_at, :utc_datetime
    field :linkedin_profile_snapshot, :map, default: %{}
    field :analysis_model, :string, default: "gpt-3.5-turbo"
    field :analysis_tokens_used, :integer
    field :analysis_cost, :decimal
    field :metadata, :map, default: %{}

    belongs_to :user, LinkedinAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile_analysis, attrs) do
    profile_analysis
    |> cast(attrs, [
      :user_id,
      :analysis_type,
      :current_content,
      :analysis_results,
      :improvement_suggestions,
      :score,
      :priority_level,
      :status,
      :implemented_at,
      :linkedin_profile_snapshot,
      :analysis_model,
      :analysis_tokens_used,
      :analysis_cost,
      :metadata
    ])
    |> validate_required([:user_id, :analysis_type, :analysis_results])
    |> validate_inclusion(:analysis_type, [
      "headline",
      "summary",
      "overall",
      "skills",
      "experience"
    ])
    |> validate_inclusion(:priority_level, ["low", "medium", "high", "critical"])
    |> validate_inclusion(:status, ["pending", "reviewed", "implemented", "dismissed"])
    |> validate_number(:score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:analysis_tokens_used, greater_than_or_equal_to: 0)
  end

  @doc """
  Gets the analysis type display name.
  """
  def analysis_type_display_name(%__MODULE__{analysis_type: "headline"}), do: "Headline Analysis"
  def analysis_type_display_name(%__MODULE__{analysis_type: "summary"}), do: "Summary Analysis"

  def analysis_type_display_name(%__MODULE__{analysis_type: "overall"}),
    do: "Overall Profile Analysis"

  def analysis_type_display_name(%__MODULE__{analysis_type: "skills"}), do: "Skills Analysis"

  def analysis_type_display_name(%__MODULE__{analysis_type: "experience"}),
    do: "Experience Analysis"

  def analysis_type_display_name(_), do: "Unknown Analysis"

  @doc """
  Gets the priority level display name with color coding.
  """
  def priority_display(%__MODULE__{priority_level: "critical"}), do: {"Critical", "text-red-600"}
  def priority_display(%__MODULE__{priority_level: "high"}), do: {"High", "text-orange-600"}
  def priority_display(%__MODULE__{priority_level: "medium"}), do: {"Medium", "text-yellow-600"}
  def priority_display(%__MODULE__{priority_level: "low"}), do: {"Low", "text-green-600"}
  def priority_display(_), do: {"Unknown", "text-gray-600"}

  @doc """
  Gets the status display name with color coding.
  """
  def status_display(%__MODULE__{status: "pending"}), do: {"Pending Review", "text-blue-600"}
  def status_display(%__MODULE__{status: "reviewed"}), do: {"Reviewed", "text-purple-600"}
  def status_display(%__MODULE__{status: "implemented"}), do: {"Implemented", "text-green-600"}
  def status_display(%__MODULE__{status: "dismissed"}), do: {"Dismissed", "text-gray-600"}
  def status_display(_), do: {"Unknown", "text-gray-600"}

  @doc """
  Gets the score color based on the score value.
  """
  def score_color(%__MODULE__{score: score}) when score >= 80, do: "text-green-600"
  def score_color(%__MODULE__{score: score}) when score >= 60, do: "text-yellow-600"
  def score_color(%__MODULE__{score: score}) when score >= 40, do: "text-orange-600"
  def score_color(_), do: "text-red-600"

  @doc """
  Gets the score grade (A, B, C, D, F).
  """
  def score_grade(%__MODULE__{score: score}) when score >= 90, do: "A"
  def score_grade(%__MODULE__{score: score}) when score >= 80, do: "B"
  def score_grade(%__MODULE__{score: score}) when score >= 70, do: "C"
  def score_grade(%__MODULE__{score: score}) when score >= 60, do: "D"
  def score_grade(_), do: "F"

  @doc """
  Checks if the analysis is actionable (pending or reviewed).
  """
  def actionable?(%__MODULE__{status: status}) when status in ["pending", "reviewed"], do: true
  def actionable?(_), do: false

  @doc """
  Checks if the analysis has been completed (implemented or dismissed).
  """
  def completed?(%__MODULE__{status: status}) when status in ["implemented", "dismissed"],
    do: true

  def completed?(_), do: false

  @doc """
  Gets the number of improvement suggestions.
  """
  def suggestions_count(%__MODULE__{improvement_suggestions: suggestions})
      when is_list(suggestions) do
    length(suggestions)
  end

  def suggestions_count(_), do: 0

  @doc """
  Gets high priority suggestions.
  """
  def high_priority_suggestions(%__MODULE__{improvement_suggestions: suggestions})
      when is_list(suggestions) do
    Enum.filter(suggestions, fn suggestion ->
      Map.get(suggestion, "priority") == "high"
    end)
  end

  def high_priority_suggestions(_), do: []

  @doc """
  Checks if the analysis is recent (within last 7 days).
  """
  def recent?(%__MODULE__{inserted_at: inserted_at}) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)
    DateTime.compare(inserted_at, seven_days_ago) == :gt
  end

  @doc """
  Gets days since analysis was created.
  """
  def days_since_created(%__MODULE__{inserted_at: inserted_at}) do
    DateTime.diff(DateTime.utc_now(), inserted_at, :day)
  end

  @doc """
  Gets days since implementation (if implemented).
  """
  def days_since_implemented(%__MODULE__{implemented_at: nil}), do: nil

  def days_since_implemented(%__MODULE__{implemented_at: implemented_at}) do
    DateTime.diff(DateTime.utc_now(), implemented_at, :day)
  end

  @doc """
  Gets the analysis cost in dollars.
  """
  def cost_in_dollars(%__MODULE__{analysis_cost: nil}), do: "$0.00"

  def cost_in_dollars(%__MODULE__{analysis_cost: cost}) do
    "$" <> Decimal.to_string(cost, :normal)
  end

  @doc """
  Gets a summary of the analysis results.
  """
  def results_summary(%__MODULE__{analysis_results: results}) when is_map(results) do
    results
    |> Map.values()
    |> Enum.take(3)
    |> Enum.join(", ")
  end

  def results_summary(_), do: "No analysis results available"

  @doc """
  Checks if the analysis needs attention (high/critical priority and pending).
  """
  def needs_attention?(%__MODULE__{priority_level: priority, status: "pending"})
      when priority in ["high", "critical"],
      do: true

  def needs_attention?(_), do: false

  @doc """
  Gets improvement areas from analysis results.
  """
  def improvement_areas(%__MODULE__{analysis_results: results}) when is_map(results) do
    results
    |> Enum.filter(fn {_key, value} ->
      String.contains?(String.downcase(to_string(value)), ["needs", "missing", "poor", "weak"])
    end)
    |> Enum.map(fn {key, _value} -> String.replace(key, "_", " ") |> String.capitalize() end)
  end

  def improvement_areas(_), do: []

  @doc """
  Gets strengths from analysis results.
  """
  def strengths(%__MODULE__{analysis_results: results}) when is_map(results) do
    results
    |> Enum.filter(fn {_key, value} ->
      String.contains?(String.downcase(to_string(value)), [
        "good",
        "excellent",
        "strong",
        "well",
        "present"
      ])
    end)
    |> Enum.map(fn {key, _value} -> String.replace(key, "_", " ") |> String.capitalize() end)
  end

  def strengths(_), do: []
end
