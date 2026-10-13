
defmodule ShilingiGuard.Finance.BudgetSummaryTest do
  use ShilingiGuard.DataCase

  import ShilingiGuard.AccountsFixtures, only: [user_scope_fixture: 0]

  alias ShilingiGuard.Finance

  defp create_budget(scope) do
    {:ok, budget} =
      Finance.create_budget(scope, %{
        name: "October 2026",
        starts_on: ~D[2026-10-01],
        ends_on: ~D[2026-10-31],
        status: "active"
      })

    budget
  end

  defp create_income(scope, budget, amount) do
    {:ok, income} =
      Finance.create_income(scope.user, %{
        amount: amount,
        source: "Salary",
        received_on: ~D[2026-10-01],
        budget_id: budget.id
      })

    income
  end

  defp create_allocation(scope, budget, name, amount) do
    {:ok, allocation} =
      Finance.create_allocation(scope, %{
        name: name,
        type: "spending",
        amount: amount,
        budget_id: budget.id
      })

    allocation
  end

  test "budget_summary/2 adds multiple income entries" do
    scope = user_scope_fixture()
    budget = create_budget(scope)

    create_income(scope, budget, "6000.00")
    create_income(scope, budget, "4000.00")

    summary = Finance.budget_summary(scope, budget)

    assert summary.total_income == Decimal.new("10000.00")
    assert summary.total_allocated == Decimal.new("0")
    assert summary.unallocated == Decimal.new("10000.00")
  end

  test "budget_summary/2 subtracts allocations from income" do
    scope = user_scope_fixture()
    budget = create_budget(scope)

    create_income(scope, budget, "10000.00")
    create_allocation(scope, budget, "Food", "3000.00")

    summary = Finance.budget_summary(scope, budget)

    assert summary.total_income == Decimal.new("10000.00")
    assert summary.total_allocated == Decimal.new("3000.00")
    assert summary.unallocated == Decimal.new("7000.00")
  end

  test "budget_summary/2 returns zero totals for an empty budget" do
    scope = user_scope_fixture()
    budget = create_budget(scope)

    summary = Finance.budget_summary(scope, budget)

    assert Decimal.equal?(summary.total_income, Decimal.new("0"))
    assert Decimal.equal?(summary.total_allocated, Decimal.new("0"))
    assert Decimal.equal?(summary.unallocated, Decimal.new("0"))
  end

  test "budget_summary/2 rejects another user's budget" do
    scope = user_scope_fixture()
    other_scope = user_scope_fixture()
    other_users_budget = create_budget(other_scope)

    assert_raise Ecto.NoResultsError, fn ->
      Finance.budget_summary(scope, other_users_budget)
    end
  end
end
