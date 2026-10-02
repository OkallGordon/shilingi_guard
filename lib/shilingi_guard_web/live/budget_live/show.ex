defmodule ShilingiGuardWeb.BudgetLive.Show do
  use ShilingiGuardWeb, :live_view

  alias ShilingiGuard.Finance

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@budget.name}
        <:subtitle>
          {@budget.starts_on} to {@budget.ends_on}
        </:subtitle>

        <:actions>
          <.button navigate={~p"/budgets"}>
            <.icon name="hero-arrow-left" /> Budgets
          </.button>

          <.button
            variant="primary"
            navigate={~p"/budgets/#{@budget}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit budget
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">
          {@budget.name}
        </:item>

        <:item title="Starts on">
          {@budget.starts_on}
        </:item>

        <:item title="Ends on">
          {@budget.ends_on}
        </:item>

        <:item title="Status">
          {@budget.status}
        </:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    budget =
      Finance.get_budget!(
        socket.assigns.current_scope,
        id
      )

    {:ok,
     socket
     |> assign(:page_title, budget.name)
     |> assign(:budget, budget)}
  end
end
