defmodule ShilingiGuard.FinanceTest do
  use ShilingiGuard.DataCase

  import ShilingiGuard.FinanceFixtures
  import ShilingiGuard.AccountsFixtures

  alias ShilingiGuard.AccountsFixtures
  alias ShilingiGuard.FinanceFixtures
  alias ShilingiGuard.Finance

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

    describe "transactions" do

      setup do
        %{scope: user_scope_fixture()}
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
    allocation =
      allocation_fixture(scope, %{
        name: "Food",
        amount: "9000",
        type: "spending"
      })

    assert {:ok, transaction} =
             Finance.create_transaction(scope, %{
               allocation_id: allocation.id,
               amount: "150",
               description: "Lunch"
             })

    assert transaction.user_id == scope.user.id
    assert transaction.allocation_id == allocation.id
    assert Decimal.equal?(transaction.amount, Decimal.new("150"))
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
   end
  end
