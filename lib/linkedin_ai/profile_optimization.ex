defmodule LinkedinAi.ProfileOptimization do
  @moduledoc """
  The ProfileOptimization context.
  Handles LinkedIn profile analysis, optimization suggestions, and improvement tracking.
  """

  import Ecto.Query, warn: false
  alias LinkedinAi.Repo
  alias LinkedinAi.ProfileOptimization.ProfileAnalysis
  alias LinkedinAi.Accounts.User
  alias LinkedinAi.Subscriptions

  ## Profile Analysis Management

  @doc """
  Lists profile analyses for a user with optional filters.

  ## Examples

      iex> list_user_analyses(user)
      [%ProfileAnalysis{}, ...]

      iex> list_user_analyses(user, analysis_type: "headline", status: "pending")
      [%ProfileAnalysis{}, ...]

  """
  def list_user_analyses(%User{} = user, filters \\ []) do
    query =
      from(pa in ProfileAnalysis,
        where: pa.user_id == ^user.id,
        order_by: [desc: pa.inserted_at]
      )

    query
    |> apply_analysis_filters(filters)
    |> Repo.all()
  end

  defp apply_analysis_filters(query, []), do: query

  defp apply_analysis_filters(query, [{:analysis_type, analysis_type} | rest]) do
    query
    |> where([pa], pa.analysis_type == ^analysis_type)
    |> apply_analysis_filters(rest)
  end

  defp apply_analysis_filters(query, [{:status, status} | rest]) do
    query
    |> where([pa], pa.status == ^status)
    |> apply_analysis_filters(rest)
  end

  defp apply_analysis_filters(query, [{:priority_level, priority} | rest]) do
    query
    |> where([pa], pa.priority_level == ^priority)
    |> apply_analysis_filters(rest)
  end

  defp apply_analysis_filters(query, [_filter | rest]) do
    apply_analysis_filters(query, rest)
  end

  @doc """
  Gets a single profile analysis.

  Raises `Ecto.NoResultsError` if the ProfileAnalysis does not exist.

  ## Examples

      iex> get_profile_analysis!(123)
      %ProfileAnalysis{}

      iex> get_profile_analysis!(456)
      ** (Ecto.NoResultsError)

  """
  def get_profile_analysis!(id), do: Repo.get!(ProfileAnalysis, id)

  @doc """
  Gets a profile analysis by user and ID.

  ## Examples

      iex> get_user_analysis(user, 123)
      %ProfileAnalysis{}

      iex> get_user_analysis(user, 456)
      nil

  """
  def get_user_analysis(%User{} = user, analysis_id) do
    Repo.get_by(ProfileAnalysis, id: analysis_id, user_id: user.id)
  end

  @doc """
  Analyzes user's LinkedIn profile using AI.

  ## Examples

      iex> analyze_profile(user, "headline")
      {:ok, %ProfileAnalysis{}}

      iex> analyze_profile(user, "invalid_type")
      {:error, %Ecto.Changeset{}}

  """
  def analyze_profile(%User{} = user, analysis_type) do
    # Check usage limits
    if Subscriptions.usage_limit_exceeded?(user, "profile_analysis") do
      {:error, :usage_limit_exceeded}
    else
      # Get current LinkedIn profile data
      case get_linkedin_profile_data(user) do
        {:ok, profile_data} ->
          # Analyze with AI
          case analyze_with_ai(analysis_type, profile_data) do
            {:ok, ai_response} ->
              analysis_attrs = %{
                user_id: user.id,
                analysis_type: analysis_type,
                current_content: extract_current_content(profile_data, analysis_type),
                analysis_results: ai_response.analysis,
                improvement_suggestions: ai_response.suggestions,
                score: ai_response.score,
                priority_level: determine_priority(ai_response.score),
                linkedin_profile_snapshot: profile_data,
                analysis_model: ai_response.model,
                analysis_tokens_used: ai_response.tokens_used,
                analysis_cost: ai_response.cost
              }

              result = create_profile_analysis(analysis_attrs)

              # Record usage
              if elem(result, 0) == :ok do
                Subscriptions.record_usage(user, "profile_analysis", 1)
              end

              result

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Creates a profile analysis.

  ## Examples

      iex> create_profile_analysis(%{field: value})
      {:ok, %ProfileAnalysis{}}

      iex> create_profile_analysis(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_profile_analysis(attrs \\ %{}) do
    %ProfileAnalysis{}
    |> ProfileAnalysis.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a profile analysis.

  ## Examples

      iex> update_profile_analysis(profile_analysis, %{field: new_value})
      {:ok, %ProfileAnalysis{}}

      iex> update_profile_analysis(profile_analysis, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_profile_analysis(%ProfileAnalysis{} = profile_analysis, attrs) do
    profile_analysis
    |> ProfileAnalysis.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a profile analysis.

  ## Examples

      iex> delete_profile_analysis(profile_analysis)
      {:ok, %ProfileAnalysis{}}

      iex> delete_profile_analysis(profile_analysis)
      {:error, %Ecto.Changeset{}}

  """
  def delete_profile_analysis(%ProfileAnalysis{} = profile_analysis) do
    Repo.delete(profile_analysis)
  end

  @doc """
  Marks analysis as reviewed.

  ## Examples

      iex> mark_as_reviewed(profile_analysis)
      {:ok, %ProfileAnalysis{}}

  """
  def mark_as_reviewed(%ProfileAnalysis{} = profile_analysis) do
    update_profile_analysis(profile_analysis, %{status: "reviewed"})
  end

  @doc """
  Marks analysis as implemented.

  ## Examples

      iex> mark_as_implemented(profile_analysis)
      {:ok, %ProfileAnalysis{}}

  """
  def mark_as_implemented(%ProfileAnalysis{} = profile_analysis) do
    update_profile_analysis(profile_analysis, %{
      status: "implemented",
      implemented_at: DateTime.utc_now()
    })
  end

  @doc """
  Dismisses an analysis.

  ## Examples

      iex> dismiss_analysis(profile_analysis)
      {:ok, %ProfileAnalysis{}}

  """
  def dismiss_analysis(%ProfileAnalysis{} = profile_analysis) do
    update_profile_analysis(profile_analysis, %{status: "dismissed"})
  end

  ## LinkedIn Profile Data (Mock Implementation)

  defp get_linkedin_profile_data(%User{} = user) do
    if User.linkedin_connected?(user) do
      # Mock LinkedIn profile data - in real implementation, this would call LinkedIn API
      {:ok,
       %{
         headline: user.linkedin_headline || "Professional at Company",
         summary:
           user.linkedin_summary || "Experienced professional with expertise in various areas.",
         industry: user.linkedin_industry || "Technology",
         location: user.linkedin_location || "San Francisco, CA",
         connections_count: user.linkedin_connections_count || 500,
         profile_url: user.linkedin_profile_url,
         profile_picture_url: user.linkedin_profile_picture_url,
         last_synced: user.linkedin_last_synced_at || DateTime.utc_now()
       }}
    else
      {:error, :linkedin_not_connected}
    end
  end

  defp extract_current_content(profile_data, analysis_type) do
    case analysis_type do
      "headline" -> Map.get(profile_data, :headline)
      "summary" -> Map.get(profile_data, :summary)
      "overall" -> inspect(profile_data)
      _ -> ""
    end
  end

  ## AI Analysis (Mock Implementation)

  defp analyze_with_ai(analysis_type, profile_data) do
    # Mock AI analysis - in real implementation, this would call OpenAI API
    case analysis_type do
      "headline" ->
        headline = Map.get(profile_data, :headline, "")
        score = calculate_headline_score(headline)

        {:ok,
         %{
           analysis: %{
             "clarity" => if(String.length(headline) > 10, do: "Good", else: "Needs improvement"),
             "keywords" =>
               if(String.contains?(headline, ["Professional", "Expert"]),
                 do: "Present",
                 else: "Missing"
               ),
             "length" => if(String.length(headline) <= 220, do: "Appropriate", else: "Too long")
           },
           suggestions: generate_headline_suggestions(headline),
           score: score,
           model: "gpt-3.5-turbo",
           tokens_used: 150,
           cost: Decimal.new("0.001")
         }}

      "summary" ->
        summary = Map.get(profile_data, :summary, "")
        score = calculate_summary_score(summary)

        {:ok,
         %{
           analysis: %{
             "structure" =>
               if(String.length(summary) > 100, do: "Well structured", else: "Too brief"),
             "keywords" => "Industry keywords present",
             "call_to_action" =>
               if(String.contains?(summary, ["contact", "connect"]),
                 do: "Present",
                 else: "Missing"
               )
           },
           suggestions: generate_summary_suggestions(summary),
           score: score,
           model: "gpt-3.5-turbo",
           tokens_used: 200,
           cost: Decimal.new("0.002")
         }}

      "overall" ->
        score = calculate_overall_score(profile_data)

        {:ok,
         %{
           analysis: %{
             "completeness" =>
               "Profile is #{if score > 70, do: "well", else: "partially"} completed",
             "optimization" =>
               "#{if score > 80, do: "Good", else: "Needs improvement"} optimization level",
             "engagement_potential" =>
               "#{if score > 75, do: "High", else: "Medium"} engagement potential"
           },
           suggestions: generate_overall_suggestions(profile_data),
           score: score,
           model: "gpt-3.5-turbo",
           tokens_used: 300,
           cost: Decimal.new("0.003")
         }}

      _ ->
        {:error, :invalid_analysis_type}
    end
  end

  defp calculate_headline_score(headline) do
    score = 0
    score = score + if String.length(headline) > 10, do: 30, else: 0
    score = score + if String.length(headline) <= 220, do: 20, else: 0

    score =
      score +
        if String.contains?(headline, ["Professional", "Expert", "Manager"]), do: 25, else: 0

    score = score + if String.match?(headline, ~r/\b\w+\b.*\b\w+\b/), do: 25, else: 0
    min(100, score)
  end

  defp calculate_summary_score(summary) do
    score = 0
    score = score + if String.length(summary) > 100, do: 40, else: 0
    score = score + if String.length(summary) <= 2600, do: 20, else: 0

    score =
      score + if String.contains?(summary, ["experience", "skills", "expertise"]), do: 20, else: 0

    score =
      score + if String.contains?(summary, ["contact", "connect", "reach out"]), do: 20, else: 0

    min(100, score)
  end

  defp calculate_overall_score(profile_data) do
    score = 0
    score = score + if Map.get(profile_data, :headline), do: 25, else: 0
    score = score + if Map.get(profile_data, :summary), do: 25, else: 0
    score = score + if Map.get(profile_data, :industry), do: 15, else: 0
    score = score + if Map.get(profile_data, :location), do: 10, else: 0
    score = score + if Map.get(profile_data, :profile_picture_url), do: 15, else: 0
    score = score + if (Map.get(profile_data, :connections_count) || 0) > 50, do: 10, else: 0
    min(100, score)
  end

  defp generate_headline_suggestions(_headline) do
    [
      %{
        "type" => "improvement",
        "title" => "Add specific skills or expertise",
        "description" => "Include 2-3 key skills or areas of expertise in your headline",
        "example" =>
          "Software Engineer | React & Node.js Expert | Building Scalable Web Applications"
      },
      %{
        "type" => "optimization",
        "title" => "Use industry keywords",
        "description" => "Include relevant industry keywords to improve discoverability",
        "example" => "Add terms like 'Full Stack', 'DevOps', or 'Machine Learning' if applicable"
      },
      %{
        "type" => "engagement",
        "title" => "Make it more engaging",
        "description" => "Use action words and show the value you provide",
        "example" => "Helping startups scale with robust backend solutions"
      }
    ]
  end

  defp generate_summary_suggestions(_summary) do
    [
      %{
        "type" => "structure",
        "title" => "Improve structure",
        "description" => "Start with a strong opening statement about your professional identity",
        "example" => "Begin with 'I am a [role] with [X] years of experience in [industry]'"
      },
      %{
        "type" => "achievements",
        "title" => "Add quantifiable achievements",
        "description" => "Include specific numbers and results from your work",
        "example" => "Increased team productivity by 30% or managed a team of 15 people"
      },
      %{
        "type" => "call_to_action",
        "title" => "Include a call to action",
        "description" => "End with how people can connect with you",
        "example" => "Feel free to connect if you'd like to discuss [relevant topic]"
      }
    ]
  end

  defp generate_overall_suggestions(profile_data) do
    suggestions = []

    suggestions =
      if !Map.get(profile_data, :headline) do
        [
          %{
            "type" => "missing_content",
            "title" => "Add a compelling headline",
            "description" => "Your headline is the first thing people see. Make it count!",
            "priority" => "high"
          }
          | suggestions
        ]
      else
        suggestions
      end

    suggestions =
      if !Map.get(profile_data, :summary) do
        [
          %{
            "type" => "missing_content",
            "title" => "Write a professional summary",
            "description" =>
              "A good summary tells your professional story and attracts the right connections",
            "priority" => "high"
          }
          | suggestions
        ]
      else
        suggestions
      end

    suggestions =
      if (Map.get(profile_data, :connections_count) || 0) < 50 do
        [
          %{
            "type" => "networking",
            "title" => "Grow your network",
            "description" => "Connect with colleagues, industry peers, and thought leaders",
            "priority" => "medium"
          }
          | suggestions
        ]
      else
        suggestions
      end

    suggestions
  end

  defp determine_priority(score) when score >= 80, do: "low"
  defp determine_priority(score) when score >= 60, do: "medium"
  defp determine_priority(score) when score >= 40, do: "high"
  defp determine_priority(_), do: "critical"

  ## Analytics

  @doc """
  Gets profile analysis statistics for a user.

  ## Examples

      iex> get_user_analysis_stats(user)
      %{total_analyses: 5, pending: 2, implemented: 2, avg_score: 75}

  """
  def get_user_analysis_stats(%User{} = user) do
    query = from(pa in ProfileAnalysis, where: pa.user_id == ^user.id)

    total_query = from(pa in query, select: count(pa.id))
    pending_query = from(pa in query, where: pa.status == "pending", select: count(pa.id))
    implemented_query = from(pa in query, where: pa.status == "implemented", select: count(pa.id))
    avg_score_query = from(pa in query, select: avg(pa.score))

    %{
      total_analyses: Repo.one(total_query),
      pending: Repo.one(pending_query),
      implemented: Repo.one(implemented_query),
      avg_score: Repo.one(avg_score_query) |> round_score()
    }
  end

  defp round_score(nil), do: 0
  defp round_score(score), do: Float.round(score, 1)

  ## Changeset Helpers

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking profile analysis changes.

  ## Examples

      iex> change_profile_analysis(profile_analysis)
      %Ecto.Changeset{data: %ProfileAnalysis{}}

  """
  def change_profile_analysis(%ProfileAnalysis{} = profile_analysis, attrs \\ %{}) do
    ProfileAnalysis.changeset(profile_analysis, attrs)
  end

  ## Admin Dashboard Functions

  @doc """
  Counts profiles analyzed today.
  """
  def count_profiles_analyzed_today do
    today = Date.utc_today()
    
    from(pa in ProfileAnalysis,
      where: fragment("DATE(?)", pa.inserted_at) == ^today,
      select: count(pa.id)
    )
    |> Repo.one()
  end

  @doc """
  Lists recent analyses for admin dashboard.
  """
  def list_recent_analyses(limit \\ 10) do
    from(pa in ProfileAnalysis,
      order_by: [desc: pa.inserted_at],
      limit: ^limit,
      preload: [:user],
      select: [:id, :analysis_type, :score, :status, :inserted_at, :user_id]
    )
    |> Repo.all()
  end
end
