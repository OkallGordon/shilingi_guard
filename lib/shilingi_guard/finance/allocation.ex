defmodule ShilingiGuard.Finance.Allocation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "allocations" do
    field :name, :string
    field :amount, :decimal
    field :type, :string

    belongs_to :user, ShilingiGuard.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(allocation, attrs) do
    allocation
    |> cast(attrs, [:name, :amount, :type])
    |> validate_required([:name, :amount, :type])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:type, ["protected", "spending"])
  end
end
