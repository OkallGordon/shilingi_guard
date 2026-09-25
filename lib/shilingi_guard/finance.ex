defmodule ShilingiGuard.Finance do
  @moduledoc """
  The Finance context.

  This module is responsible for managing the user's
  financial data and business rules.
  """

  import Ecto.Query, warn: false

  alias ShilingiGuard.Finance.Allocation
  alias ShilingiGuard.Finance.Income
  alias ShilingiGuard.Repo

  # --------------------
  # Income
  # --------------------

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

  @doc """
  Returns a changeset for tracking income changes.
  """
  def change_income(%Income{} = income, attrs \\ %{}) do
    Income.changeset(income, attrs)
  end

  # --------------------
  # Allocations
  # --------------------

  @doc """
  Returns all allocations belonging to the given user.
  """
  def list_allocations(user) do
    Allocation
    |> where([allocation], allocation.user_id == ^user.id)
    |> Repo.all()
  end

  @doc """
  Gets a single allocation belonging to the given user.
  """
  def get_allocation!(user, id) do
    Allocation
    |> where([allocation], allocation.user_id == ^user.id)
    |> Repo.get!(id)
  end

  @doc """
  Creates a new allocation for the given user.
  """
  def create_allocation(user, attrs \\ %{}) do
    %Allocation{}
    |> Allocation.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  @doc """
  Updates an allocation belonging to the given user.
  """
  def update_allocation(user, %Allocation{} = allocation, attrs) do
    true = allocation.user_id == user.id

    allocation
    |> Allocation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an allocation belonging to the given user.
  """
  def delete_allocation(user, %Allocation{} = allocation) do
    true = allocation.user_id == user.id

    Repo.delete(allocation)
  end

  @doc """
  Returns a changeset for tracking allocation changes.
  """
  def change_allocation(%Allocation{} = allocation, attrs \\ %{}) do
    Allocation.changeset(allocation, attrs)
  end
end
