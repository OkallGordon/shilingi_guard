defmodule ShilingiGuard.Finance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :amount, :decimal
    field :description, :string

    belongs_to :user, ShilingiGuard.Accounts.User
    belongs_to :allocation, ShilingiGuard.Finance.Allocation

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :description])
    |> validate_required([:amount, :description])
    |> validate_number(:amount, greater_than: 0)
  end
end
