defmodule LinkedinAi.AI do
  @moduledoc """
  The AI context.
  Handles OpenAI integration for content generation and profile analysis.
  """

  alias LinkedinAi.AI.OpenAIClient

  require Logger

  ## Content Generation

  @doc """
  Generates LinkedIn content using OpenAI.

  ## Examples

      iex> generate_content(%{prompt: "Write about AI", content_type: "post", tone: "professional"})
      {:ok, %{text: "...", tokens_used: 150, cost: 0.002}}

  """
  def generate_content(params) do
    %{
      prompt: prompt,
      content_type: content_type,
      tone: tone,
      target_audience: target_audience
    } = normalize_content_params(params)

    system_prompt = build_content_system_prompt(content_type, tone, target_audience)
    user_prompt = build_content_user_prompt(prompt, content_type)

    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ]

    case OpenAIClient.create_chat_completion(messages, content_generation_options()) do
      {:ok, response} ->
        content = extract_content_from_response(response)
        tokens_used = get_in(response, ["usage", "total_tokens"]) || 0
        cost = calculate_cost(tokens_used, "gpt-3.5-turbo")

        {:ok,
         %{
           text: content,
           tokens_used: tokens_used,
           cost: cost,
           model: "gpt-3.5-turbo"
         }}

      {:error, reason} ->
        Logger.error("OpenAI content generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Analyzes LinkedIn profile content using OpenAI.

  ## Examples

      iex> analyze_profile(%{type: "headline", content: "Software Engineer"})
      {:ok, %{analysis: %{...}, suggestions: [...], score: 75}}

  """
  def analyze_profile(params) do
    %{
      analysis_type: analysis_type,
      content: content,
      profile_data: profile_data
    } = normalize_analysis_params(params)

    system_prompt = build_analysis_system_prompt(analysis_type)
    user_prompt = build_analysis_user_prompt(analysis_type, content, profile_data)

    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ]

    case OpenAIClient.create_chat_completion(messages, analysis_options()) do
      {:ok, response} ->
        analysis_result = extract_analysis_from_response(response)
        tokens_used = get_in(response, ["usage", "total_tokens"]) || 0
        cost = calculate_cost(tokens_used, "gpt-3.5-turbo")

        {:ok,
         %{
           analysis: analysis_result.analysis,
           suggestions: analysis_result.suggestions,
           score: analysis_result.score,
           tokens_used: tokens_used,
           cost: cost,
           model: "gpt-3.5-turbo"
         }}

      {:error, reason} ->
        Logger.error("OpenAI profile analysis failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions - Content Generation

  defp normalize_content_params(params) do
    %{
      prompt: Map.get(params, :prompt, ""),
      content_type: Map.get(params, :content_type, "post"),
      tone: Map.get(params, :tone, "professional"),
      target_audience: Map.get(params, :target_audience, "general")
    }
  end

  defp build_content_system_prompt(content_type, tone, target_audience) do
    base_prompt = """
    You are an expert LinkedIn content creator and social media strategist. Your task is to create engaging, professional LinkedIn content that drives engagement and builds professional relationships.

    Content Type: #{String.capitalize(content_type)}
    Tone: #{String.capitalize(tone)}
    Target Audience: #{String.capitalize(target_audience)}

    Guidelines:
    - Keep content authentic and valuable
    - Use appropriate professional language
    - Include relevant hashtags when appropriate
    - Ensure content is engaging and encourages interaction
    - Follow LinkedIn best practices for #{content_type}s
    """

    case content_type do
      "post" ->
        base_prompt <>
          """

          For LinkedIn posts:
          - Start with a hook to grab attention
          - Keep paragraphs short for readability
          - Include a call-to-action or question to encourage engagement
          - Use 3-5 relevant hashtags
          - Aim for 150-300 words for optimal engagement
          """

      "comment" ->
        base_prompt <>
          """

          For LinkedIn comments:
          - Be supportive and add value to the conversation
          - Keep it concise but meaningful
          - Ask follow-up questions when appropriate
          - Avoid being overly promotional
          """

      "message" ->
        base_prompt <>
          """

          For LinkedIn messages:
          - Be personal and professional
          - Clearly state the purpose
          - Keep it brief and respectful
          - Include a clear call-to-action if needed
          """

      "article" ->
        base_prompt <>
          """

          For LinkedIn articles:
          - Create a compelling headline
          - Structure with clear sections and subheadings
          - Provide actionable insights or valuable information
          - Include a strong conclusion with key takeaways
          - Aim for 1000-2000 words for comprehensive coverage
          """

      _ ->
        base_prompt
    end
  end

  defp build_content_user_prompt(prompt, content_type) do
    case content_type do
      "post" ->
        "Create a LinkedIn post based on this topic or idea: #{prompt}"

      "comment" ->
        "Write a thoughtful LinkedIn comment in response to this post or topic: #{prompt}"

      "message" ->
        "Compose a professional LinkedIn message about: #{prompt}"

      "article" ->
        "Write a comprehensive LinkedIn article about: #{prompt}"

      _ ->
        "Create LinkedIn content about: #{prompt}"
    end
  end

  defp content_generation_options do
    %{
      model: "gpt-3.5-turbo",
      max_tokens: 500,
      temperature: 0.7,
      top_p: 1.0,
      frequency_penalty: 0.0,
      presence_penalty: 0.0
    }
  end

  defp extract_content_from_response(response) do
    get_in(response, ["choices", Access.at(0), "message", "content"]) || ""
  end

  ## Private Functions - Profile Analysis

  defp normalize_analysis_params(params) do
    %{
      analysis_type: Map.get(params, :analysis_type, "overall"),
      content: Map.get(params, :content, ""),
      profile_data: Map.get(params, :profile_data, %{})
    }
  end

  defp build_analysis_system_prompt(analysis_type) do
    base_prompt = """
    You are a LinkedIn profile optimization expert with years of experience helping professionals improve their LinkedIn presence. Your task is to analyze LinkedIn profile content and provide actionable improvement suggestions.

    Analysis Type: #{String.capitalize(analysis_type)}

    Your response should be a JSON object with the following structure:
    {
      "analysis": {
        "key1": "assessment1",
        "key2": "assessment2"
      },
      "suggestions": [
        {
          "type": "improvement|optimization|engagement",
          "title": "Suggestion title",
          "description": "Detailed description",
          "priority": "high|medium|low",
          "example": "Example implementation"
        }
      ],
      "score": 85
    }

    Scoring Guidelines:
    - 90-100: Excellent, minimal improvements needed
    - 80-89: Very good, minor optimizations possible
    - 70-79: Good, some improvements recommended
    - 60-69: Fair, several improvements needed
    - Below 60: Needs significant improvement
    """

    case analysis_type do
      "headline" ->
        base_prompt <>
          """

          For headline analysis, focus on:
          - Clarity and professional impact
          - Use of relevant keywords
          - Length (under 220 characters)
          - Value proposition
          - Industry-specific terminology
          - Call-to-action or engagement factor
          """

      "summary" ->
        base_prompt <>
          """

          For summary analysis, focus on:
          - Professional storytelling
          - Achievement highlights
          - Skills and expertise showcase
          - Call-to-action for connections
          - Keyword optimization
          - Length and readability
          - Personal brand consistency
          """

      "overall" ->
        base_prompt <>
          """

          For overall profile analysis, consider:
          - Profile completeness
          - Professional photo presence
          - Headline effectiveness
          - Summary quality
          - Experience descriptions
          - Skills and endorsements
          - Network size and engagement
          - Content activity
          """

      _ ->
        base_prompt
    end
  end

  defp build_analysis_user_prompt(analysis_type, content, profile_data) do
    case analysis_type do
      "headline" ->
        "Analyze this LinkedIn headline: \"#{content}\""

      "summary" ->
        "Analyze this LinkedIn summary: \"#{content}\""

      "overall" ->
        """
        Analyze this complete LinkedIn profile data:

        Headline: #{Map.get(profile_data, :headline, "Not provided")}
        Summary: #{Map.get(profile_data, :summary, "Not provided")}
        Industry: #{Map.get(profile_data, :industry, "Not provided")}
        Location: #{Map.get(profile_data, :location, "Not provided")}
        Connections: #{Map.get(profile_data, :connections_count, "Unknown")}
        Profile Picture: #{if Map.get(profile_data, :profile_picture_url), do: "Present", else: "Missing"}
        """

      _ ->
        "Analyze this LinkedIn profile content: #{content}"
    end
  end

  defp analysis_options do
    %{
      model: "gpt-3.5-turbo",
      max_tokens: 800,
      temperature: 0.3,
      top_p: 1.0,
      frequency_penalty: 0.0,
      presence_penalty: 0.0
    }
  end

  defp extract_analysis_from_response(response) do
    content = get_in(response, ["choices", Access.at(0), "message", "content"]) || "{}"

    case Jason.decode(content) do
      {:ok, parsed} ->
        %{
          analysis: Map.get(parsed, "analysis", %{}),
          suggestions: Map.get(parsed, "suggestions", []),
          score: Map.get(parsed, "score", 0)
        }

      {:error, _} ->
        # Fallback if JSON parsing fails
        %{
          analysis: %{"general" => "Analysis completed"},
          suggestions: [
            %{
              "type" => "improvement",
              "title" => "Review and optimize",
              "description" => "Consider reviewing your profile content for improvements",
              "priority" => "medium"
            }
          ],
          score: 70
        }
    end
  end

  ## Utility Functions

  defp calculate_cost(tokens, model) do
    # OpenAI pricing as of 2024 (approximate)
    cost_per_1k_tokens =
      case model do
        "gpt-3.5-turbo" -> 0.002
        "gpt-4" -> 0.03
        _ -> 0.002
      end

    Decimal.new(tokens * cost_per_1k_tokens / 1000)
  end

  ## Content Templates

  @doc """
  Gets predefined content templates for different use cases.

  ## Examples

      iex> get_content_templates("post")
      [%{name: "Achievement Post", prompt: "..."}, ...]

  """
  def get_content_templates(content_type \\ "post") do
    case content_type do
      "post" ->
        [
          %{
            name: "Achievement Post",
            description: "Share a professional achievement or milestone",
            prompt: "I recently {{achievement}}. Here's what I learned: {{key_learnings}}",
            tone: "professional",
            audience: "peers"
          },
          %{
            name: "Industry Insight",
            description: "Share insights about industry trends",
            prompt:
              "The {{industry}} industry is experiencing {{trend}}. Here's my take: {{insights}}",
            tone: "informative",
            audience: "industry"
          },
          %{
            name: "Thought Leadership",
            description: "Share expert opinions and thought leadership",
            prompt:
              "After {{years}} years in {{field}}, I believe {{opinion}}. Here's why: {{reasoning}}",
            tone: "professional",
            audience: "executives"
          },
          %{
            name: "Team Appreciation",
            description: "Appreciate team members or colleagues",
            prompt:
              "Grateful to work with {{team_member}} who {{accomplishment}}. {{appreciation_details}}",
            tone: "enthusiastic",
            audience: "general"
          }
        ]

      "comment" ->
        [
          %{
            name: "Supportive Comment",
            description: "Show support for someone's post",
            prompt:
              "Great insights! I especially agree with {{specific_point}}. In my experience, {{personal_experience}}",
            tone: "friendly",
            audience: "general"
          },
          %{
            name: "Question Comment",
            description: "Ask a thoughtful follow-up question",
            prompt:
              "This is really interesting! I'm curious about {{question}}. Have you found {{follow_up_question}}?",
            tone: "casual",
            audience: "peers"
          }
        ]

      "message" ->
        [
          %{
            name: "Connection Request",
            description: "Request to connect with someone",
            prompt:
              "Hi {{name}}, I came across your profile and was impressed by {{specific_detail}}. I'd love to connect and {{reason_to_connect}}",
            tone: "professional",
            audience: "general"
          },
          %{
            name: "Follow-up Message",
            description: "Follow up after meeting someone",
            prompt:
              "Hi {{name}}, it was great meeting you at {{event}}. I enjoyed our conversation about {{topic}}. {{follow_up_action}}",
            tone: "friendly",
            audience: "general"
          }
        ]

      _ ->
        []
    end
  end

  ## Rate Limiting and Error Handling

  @doc """
  Checks if the API rate limit has been exceeded.
  """
  def rate_limit_exceeded?(_user_id) do
    # TODO: Implement rate limiting logic
    # This could use Redis or ETS to track API usage per user
    false
  end

  @doc """
  Gets the current API usage for a user.
  """
  def get_api_usage(_user_id) do
    # TODO: Implement usage tracking
    %{
      requests_today: 0,
      tokens_used_today: 0,
      cost_today: Decimal.new("0.00")
    }
  end
end
