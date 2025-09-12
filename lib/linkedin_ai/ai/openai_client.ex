defmodule LinkedinAi.AI.OpenAIClient do
  @moduledoc """
  OpenAI API client for chat completions and other AI operations.
  """

  require Logger

  @base_url "https://api.openai.com/v1"
  @default_model "gpt-3.5-turbo"
  @max_retries 3
  @retry_delay 1000

  ## Public API

  @doc """
  Creates a chat completion using OpenAI's API.

  ## Examples

      iex> create_chat_completion([%{role: "user", content: "Hello"}])
      {:ok, %{"choices" => [%{"message" => %{"content" => "Hi there!"}}]}}

  """
  def create_chat_completion(messages, options \\ %{}) do
    params = build_completion_params(messages, options)

    with_retry(fn ->
      post("/chat/completions", params)
    end)
  end

  @doc """
  Lists available OpenAI models.

  ## Examples

      iex> list_models()
      {:ok, %{"data" => [%{"id" => "gpt-3.5-turbo", ...}]}}

  """
  def list_models do
    get("/models")
  end

  @doc """
  Gets information about a specific model.

  ## Examples

      iex> get_model("gpt-3.5-turbo")
      {:ok, %{"id" => "gpt-3.5-turbo", "object" => "model", ...}}

  """
  def get_model(model_id) do
    get("/models/#{model_id}")
  end

  ## Private Functions

  defp build_completion_params(messages, options) do
    default_params = %{
      model: @default_model,
      messages: messages,
      max_tokens: 500,
      temperature: 0.7,
      top_p: 1.0,
      frequency_penalty: 0.0,
      presence_penalty: 0.0,
      stream: false
    }

    Map.merge(default_params, options)
  end

  defp get(path, params \\ %{}) do
    url = @base_url <> path
    query_string = URI.encode_query(params)
    full_url = if query_string != "", do: url <> "?" <> query_string, else: url

    case HTTPoison.get(full_url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("OpenAI API error: #{status_code} - #{body}")
        {:error, parse_error_response(body, status_code)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp post(path, params) do
    url = @base_url <> path
    body = Jason.encode!(params)

    case HTTPoison.post(url, body, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("OpenAI API error: #{status_code} - #{response_body}")
        {:error, parse_error_response(response_body, status_code)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp headers do
    api_key = get_api_key()
    organization_id = get_organization_id()

    base_headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "LinkedinAI/1.0"}
    ]

    if organization_id do
      [{"OpenAI-Organization", organization_id} | base_headers]
    else
      base_headers
    end
  end

  defp get_api_key do
    case Application.get_env(:linkedin_ai, :openai)[:api_key] do
      nil ->
        raise "OpenAI API key not configured. Please set :linkedin_ai, :openai, :api_key in your config."

      api_key when is_binary(api_key) ->
        api_key

      {:system, env_var} ->
        System.get_env(env_var) ||
          raise "OpenAI API key environment variable #{env_var} not set."
    end
  end

  defp get_organization_id do
    case Application.get_env(:linkedin_ai, :openai)[:organization_id] do
      nil -> nil
      org_id when is_binary(org_id) -> org_id
      {:system, env_var} -> System.get_env(env_var)
    end
  end

  defp parse_error_response(body, status_code) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} ->
        error_type = Map.get(error, "type", "unknown_error")
        error_message = Map.get(error, "message", "Unknown error occurred")

        case {status_code, error_type} do
          {401, _} -> :unauthorized
          {429, "rate_limit_exceeded"} -> :rate_limit_exceeded
          {429, "quota_exceeded"} -> :quota_exceeded
          {400, "invalid_request_error"} -> {:invalid_request, error_message}
          {500, _} -> :server_error
          {503, _} -> :service_unavailable
          _ -> {:api_error, error_message}
        end

      _ ->
        case status_code do
          401 -> :unauthorized
          429 -> :rate_limit_exceeded
          500 -> :server_error
          503 -> :service_unavailable
          _ -> :unknown_error
        end
    end
  end

  ## Retry Logic

  defp with_retry(fun, retries \\ @max_retries) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason}
      when retries > 0 and
             reason in [:rate_limit_exceeded, :server_error, :service_unavailable, :network_error] ->
        Logger.warning("Retrying OpenAI request due to #{reason}, #{retries} retries left")
        :timer.sleep(@retry_delay)
        with_retry(fun, retries - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Utility Functions

  @doc """
  Estimates the number of tokens in a text string.
  This is a rough approximation - actual tokenization may differ.

  ## Examples

      iex> estimate_tokens("Hello world")
      2

  """
  def estimate_tokens(text) when is_binary(text) do
    # Rough estimation: ~4 characters per token for English text
    # This is an approximation and may not be accurate for all cases
    text
    |> String.length()
    |> div(4)
    |> max(1)
  end

  def estimate_tokens(_), do: 0

  @doc """
  Calculates the estimated cost for a completion request.

  ## Examples

      iex> estimate_cost(1000, "gpt-3.5-turbo")
      0.002

  """
  def estimate_cost(tokens, model \\ @default_model) do
    cost_per_1k_tokens =
      case model do
        "gpt-3.5-turbo" -> 0.002
        "gpt-3.5-turbo-16k" -> 0.004
        "gpt-4" -> 0.03
        "gpt-4-32k" -> 0.06
        # Default to gpt-3.5-turbo pricing
        _ -> 0.002
      end

    tokens * cost_per_1k_tokens / 1000
  end

  @doc """
  Validates that a message list is properly formatted for the API.

  ## Examples

      iex> validate_messages([%{role: "user", content: "Hello"}])
      :ok

      iex> validate_messages([%{role: "invalid", content: "Hello"}])
      {:error, :invalid_role}

  """
  def validate_messages(messages) when is_list(messages) do
    valid_roles = ["system", "user", "assistant"]

    Enum.reduce_while(messages, :ok, fn message, _acc ->
      case message do
        %{role: role, content: content} when role in valid_roles and is_binary(content) ->
          if String.trim(content) == "" do
            {:halt, {:error, :empty_content}}
          else
            {:cont, :ok}
          end

        %{role: role} when role not in valid_roles ->
          {:halt, {:error, :invalid_role}}

        %{content: content} when not is_binary(content) ->
          {:halt, {:error, :invalid_content}}

        _ ->
          {:halt, {:error, :invalid_message_format}}
      end
    end)
  end

  def validate_messages(_), do: {:error, :invalid_messages_format}

  ## Rate Limiting Helpers

  @doc """
  Gets the current rate limit status from response headers.
  """
  def parse_rate_limit_headers(headers) do
    headers_map = Enum.into(headers, %{})

    %{
      limit_requests: get_header_value(headers_map, "x-ratelimit-limit-requests"),
      limit_tokens: get_header_value(headers_map, "x-ratelimit-limit-tokens"),
      remaining_requests: get_header_value(headers_map, "x-ratelimit-remaining-requests"),
      remaining_tokens: get_header_value(headers_map, "x-ratelimit-remaining-tokens"),
      reset_requests: get_header_value(headers_map, "x-ratelimit-reset-requests"),
      reset_tokens: get_header_value(headers_map, "x-ratelimit-reset-tokens")
    }
  end

  defp get_header_value(headers_map, key) do
    case Map.get(headers_map, key) do
      nil ->
        nil

      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_value, _} -> int_value
          :error -> nil
        end
    end
  end

  ## Health Check

  @doc """
  Performs a health check on the OpenAI API.

  ## Examples

      iex> health_check()
      {:ok, :healthy}

  """
  def health_check do
    case list_models() do
      {:ok, _models} -> {:ok, :healthy}
      {:error, :unauthorized} -> {:error, :unauthorized}
      {:error, _reason} -> {:error, :unhealthy}
    end
  end
end
