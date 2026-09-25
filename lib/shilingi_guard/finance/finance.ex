defmodule ShilingiGuard.Finance do
  @moduledoc """
  The Finance context.

  This module is responsible for managing the user's
  financial data and business rules.
  """

  import Ecto.Query, warn: false

  alias ShilingiGuard.Finance.Income
  alias ShilingiGuard.Repo

  @doc """
  Returns all incomes belonging to the given user.
  """
  def list_incomes(user) do
    Income
    |> where([income], income.user_id == ^user.id)
    |> Repo.all()
  end

  @doc """
  Creates a new income record for the given user.
  """
  def create_income(user, attrs \\ %{}) do
    %Income{}
    |> Income.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end
end
