defmodule ShilingiGuard.Repo.Migrations.AddUniqueIndexToSpendingRules do
  use Ecto.Migration

  def change do
    create unique_index(
             :spending_rules,
             [:allocation_id, :period],
             name: :spending_rules_allocation_id_period_index
           )
  end
end
