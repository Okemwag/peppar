defmodule LinkedinAi.Analytics do
  @moduledoc """
  The Analytics context.
  Handles data aggregation, report generation, and performance metrics for the LinkedIn AI platform.
  """

  import Ecto.Query, warn: false
  alias LinkedinAi.Repo
  alias LinkedinAi.Accounts.User
  alias LinkedinAi.Subscriptions.{Subscription, UsageRecord}
  alias LinkedinAi.ContentGeneration.GeneratedContent
  alias LinkedinAi.ProfileOptimization.ProfileAnalysis

  ## User Analytics

  @doc """
  Gets comprehensive analytics for a user.

  ## Examples

      iex> get_user_analytics(user)
      %{content: %{...}, profile: %{...}, usage: %{...}}

  """
  def get_user_analytics(%User{} = user) do
    %{
      content: get_user_content_analytics(user),
      profile: get_user_profile_analytics(user),
      usage: get_user_usage_analytics(user),
      engagement: get_user_engagement_analytics(user),
      growth: get_user_growth_analytics(user)
    }
  end

  @doc """
  Gets content generation analytics for a user.

  ## Examples

      iex> get_user_content_analytics(user)
      %{total_generated: 25, published: 10, favorites: 5, ...}

  """
  def get_user_content_analytics(%User{} = user) do
    base_query = from(gc in GeneratedContent, where: gc.user_id == ^user.id)
    
    total_generated = from(gc in base_query, select: count(gc.id)) |> Repo.one()
    published_count = from(gc in base_query, where: gc.is_published == true, select: count(gc.id)) |> Repo.one()
    favorites_count = from(gc in base_query, where: gc.is_favorite == true, select: count(gc.id)) |> Repo.one()
    
    # Content by type
    content_by_type = from(gc in base_query,
      group_by: gc.content_type,
      select: {gc.content_type, count(gc.id)}
    ) |> Repo.all() |> Enum.into(%{})
    
    # Recent activity (last 30 days)
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
    recent_content = from(gc in base_query,
      where: gc.inserted_at >= ^thirty_days_ago,
      select: count(gc.id)
    ) |> Repo.one()
    
    # Average word count
    avg_word_count = from(gc in base_query,
      where: not is_nil(gc.word_count),
      select: avg(gc.word_count)
    ) |> Repo.one() |> round_avg()
    
    %{
      total_generated: total_generated,
      published: published_count,
      favorites: favorites_count,
      content_by_type: content_by_type,
      recent_activity: recent_content,
      avg_word_count: avg_word_count,
      publish_rate: calculate_percentage(published_count, total_generated)
    }
  end

  @doc """
  Gets profile optimization analytics for a user.

  ## Examples

      iex> get_user_profile_analytics(user)
      %{total_analyses: 5, avg_score: 75, improvements: 3, ...}

  """
  def get_user_profile_analytics(%User{} = user) do
    base_query = from(pa in ProfileAnalysis, where: pa.user_id == ^user.id)
    
    total_analyses = from(pa in base_query, select: count(pa.id)) |> Repo.one()
    avg_score = from(pa in base_query, select: avg(pa.score)) |> Repo.one() |> round_avg()
    implemented_count = from(pa in base_query, where: pa.status == "implemented", select: count(pa.id)) |> Repo.one()
    
    # Latest score
    latest_score = from(pa in base_query,