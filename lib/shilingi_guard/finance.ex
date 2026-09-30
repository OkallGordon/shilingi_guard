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
  alias ShilingiGuard.Finance.Transaction

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

  # --------------------
  # Transactions
  # --------------------

  @doc """
  Returns all transactions belonging to the user in the given scope.
  """
  def list_transactions(%Scope{user: user}) do
    Transaction
    |> where([transaction], transaction.user_id == ^user.id)
    |> Repo.all()
    |> Repo.preload([:user, :allocation])
  end

  @doc """
  Gets a single transaction belonging to the user in the given scope.
  """
  def get_transaction!(%Scope{user: user}, id) do
    Transaction
    |> where([transaction], transaction.user_id == ^user.id)
    |> Repo.get!(id)
    |> Repo.preload([:user, :allocation])
  end

  @doc """
  Creates a transaction for the user in the given scope.
  """
  def create_transaction(%Scope{user: user} = scope, attrs \\ %{}) do
    allocation_id = Map.get(attrs, "allocation_id") || Map.get(attrs, :allocation_id)

    allocation =
      Allocation
      |> where([allocation], allocation.id == ^allocation_id and allocation.user_id == ^user.id)
      |> Repo.one!()

    changeset =
      %Transaction{}
      |> Transaction.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Ecto.Changeset.put_assoc(:allocation, allocation)

    if changeset.valid? do
      transaction = Ecto.Changeset.apply_changes(changeset)

      spending_rules =
        SpendingRule
        |> where(
          [rule],
          rule.allocation_id == ^allocation.id and
            rule.user_id == ^user.id
        )
        |> Repo.all()

      case spending_rules do
        [] ->
          Ecto.Changeset.add_error(
            changeset,
            :amount,
            "allocation has no spending rule"
          )
          |> then(&{:error, &1})

        rules ->
          case check_spending_rules(scope, transaction, rules) do
            :ok ->
              Repo.insert(changeset)

            {:error, message} ->
              Ecto.Changeset.add_error(changeset, :amount, message)
              |> then(&{:error, &1})
          end
      end
    else
      {:error, changeset}
    end
  end

 defp check_spending_rules(
       %Scope{user: user} = scope,
       transaction,
       rules
     ) do
  Enum.reduce_while(rules, :ok, fn rule, :ok ->
    {period_start, period_end} =
      period_bounds(
        transaction.occurred_at,
        rule.period,
        user.timezone
      )

    remaining =
      remaining_allowance(
        scope,
        rule,
        period_start,
        period_end
      )

    if Decimal.compare(transaction.amount, remaining) in [:lt, :eq] do
      {:cont, :ok}
    else
      {:halt, {:error, "transaction exceeds the spending limit"}}
    end
  end)
end
  defp period_bounds(
       %DateTime{} = occurred_at,
       "daily",
       timezone
     ) do
  local_datetime = DateTime.shift_zone!(occurred_at, timezone)
  local_date = DateTime.to_date(local_datetime)

  period_start =
    DateTime.new!(
      local_date,
      ~T[00:00:00],
      timezone
    )

  period_end =
    DateTime.add(period_start, 1, :day)

  {
    DateTime.shift_zone!(period_start, "Etc/UTC"),
    DateTime.shift_zone!(period_end, "Etc/UTC")
  }
end

defp period_bounds(
       %DateTime{} = occurred_at,
       "weekly",
       timezone
     ) do
  local_datetime = DateTime.shift_zone!(occurred_at, timezone)
  local_date = DateTime.to_date(local_datetime)

  days_from_monday = Date.day_of_week(local_date) - 1
  monday = Date.add(local_date, -days_from_monday)
  next_monday = Date.add(monday, 7)

  period_start =
    DateTime.new!(
      monday,
      ~T[00:00:00],
      timezone
    )

  period_end =
    DateTime.new!(
      next_monday,
      ~T[00:00:00],
      timezone
    )

  {
    DateTime.shift_zone!(period_start, "Etc/UTC"),
    DateTime.shift_zone!(period_end, "Etc/UTC")
  }
end

defp period_bounds(
       %DateTime{} = occurred_at,
       "monthly",
       timezone
     ) do
  local_datetime = DateTime.shift_zone!(occurred_at, timezone)
  local_date = DateTime.to_date(local_datetime)

  first_day =
    Date.new!(
      local_date.year,
      local_date.month,
      1
    )

  next_month =
    if local_date.month == 12 do
      Date.new!(local_date.year + 1, 1, 1)
    else
      Date.new!(local_date.year, local_date.month + 1, 1)
    end

  period_start =
    DateTime.new!(
      first_day,
      ~T[00:00:00],
      timezone
    )

  period_end =
    DateTime.new!(
      next_month,
      ~T[00:00:00],
      timezone
    )

  {
    DateTime.shift_zone!(period_start, "Etc/UTC"),
    DateTime.shift_zone!(period_end, "Etc/UTC")
  }
 end

  @doc """
  Updates a transaction belonging to the user in the given scope.
  """
  def update_transaction(
        %Scope{user: user},
        %Transaction{} = transaction,
        attrs
      ) do
    true = transaction.user_id == user.id

    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a transaction belonging to the user in the given scope.
  """
  def delete_transaction(
        %Scope{user: user},
        %Transaction{} = transaction
      ) do
    true = transaction.user_id == user.id

    Repo.delete(transaction)
  end

  @doc """
  Returns a changeset for tracking transaction changes.
  """
  def change_transaction(
        %Scope{user: _user},
        %Transaction{} = transaction,
        attrs \\ %{}
      ) do
    Transaction.changeset(transaction, attrs)
  end

  # Spending calculations
  def spent_in_period(
        %Scope{user: user},
        allocation_id,
        %DateTime{} = period_start,
        %DateTime{} = period_end
      ) do
    Transaction
    |> where([transaction], transaction.user_id == ^user.id)
    |> where([transaction], transaction.allocation_id == ^allocation_id)
    |> where(
      [transaction],
      transaction.occurred_at >= ^period_start and
        transaction.occurred_at < ^period_end
    )
    |> select([transaction], sum(transaction.amount))
    |> Repo.one()
    |> case do
      nil -> Decimal.new("0")
      amount -> amount
    end
  end

  def remaining_allowance(
        %Scope{} = scope,
        %SpendingRule{limit_amount: limit_amount, allocation_id: allocation_id},
        %DateTime{} = period_start,
        %DateTime{} = period_end
      ) do
    spent = spent_in_period(scope, allocation_id, period_start, period_end)

    Decimal.max(
      Decimal.sub(limit_amount, spent),
      Decimal.new("0")
    )
  end
end
