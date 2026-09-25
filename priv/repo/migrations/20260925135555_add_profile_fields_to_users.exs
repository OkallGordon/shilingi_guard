defmodule ShilingiGuard.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :full_name, :string
      add :phone_number, :string
    end
  end
end
