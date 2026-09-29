defmodule ShilingiGuard.Repo.Migrations.CreateSpendingRules do
  use Ecto.Migration

  def change do
    create table(:spending_rules) do
      add :period, :string, null: false
      add :limit_amount, :decimal, null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :allocation_id,
          references(:allocations, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:spending_rules, [:user_id])
    create index(:spending_rules, [:allocation_id])
  end
end
