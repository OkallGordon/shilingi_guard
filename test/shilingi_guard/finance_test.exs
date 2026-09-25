defmodule ShilingiGuard.FinanceTest do
  use ShilingiGuard.DataCase

  alias ShilingiGuard.AccountsFixtures
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
      assert_raise Ecto.NoResultsError, fn -> Finance.get_allocation!(other_scope, allocation.id) end
    end

    test "create_allocation/2 with valid data creates a allocation" do
      valid_attrs = %{name: "some name", type: "some type", amount: "120.5"}
      scope = user_scope_fixture()

      assert {:ok, %Allocation{} = allocation} = Finance.create_allocation(scope, valid_attrs)
      assert allocation.name == "some name"
      assert allocation.type == "some type"
      assert allocation.amount == Decimal.new("120.5")
      assert allocation.user_id == scope.user.id
    end

    test "create_allocation/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Finance.create_allocation(scope, @invalid_attrs)
    end

    test "update_allocation/3 with valid data updates the allocation" do
      scope = user_scope_fixture()
      allocation = allocation_fixture(scope)
      update_attrs = %{name: "some updated name", type: "some updated type", amount: "456.7"}

      assert {:ok, %Allocation{} = allocation} = Finance.update_allocation(scope, allocation, update_attrs)
      assert allocation.name == "some updated name"
      assert allocation.type == "some updated type"
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
      assert {:error, %Ecto.Changeset{}} = Finance.update_allocation(scope, allocation, @invalid_attrs)
      assert allocation == Finance.get_allocation!(scope, allocation.id)
    end

    test "delete_allocation/2 deletes the allocation" do
      scope = user_scope_fixture()
      allocation = allocation_fixture(scope)
      assert {:ok, %Allocation{}} = Finance.delete_allocation(scope, allocation)
      assert_raise Ecto.NoResultsError, fn -> Finance.get_allocation!(scope, allocation.id) end
    end

    test "delete_allocation/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      allocation = allocation_fixture(scope)
      assert_raise MatchError, fn -> Finance.delete_allocation(other_scope, allocation) end
    end

    test "change_allocation/2 returns a allocation changeset" do
      scope = user_scope_fixture()
      allocation = allocation_fixture(scope)
      assert %Ecto.Changeset{} = Finance.change_allocation(scope, allocation)
    end
  end
end
