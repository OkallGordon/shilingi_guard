defmodule ShilingiGuard.Finance.Income do
  use Ecto.Schema
  import Ecto.Changeset

  schema "incomes" do
    field :amount, :decimal
    field :source, :string
    field :received_on, :date

    belongs_to :user, ShilingiGuard.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(income, attrs) do
    income
    |> cast(attrs, [:amount, :source, :received_on])
    |> validate_required([:amount, :source, :received_on])
    |> validate_number(:amount, greater_than: 0)
  end
end
