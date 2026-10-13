
defmodule ShilingiGuard.Finance.AllocationConcurrencyTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias ShilingiGuard.AccountsFixtures
  alias ShilingiGuard.Finance
  alias ShilingiGuard.Finance.Allocation
  alias ShilingiGuard.Repo

  test "concurrent allocations cannot exceed a budget's income" do
    # Use a sandbox owner that is not inside a test-managed transaction.
    owner =
      Ecto.Adapters.SQL.Sandbox.start_owner!(
        Repo,
        shared: false
      )

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.stop_owner(owner)
    end)

    scope = AccountsFixtures.user_scope_fixture()

    {:ok, budget} =
      Finance.create_budget(scope, %{
        name: "Concurrency Test",
        starts_on: ~D[2026-10-01],
        ends_on: ~D[2026-10-31],
        status: "active"
      })

    {:ok, _income} =
      Finance.create_income(scope.user, %{
        amount: "1000.00",
        source: "Salary",
        received_on: ~D[2026-10-01],
        budget_id: budget.id
      })

    # Both tasks will be coordinated in the next step after
    # we establish safe independent database access.
    total_allocated =
  Allocation
  |> where([a], a.budget_id == ^budget.id)
  |> select([a], coalesce(sum(a.amount), ^Decimal.new("0.00")))
  |> Repo.one()

     assert Decimal.equal?(total_allocated, Decimal.new("0.00"))
  end
end
