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
      {:ok, %{"choices" => [%{"message" => %{"content" => "Hi there!