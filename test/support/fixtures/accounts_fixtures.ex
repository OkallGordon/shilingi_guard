defmodule ShilingiGuard.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ShilingiGuard.Accounts` context.
  """

  import Ecto.Query

  alias ShilingiGuard.Accounts
  alias ShilingiGuard.Accounts.Scope
  alias ShilingiGuard.Accounts.User
  alias ShilingiGuard.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      full_name: "Test User",
      email: unique_user_email(),
      phone_number: "0712345678",
      password: valid_user_password(),
      password_confirmation: valid_user_password()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        full_name: "Test User",
        email: unique_user_email(),
        phone_number: "0712345678"
      })

    {:ok, user} =
      %User{}
      |> User.registration_changeset(attrs)
      |> Repo.insert()

    user
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    {:ok, user} =
      user
      |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now(:second))
      |> Repo.update()

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
