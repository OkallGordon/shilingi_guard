defmodule ShilingiGuard.Finance.SpendingRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spending_rules" do
    field :period, :string
    field :limit_amount, :decimal

    belongs_to :user, ShilingiGuard.Accounts.User
    belongs_to :allocation, ShilingiGuard.Finance.Allocation

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(spending_rule, attrs) do
    spending_rule
    |> cast(attrs, [:period, :limit_amount])
    |> validate_required([:period, :limit_amount])
    |> validate_inclusion(:period, ["daily", "weekly", "monthly"])
    |> validate_number(:limit_amount, greater_than: 0)
    |> unique_constraint([:allocation_id, :period],
      name: :spending_rules_allocation_id_period_index,
      message: "already has a spending rule for this period"
    )
  end
end
