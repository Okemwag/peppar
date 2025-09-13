defmodule LinkedinAi.Security do
  @moduledoc """
  Security utilities for the LinkedIn AI platform.
  Handles API key encryption, security logging, and other security-related functions.
  """

  @doc """
  Encrypts sensitive data like API keys using AES encryption.
  """
  def encrypt(plaintext) when is_binary(plaintext) do
    secret_key = get_encryption_key()
    iv = :crypto.strong_rand_bytes(16)

    encrypted = :crypto.crypto_one_time(:aes_256_cbc, secret_key, iv, plaintext, true)

    # Combine IV and encrypted data, then base64 encode
    (iv <> encrypted) |> Base.encode64()
  end

  @doc """
  Decrypts previously encrypted data.
  """
  def decrypt(ciphertext) when is_binary(ciphertext) do
    secret_key = get_encryption_key()

    case Base.decode64(ciphertext) do
      {:ok, decoded} ->
        <<iv::binary-16, encrypted::binary>> = decoded

        case :crypto.crypto_one_time(:aes_256_cbc, secret_key, iv, encrypted, false) do
          decrypted when is_binary(decrypted) ->
            {:ok, decrypted}

          _ ->
            {:error, :decryption_failed}
        end

      :error ->
        {:error, :invalid_format}
    end
  end

  @doc """
  Safely encrypts API keys for storage.
  """
  def encrypt_api_key(api_key) when is_binary(api_key) do
    encrypt(api_key)
  end

  @doc """
  Safely decrypts API keys for use.
  """
  def decrypt_api_key(encrypted_key) when is_binary(encrypted_key) do
    decrypt(encrypted_key)
  end

  @doc """
  Logs security events for audit purposes.
  """
  def log_security_event(event_type, details \\ %{}, user_id \\ nil) do
    event_data = %{
      event_type: event_type,
      details: details,
      user_id: user_id,
      timestamp: DateTime.utc_now(),
      ip_address: get_client_ip(),
      user_agent: get_user_agent()
    }

    # Log to standard logger
    require Logger
    Logger.warning("Security Event: #{event_type}", event_data)

    # Store in database for audit trail
    LinkedinAi.Security.AuditLog.create_entry(event_data)
  end

  @doc """
  Validates API key format and strength.
  """
  def validate_api_key(api_key) when is_binary(api_key) do
    cond do
      String.length(api_key) < 20 ->
        {:error, :too_short}

      not String.match?(api_key, ~r/^[a-zA-Z0-9_-]+$/) ->
        {:error, :invalid_characters}

      true ->
        :ok
    end
  end

  @doc """
  Generates a secure random token for various purposes.
  """
  def generate_secure_token(length \\ 32) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> String.slice(0, length)
  end

  # Private functions

  defp get_encryption_key do
    # Get from environment or generate a default for development
    case System.get_env("ENCRYPTION_KEY") do
      nil ->
        # For development only - in production this should always be set
        :crypto.hash(:sha256, "linkedin_ai_dev_key_#{Mix.env()}")

      key when byte_size(key) >= 32 ->
        :crypto.hash(:sha256, key)

      key ->
        :crypto.hash(:sha256, key <> "linkedin_ai_padding")
    end
  end

  defp get_client_ip do
    # This would be set by a plug in the request pipeline
    Process.get(:client_ip, "unknown")
  end

  defp get_user_agent do
    # This would be set by a plug in the request pipeline
    Process.get(:user_agent, "unknown")
  end
end
