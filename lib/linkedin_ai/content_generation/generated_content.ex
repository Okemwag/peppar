defmodule LinkedinAi.ContentGeneration.GeneratedContent do
  @moduledoc """
  Generated content schema for AI-generated LinkedIn content.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  schema "generated_contents" do
    field :content_type, :string
    field :prompt, :string
    field :generated_text, :string
    field :tone, :string
    field :target_audience, :string
    field :hashtags, {:array, :string}, default: []
    field :word_count, :integer
    field :is_favorite, :boolean, default: false
    field :is_published, :boolean, default: false
    field :published_at, :utc_datetime
    field :linkedin_post_id, :string
    field :engagement_metrics, :map, default: %{}
    field :generation_model, :string, default: "gpt-3.5-turbo"
    field :generation_tokens_used, :integer
    field :generation_cost, :decimal
    field :metadata, :map, default: %{}

    belongs_to :user, LinkedinAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(generated_content, attrs) do
    generated_content
    |> cast(attrs, [
      :user_id, :content_type, :prompt, :generated_text, :tone, :target_audience,
      :hashtags, :word_count, :is_favorite, :is_published, :published_at,
      :linkedin_post_id, :engagement_metrics, :generation_model,
      :generation_tokens_used, :generation_cost, :metadata
    ])
    |> validate_required([:user_id, :content_type, :prompt, :generated_text])
    |> validate_inclusion(:content_type, ["post", "comment", "message", "article"])
    |> validate_inclusion(:tone, ["professional", "casual", "enthusiastic", "informative", "friendly"])
    |> validate_inclusion(:target_audience, ["general", "executives", "peers", "industry", "students"])
    |> validate_length(:prompt, min: 10, max: 1000)
    |> validate_length(:generated_text, min: 1, max: 10000)
    |> validate_number(:word_count, greater_than_or_equal_to: 0)
    |> validate_number(:generation_tokens_used, greater_than_or_equal_to: 0)
    |> unique_constraint(:linkedin_post_id)
  end

  @doc """
  Gets the content type display name.
  """
  def content_type_display_name(%__MODULE__{content_type: "post"}), do: "LinkedIn Post"
  def content_type_display_name(%__MODULE__{content_type: "comment"}), do: "Comment"
  def content_type_display_name(%__MODULE__{content_type: "message"}), do: "Direct Message"
  def content_type_display_name(%__MODULE__{content_type: "article"}), do: "Article"
  def content_type_display_name(_), do: "Unknown"

  @doc """
  Gets the tone display name.
  """
  def tone_display_name(%__MODULE__{tone: "professional"}), do: "Professional"
  def tone_display_name(%__MODULE__{tone: "casual"}), do: "Casual"
  def tone_display_name(%__MODULE__{tone: "enthusiastic"}), do: "Enthusiastic"
  def tone_display_name(%__MODULE__{tone: "informative"}), do: "Informative"
  def tone_display_name(%__MODULE__{tone: "friendly"}), do: "Friendly"
  def tone_display_name(_), do: "Default"

  @doc """
  Gets the target audience display name.
  """
  def audience_display_name(%__MODULE__{target_audience: "general"}), do: "General Audience"
  def audience_display_name(%__MODULE__{target_audience: "executives"}), do: "Executives"
  def audience_display_name(%__MODULE__{target_audience: "peers"}), do: "Industry Peers"
  def audience_display_name(%__MODULE__{target_audience: "industry"}), do: "Industry Professionals"
  def audience_display_name(%__MODULE__{target_audience: "students"}), do: "Students"
  def audience_display_name(_), do: "General"

  @doc """
  Gets a preview of the generated text (first 100 characters).
  """
  def preview(%__MODULE__{generated_text: text}) when is_binary(text) do
    if String.length(text) > 100 do
      String.slice(text, 0, 100) <> "..."
    else
      text
    end
  end
  def preview(_), do: ""

  @doc """
  Checks if the content has engagement metrics.
  """
  def has_engagement?(%__MODULE__{engagement_metrics: metrics}) when map_size(metrics) > 0, do: true
  def has_engagement?(_), do: false

  @doc """
  Gets total engagement count (likes + comments + shares).
  """
  def total_engagement(%__MODULE__{engagement_metrics: metrics}) do
    likes = Map.get(metrics, "likes", 0)
    comments = Map.get(metrics, "comments", 0)
    shares = Map.get(metrics, "shares", 0)
    likes + comments + shares
  end

  @doc """
  Gets engagement rate as a percentage.
  """
  def engagement_rate(%__MODULE__{engagement_metrics: metrics}) do
    views = Map.get(metrics, "views", 0)
    total_engagement = total_engagement(%__MODULE__{engagement_metrics: metrics})
    
    if views > 0 do
      Float.round(total_engagement / views * 100, 2)
    else
      0.0
    end
  end

  @doc """
  Formats hashtags as a string.
  """
  def hashtags_string(%__MODULE__{hashtags: hashtags}) when is_list(hashtags) do
    hashtags
    |> Enum.map(&("#" <> &1))
    |> Enum.join(" ")
  end
  def hashtags_string(_), do: ""

  @doc """
  Checks if content is recently generated (within last 24 hours).
  """
  def recently_generated?(%__MODULE__{inserted_at: inserted_at}) do
    twenty_four_hours_ago = DateTime.utc_now() |> DateTime.add(-24, :hour)
    DateTime.compare(inserted_at, twenty_four_hours_ago) == :gt
  end

  @doc """
  Gets the generation cost in dollars.
  """
  def cost_in_dollars(%__MODULE__{generation_cost: nil}), do: "$0.00"
  def cost_in_dollars(%__MODULE__{generation_cost: cost}) do
    "$" <> Decimal.to_string(cost, :normal)
  end
end