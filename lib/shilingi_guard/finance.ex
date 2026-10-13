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
  alias ShilingiGuard.Finance.Budget

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
    |> Repo.preload(:budget)
  end

  @doc """
  Creates a new income record for the given user.

  Income assigned to a budget is inserted while holding a lock on
  that budget, coordinating with budget allocation checks.
  """
  def create_income(user, attrs \\ %{}) do
    changeset =
      %Income{}
      |> Income.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:user, user)

    budget_id = Ecto.Changeset.get_field(changeset, :budget_id)

    cond do
      not changeset.valid? ->
        {:error, changeset}

      is_nil(budget_id) ->
        Repo.insert(changeset)

      true ->
        Repo.transaction(fn ->
          budget =
            Budget
            |> where([budget], budget.id == ^budget_id and budget.user_id == ^user.id)
            |> lock("FOR UPDATE")
            |> Repo.one()

          if is_nil(budget) do
            Repo.rollback(
              Ecto.Changeset.add_error(
                changeset,
                :budget_id,
                "budget does not belong to this user"
              )
            )
          end

          changeset
          |> Ecto.Changeset.put_assoc(:budget, budget)
          |> Repo.insert()
          |> case do
            {:ok, income} -> income
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
        |> case do
          {:ok, income} -> {:ok, income}
          {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
        end
    end
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

  When a budget is selected, the budget row is locked inside a
  transaction before calculating totals and inserting the allocation.
  """
  def create_allocation(%Scope{user: user}, attrs \\ %{}) do
    budget_id = Map.get(attrs, "budget_id") || Map.get(attrs, :budget_id)

    changeset =
      %Allocation{}
      |> Allocation.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:user, user)

    cond do
      not changeset.valid? ->
        {:error, changeset}

      is_nil(budget_id) ->
        Repo.insert(changeset)

      true ->
        Repo.transaction(fn ->
          budget =
            Budget
            |> where([budget], budget.id == ^budget_id and budget.user_id == ^user.id)
            |> lock("FOR UPDATE")
            |> Repo.one()

          if is_nil(budget) do
            Repo.rollback(
              Ecto.Changeset.add_error(
                changeset,
                :budget_id,
                "budget does not belong to this user"
              )
            )
          end

          total_income =
            Income
            |> where(
              [income],
              income.user_id == ^user.id and income.budget_id == ^budget.id
            )
            |> select(
              [income],
              coalesce(sum(income.amount), ^Decimal.new("0"))
            )
            |> Repo.one()

          total_allocations =
            Allocation
            |> where(
              [allocation],
              allocation.user_id == ^user.id and
                allocation.budget_id == ^budget.id
            )
            |> select(
              [allocation],
              coalesce(sum(allocation.amount), ^Decimal.new("0"))
            )
            |> Repo.one()

          new_amount = Ecto.Changeset.get_field(changeset, :amount)
          total_after_allocation = Decimal.add(total_allocations, new_amount)

          if Decimal.compare(total_after_allocation, total_income) == :gt do
            Repo.rollback(
              Ecto.Changeset.add_error(
                changeset,
                :amount,
                "total allocations cannot exceed total income"
              )
            )
          end

          changeset
          |> Ecto.Changeset.put_assoc(:budget, budget)
          |> Repo.insert()
          |> case do
            {:ok, allocation} -> allocation
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
        |> case do
          {:ok, allocation} -> {:ok, allocation}
          {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Updates an allocation belonging to the user in the given scope.

  Budgeted allocations are updated under a budget row lock so the
  income ceiling is checked against current totals.
  """
  def update_allocation(%Scope{user: user}, %Allocation{} = allocation, attrs) do
    true = allocation.user_id == user.id

    changeset = Allocation.changeset(allocation, attrs)

    cond do
      not changeset.valid? ->
        {:error, changeset}

      is_nil(allocation.budget_id) ->
        Repo.update(changeset)

      true ->
        Repo.transaction(fn ->
          budget =
            Budget
            |> where(
              [budget],
              budget.id == ^allocation.budget_id and budget.user_id == ^user.id
            )
            |> lock("FOR UPDATE")
            |> Repo.one()

          if is_nil(budget) do
            Repo.rollback(
              Ecto.Changeset.add_error(
                changeset,
                :budget_id,
                "budget does not belong to this user"
              )
            )
          end

          total_income =
            Income
            |> where(
              [income],
              income.user_id == ^user.id and income.budget_id == ^budget.id
            )
            |> select(
              [income],
              coalesce(sum(income.amount), ^Decimal.new("0"))
            )
            |> Repo.one()

          other_allocations =
            Allocation
            |> where(
              [item],
              item.user_id == ^user.id and
                item.budget_id == ^budget.id and
                item.id != ^allocation.id
            )
            |> select(
              [item],
              coalesce(sum(item.amount), ^Decimal.new("0"))
            )
            |> Repo.one()

          new_amount = Ecto.Changeset.get_field(changeset, :amount)
          total_after_update = Decimal.add(other_allocations, new_amount)

          if Decimal.compare(total_after_update, total_income) == :gt do
            Repo.rollback(
              Ecto.Changeset.add_error(
                changeset,
                :amount,
                "total allocations cannot exceed total income"
              )
            )
          end

          case Repo.update(changeset) do
            {:ok, updated_allocation} -> updated_allocation
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
        |> case do
          {:ok, updated_allocation} -> {:ok, updated_allocation}
          {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
        end
    end
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

    if allocation.type == "protected" do
      changeset =
        Ecto.Changeset.add_error(
          changeset,
          :allocation_id,
          "protected allocations cannot be spent"
        )

      {:error, changeset}
    else
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

  # Budgets

  @doc """
  Calculates the income, allocated amount, and unallocated amount
  for a budget owned by the current user.
  """
  def budget_summary(%Scope{user: user}, %Budget{} = budget) do
    if budget.user_id != user.id do
      raise Ecto.NoResultsError, queryable: Budget
    end

    total_income =
      Income
      |> where(
        [income],
        income.user_id == ^user.id and income.budget_id == ^budget.id
      )
      |> select(
        [income],
        coalesce(sum(income.amount), ^Decimal.new("0"))
      )
      |> Repo.one()

    total_allocated =
      Allocation
      |> where(
        [allocation],
        allocation.user_id == ^user.id and allocation.budget_id == ^budget.id
      )
      |> select(
        [allocation],
        coalesce(sum(allocation.amount), ^Decimal.new("0"))
      )
      |> Repo.one()

    %{
      total_income: total_income,
      total_allocated: total_allocated,
      unallocated: Decimal.sub(total_income, total_allocated)
    }
  end

  def list_budgets(%Scope{user: user}) do
    Budget
    |> where([budget], budget.user_id == ^user.id)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def get_budget!(%Scope{user: user}, id) do
    Budget
    |> where([budget], budget.user_id == ^user.id)
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  def create_budget(%Scope{user: user}, attrs \\ %{}) do
    %Budget{}
    |> Budget.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  def update_budget(%Scope{user: user}, %Budget{} = budget, attrs) do
    true = budget.user_id == user.id
    budget |> Budget.changeset(attrs) |> Repo.update()
  end

  def delete_budget(%Scope{user: user}, %Budget{} = budget) do
    true = budget.user_id == user.id
    Repo.delete(budget)
  end

  def change_budget(%Scope{user: _user}, %Budget{} = budget, attrs \\ %{}) do
    Budget.changeset(budget, attrs)
  end
end
