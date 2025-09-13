defmodule LinkedinAi.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias LinkedinAi.Repo

  alias LinkedinAi.Accounts.{User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

  """
  def get_user(id), do: Repo.get(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Enhanced User Management

  @doc """
  Gets a user with preloaded associations.

  ## Examples

      iex> get_user_with_associations!(123)
      %User{subscription: %Subscription{}, generated_contents: [...]}

  """
  def get_user_with_associations!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload([
      :subscription,
      :generated_contents,
      :profile_analyses,
      :content_templates,
      :usage_records
    ])
  end

  @doc """
  Gets a user by LinkedIn ID.

  ## Examples

      iex> get_user_by_linkedin_id("linkedin_123")
      %User{}

      iex> get_user_by_linkedin_id("unknown")
      nil

  """
  def get_user_by_linkedin_id(linkedin_id) when is_binary(linkedin_id) do
    Repo.get_by(User, linkedin_id: linkedin_id)
  end

  @doc """
  Updates user profile information.

  ## Examples

      iex> update_user_profile(user, %{first_name: "John", last_name: "Doe"})
      {:ok, %User{}}

      iex> update_user_profile(user, %{first_name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates user LinkedIn information.

  ## Examples

      iex> update_user_linkedin(user, %{linkedin_id: "123", linkedin_access_token: "token"})
      {:ok, %User{}}

  """
  def update_user_linkedin(%User{} = user, attrs) do
    user
    |> User.linkedin_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates user onboarding progress.

  ## Examples

      iex> update_user_onboarding(user, %{onboarding_step: "profile_setup"})
      {:ok, %User{}}

  """
  def update_user_onboarding(%User{} = user, attrs) do
    user
    |> User.onboarding_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Completes user onboarding.

  ## Examples

      iex> complete_user_onboarding(user)
      {:ok, %User{}}

  """
  def complete_user_onboarding(%User{} = user) do
    user
    |> User.onboarding_changeset(%{onboarding_completed: true, onboarding_step: "completed"})
    |> Repo.update()
  end

  @doc """
  Records user login activity.

  ## Examples

      iex> record_user_login(user)
      {:ok, %User{}}

  """
  def record_user_login(%User{} = user) do
    user
    |> User.login_changeset()
    |> Repo.update()
  end

  @doc """
  Starts user trial period.

  ## Examples

      iex> start_user_trial(user, 14)
      {:ok, %User{}}

  """
  def start_user_trial(%User{} = user, trial_days \\ 14) do
    trial_ends_at = DateTime.utc_now() |> DateTime.add(trial_days, :day)

    user
    |> User.trial_changeset(%{trial_ends_at: trial_ends_at, has_used_trial: true})
    |> Repo.update()
  end

  @doc """
  Ends user trial period.

  ## Examples

      iex> end_user_trial(user)
      {:ok, %User{}}

  """
  def end_user_trial(%User{} = user) do
    user
    |> User.trial_changeset(%{trial_ends_at: nil})
    |> Repo.update()
  end

  ## Admin Functions

  @doc """
  Lists all users with pagination.

  ## Examples

      iex> list_users()
      [%User{}, ...]

      iex> list_users(page: 2, per_page: 10)
      [%User{}, ...]

  """
  def list_users(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    User
    |> order_by([u], desc: u.inserted_at)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
  end

  @doc """
  Searches users by email, name, or company.

  ## Examples

      iex> search_users("john")
      [%User{}, ...]

  """
  def search_users(query) when is_binary(query) do
    search_term = "%#{query}%"

    User
    |> where(
      [u],
      ilike(u.email, ^search_term) or
        ilike(u.first_name, ^search_term) or
        ilike(u.last_name, ^search_term) or
        ilike(u.company, ^search_term)
    )
    |> order_by([u], desc: u.inserted_at)
    |> limit(50)
    |> Repo.all()
  end

  @doc """
  Updates user admin settings.

  ## Examples

      iex> update_user_admin(user, %{role: "admin", account_status: "active"})
      {:ok, %User{}}

  """
  def update_user_admin(%User{} = user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Suspends a user account.

  ## Examples

      iex> suspend_user(user)
      {:ok, %User{}}

  """
  def suspend_user(%User{} = user) do
    update_user_admin(user, %{account_status: "suspended"})
  end

  @doc """
  Activates a user account.

  ## Examples

      iex> activate_user(user)
      {:ok, %User{}}

  """
  def activate_user(%User{} = user) do
    update_user_admin(user, %{account_status: "active"})
  end

  @doc """
  Promotes a user to admin.

  ## Examples

      iex> promote_to_admin(user)
      {:ok, %User{}}

  """
  def promote_to_admin(%User{} = user) do
    update_user_admin(user, %{role: "admin", is_admin: true})
  end

  ## Authorization Helpers

  @doc """
  Checks if a user has admin role.

  ## Examples

      iex> admin?(user)
      true

  """
  def admin?(%User{role: "admin"}), do: true
  def admin?(_), do: false

  @doc """
  Checks if a user can access admin features.

  ## Examples

      iex> can_access_admin?(user)
      true

  """
  def can_access_admin?(%User{} = user) do
    admin?(user) && User.active?(user)
  end

  @doc """
  Gets all admin users.

  ## Examples

      iex> list_admin_users()
      [%User{}, ...]

  """
  def list_admin_users do
    from(u in User, where: u.role == "admin" and u.account_status == "active")
    |> Repo.all()
  end

  @doc """
  Checks if a user can perform an action.

  ## Examples

      iex> can?(user, :manage_users)
      true

      iex> can?(user, :view_admin_panel)
      false

  """
  def can?(%User{} = user, action) do
    case action do
      :manage_users -> User.admin?(user)
      :view_admin_panel -> User.admin?(user)
      :manage_subscriptions -> User.admin?(user)
      :view_analytics -> User.admin?(user)
      :generate_content -> User.active?(user)
      :analyze_profile -> User.active?(user)
      _ -> false
    end
  end

  @doc """
  Gets users count by status.

  ## Examples

      iex> get_users_count_by_status()
      %{active: 100, suspended: 5, banned: 2}

  """
  def get_users_count_by_status do
    User
    |> group_by([u], u.account_status)
    |> select([u], {u.account_status, count(u.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets users count by role.

  ## Examples

      iex> get_users_count_by_role()
      %{user: 95, admin: 5}

  """
  def get_users_count_by_role do
    User
    |> group_by([u], u.role)
    |> select([u], {u.role, count(u.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets recent user registrations.

  ## Examples

      iex> get_recent_registrations(7)
      [%User{}, ...]

  """
  def get_recent_registrations(days \\ 7) do
    since = DateTime.utc_now() |> DateTime.add(-days, :day)

    User
    |> where([u], u.inserted_at >= ^since)
    |> order_by([u], desc: u.inserted_at)
    |> Repo.all()
  end

  ## Changeset Helpers

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user profile changes.

  ## Examples

      iex> change_user_profile(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user LinkedIn changes.

  ## Examples

      iex> change_user_linkedin(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_linkedin(%User{} = user, attrs \\ %{}) do
    User.linkedin_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user onboarding changes.

  ## Examples

      iex> change_user_onboarding(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_onboarding(%User{} = user, attrs \\ %{}) do
    User.onboarding_changeset(user, attrs)
  end

  ## Admin Dashboard Functions

  @doc """
  Counts total number of users.
  """
  def count_users do
    from(u in User, select: count(u.id)) |> Repo.one()
  end

  @doc """
  Counts active users today (users who logged in today).
  """
  def count_active_users_today do
    today = Date.utc_today()

    from(u in User,
      where: fragment("DATE(?)", u.last_login_at) == ^today,
      select: count(u.id)
    )
    |> Repo.one()
  end

  @doc """
  Counts new users registered this week.
  """
  def count_new_users_this_week do
    week_ago = Date.add(Date.utc_today(), -7)

    from(u in User,
      where: fragment("DATE(?)", u.inserted_at) >= ^week_ago,
      select: count(u.id)
    )
    |> Repo.one()
  end

  @doc """
  Lists recent users (limited number).
  """
  def list_recent_users(limit \\ 10) do
    from(u in User,
      order_by: [desc: u.inserted_at],
      limit: ^limit,
      select: [:id, :first_name, :last_name, :email, :inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists users for admin management with search, filters, and pagination.
  """
  def list_users_admin(opts \\ []) do
    search = Keyword.get(opts, :search, "")
    filters = Keyword.get(opts, :filters, %{})
    sort_by = Keyword.get(opts, :sort_by, "inserted_at")
    sort_order = Keyword.get(opts, :sort_order, "desc")
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    query = from(u in User)

    query
    |> apply_admin_search(search)
    |> apply_admin_filters(filters)
    |> apply_admin_sort(sort_by, sort_order)
    |> apply_admin_pagination(page, per_page)
    |> Repo.all()
  end

  @doc """
  Counts users for admin management with search and filters.
  """
  def count_users_admin(opts \\ []) do
    search = Keyword.get(opts, :search, "")
    filters = Keyword.get(opts, :filters, %{})

    query = from(u in User, select: count(u.id))

    query
    |> apply_admin_search(search)
    |> apply_admin_filters(filters)
    |> Repo.one()
  end

  defp apply_admin_search(query, ""), do: query

  defp apply_admin_search(query, search) do
    search_term = "%#{search}%"

    from(u in query,
      where:
        ilike(u.first_name, ^search_term) or
          ilike(u.last_name, ^search_term) or
          ilike(u.email, ^search_term)
    )
  end

  defp apply_admin_filters(query, filters) when map_size(filters) == 0, do: query

  defp apply_admin_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      case key do
        :status -> from(u in acc, where: u.account_status == ^value)
        :role -> from(u in acc, where: u.role == ^value)
        :subscription -> apply_subscription_filter(acc, value)
        _ -> acc
      end
    end)
  end

  defp apply_subscription_filter(query, "active") do
    from(u in query,
      join: s in assoc(u, :subscriptions),
      where: s.status in ["active", "trialing"]
    )
  end

  defp apply_subscription_filter(query, "inactive") do
    from(u in query,
      left_join: s in assoc(u, :subscriptions),
      where: is_nil(s.id) or s.status not in ["active", "trialing"]
    )
  end

  defp apply_subscription_filter(query, _), do: query

  defp apply_admin_sort(query, sort_by, sort_order) do
    order = if sort_order == "desc", do: :desc, else: :asc

    case sort_by do
      "first_name" -> from(u in query, order_by: [{^order, u.first_name}])
      "last_name" -> from(u in query, order_by: [{^order, u.last_name}])
      "email" -> from(u in query, order_by: [{^order, u.email}])
      "account_status" -> from(u in query, order_by: [{^order, u.account_status}])
      "role" -> from(u in query, order_by: [{^order, u.role}])
      "last_login_at" -> from(u in query, order_by: [{^order, u.last_login_at}])
      _ -> from(u in query, order_by: [{^order, u.inserted_at}])
    end
  end

  defp apply_admin_pagination(query, page, per_page) do
    offset = (page - 1) * per_page

    from(u in query,
      limit: ^per_page,
      offset: ^offset
    )
  end

  @doc """
  Counts new users for a specific period.
  """
  def count_new_users_for_period({start_date, end_date}) do
    from(u in User,
      where:
        fragment("DATE(?)", u.inserted_at) >= ^start_date and
          fragment("DATE(?)", u.inserted_at) <= ^end_date,
      select: count(u.id)
    )
    |> Repo.one()
  end

  ## Analytics Processing Functions

  @doc """
  Counts new users for a specific date.
  """
  def count_new_users_for_date(date) do
    from(u in User,
      where: fragment("DATE(?)", u.inserted_at) == ^date,
      select: count(u.id)
    )
    |> Repo.one()
  end

  @doc """
  Counts active users for a specific date.
  """
  def count_active_users_for_date(date) do
    from(u in User,
      where: fragment("DATE(?)", u.last_login_at) == ^date,
      select: count(u.id)
    )
    |> Repo.one()
  end

  @doc """
  Lists active users for a specific date.
  """
  def list_active_users_for_date(date) do
    from(u in User,
      where:
        fragment("DATE(?)", u.last_login_at) == ^date or
          fragment("DATE(?)", u.updated_at) == ^date,
      select: u
    )
    |> Repo.all()
  end
end
