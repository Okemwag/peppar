defmodule LinkedinAi.AI.Behaviour do
  @moduledoc """
  Behaviour for AI operations to enable mocking in tests.
  """

  @callback generate_content(map()) :: {:ok, map()} | {:error, term()}
  @callback analyze_profile(map()) :: {:ok, map()} | {:error, term()}
end
