defmodule ShilingiGuard.Finance.Budget do
  use Ecto.Schema
  import Ecto.Changeset

  schema "budgets" do
    field :name, :string
    field :starts_on, :date
    field :ends_on, :date
    field :status, :string

    belongs_to :user, ShilingiGuard.Accounts.User

    has_many :incomes, ShilingiGuard.Finance.Income
    has_many :allocations, ShilingiGuard.Finance.Allocation

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(budget, attrs) do
    budget
    |> cast(attrs, [:name, :starts_on, :ends_on, :status])
    |> validate_required([:name, :starts_on, :ends_on, :status])
    |> validate_inclusion(:status, ["active", "completed", "cancelled"])
    |> validate_date_range()
  end

  defp validate_date_range(changeset) do
    starts_on = get_field(changeset, :starts_on)
    ends_on = get_field(changeset, :ends_on)

    if starts_on && ends_on && Date.compare(starts_on, ends_on) == :gt do
      add_error(changeset, :ends_on, "must be on or after the start date")
    else
      changeset
    end
  end
end
