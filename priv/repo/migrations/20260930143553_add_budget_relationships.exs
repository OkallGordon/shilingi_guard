defmodule ShilingiGuard.Repo.Migrations.AddBudgetRelationships do
  use Ecto.Migration

  def change do
    alter table(:incomes) do
      add :budget_id, references(:budgets, on_delete: :delete_all)
    end

    create index(:incomes, [:budget_id])

    alter table(:allocations) do
      add :budget_id, references(:budgets, on_delete: :delete_all)
    end

    create index(:allocations, [:budget_id])
  end
end
