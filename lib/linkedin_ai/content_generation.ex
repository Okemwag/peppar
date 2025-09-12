defmodule LinkedinAi.ContentGeneration do
  @moduledoc """
  The ContentGeneration context.
  Handles AI-powered content generation, templates, and content management.
  """

  import Ecto.Query, warn: false
  alias LinkedinAi.Repo
  alias LinkedinAi.ContentGeneration.{GeneratedContent, ContentTemplate}
  alias LinkedinAi.Accounts.User
  alias LinkedinAi.Subscriptions

  ## Generated Content Management

  @doc """
  Lists generated contents for a user with optional filters.

  ## Examples

      iex> list_user_contents(user)
      [%GeneratedContent{}, ...]

      iex> list_user_contents(user, content_type: "post", is_favorite: true)
      [%GeneratedContent{}, ...]

  """
  def list_user_contents(%User{} = user, filters \\ []) do
    query =
      from(gc in GeneratedContent,
        where: gc.user_id == ^user.id,
        order_by: [desc: gc.inserted_at]
      )

    query
    |> apply_content_filters(filters)
    |> Repo.all()
  end

  defp apply_content_filters(query, []), do: query

  defp apply_content_filters(query, [{:content_type, content_type} | rest]) do
    query
    |> where([gc], gc.content_type == ^content_type)
    |> apply_content_filters(rest)
  end

  defp apply_content_filters(query, [{:is_favorite, is_favorite} | rest]) do
    query
    |> where([gc], gc.is_favorite == ^is_favorite)
    |> apply_content_filters(rest)
  end

  defp apply_content_filters(query, [{:is_published, is_published} | rest]) do
    query
    |> where([gc], gc.is_published == ^is_published)
    |> apply_content_filters(rest)
  end

  defp apply_content_filters(query, [_filter | rest]) do
    apply_content_filters(query, rest)
  end

  @doc """
  Gets a single generated content.

  Raises `Ecto.NoResultsError` if the GeneratedContent does not exist.

  ## Examples

      iex> get_generated_content!(123)
      %GeneratedContent{}

      iex> get_generated_content!(456)
      ** (Ecto.NoResultsError)

  """
  def get_generated_content!(id), do: Repo.get!(GeneratedContent, id)

  @doc """
  Gets a generated content by user and ID.

  ## Examples

      iex> get_user_content(user, 123)
      %GeneratedContent{}

      iex> get_user_content(user, 456)
      nil

  """
  def get_user_content(%User{} = user, content_id) do
    Repo.get_by(GeneratedContent, id: content_id, user_id: user.id)
  end

  @doc """
  Generates content using AI based on user prompt and preferences.

  ## Examples

      iex> generate_content(user, %{prompt: "Write a LinkedIn post about AI", content_type: "post"})
      {:ok, %GeneratedContent{}}

      iex> generate_content(user, %{prompt: ""})
      {:error, %Ecto.Changeset{}}

  """
  def generate_content(%User{} = user, attrs) do
    # Check usage limits
    if Subscriptions.usage_limit_exceeded?(user, "content_generation") do
      {:error, :usage_limit_exceeded}
    else
      # Generate content with AI
      case generate_ai_content(attrs) do
        {:ok, ai_response} ->
          content_attrs =
            Map.merge(attrs, %{
              user_id: user.id,
              generated_text: ai_response.text,
              word_count: count_words(ai_response.text),
              generation_model: ai_response.model,
              generation_tokens_used: ai_response.tokens_used,
              generation_cost: ai_response.cost
            })

          result = create_generated_content(content_attrs)

          # Record usage
          if elem(result, 0) == :ok do
            Subscriptions.record_usage(user, "content_generation", 1)
          end

          result

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Creates a generated content.

  ## Examples

      iex> create_generated_content(%{field: value})
      {:ok, %GeneratedContent{}}

      iex> create_generated_content(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_generated_content(attrs \\ %{}) do
    %GeneratedContent{}
    |> GeneratedContent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a generated content.

  ## Examples

      iex> update_generated_content(generated_content, %{field: new_value})
      {:ok, %GeneratedContent{}}

      iex> update_generated_content(generated_content, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_generated_content(%GeneratedContent{} = generated_content, attrs) do
    generated_content
    |> GeneratedContent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a generated content.

  ## Examples

      iex> delete_generated_content(generated_content)
      {:ok, %GeneratedContent{}}

      iex> delete_generated_content(generated_content)
      {:error, %Ecto.Changeset{}}

  """
  def delete_generated_content(%GeneratedContent{} = generated_content) do
    Repo.delete(generated_content)
  end

  @doc """
  Toggles favorite status of generated content.

  ## Examples

      iex> toggle_favorite(generated_content)
      {:ok, %GeneratedContent{}}

  """
  def toggle_favorite(%GeneratedContent{} = generated_content) do
    update_generated_content(generated_content, %{is_favorite: !generated_content.is_favorite})
  end

  @doc """
  Marks content as published.

  ## Examples

      iex> mark_as_published(generated_content, "linkedin_post_123")
      {:ok, %GeneratedContent{}}

  """
  def mark_as_published(%GeneratedContent{} = generated_content, linkedin_post_id \\ nil) do
    update_generated_content(generated_content, %{
      is_published: true,
      published_at: DateTime.utc_now(),
      linkedin_post_id: linkedin_post_id
    })
  end

  ## Content Templates Management

  @doc """
  Lists content templates for a user.

  ## Examples

      iex> list_user_templates(user)
      [%ContentTemplate{}, ...]

  """
  def list_user_templates(%User{} = user) do
    from(ct in ContentTemplate,
      where: ct.user_id == ^user.id or ct.is_public == true,
      order_by: [desc: ct.usage_count, desc: ct.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists system templates (public templates).

  ## Examples

      iex> list_system_templates()
      [%ContentTemplate{}, ...]

  """
  def list_system_templates do
    from(ct in ContentTemplate,
      where: ct.is_system_template == true,
      order_by: [desc: ct.usage_count]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single content template.

  ## Examples

      iex> get_content_template!(123)
      %ContentTemplate{}

  """
  def get_content_template!(id), do: Repo.get!(ContentTemplate, id)

  @doc """
  Creates a content template.

  ## Examples

      iex> create_content_template(%{field: value})
      {:ok, %ContentTemplate{}}

  """
  def create_content_template(attrs \\ %{}) do
    %ContentTemplate{}
    |> ContentTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a content template.

  ## Examples

      iex> update_content_template(content_template, %{field: new_value})
      {:ok, %ContentTemplate{}}

  """
  def update_content_template(%ContentTemplate{} = content_template, attrs) do
    content_template
    |> ContentTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a content template.

  ## Examples

      iex> delete_content_template(content_template)
      {:ok, %ContentTemplate{}}

  """
  def delete_content_template(%ContentTemplate{} = content_template) do
    Repo.delete(content_template)
  end

  @doc """
  Increments usage count for a template.

  ## Examples

      iex> increment_template_usage(template)
      {:ok, %ContentTemplate{}}

  """
  def increment_template_usage(%ContentTemplate{} = template) do
    update_content_template(template, %{usage_count: template.usage_count + 1})
  end

  ## AI Content Generation (Mock Implementation)

  defp generate_ai_content(attrs) do
    # This is a mock implementation. In a real app, this would call OpenAI API
    prompt = Map.get(attrs, :prompt, "")
    content_type = Map.get(attrs, :content_type, "post")
    tone = Map.get(attrs, :tone, "professional")

    if String.length(prompt) < 10 do
      {:error, :prompt_too_short}
    else
      # Mock AI response
      generated_text = generate_mock_content(content_type, tone, prompt)

      {:ok,
       %{
         text: generated_text,
         model: "gpt-3.5-turbo",
         # rough estimate
         tokens_used: String.length(generated_text) |> div(4),
         # mock cost
         cost: Decimal.new("0.002")
       }}
    end
  end

  defp generate_mock_content("post", tone, prompt) do
    case tone do
      "professional" ->
        "🚀 Excited to share insights on #{extract_topic(prompt)}! 

In today's rapidly evolving landscape, it's crucial to stay ahead of the curve. Here are my key takeaways:

✅ Innovation drives success
✅ Collaboration fuels growth  
✅ Continuous learning is essential

What are your thoughts on this topic? I'd love to hear your perspective in the comments!

#LinkedIn #Professional #Growth #Innovation"

      "casual" ->
        "Hey LinkedIn! 👋

Just had some thoughts about #{extract_topic(prompt)} and wanted to share...

#{prompt}

Anyone else thinking about this? Drop your thoughts below! 💭

#Thoughts #Discussion"

      _ ->
        "Sharing some insights about #{extract_topic(prompt)}:

#{prompt}

Looking forward to your thoughts and experiences on this topic.

#Professional #Insights"
    end
  end

  defp generate_mock_content("comment", _tone, prompt) do
    "Great point! #{prompt} This really resonates with my experience. Thanks for sharing this valuable insight! 👍"
  end

  defp generate_mock_content("message", _tone, prompt) do
    "Hi there! I hope this message finds you well. #{prompt} I'd love to connect and discuss this further. Best regards!"
  end

  defp generate_mock_content(_, _, prompt) do
    "Here's some content based on your request: #{prompt}"
  end

  defp extract_topic(prompt) do
    # Simple topic extraction - in real implementation, this would be more sophisticated
    prompt
    |> String.split()
    |> Enum.take(3)
    |> Enum.join(" ")
    |> String.downcase()
  end

  defp count_words(text) do
    text
    |> String.split()
    |> length()
  end

  ## Analytics

  @doc """
  Gets content generation statistics for a user.

  ## Examples

      iex> get_user_content_stats(user)
      %{total_generated: 25, favorites: 5, published: 10}

  """
  def get_user_content_stats(%User{} = user) do
    query = from(gc in GeneratedContent, where: gc.user_id == ^user.id)

    total_query = from(gc in query, select: count(gc.id))
    favorites_query = from(gc in query, where: gc.is_favorite == true, select: count(gc.id))
    published_query = from(gc in query, where: gc.is_published == true, select: count(gc.id))

    %{
      total_generated: Repo.one(total_query),
      favorites: Repo.one(favorites_query),
      published: Repo.one(published_query)
    }
  end

  ## Changeset Helpers

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking generated content changes.

  ## Examples

      iex> change_generated_content(generated_content)
      %Ecto.Changeset{data: %GeneratedContent{}}

  """
  def change_generated_content(%GeneratedContent{} = generated_content, attrs \\ %{}) do
    GeneratedContent.changeset(generated_content, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking content template changes.

  ## Examples

      iex> change_content_template(content_template)
      %Ecto.Changeset{data: %ContentTemplate{}}

  """
  def change_content_template(%ContentTemplate{} = content_template, attrs \\ %{}) do
    ContentTemplate.changeset(content_template, attrs)
  end

  ## Admin Dashboard Functions

  @doc """
  Counts content generated today.
  """
  def count_content_generated_today do
    today = Date.utc_today()
    
    from(gc in GeneratedContent,
      where: fragment("DATE(?)", gc.inserted_at) == ^today,
      select: count(gc.id)
    )
    |> Repo.one()
  end

  @doc """
  Lists recent content for admin dashboard.
  """
  def list_recent_content(limit \\ 10) do
    from(gc in GeneratedContent,
      order_by: [desc: gc.inserted_at],
      limit: ^limit,
      preload: [:user],
      select: [:id, :content_type, :title, :inserted_at, :user_id]
    )
    |> Repo.all()
  end

  ## Advanced Analytics Functions

  @doc """
  Counts total content generated.
  """
  def count_total_content do
    from(gc in GeneratedContent, select: count(gc.id)) |> Repo.one()
  end

  @doc """
  Counts content generated for a specific period.
  """
  def count_content_for_period({start_date, end_date}) do
    from(gc in GeneratedContent,
      where: fragment("DATE(?)", gc.inserted_at) >= ^start_date and
             fragment("DATE(?)", gc.inserted_at) <= ^end_date,
      select: count(gc.id)
    )
    |> Repo.one()
  end

  @doc """
  Counts published content for a period.
  """
  def count_published_content({start_date, end_date}) do
    from(gc in GeneratedContent,
      where: gc.is_published == true and
             fragment("DATE(?)", gc.inserted_at) >= ^start_date and
             fragment("DATE(?)", gc.inserted_at) <= ^end_date,
      select: count(gc.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets average content quality score.
  """
  def get_average_quality_score do
    # Placeholder - would need quality scoring system
    8.2
  end

  @doc """
  Gets popular content types for a period.
  """
  def get_popular_content_types({start_date, end_date}) do
    from(gc in GeneratedContent,
      where: fragment("DATE(?)", gc.inserted_at) >= ^start_date and
             fragment("DATE(?)", gc.inserted_at) <= ^end_date,
      group_by: gc.content_type,
      select: {gc.content_type, count(gc.id)},
      order_by: [desc: count(gc.id)]
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets content engagement statistics.
  """
  def get_content_engagement_stats({_start_date, _end_date}) do
    # Placeholder - would calculate from LinkedIn engagement data
    75.8
  end

  @doc """
  Gets usage statistics for a period.
  """
  def get_usage_stats({start_date, end_date}) do
    %{
      usage_count: count_content_for_period({start_date, end_date}),
      unique_users: count_unique_users_for_period({start_date, end_date}),
      avg_per_user: calculate_avg_content_per_user({start_date, end_date})
    }
  end

  defp count_unique_users_for_period({start_date, end_date}) do
    from(gc in GeneratedContent,
      where: fragment("DATE(?)", gc.inserted_at) >= ^start_date and
             fragment("DATE(?)", gc.inserted_at) <= ^end_date,
      select: count(gc.user_id, :distinct)
    )
    |> Repo.one()
  end

  defp calculate_avg_content_per_user({start_date, end_date}) do
    total_content = count_content_for_period({start_date, end_date})
    unique_users = count_unique_users_for_period({start_date, end_date})
    
    if unique_users > 0 do
      Float.round(total_content / unique_users, 1)
    else
      0.0
    end
  end
end
