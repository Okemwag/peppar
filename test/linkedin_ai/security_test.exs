defmodule LinkedinAi.SecurityTest do
  use LinkedinAi.DataCase, async: true

  alias LinkedinAi.Security

  describe "encrypt/1 and decrypt/1" do
    test "encrypts and decrypts data correctly" do
      plaintext = "sensitive_api_key_12345"

      encrypted = Security.encrypt(plaintext)
      assert encrypted != plaintext
      assert is_binary(encrypted)

      {:ok, decrypted} = Security.decrypt(encrypted)
      assert decrypted == plaintext
    end

    test "returns error for invalid encrypted data" do
      assert {:error, :invalid_format} = Security.decrypt("invalid_base64")
      assert {:error, :decryption_failed} = Security.decrypt(Base.encode64("invalid_data"))
    end
  end

  describe "encrypt_api_key/1 and decrypt_api_key/1" do
    test "encrypts and decrypts API keys" do
      api_key = "sk-1234567890abcdef"

      encrypted = Security.encrypt_api_key(api_key)
      {:ok, decrypted} = Security.decrypt_api_key(encrypted)

      assert decrypted == api_key
    end
  end

  describe "validate_api_key/1" do
    test "validates API key format" do
      assert :ok = Security.validate_api_key("sk-1234567890abcdef1234")
      assert {:error, :too_short} = Security.validate_api_key("short")
      assert {:error, :invalid_characters} = Security.validate_api_key("key with spaces!")
    end
  end

  describe "generate_secure_token/1" do
    test "generates secure tokens" do
      token1 = Security.generate_secure_token()
      token2 = Security.generate_secure_token()

      assert is_binary(token1)
      assert is_binary(token2)
      assert token1 != token2
      assert String.length(token1) == 32
    end

    test "generates tokens of specified length" do
      token = Security.generate_secure_token(16)
      assert String.length(token) == 16
    end
  end

  describe "log_security_event/3" do
    test "logs security events" do
      # This test would need to mock the audit log creation
      # For now, we'll just ensure it doesn't crash
      assert :ok = Security.log_security_event("test_event", %{test: "data"}, 1)
    end
  end
end
