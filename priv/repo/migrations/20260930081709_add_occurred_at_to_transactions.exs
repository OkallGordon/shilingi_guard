defmodule ShilingiGuard.Repo.Migrations.AddOccurredAtToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :occurred_at, :utc_datetime, null: false
    end
  end
end
