defmodule ShilingiGuard.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :amount, :decimal, null: false
      add :description, :string, null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :allocation_id, references(:allocations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:user_id])
    create index(:transactions, [:allocation_id])
  end
end
