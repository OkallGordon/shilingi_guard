defmodule ShilingiGuard.Finance.BudgetTest do
  use ShilingiGuard.DataCase

  alias ShilingiGuard.AccountsFixtures
  alias ShilingiGuard.Finance
  alias ShilingiGuard.Finance.Budget

  describe "budgets" do
    setup do
      user =  AccountsFixtures.user_fixture()
      scope = ShilingiGuard.Accounts.Scope.for_user(user)

      %{user: user, scope: scope}
    end

    test "creates a budget", %{scope: scope} do
      attrs = %{
        name: "September 2026",
        starts_on: ~D[2026-09-01],
        ends_on: ~D[2026-09-30],
        status: "active"
      }

      assert {:ok, %Budget{} = budget} =
               Finance.create_budget(scope, attrs)

      assert budget.name == "September 2026"
      assert budget.starts_on == ~D[2026-09-01]
      assert budget.ends_on == ~D[2026-09-30]
      assert budget.status == "active"
    end

    test "lists only the current user's budgets", %{scope: scope, user: user} do
      other_user = AccountsFixtures.user_fixture()
      other_scope = ShilingiGuard.Accounts.Scope.for_user(other_user)

      {:ok, budget} =
        Finance.create_budget(scope, %{
          name: "My Budget",
          starts_on: ~D[2026-09-01],
          ends_on: ~D[2026-09-30],
          status: "active"
        })

      {:ok, _other_budget} =
        Finance.create_budget(other_scope, %{
          name: "Other Budget",
          starts_on: ~D[2026-09-01],
          ends_on: ~D[2026-09-30],
          status: "active"
        })

      budgets = Finance.list_budgets(scope)

      assert length(budgets) == 1
      assert hd(budgets).id == budget.id
      assert hd(budgets).user_id == user.id
    end

    test "gets a budget belonging to the current user", %{scope: scope} do
      {:ok, budget} =
        Finance.create_budget(scope, %{
          name: "My Budget",
          starts_on: ~D[2026-09-01],
          ends_on: ~D[2026-09-30],
          status: "active"
        })

      assert %Budget{} = fetched = Finance.get_budget!(scope, budget.id)
      assert fetched.id == budget.id
    end

    test "does not get another user's budget", %{scope: scope} do
      other_user = AccountsFixtures.user_fixture()
      other_scope = ShilingiGuard.Accounts.Scope.for_user(other_user)

      {:ok, budget} =
        Finance.create_budget(other_scope, %{
          name: "Private Budget",
          starts_on: ~D[2026-09-01],
          ends_on: ~D[2026-09-30],
          status: "active"
        })

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_budget!(scope, budget.id)
      end
    end

    test "updates a budget", %{scope: scope} do
      {:ok, budget} =
        Finance.create_budget(scope, %{
          name: "September 2026",
          starts_on: ~D[2026-09-01],
          ends_on: ~D[2026-09-30],
          status: "active"
        })

      assert {:ok, updated} =
               Finance.update_budget(scope, budget, %{
                 name: "September Budget",
                 status: "completed"
               })

      assert updated.name == "September Budget"
      assert updated.status == "completed"
    end

    test "deletes a budget", %{scope: scope} do
      {:ok, budget} =
        Finance.create_budget(scope, %{
          name: "September 2026",
          starts_on: ~D[2026-09-01],
          ends_on: ~D[2026-09-30],
          status: "active"
        })

      assert {:ok, %Budget{}} =
               Finance.delete_budget(scope, budget)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_budget!(scope, budget.id)
      end
    end

    test "rejects a budget whose end date is before its start date", %{scope: scope} do
      assert {:error, changeset} =
               Finance.create_budget(scope, %{
                 name: "Invalid Budget",
                 starts_on: ~D[2026-09-30],
                 ends_on: ~D[2026-09-01],
                 status: "active"
               })

      assert "must be on or after the start date" in
               errors_on(changeset).ends_on
    end

    test "rejects an invalid budget status", %{scope: scope} do
      assert {:error, changeset} =
               Finance.create_budget(scope, %{
                 name: "Invalid Status",
                 starts_on: ~D[2026-09-01],
                 ends_on: ~D[2026-09-30],
                 status: "invalid"
               })

      assert "is invalid" in errors_on(changeset).status
    end
  end
end
