defmodule ShilingiGuard.Finance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :amount, :decimal
    field :description, :string
    field :occurred_at, :utc_datetime

    belongs_to :user, ShilingiGuard.Accounts.User
    belongs_to :allocation, ShilingiGuard.Finance.Allocation

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :description, :occurred_at])
    |> validate_required([:amount, :description, :occurred_at])
    |> validate_number(:amount, greater_than: 0)
  end
end
