defmodule LinkedinAi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime

    # LinkedIn integration fields
    field :linkedin_id, :string
    field :linkedin_access_token, :string, redact: true
    field :linkedin_refresh_token, :string, redact: true
    field :linkedin_token_expires_at, :utc_datetime
    field :linkedin_profile_url, :string
    field :linkedin_headline, :string
    field :linkedin_summary, :string
    field :linkedin_industry, :string
    field :linkedin_location, :string
    field :linkedin_connections_count, :integer
    field :linkedin_profile_picture_url, :string
    field :linkedin_last_synced_at, :utc_datetime

    # User profile fields
    field :first_name, :string
    field :last_name, :string
    field :company, :string
    field :job_title, :string
    field :phone, :string
    field :timezone, :string, default: "UTC"

    # Role and permissions
    field :role, :string, default: "user"
    field :is_admin, :boolean, default: false

    # Onboarding and preferences
    field :onboarding_completed, :boolean, default: false
    field :onboarding_step, :string, default: "welcome"
    field :email_notifications, :boolean, default: true
    field :marketing_emails, :boolean, default: false

    # Account status
    field :account_status, :string, default: "active"
    field :last_login_at, :utc_datetime
    field :login_count, :integer, default: 0

    # Subscription trial tracking
    field :trial_ends_at, :utc_datetime
    field :has_used_trial, :boolean, default: false

    # Associations (will be enabled once schemas are created)
    # has_one :subscription, LinkedinAi.Subscriptions.Subscription
    # has_many :generated_contents, LinkedinAi.ContentGeneration.GeneratedContent
    # has_many :profile_analyses, LinkedinAi.ProfileOptimization.ProfileAnalysis
    # has_many :content_templates, LinkedinAi.ContentGeneration.ContentTemplate
    # has_many :usage_records, LinkedinAi.Subscriptions.UsageRecord

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    # Examples of additional password validation:
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, LinkedinAi.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%LinkedinAi.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  @doc """
  A user changeset for updating profile information.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :first_name, :last_name, :company, :job_title, :phone, :timezone,
      :email_notifications, :marketing_emails
    ])
    |> validate_length(:first_name, max: 100)
    |> validate_length(:last_name, max: 100)
    |> validate_length(:company, max: 200)
    |> validate_length(:job_title, max: 200)
    |> validate_format(:phone, ~r/^[\+]?[1-9][\d]{0,15}$/, message: "must be a valid phone number")
    |> validate_inclusion(:timezone, Timex.timezones())
  end

  @doc """
  A user changeset for LinkedIn integration.
  """
  def linkedin_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :linkedin_id, :linkedin_access_token, :linkedin_refresh_token,
      :linkedin_token_expires_at, :linkedin_profile_url, :linkedin_headline,
      :linkedin_summary, :linkedin_industry, :linkedin_location,
      :linkedin_connections_count, :linkedin_profile_picture_url,
      :linkedin_last_synced_at
    ])
    |> validate_required([:linkedin_id])
    |> unique_constraint(:linkedin_id)
    |> validate_length(:linkedin_headline, max: 220)
    |> validate_length(:linkedin_summary, max: 2600)
    |> validate_number(:linkedin_connections_count, greater_than_or_equal_to: 0)
  end

  @doc """
  A user changeset for onboarding progress.
  """
  def onboarding_changeset(user, attrs) do
    user
    |> cast(attrs, [:onboarding_completed, :onboarding_step])
    |> validate_inclusion(:onboarding_step, [
      "welcome", "profile_setup", "linkedin_connect", "subscription_select", "completed"
    ])
  end

  @doc """
  A user changeset for admin operations.
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:role, :is_admin, :account_status])
    |> validate_inclusion(:role, ["user", "admin", "moderator"])
    |> validate_inclusion(:account_status, ["active", "suspended", "banned", "pending"])
  end

  @doc """
  A user changeset for tracking login activity.
  """
  def login_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    user
    |> change(
      last_login_at: now,
      login_count: (user.login_count || 0) + 1
    )
  end

  @doc """
  A user changeset for trial management.
  """
  def trial_changeset(user, attrs) do
    user
    |> cast(attrs, [:trial_ends_at, :has_used_trial])
    |> validate_change(:trial_ends_at, fn :trial_ends_at, trial_ends_at ->
      if DateTime.compare(trial_ends_at, DateTime.utc_now()) == :lt do
        [trial_ends_at: "cannot be in the past"]
      else
        []
      end
    end)
  end

  @doc """
  Returns the user's full name or email if name is not available.
  """
  def display_name(%__MODULE__{first_name: first_name, last_name: last_name, email: email}) do
    case {first_name, last_name} do
      {nil, nil} -> email
      {first, nil} -> first
      {nil, last} -> last
      {first, last} -> "#{first} #{last}"
    end
  end

  @doc """
  Checks if the user has admin privileges.
  """
  def admin?(%__MODULE__{is_admin: true}), do: true
  def admin?(%__MODULE__{role: "admin"}), do: true
  def admin?(_), do: false

  @doc """
  Checks if the user's account is active.
  """
  def active?(%__MODULE__{account_status: "active"}), do: true
  def active?(_), do: false

  @doc """
  Checks if the user has completed onboarding.
  """
  def onboarding_complete?(%__MODULE__{onboarding_completed: true}), do: true
  def onboarding_complete?(_), do: false

  @doc """
  Checks if the user has LinkedIn connected.
  """
  def linkedin_connected?(%__MODULE__{linkedin_id: linkedin_id}) when is_binary(linkedin_id), do: true
  def linkedin_connected?(_), do: false

  @doc """
  Checks if the user's LinkedIn token is expired.
  """
  def linkedin_token_expired?(%__MODULE__{linkedin_token_expires_at: nil}), do: true
  def linkedin_token_expired?(%__MODULE__{linkedin_token_expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Checks if the user is in trial period.
  """
  def in_trial?(%__MODULE__{trial_ends_at: nil}), do: false
  def in_trial?(%__MODULE__{trial_ends_at: trial_ends_at}) do
    DateTime.compare(trial_ends_at, DateTime.utc_now()) == :gt
  end
end
