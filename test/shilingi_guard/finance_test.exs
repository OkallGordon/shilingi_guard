defmodule ShilingiGuard.FinanceTest do
  use ShilingiGuard.DataCase

  import ShilingiGuard.FinanceFixtures
  import ShilingiGuard.AccountsFixtures

  alias ShilingiGuard.AccountsFixtures
  alias ShilingiGuard.FinanceFixtures
  alias ShilingiGuard.Finance
  alias ShilingiGuard.Repo

  describe "incomes" do
    test "list_incomes/1 returns incomes belonging to the user" do
      user = AccountsFixtures.user_fixture()

      assert Finance.list_incomes(user) == []
    end

    test "create_income/2 creates an income for the user" do
      user = AccountsFixtures.user_fixture()

      attrs = %{
        amount: "30000.00",
        source: "Salary",
        received_on: ~D[2026-09-25]
      }

      assert {:ok, income} = Finance.create_income(user, attrs)

      assert income.amount == Decimal.new("30000.00")
      assert income.source == "Salary"
      assert income.received_on == ~D[2026-09-25]
      assert income.user_id == user.id
    end

    test "list_incomes/1 only returns incomes belonging to the given user" do
      user_one = AccountsFixtures.user_fixture()
      user_two = AccountsFixtures.user_fixture()

      attrs = %{
        amount: "30000.00",
        source: "Salary",
        received_on: ~D[2026-09-25]
      }

      assert {:ok, income} = Finance.create_income(user_one, attrs)

      incomes_for_user_one = Finance.list_incomes(user_one)
      incomes_for_user_two = Finance.list_incomes(user_two)

      assert length(incomes_for_user_one) == 1
      assert hd(incomes_for_user_one).id == income.id
      assert hd(incomes_for_user_one).user_id == user_one.id

      assert incomes_for_user_two == []
    end

    test "does not allow income to be attached to another user's budget" do
      user = AccountsFixtures.user_fixture()
      scope = ShilingiGuard.Accounts.Scope.for_user(user)

      other_user = AccountsFixtures.user_fixture()
      other_scope = ShilingiGuard.Accounts.Scope.for_user(other_user)

      assert {:ok, other_budget} =
               Finance.create_budget(other_scope, %{
                 name: "Other User Budget",
                 starts_on: ~D[2026-09-01],
                 ends_on: ~D[2026-09-30],
                 status: "active"
               })

      assert {:error, changeset} =
               Finance.create_income(scope.user, %{
                 amount: "1000.00",
                 source: "Salary",
                 received_on: ~D[2026-09-30],
                 budget_id: other_budget.id
               })

      assert "budget does not belong to this user" in errors_on(changeset).budget_id
    end
  end

  describe "allocations" do
    alias ShilingiGuard.Finance.Allocation

    import ShilingiGuard.AccountsFixtures, only: [user_scope_fixture: 0]
    import ShilingiGuard.FinanceFixtures

    @invalid_attrs %{name: nil, type: nil, amount: nil}

    test "list_allocations/1 returns all scoped allocations" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()

      allocation = allocation_fixture(scope)
      other_allocation = allocation_fixture(other_scope)

      assert Finance.list_allocations(scope) == [allocation]
      assert Finance.list_allocations(other_scope) == [other_allocation]
    end

    test "get_allocation!/2 returns the allocation with given id" do
      scope = user_scope_fixture()
      allocation = allocation_fixture(scope)
      other_scope = user_scope_fixture()

      assert Finance.get_allocation!(scope, allocation.id) == allocation

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_allocation!(other_scope, allocation.id)
      end
    end

    test "create_allocation/2 with valid data creates a allocation" do
      valid_attrs = %{
        name: "some name",
        type: "spending",
        amount: "120.5"
      }

      scope = user_scope_fixture()

      assert {:ok, %Allocation{} = allocation} =
               Finance.create_allocation(scope, valid_attrs)

      assert allocation.name == "some name"
      assert allocation.type == "spending"
      assert allocation.amount == Decimal.new("120.5")
      assert allocation.user_id == scope.user.id
    end

    test "create_allocation/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Finance.create_allocation(scope, @invalid_attrs)
    end

    test "update_allocation/3 with valid data updates the allocation" do
      scope = user_scope_fixture()
      allocation = allocation_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        type: "protected",
        amount: "456.7"
      }

      assert {:ok, %Allocation{} = allocation} =
               Finance.update_allocation(scope, allocation, update_attrs)

      assert allocation.name == "some updated name"
      assert allocation.type == "protected"
      assert allocation.amount == Decimal.new("456.7")
    end

    test "does not allow total allocations to exceed total income in a budget" do
      scope = user_scope_fixture()

      assert {:ok, budget} =
               Finance.create_budget(scope, %{
                 name: "September 2026",
                 starts_on: ~D[2026-09-01],
                 ends_on: ~D[2026-09-30],
                 status: "active"
               })

      assert {:ok, _income} =
               Finance.create_income(scope.user, %{
                 amount: "1000.00",
                 source: "Salary",
                 received_on: ~D[2026-09-30],
                 budget_id: budget.id
               })

      assert {:ok, _first_allocation} =
               Finance.create_allocation(scope, %{
                 name: "Food",
                 type: "spending",
                 amount: "700.00",
                 budget_id: budget.id
               })

      assert {:error, changeset} =
               Finance.create_allocation(scope, %{
                 name: "Transport",
                 type: "spending",
                 amount: "400.00",
                 budget_id: budget.id
               })

      assert "total allocations cannot exceed total income" in errors_on(changeset).amount
    end

    test "update_allocation/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      allocation = allocation_fixture(scope)

      assert_raise MatchError, fn ->
        Finance.update_allocation(other_scope, allocation, %{})
      end
    end

    test "update_allocation/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      allocation = allocation_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Finance.update_allocation(scope, allocation, @invalid_attrs)

      assert allocation == Finance.get_allocation!(scope, allocation.id)
    end

    test "delete_allocation/2 deletes the allocation" do
      scope = user_scope_fixture()
      allocation = allocation_fixture(scope)

      assert {:ok, %Allocation{}} =
               Finance.delete_allocation(scope, allocation)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_allocation!(scope, allocation.id)
      end
    end

    test "delete_allocation/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      allocation = allocation_fixture(scope)

      assert_raise MatchError, fn ->
        Finance.delete_allocation(other_scope, allocation)
      end
    end

    test "change_allocation/2 returns a allocation changeset" do
      scope = user_scope_fixture()
      allocation = allocation_fixture(scope)

      assert %Ecto.Changeset{} =
               Finance.change_allocation(scope, allocation)
    end

    test "does not allow an allocation to be attached to another user's budget" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()

      assert {:ok, other_budget} =
               Finance.create_budget(other_scope, %{
                 name: "Other User Budget",
                 starts_on: ~D[2026-09-01],
                 ends_on: ~D[2026-09-30],
                 status: "active"
               })

      assert {:error, changeset} =
               Finance.create_allocation(scope, %{
                 name: "Food",
                 type: "spending",
                 amount: "500.00",
                 budget_id: other_budget.id
               })

      assert "budget does not belong to this user" in errors_on(changeset).budget_id
    end

    test "does not allow updating an allocation to exceed total income in a budget" do
      scope = user_scope_fixture()

      assert {:ok, budget} =
               Finance.create_budget(scope, %{
                 name: "September 2026",
                 starts_on: ~D[2026-09-01],
                 ends_on: ~D[2026-09-30],
                 status: "active"
               })

      assert {:ok, _income} =
               Finance.create_income(scope.user, %{
                 amount: "1000.00",
                 source: "Salary",
                 received_on: ~D[2026-09-30],
                 budget_id: budget.id
               })

      assert {:ok, food} =
               Finance.create_allocation(scope, %{
                 name: "Food",
                 type: "spending",
                 amount: "600.00",
                 budget_id: budget.id
               })

      assert {:ok, _transport} =
               Finance.create_allocation(scope, %{
                 name: "Transport",
                 type: "spending",
                 amount: "300.00",
                 budget_id: budget.id
               })

      assert {:error, changeset} =
               Finance.update_allocation(scope, food, %{
                 amount: "800.00"
               })

      assert "total allocations cannot exceed total income" in errors_on(changeset).amount
    end

    test "allows total allocations to equal total income in a budget" do
      scope = user_scope_fixture()

      assert {:ok, budget} =
               Finance.create_budget(scope, %{
                 name: "September 2026",
                 starts_on: ~D[2026-09-01],
                 ends_on: ~D[2026-09-30],
                 status: "active"
               })

      assert {:ok, _income} =
               Finance.create_income(scope.user, %{
                 amount: "1000.00",
                 source: "Salary",
                 received_on: ~D[2026-09-30],
                 budget_id: budget.id
               })

      assert {:ok, _allocation} =
               Finance.create_allocation(scope, %{
                 name: "Monthly Expenses",
                 type: "spending",
                 amount: "1000.00",
                 budget_id: budget.id
               })
    end

    test "sums multiple incomes when checking budget allocation limit" do
      scope = user_scope_fixture()

      assert {:ok, budget} =
               Finance.create_budget(scope, %{
                 name: "September 2026",
                 starts_on: ~D[2026-09-01],
                 ends_on: ~D[2026-09-30],
                 status: "active"
               })

      assert {:ok, _first_income} =
               Finance.create_income(scope.user, %{
                 amount: "1000.00",
                 source: "Salary",
                 received_on: ~D[2026-09-01],
                 budget_id: budget.id
               })

      assert {:ok, _second_income} =
               Finance.create_income(scope.user, %{
                 amount: "500.00",
                 source: "Side Income",
                 received_on: ~D[2026-09-15],
                 budget_id: budget.id
               })

      assert {:ok, _allocation} =
               Finance.create_allocation(scope, %{
                 name: "Expenses",
                 type: "spending",
                 amount: "1500.00",
                 budget_id: budget.id
               })
    end
  end

  describe "spending rules" do
    test "creates a spending rule for an allocation" do
      scope = AccountsFixtures.user_scope_fixture()
      allocation = FinanceFixtures.allocation_fixture(scope)

      attrs = %{
        period: "daily",
        limit_amount: "300",
        allocation_id: allocation.id
      }

      assert {:ok, spending_rule} =
               Finance.create_spending_rule(scope, attrs)

      assert spending_rule.period == "daily"
      assert Decimal.equal?(spending_rule.limit_amount, Decimal.new("300"))
      assert spending_rule.user_id == scope.user.id
      assert spending_rule.allocation_id == allocation.id
    end

    test "does not allow a user to create a rule for another user's allocation" do
      scope = AccountsFixtures.user_scope_fixture()
      other_scope = AccountsFixtures.user_scope_fixture()

      other_allocation = FinanceFixtures.allocation_fixture(other_scope)

      attrs = %{
        period: "daily",
        limit_amount: "300",
        allocation_id: other_allocation.id
      }

      assert_raise Ecto.NoResultsError, fn ->
        Finance.create_spending_rule(scope, attrs)
      end
    end

    test "rejects an invalid spending rule period" do
      scope = AccountsFixtures.user_scope_fixture()
      allocation = FinanceFixtures.allocation_fixture(scope)

      attrs = %{
        period: "yearly",
        limit_amount: "300",
        allocation_id: allocation.id
      }

      assert {:error, changeset} =
               Finance.create_spending_rule(scope, attrs)

      assert "is invalid" in errors_on(changeset).period
    end
  end

  test "rejects a zero spending rule limit" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      period: "daily",
      limit_amount: "0",
      allocation_id: allocation.id
    }

    assert {:error, changeset} =
             Finance.create_spending_rule(scope, attrs)

    assert "must be greater than 0" in errors_on(changeset).limit_amount
  end

  test "rejects a negative spending rule limit" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      period: "daily",
      limit_amount: "-100",
      allocation_id: allocation.id
    }

    assert {:error, changeset} =
             Finance.create_spending_rule(scope, attrs)

    assert "must be greater than 0" in errors_on(changeset).limit_amount
  end

  test "rejects a spending rule without period and limit" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      allocation_id: allocation.id
    }

    assert {:error, changeset} =
             Finance.create_spending_rule(scope, attrs)

    errors = errors_on(changeset)

    assert "can't be blank" in errors.period
    assert "can't be blank" in errors.limit_amount
  end

  test "creates a weekly spending rule" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      period: "weekly",
      limit_amount: "1500",
      allocation_id: allocation.id
    }

    assert {:ok, spending_rule} =
             Finance.create_spending_rule(scope, attrs)

    assert spending_rule.period == "weekly"
    assert Decimal.equal?(spending_rule.limit_amount, Decimal.new("1500"))
  end

  test "creates a monthly spending rule" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      period: "monthly",
      limit_amount: "2000",
      allocation_id: allocation.id
    }

    assert {:ok, spending_rule} =
             Finance.create_spending_rule(scope, attrs)

    assert spending_rule.period == "monthly"
    assert Decimal.equal?(spending_rule.limit_amount, Decimal.new("2000"))
  end

  test "lists spending rules belonging to the user" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      period: "daily",
      limit_amount: "300",
      allocation_id: allocation.id
    }

    {:ok, spending_rule} = Finance.create_spending_rule(scope, attrs)

    assert [listed_rule] = Finance.list_spending_rules(scope)
    assert listed_rule.id == spending_rule.id
    assert listed_rule.period == "daily"
    assert Decimal.equal?(listed_rule.limit_amount, Decimal.new("300"))
  end

  test "gets a spending rule belonging to the user" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      period: "daily",
      limit_amount: "300",
      allocation_id: allocation.id
    }

    {:ok, spending_rule} = Finance.create_spending_rule(scope, attrs)

    fetched_rule =
      Finance.get_spending_rule!(scope, spending_rule.id)

    assert fetched_rule.id == spending_rule.id
    assert fetched_rule.period == "daily"
    assert Decimal.equal?(fetched_rule.limit_amount, Decimal.new("300"))
    assert fetched_rule.allocation_id == allocation.id
    assert fetched_rule.user_id == scope.user.id
  end

  test "updates a spending rule belonging to the user" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      period: "daily",
      limit_amount: "300",
      allocation_id: allocation.id
    }

    {:ok, spending_rule} = Finance.create_spending_rule(scope, attrs)

    update_attrs = %{
      period: "weekly",
      limit_amount: "1500"
    }

    assert {:ok, updated_rule} =
             Finance.update_spending_rule(scope, spending_rule, update_attrs)

    assert updated_rule.id == spending_rule.id
    assert updated_rule.period == "weekly"
    assert Decimal.equal?(updated_rule.limit_amount, Decimal.new("1500"))
    assert updated_rule.allocation_id == allocation.id
    assert updated_rule.user_id == scope.user.id
  end

  test "deletes a spending rule belonging to the user" do
    scope = AccountsFixtures.user_scope_fixture()
    allocation = FinanceFixtures.allocation_fixture(scope)

    attrs = %{
      period: "daily",
      limit_amount: "300",
      allocation_id: allocation.id
    }

    {:ok, spending_rule} = Finance.create_spending_rule(scope, attrs)

    assert {:ok, deleted_rule} =
             Finance.delete_spending_rule(scope, spending_rule)

    assert deleted_rule.id == spending_rule.id

    assert_raise Ecto.NoResultsError, fn ->
      Finance.get_spending_rule!(scope, spending_rule.id)
    end
  end

  test "does not allow a user to update another user's spending rule" do
    scope = AccountsFixtures.user_scope_fixture()
    other_scope = AccountsFixtures.user_scope_fixture()

    allocation = FinanceFixtures.allocation_fixture(other_scope)

    attrs = %{
      period: "daily",
      limit_amount: "300",
      allocation_id: allocation.id
    }

    {:ok, spending_rule} =
      Finance.create_spending_rule(other_scope, attrs)

    assert_raise MatchError, fn ->
      Finance.update_spending_rule(
        scope,
        spending_rule,
        %{limit_amount: "500"}
      )
    end
  end

  test "does not allow a user to delete another user's spending rule" do
    scope = AccountsFixtures.user_scope_fixture()
    other_scope = AccountsFixtures.user_scope_fixture()

    allocation = FinanceFixtures.allocation_fixture(other_scope)

    attrs = %{
      period: "daily",
      limit_amount: "300",
      allocation_id: allocation.id
    }

    {:ok, spending_rule} =
      Finance.create_spending_rule(other_scope, attrs)

    assert_raise MatchError, fn ->
      Finance.delete_spending_rule(scope, spending_rule)
    end
  end

  test "does not allow duplicate spending rules for the same allocation and period" do
    scope = AccountsFixtures.user_scope_fixture()

    allocation = FinanceFixtures.allocation_fixture(scope)

    assert {:ok, _rule} =
             Finance.create_spending_rule(scope, %{
               allocation_id: allocation.id,
               period: "daily",
               limit_amount: "300.0"
             })

    assert {:error, changeset} =
             Finance.create_spending_rule(scope, %{
               allocation_id: allocation.id,
               period: "daily",
               limit_amount: "500.0"
             })

    assert "already has a spending rule for this period" in errors_on(changeset).allocation_id

    assert {:ok, _weekly_rule} =
             Finance.create_spending_rule(scope, %{
               allocation_id: allocation.id,
               period: "weekly",
               limit_amount: "1500.0"
             })
  end

  describe "transactions" do
    setup do
      %{scope: user_scope_fixture()}
    end

    test "does not allow transactions against protected allocations", %{scope: scope} do
      allocation =
        FinanceFixtures.allocation_fixture(scope, %{
          type: "protected",
          amount: "20000.0"
        })

      FinanceFixtures.spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      assert {:error, changeset} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "50.0",
                 description: "Attempted protected spending",
                 occurred_at: ~U[2026-09-30 08:00:00Z]
               })

      assert "protected allocations cannot be spent" in errors_on(changeset).allocation_id
    end

    test "lists transactions belonging to the user", %{scope: scope} do
      transaction = transaction_fixture(scope)

      assert Finance.list_transactions(scope) == [transaction]
    end

    test "does not list another user's transactions", %{scope: scope} do
      other_scope = user_scope_fixture()

      transaction_fixture(other_scope)

      assert Finance.list_transactions(scope) == []
    end

    test "gets a transaction belonging to the user", %{scope: scope} do
      transaction = transaction_fixture(scope)

      assert Finance.get_transaction!(scope, transaction.id) == transaction
    end

    test "cannot get another user's transaction", %{scope: scope} do
      other_scope = user_scope_fixture()
      transaction = transaction_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_transaction!(scope, transaction.id)
      end
    end

    test "creates a transaction for the user's allocation", %{scope: scope} do
      allocation = allocation_fixture(scope)

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      assert {:ok, transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "150",
                 description: "Lunch",
                 occurred_at: ~U[2026-09-30 08:00:00Z]
               })

      assert transaction.amount == Decimal.new("150")
      assert transaction.description == "Lunch"
    end

    test "cannot create a transaction for another user's allocation", %{
      scope: scope
    } do
      other_scope = user_scope_fixture()

      other_allocation =
        allocation_fixture(other_scope, %{
          name: "Other user's Food",
          amount: "9000",
          type: "spending"
        })

      assert_raise Ecto.NoResultsError, fn ->
        Finance.create_transaction(scope, %{
          allocation_id: other_allocation.id,
          amount: "150",
          description: "Lunch"
        })
      end

      assert Finance.list_transactions(scope) == []
    end

    test "updates a user's transaction", %{scope: scope} do
      transaction = transaction_fixture(scope)

      assert {:ok, updated_transaction} =
               Finance.update_transaction(scope, transaction, %{
                 amount: "200",
                 description: "Dinner"
               })

      assert Decimal.equal?(updated_transaction.amount, Decimal.new("200"))
      assert updated_transaction.description == "Dinner"
    end

    test "cannot update another user's transaction", %{scope: scope} do
      other_scope = user_scope_fixture()
      transaction = transaction_fixture(other_scope)

      assert_raise MatchError, fn ->
        Finance.update_transaction(scope, transaction, %{
          amount: "200",
          description: "Dinner"
        })
      end
    end

    test "deletes a user's transaction", %{scope: scope} do
      transaction = transaction_fixture(scope)

      assert {:ok, _deleted_transaction} =
               Finance.delete_transaction(scope, transaction)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_transaction!(scope, transaction.id)
      end
    end

    test "cannot delete another user's transaction", %{scope: scope} do
      other_scope = user_scope_fixture()
      transaction = transaction_fixture(other_scope)

      assert_raise MatchError, fn ->
        Finance.delete_transaction(scope, transaction)
      end
    end

    test "allows a transaction when it stays within the spending rule", %{scope: scope} do
      allocation = allocation_fixture(scope)

      {:ok, _spending_rule} =
        Finance.create_spending_rule(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300.0"
        })

      assert {:ok, transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "250.0",
                 description: "Daily spending",
                 occurred_at: ~U[2026-09-30 10:00:00Z]
               })

      assert transaction.amount == Decimal.new("250.0")
    end

    test "rejects a transaction when it exceeds the spending rule", %{scope: scope} do
      allocation = allocation_fixture(scope)

      {:ok, _spending_rule} =
        Finance.create_spending_rule(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300.0"
        })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "250.0",
                 description: "First spending",
                 occurred_at: ~U[2026-09-30 10:00:00Z]
               })

      assert {:error, changeset} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "100.0",
                 description: "Second spending",
                 occurred_at: ~U[2026-09-30 12:00:00Z]
               })

      assert "transaction exceeds the spending limit" in errors_on(changeset).amount
    end

    test "rejects a transaction when the allocation has no spending rule", %{scope: scope} do
      allocation = allocation_fixture(scope)

      assert {:error, changeset} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "100.0",
                 description: "Uncontrolled spending",
                 occurred_at: ~U[2026-09-30 10:00:00Z]
               })

      assert "allocation has no spending rule" in errors_on(changeset).amount
    end

    test "rejects a transaction when combined daily spending exceeds the limit", %{
      scope: scope
    } do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "200",
                 description: "Lunch",
                 occurred_at: ~U[2026-09-30 12:00:00Z]
               })

      assert {:error, changeset} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "101",
                 description: "Dinner",
                 occurred_at: ~U[2026-09-30 18:00:00Z]
               })

      assert "transaction exceeds the spending limit" in errors_on(changeset).amount
    end

    test "allows transactions that exactly reach the daily limit", %{scope: scope} do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      assert {:ok, _first_transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "200",
                 description: "Lunch",
                 occurred_at: ~U[2026-09-30 12:00:00Z]
               })

      assert {:ok, _second_transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "100",
                 description: "Dinner",
                 occurred_at: ~U[2026-09-30 18:00:00Z]
               })

      remaining =
        Finance.remaining_allowance(
          scope,
          Repo.get_by!(
            ShilingiGuard.Finance.SpendingRule,
            allocation_id: allocation.id,
            period: "daily"
          ),
          ~U[2026-09-30 00:00:00Z],
          ~U[2026-10-01 00:00:00Z]
        )

      assert Decimal.equal?(remaining, Decimal.new("0"))
    end

    test "allows a fresh daily allowance on the next day", %{scope: scope} do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "300",
                 description: "Food for September 30",
                 occurred_at: ~U[2026-09-30 18:00:00Z]
               })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "300",
                 description: "Food for October 1",
                 occurred_at: ~U[2026-10-01 08:00:00Z]
               })
    end

    test "does not count previous day spending toward today's allowance", %{
      scope: scope
    } do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "300",
                 description: "Food yesterday",
                 occurred_at: ~U[2026-09-30 18:00:00Z]
               })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "300",
                 description: "Food today",
                 occurred_at: ~U[2026-10-01 10:00:00Z]
               })
    end

    test "rejects a transaction when weekly spending exceeds the limit", %{
      scope: scope
    } do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "weekly",
        limit_amount: "1000.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "700",
                 description: "Food",
                 occurred_at: ~U[2026-09-30 12:00:00Z]
               })

      assert {:error, changeset} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "301",
                 description: "More food",
                 occurred_at: ~U[2026-10-01 12:00:00Z]
               })

      assert "transaction exceeds the spending limit" in errors_on(changeset).amount
    end

    test "allows a fresh weekly allowance when a new week begins", %{
      scope: scope
    } do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "weekly",
        limit_amount: "1000.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "1000",
                 description: "Food this week",
                 occurred_at: ~U[2026-09-27 18:00:00Z]
               })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "1000",
                 description: "Food next week",
                 occurred_at: ~U[2026-09-28 08:00:00Z]
               })
    end

    test "rejects a transaction when monthly spending exceeds the limit", %{
      scope: scope
    } do
      allocation =
        allocation_fixture(scope, %{
          name: "Shopping",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "monthly",
        limit_amount: "2000.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "1500",
                 description: "Shopping",
                 occurred_at: ~U[2026-09-15 12:00:00Z]
               })

      assert {:error, changeset} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "501",
                 description: "More shopping",
                 occurred_at: ~U[2026-09-25 12:00:00Z]
               })

      assert "transaction exceeds the spending limit" in errors_on(changeset).amount
    end

    test "allows a fresh monthly allowance when a new month begins", %{
      scope: scope
    } do
      allocation =
        allocation_fixture(scope, %{
          name: "Shopping",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "monthly",
        limit_amount: "2000.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "2000",
                 description: "September shopping",
                 occurred_at: ~U[2026-09-30 18:00:00Z]
               })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "2000",
                 description: "October shopping",
                 occurred_at: ~U[2026-10-01 08:00:00Z]
               })
    end

    test "daily spending resets at midnight in the user's timezone", %{scope: scope} do
      user =
        scope.user
        |> Ecto.Changeset.change(timezone: "Africa/Nairobi")
        |> ShilingiGuard.Repo.update!()

      scope = %{scope | user: user}

      allocation = allocation_fixture(scope)

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "250.0",
                 description: "Before midnight",
                 occurred_at: ~U[2026-09-30 20:59:00Z]
               })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "100.0",
                 description: "After midnight",
                 occurred_at: ~U[2026-09-30 21:00:00Z]
               })
    end

    test "daily spending does not reset before midnight in the user's timezone", %{scope: scope} do
      user =
        scope.user
        |> Ecto.Changeset.change(timezone: "Africa/Nairobi")
        |> ShilingiGuard.Repo.update!()

      scope = %{scope | user: user}

      allocation = allocation_fixture(scope)

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "250.0",
                 description: "First transaction",
                 occurred_at: ~U[2026-09-30 20:00:00Z]
               })

      assert {:error, changeset} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "100.0",
                 description: "Second transaction",
                 occurred_at: ~U[2026-09-30 20:30:00Z]
               })

      assert "transaction exceeds the spending limit" in errors_on(changeset).amount
    end

    test "weekly spending resets at Monday midnight in the user's timezone", %{scope: scope} do
      user =
        scope.user
        |> Ecto.Changeset.change(timezone: "Africa/Nairobi")
        |> ShilingiGuard.Repo.update!()

      scope = %{scope | user: user}

      allocation = allocation_fixture(scope)

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "weekly",
        limit_amount: "300.0"
      })

      # Sunday 20:59 UTC = Sunday 23:59 in Nairobi.
      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "250.0",
                 description: "Sunday transaction",
                 occurred_at: ~U[2026-09-27 20:59:00Z]
               })

      # Sunday 21:00 UTC = Monday 00:00 in Nairobi.
      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "100.0",
                 description: "Monday transaction",
                 occurred_at: ~U[2026-09-27 21:00:00Z]
               })
    end

    test "monthly spending resets at the first day of the month in the user's timezone", %{
      scope: scope
    } do
      user =
        scope.user
        |> Ecto.Changeset.change(timezone: "Africa/Nairobi")
        |> ShilingiGuard.Repo.update!()

      scope = %{scope | user: user}

      allocation = allocation_fixture(scope)

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "monthly",
        limit_amount: "300.0"
      })

      # September 30 20:59 UTC = September 30 23:59 in Nairobi.
      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "250.0",
                 description: "September transaction",
                 occurred_at: ~U[2026-09-30 20:59:00Z]
               })

      # September 30 21:00 UTC = October 1 00:00 in Nairobi.
      assert {:ok, _transaction} =
               Finance.create_transaction(scope, %{
                 allocation_id: allocation.id,
                 amount: "100.0",
                 description: "October transaction",
                 occurred_at: ~U[2026-09-30 21:00:00Z]
               })
    end
  end

  describe "spending calculations" do
    setup do
      %{scope: user_scope_fixture()}
    end

    test "returns zero when there are no transactions", %{scope: scope} do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.spent_in_period(scope, allocation.id, start_time, end_time),
               Decimal.new("0")
             )
    end

    test "returns the amount of one transaction in the period", %{scope: scope} do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      {:ok, _transaction} =
        Finance.create_transaction(scope, %{
          allocation_id: allocation.id,
          amount: "150",
          description: "Lunch",
          occurred_at: ~U[2026-09-30 12:00:00Z]
        })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.spent_in_period(scope, allocation.id, start_time, end_time),
               Decimal.new("150")
             )
    end

    test "adds multiple transactions in the period", %{scope: scope} do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "150",
        description: "Lunch",
        occurred_at: ~U[2026-09-30 12:00:00Z]
      })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "50",
        description: "Soda",
        occurred_at: ~U[2026-09-30 15:00:00Z]
      })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "80",
        description: "Snack",
        occurred_at: ~U[2026-09-30 18:00:00Z]
      })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.spent_in_period(scope, allocation.id, start_time, end_time),
               Decimal.new("280")
             )
    end

    test "excludes transactions outside the period", %{scope: scope} do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "100",
        description: "Yesterday",
        occurred_at: ~U[2026-09-29 23:00:00Z]
      })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "150",
        description: "Today",
        occurred_at: ~U[2026-09-30 12:00:00Z]
      })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "200",
        description: "Tomorrow",
        occurred_at: ~U[2026-10-01 01:00:00Z]
      })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.spent_in_period(scope, allocation.id, start_time, end_time),
               Decimal.new("150")
             )
    end

    test "does not include transactions from another allocation", %{scope: scope} do
      food =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: food.id,
        period: "daily",
        limit_amount: "300.0"
      })

      transport =
        allocation_fixture(scope, %{
          name: "Transport",
          amount: "5000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: transport.id,
        period: "daily",
        limit_amount: "300.0"
      })

      Finance.create_transaction(scope, %{
        allocation_id: food.id,
        amount: "150",
        description: "Lunch",
        occurred_at: ~U[2026-09-30 12:00:00Z]
      })

      Finance.create_transaction(scope, %{
        allocation_id: transport.id,
        amount: "500",
        description: "Matatu",
        occurred_at: ~U[2026-09-30 13:00:00Z]
      })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.spent_in_period(scope, food.id, start_time, end_time),
               Decimal.new("150")
             )
    end

    test "does not include another user's transactions", %{scope: scope} do
      other_scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      other_allocation =
        allocation_fixture(other_scope, %{
          name: "Other Food",
          amount: "9000",
          type: "spending"
        })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "150",
        description: "My lunch",
        occurred_at: ~U[2026-09-30 12:00:00Z]
      })

      Finance.create_transaction(other_scope, %{
        allocation_id: other_allocation.id,
        amount: "500",
        description: "Their lunch",
        occurred_at: ~U[2026-09-30 13:00:00Z]
      })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.spent_in_period(scope, allocation.id, start_time, end_time),
               Decimal.new("150")
             )
    end

    test "includes the start boundary but excludes the end boundary", %{scope: scope} do
      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule_fixture(scope, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "300.0"
      })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "100",
        description: "At start",
        occurred_at: ~U[2026-09-30 00:00:00Z]
      })

      Finance.create_transaction(scope, %{
        allocation_id: allocation.id,
        amount: "200",
        description: "At end",
        occurred_at: ~U[2026-10-01 00:00:00Z]
      })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.spent_in_period(scope, allocation.id, start_time, end_time),
               Decimal.new("100")
             )
    end
  end

  describe "remaining allowance" do
    setup do
      %{scope: user_scope_fixture()}
    end

    test "returns the full limit when nothing has been spent", %{scope: scope} do
      allocation = allocation_fixture(scope)

      {:ok, spending_rule} =
        Finance.create_spending_rule(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300.0"
        })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.remaining_allowance(
                 scope,
                 spending_rule,
                 start_time,
                 end_time
               ),
               Decimal.new("300.0")
             )
    end

    test "subtracts spent amount from the limit", %{scope: scope} do
      allocation = allocation_fixture(scope)

      {:ok, spending_rule} =
        Finance.create_spending_rule(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300.0"
        })

      {:ok, _transaction} =
        Finance.create_transaction(scope, %{
          allocation_id: allocation.id,
          amount: "230.0",
          description: "Lunch and transport",
          occurred_at: ~U[2026-09-30 10:00:00Z]
        })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.remaining_allowance(
                 scope,
                 spending_rule,
                 start_time,
                 end_time
               ),
               Decimal.new("70.0")
             )
    end

    test "returns zero when exactly the full limit has been spent", %{scope: scope} do
      allocation = allocation_fixture(scope)

      {:ok, spending_rule} =
        Finance.create_spending_rule(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300.0"
        })

      {:ok, _transaction} =
        Finance.create_transaction(scope, %{
          allocation_id: allocation.id,
          amount: "300.0",
          description: "Daily spending",
          occurred_at: ~U[2026-09-30 10:00:00Z]
        })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.remaining_allowance(
                 scope,
                 spending_rule,
                 start_time,
                 end_time
               ),
               Decimal.new("0")
             )
    end

    test "never returns a negative allowance", %{scope: scope} do
      allocation = allocation_fixture(scope)

      {:ok, spending_rule} =
        Finance.create_spending_rule(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300.0"
        })

      {:ok, _transaction} =
        Finance.create_transaction(scope, %{
          allocation_id: allocation.id,
          amount: "300.0",
          description: "Overspent amount",
          occurred_at: ~U[2026-09-30 10:00:00Z]
        })

      start_time = ~U[2026-09-30 00:00:00Z]
      end_time = ~U[2026-10-01 00:00:00Z]

      assert Decimal.equal?(
               Finance.remaining_allowance(
                 scope,
                 spending_rule,
                 start_time,
                 end_time
               ),
               Decimal.new("0")
             )
    end
  end
end
