defmodule ShilingiGuard.Repo.Migrations.AddUserIdToIncomes do
  use Ecto.Migration

  def change do
    alter table(:incomes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    create index(:incomes, [:user_id])
  end
end
