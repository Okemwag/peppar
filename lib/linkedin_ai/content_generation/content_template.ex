defmodule LinkedinAi.ContentGeneration.ContentTemplate do
  @moduledoc """
  Content template schema for reusable content generation prompts.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_templates" do
    field :name, :string
    field :description, :string
    field :content_type, :string
    field :template_prompt, :string
    field :default_tone, :string
    field :default_audience, :string
    field :is_public, :boolean, default: false
    field :is_system_template, :boolean, default: false
    field :usage_count, :integer, default: 0
    field :tags, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    belongs_to :user, LinkedinAi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_template, attrs) do
    content_template
    |> cast(attrs, [
      :user_id, :name, :description, :content_type, :template_prompt,
      :default_tone, :default_audience, :is_public, :is_system_template,
      :usage_count, :tags, :metadata
    ])
    |> validate_required([:name, :content_type, :template_prompt])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_length(:template_prompt, min: 10, max: 2000)
    |> validate_inclusion(:content_type, ["post", "comment", "message", "article"])
    |> validate_inclusion(:default_tone, ["professional", "casual", "enthusiastic", "informative", "friendly"])
    |> validate_inclusion(:default_audience, ["general", "executives", "peers", "industry", "students"])
    |> validate_number(:usage_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :name])
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
  def tone_display_name(%__MODULE__{default_tone: "professional"}), do: "Professional"
  def tone_display_name(%__MODULE__{default_tone: "casual"}), do: "Casual"
  def tone_display_name(%__MODULE__{default_tone: "enthusiastic"}), do: "Enthusiastic"
  def tone_display_name(%__MODULE__{default_tone: "informative"}), do: "Informative"
  def tone_display_name(%__MODULE__{default_tone: "friendly"}), do: "Friendly"
  def tone_display_name(_), do: "Default"

  @doc """
  Gets the audience display name.
  """
  def audience_display_name(%__MODULE__{default_audience: "general"}), do: "General Audience"
  def audience_display_name(%__MODULE__{default_audience: "executives"}), do: "Executives"
  def audience_display_name(%__MODULE__{default_audience: "peers"}), do: "Industry Peers"
  def audience_display_name(%__MODULE__{default_audience: "industry"}), do: "Industry Professionals"
  def audience_display_name(%__MODULE__{default_audience: "students"}), do: "Students"
  def audience_display_name(_), do: "General"

  @doc """
  Gets a preview of the template prompt (first 100 characters).
  """
  def preview(%__MODULE__{template_prompt: prompt}) when is_binary(prompt) do
    if String.length(prompt) > 100 do
      String.slice(prompt, 0, 100) <> "..."
    else
      prompt
    end
  end
  def preview(_), do: ""

  @doc """
  Checks if the template is popular (usage count > 10).
  """
  def popular?(%__MODULE__{usage_count: count}) when count > 10, do: true
  def popular?(_), do: false

  @doc """
  Checks if the template is recently created (within last 7 days).
  """
  def recently_created?(%__MODULE__{inserted_at: inserted_at}) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)
    DateTime.compare(inserted_at, seven_days_ago) == :gt
  end

  @doc """
  Formats tags as a string.
  """
  def tags_string(%__MODULE__{tags: tags}) when is_list(tags) do
    Enum.join(tags, ", ")
  end
  def tags_string(_), do: ""

  @doc """
  Gets template visibility status.
  """
  def visibility_status(%__MODULE__{is_system_template: true}), do: "System Template"
  def visibility_status(%__MODULE__{is_public: true}), do: "Public"
  def visibility_status(_), do: "Private"

  @doc """
  Checks if template can be edited by user.
  """
  def editable_by_user?(%__MODULE__{is_system_template: true}, _user), do: false
  def editable_by_user?(%__MODULE__{user_id: user_id}, %{id: user_id}), do: true
  def editable_by_user?(_, _), do: false

  @doc """
  Gets usage popularity level.
  """
  def popularity_level(%__MODULE__{usage_count: count}) do
    cond do
      count >= 100 -> "Very Popular"
      count >= 50 -> "Popular"
      count >= 10 -> "Moderately Popular"
      count >= 1 -> "Used"
      true -> "New"
    end
  end

  @doc """
  Processes template prompt with variables.
  Variables in the format {{variable_name}} will be replaced.
  """
  def process_template(%__MODULE__{template_prompt: prompt}, variables \\ %{}) do
    Enum.reduce(variables, prompt, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", to_string(value))
    end)
  end

  @doc """
  Extracts variables from template prompt.
  Returns a list of variable names found in {{variable}} format.
  """
  def extract_variables(%__MODULE__{template_prompt: prompt}) do
    Regex.scan(~r/\{\{(\w+)\}\}/, prompt)
    |> Enum.map(fn [_match, var] -> var end)
    |> Enum.uniq()
  end
end