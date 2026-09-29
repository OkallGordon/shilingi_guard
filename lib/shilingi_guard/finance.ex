defmodule ShilingiGuard.Finance do
  @moduledoc """
  The Finance context.

  This module is responsible for managing the user's
  financial data and business rules.
  """

  import Ecto.Query, warn: false

  alias ShilingiGuard.Accounts.Scope
  alias ShilingiGuard.Finance.Allocation
  alias ShilingiGuard.Finance.Income
  alias ShilingiGuard.Finance.SpendingRule
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
  Returns all allocations belonging to the user in the given scope.
  """
  def list_allocations(%Scope{user: user}) do
    Allocation
    |> where([allocation], allocation.user_id == ^user.id)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Gets a single allocation belonging to the user in the given scope.
  """
  def get_allocation!(%Scope{user: user}, id) do
    Allocation
    |> where([allocation], allocation.user_id == ^user.id)
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  @doc """
  Creates a new allocation for the user in the given scope.
  """
  def create_allocation(%Scope{user: user}, attrs \\ %{}) do
    %Allocation{}
    |> Allocation.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  @doc """
  Updates an allocation belonging to the user in the given scope.
  """
  def update_allocation(
        %Scope{user: user},
        %Allocation{} = allocation,
        attrs
      ) do
    true = allocation.user_id == user.id

    allocation
    |> Allocation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an allocation belonging to the user in the given scope.
  """
  def delete_allocation(
        %Scope{user: user},
        %Allocation{} = allocation
      ) do
    true = allocation.user_id == user.id

    Repo.delete(allocation)
  end

  @doc """
  Returns a changeset for tracking allocation changes.
  """
  def change_allocation(
        %Scope{user: _user},
        %Allocation{} = allocation,
        attrs \\ %{}
      ) do
    Allocation.changeset(allocation, attrs)
  end

  # --------------------
  # Spending Rules
  # --------------------

  @doc """
  Returns all spending rules belonging to the user in the given scope.
  """
  def list_spending_rules(%Scope{user: user}) do
    SpendingRule
    |> where([rule], rule.user_id == ^user.id)
    |> Repo.all()
    |> Repo.preload([:user, :allocation])
  end

  @doc """
  Gets a single spending rule belonging to the user in the given scope.
  """
  def get_spending_rule!(%Scope{user: user}, id) do
    SpendingRule
    |> where([rule], rule.user_id == ^user.id)
    |> Repo.get!(id)
    |> Repo.preload([:user, :allocation])
  end

  @doc """
  Creates a spending rule for the user in the given scope.
  """

def create_spending_rule(%Scope{user: user}, attrs \\ %{}) do
  allocation_id = Map.get(attrs, "allocation_id") || Map.get(attrs, :allocation_id)

  allocation =
    Allocation
    |> where([allocation], allocation.id == ^allocation_id and allocation.user_id == ^user.id)
    |> Repo.one!()

  %SpendingRule{}
  |> SpendingRule.changeset(attrs)
  |> Ecto.Changeset.put_assoc(:user, user)
  |> Ecto.Changeset.put_assoc(:allocation, allocation)
  |> Repo.insert()
end

  @doc """
  Updates a spending rule belonging to the user in the given scope.
  """
  def update_spending_rule(
        %Scope{user: user},
        %SpendingRule{} = spending_rule,
        attrs
      ) do
    true = spending_rule.user_id == user.id

    spending_rule
    |> SpendingRule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a spending rule belonging to the user in the given scope.
  """
  def delete_spending_rule(
        %Scope{user: user},
        %SpendingRule{} = spending_rule
      ) do
    true = spending_rule.user_id == user.id

    Repo.delete(spending_rule)
  end

  @doc """
  Returns a changeset for tracking spending rule changes.
  """
  def change_spending_rule(
        %Scope{user: _user},
        %SpendingRule{} = spending_rule,
        attrs \\ %{}
      ) do
    SpendingRule.changeset(spending_rule, attrs)
      end
end
