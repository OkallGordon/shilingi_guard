defmodule ShilingiGuard.FinanceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ShilingiGuard.Finance` context.
  """

  @doc """
  Generate a allocation.
  """
  def allocation_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        amount: "120.5",
        name: "some name",
        type: "some type"
      })

    {:ok, allocation} = ShilingiGuard.Finance.create_allocation(scope, attrs)
    allocation
  end
end
