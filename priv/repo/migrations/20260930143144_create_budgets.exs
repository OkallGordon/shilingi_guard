defmodule ShilingiGuard.Repo.Migrations.CreateBudgets do
  use Ecto.Migration

  def change do
    create table(:budgets) do
      add :name, :string, null: false
      add :starts_on, :date, null: false
      add :ends_on, :date, null: false
      add :status, :string, null: false

      add :user_id,
          references(:users, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:budgets, [:user_id])

    create constraint(
             :budgets,
             :budgets_dates_valid,
             check: "starts_on <= ends_on"
           )
  end
end
