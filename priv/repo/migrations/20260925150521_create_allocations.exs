defmodule ShilingiGuard.Repo.Migrations.CreateAllocations do
  use Ecto.Migration

  def change do
    create table(:allocations) do
      add :name, :string
      add :amount, :decimal
      add :type, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:allocations, [:user_id])
  end
end
