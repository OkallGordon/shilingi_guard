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
end
