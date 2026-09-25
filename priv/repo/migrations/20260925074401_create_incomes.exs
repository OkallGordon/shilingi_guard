defmodule ShilingiGuard.Repo.Migrations.CreateIncomes do
  use Ecto.Migration

  def change do
    create table(:incomes) do
      add :amount, :decimal, null: false
      add :source, :string, null: false
      add :received_on, :date, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
