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
        type: "spending"
      })

    {:ok, allocation} = ShilingiGuard.Finance.create_allocation(scope, attrs)
    allocation
  end

  @doc """
  Generate a spending rule.
  """
  def spending_rule_fixture(scope, attrs \\ %{}) do
    allocation = allocation_fixture(scope)

    attrs =
      Enum.into(attrs, %{
        allocation_id: allocation.id,
        period: "daily",
        limit_amount: "50.0"
      })

    {:ok, spending_rule} =
      ShilingiGuard.Finance.create_spending_rule(scope, attrs)

    spending_rule
  end
end
