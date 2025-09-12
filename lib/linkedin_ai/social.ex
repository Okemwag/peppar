defmodule LinkedinAi.Social do
  @moduledoc """
  The Social context.
  Handles LinkedIn API integration for OAuth, profile data, and content publishing.
  """

  alias LinkedinAi.Social.LinkedInClient
  alias LinkedinAi.Accounts.User
  alias LinkedinAi.Accounts

  require Logger

  ## OAuth Flow

  @doc """
  Generates LinkedIn OAuth authorization URL.

  ## Examples

      iex> get_authorization_url("http://localhost:4000/auth/linkedin/callback")
      "https://www.linkedin.com/oauth/v2/authorization?response_type=code&client_id=..."

  """
  def get_authorization_url(redirect_uri, state \\ nil) do
    LinkedInClient.get_authorization_url(redirect_uri, state)
  end

  @doc """
  Exchanges authorization code for access token.

  ## Examples

      iex> exchange_code_for_token("auth_code", "http://localhost:4000/auth/linkedin/callback")
      {:ok, %{access_token: "...", expires_in: 5184000}}

  """
  def exchange_code_for_token(code, redirect_uri) do
    case LinkedInClient.exchange_code_for_token(code, redirect_uri) do
      {:ok, token_data} ->
        {:ok, token_data}

      {:error, reason} ->
        Logger.error("Failed to exchange LinkedIn code for token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Connects a user's LinkedIn account by storing OAuth tokens and fetching profile data.

  ## Examples

      iex> connect_linkedin_account(user, "access_token", 5184000)
      {:ok, %User{linkedin_id: "...", linkedin_access_token: "..."}}

  """
  def connect_linkedin_account(%User{} = user, access_token, expires_in) do
    expires_at = DateTime.utc_now() |> DateTime.add(expires_in, :second)

    # Fetch LinkedIn profile data
    case LinkedInClient.get_profile(access_token) do
      {:ok, profile_data} ->
        linkedin_attrs = %{
          linkedin_id: profile_data["id"],
          linkedin_access_token: access_token,
          linkedin_token_expires_at: expires_at,
          linkedin_profile_url: build_profile_url(profile_data),
          linkedin_headline: profile_data["headline"],
          linkedin_industry: profile_data["industry"],
          linkedin_location: get_location_string(profile_data),
          linkedin_profile_picture_url: get_profile_picture_url(profile_data),
          linkedin_last_synced_at: DateTime.utc_now(),
          first_name: get_in(profile_data, ["firstName", "localized", "en_US"]),
          last_name: get_in(profile_data, ["lastName", "localized", "en_US"])
        }

        case Accounts.update_user_linkedin(user, linkedin_attrs) do
          {:ok, updated_user} ->
            Logger.info("Successfully connected LinkedIn account for user #{user.id}")
            {:ok, updated_user}

          {:error, changeset} ->
            Logger.error("Failed to update user with LinkedIn data: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end

      {:error, reason} ->
        Logger.error("Failed to fetch LinkedIn profile: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Disconnects a user's LinkedIn account.

  ## Examples

      iex> disconnect_linkedin_account(user)
      {:ok, %User{linkedin_id: nil, linkedin_access_token: nil}}

  """
  def disconnect_linkedin_account(%User{} = user) do
    linkedin_attrs = %{
      linkedin_id: nil,
      linkedin_access_token: nil,
      linkedin_refresh_token: nil,
      linkedin_token_expires_at: nil,
      linkedin_profile_url: nil,
      linkedin_headline: nil,
      linkedin_summary: nil,
      linkedin_industry: nil,
      linkedin_location: nil,
      linkedin_connections_count: nil,
      linkedin_profile_picture_url: nil,
      linkedin_last_synced_at: nil
    }

    case Accounts.update_user_linkedin(user, linkedin_attrs) do
      {:ok, updated_user} ->
        Logger.info("Successfully disconnected LinkedIn account for user #{user.id}")
        {:ok, updated_user}

      {:error, changeset} ->
        Logger.error("Failed to disconnect LinkedIn account: #{inspect(changeset.errors)}")
        {:error, :update_failed}
    end
  end

  ## Profile Data Management

  @doc """
  Syncs user's LinkedIn profile data.

  ## Examples

      iex> sync_profile_data(user)
      {:ok, %User{linkedin_headline: "Updated headline", ...}}

  """
  def sync_profile_data(%User{} = user) do
    if User.linkedin_connected?(user) && !User.linkedin_token_expired?(user) do
      case LinkedInClient.get_profile(user.linkedin_access_token) do
        {:ok, profile_data} ->
          # Also fetch additional profile details
          with {:ok, summary_data} <-
                 LinkedInClient.get_profile_summary(user.linkedin_access_token),
               {:ok, connections_count} <-
                 LinkedInClient.get_connections_count(user.linkedin_access_token) do
            linkedin_attrs = %{
              linkedin_headline: profile_data["headline"],
              linkedin_summary: summary_data["summary"],
              linkedin_industry: profile_data["industry"],
              linkedin_location: get_location_string(profile_data),
              linkedin_connections_count: connections_count,
              linkedin_profile_picture_url: get_profile_picture_url(profile_data),
              linkedin_last_synced_at: DateTime.utc_now()
            }

            case Accounts.update_user_linkedin(user, linkedin_attrs) do
              {:ok, updated_user} ->
                Logger.info("Successfully synced LinkedIn profile for user #{user.id}")
                {:ok, updated_user}

              {:error, changeset} ->
                Logger.error(
                  "Failed to update user with synced LinkedIn data: #{inspect(changeset.errors)}"
                )

                {:error, :update_failed}
            end
          else
            {:error, reason} ->
              Logger.warning("Failed to fetch additional LinkedIn data: #{inspect(reason)}")
              # Still update what we have
              basic_attrs = %{
                linkedin_headline: profile_data["headline"],
                linkedin_industry: profile_data["industry"],
                linkedin_location: get_location_string(profile_data),
                linkedin_last_synced_at: DateTime.utc_now()
              }

              Accounts.update_user_linkedin(user, basic_attrs)
          end

        {:error, reason} ->
          Logger.error("Failed to sync LinkedIn profile for user #{user.id}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :not_connected_or_expired}
    end
  end

  @doc """
  Gets fresh LinkedIn profile data without storing it.

  ## Examples

      iex> get_fresh_profile_data(user)
      {:ok, %{headline: "...", summary: "...", connections_count: 500}}

  """
  def get_fresh_profile_data(%User{} = user) do
    if User.linkedin_connected?(user) && !User.linkedin_token_expired?(user) do
      with {:ok, profile_data} <- LinkedInClient.get_profile(user.linkedin_access_token),
           {:ok, summary_data} <- LinkedInClient.get_profile_summary(user.linkedin_access_token),
           {:ok, connections_count} <-
             LinkedInClient.get_connections_count(user.linkedin_access_token) do
        {:ok,
         %{
           headline: profile_data["headline"],
           summary: summary_data["summary"],
           industry: profile_data["industry"],
           location: get_location_string(profile_data),
           connections_count: connections_count,
           profile_picture_url: get_profile_picture_url(profile_data),
           profile_url: build_profile_url(profile_data)
         }}
      else
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :not_connected_or_expired}
    end
  end

  ## Content Publishing

  @doc """
  Publishes content to LinkedIn.

  ## Examples

      iex> publish_content(user, %{text: "Hello LinkedIn!", visibility: "PUBLIC"})
      {:ok, %{post_id: "urn:li:share:123", post_url: "https://linkedin.com/..."}}

  """
  def publish_content(%User{} = user, content_params) do
    if User.linkedin_connected?(user) && !User.linkedin_token_expired?(user) do
      case LinkedInClient.create_post(user.linkedin_access_token, content_params) do
        {:ok, post_data} ->
          post_id = post_data["id"]
          post_url = build_post_url(post_id)

          Logger.info("Successfully published content to LinkedIn for user #{user.id}")
          {:ok, %{post_id: post_id, post_url: post_url}}

        {:error, reason} ->
          Logger.error(
            "Failed to publish content to LinkedIn for user #{user.id}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      {:error, :not_connected_or_expired}
    end
  end

  @doc """
  Gets engagement metrics for a LinkedIn post.

  ## Examples

      iex> get_post_engagement(user, "urn:li:share:123")
      {:ok, %{likes: 10, comments: 5, shares: 2, views: 100}}

  """
  def get_post_engagement(%User{} = user, post_id) do
    if User.linkedin_connected?(user) && !User.linkedin_token_expired?(user) do
      case LinkedInClient.get_post_analytics(user.linkedin_access_token, post_id) do
        {:ok, analytics_data} ->
          engagement = %{
            likes: get_in(analytics_data, ["likes", "totalCount"]) || 0,
            comments: get_in(analytics_data, ["comments", "totalCount"]) || 0,
            shares: get_in(analytics_data, ["shares", "totalCount"]) || 0,
            views: get_in(analytics_data, ["views", "totalCount"]) || 0
          }

          {:ok, engagement}

        {:error, reason} ->
          Logger.error("Failed to get post engagement for user #{user.id}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :not_connected_or_expired}
    end
  end

  ## Token Management

  @doc """
  Refreshes LinkedIn access token if needed.

  ## Examples

      iex> refresh_token_if_needed(user)
      {:ok, %User{linkedin_access_token: "new_token", ...}}

  """
  def refresh_token_if_needed(%User{} = user) do
    if User.linkedin_connected?(user) && User.linkedin_token_expired?(user) do
      if user.linkedin_refresh_token do
        case LinkedInClient.refresh_access_token(user.linkedin_refresh_token) do
          {:ok, token_data} ->
            expires_at = DateTime.utc_now() |> DateTime.add(token_data["expires_in"], :second)

            linkedin_attrs = %{
              linkedin_access_token: token_data["access_token"],
              linkedin_refresh_token: token_data["refresh_token"],
              linkedin_token_expires_at: expires_at
            }

            case Accounts.update_user_linkedin(user, linkedin_attrs) do
              {:ok, updated_user} ->
                Logger.info("Successfully refreshed LinkedIn token for user #{user.id}")
                {:ok, updated_user}

              {:error, changeset} ->
                Logger.error(
                  "Failed to update user with refreshed token: #{inspect(changeset.errors)}"
                )

                {:error, :update_failed}
            end

          {:error, reason} ->
            Logger.error(
              "Failed to refresh LinkedIn token for user #{user.id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
      else
        {:error, :no_refresh_token}
      end
    else
      # No refresh needed
      {:ok, user}
    end
  end

  ## Private Helper Functions

  defp build_profile_url(profile_data) do
    case get_in(profile_data, ["vanityName"]) do
      nil -> "https://www.linkedin.com/in/#{profile_data["id"]}"
      vanity_name -> "https://www.linkedin.com/in/#{vanity_name}"
    end
  end

  defp get_location_string(profile_data) do
    case get_in(profile_data, ["location", "country", "localized", "en_US"]) do
      nil ->
        nil

      country ->
        region = get_in(profile_data, ["location", "region", "localized", "en_US"])
        if region, do: "#{region}, #{country}", else: country
    end
  end

  defp get_profile_picture_url(profile_data) do
    get_in(profile_data, ["profilePicture", "displayImage~", "elements"])
    |> case do
      nil ->
        nil

      elements when is_list(elements) ->
        # Get the largest image
        elements
        |> Enum.max_by(
          fn element ->
            get_in(element, [
              "data",
              "com.linkedin.digitalmedia.mediaartifact.StillImage",
              "storageSize",
              "width"
            ]) || 0
          end,
          fn -> nil end
        )
        |> case do
          nil -> nil
          element -> get_in(element, ["identifiers", Access.at(0), "identifier"])
        end

      _ ->
        nil
    end
  end

  defp build_post_url(post_id) do
    # Extract the numeric ID from the URN
    case Regex.run(~r/urn:li:share:(\d+)/, post_id) do
      [_, numeric_id] -> "https://www.linkedin.com/posts/activity-#{numeric_id}"
      _ -> "https://www.linkedin.com/feed/"
    end
  end

  ## Utility Functions

  @doc """
  Checks if a user needs to reconnect their LinkedIn account.

  ## Examples

      iex> needs_reconnection?(user)
      false

  """
  def needs_reconnection?(%User{} = user) do
    User.linkedin_connected?(user) && User.linkedin_token_expired?(user) &&
      !user.linkedin_refresh_token
  end

  @doc """
  Gets LinkedIn connection status for a user.

  ## Examples

      iex> get_connection_status(user)
      %{connected: true, expired: false, needs_refresh: false}

  """
  def get_connection_status(%User{} = user) do
    %{
      connected: User.linkedin_connected?(user),
      expired: User.linkedin_token_expired?(user),
      needs_refresh: needs_reconnection?(user),
      last_synced: user.linkedin_last_synced_at
    }
  end

  @doc """
  Validates content before publishing to LinkedIn.

  ## Examples

      iex> validate_content(%{text: "Hello world!"})
      :ok

      iex> validate_content(%{text: ""})
      {:error, :empty_content}

  """
  def validate_content(content_params) do
    text = Map.get(content_params, :text, "")

    cond do
      String.trim(text) == "" ->
        {:error, :empty_content}

      String.length(text) > 3000 ->
        {:error, :content_too_long}

      true ->
        :ok
    end
  end
end
