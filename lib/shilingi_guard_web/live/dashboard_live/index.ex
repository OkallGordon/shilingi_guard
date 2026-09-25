defmodule ShilingiGuardWeb.DashboardLive.Index do
  use ShilingiGuardWeb, :live_view

  alias ShilingiGuard.Finance

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    incomes = Finance.list_incomes(user)

    {:ok,
     socket
     |> assign(:incomes, incomes)
     |> assign(:monthly_income, calculate_monthly_income(incomes))}
  end

  defp calculate_monthly_income(incomes) do
    current_month = Date.utc_today().month
    current_year = Date.utc_today().year

    incomes
    |> Enum.filter(fn income ->
      income.received_on.month == current_month and
        income.received_on.year == current_year
    end)
    |> Enum.reduce(Decimal.new("0"), fn income, total ->
      Decimal.add(total, income.amount)
    end)
  end
end
