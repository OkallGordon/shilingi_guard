defmodule ShilingiGuardWeb.BudgetLive.Index do
  use ShilingiGuardWeb, :live_view

  alias ShilingiGuard.Finance

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Budgets
        <:subtitle>
          Manage the time periods you use to organize your income and allocations.
        </:subtitle>

        <:actions>
          <.button variant="primary" navigate={~p"/budgets/new"}>
            <.icon name="hero-plus" /> New Budget
          </.button>
        </:actions>
      </.header>

      <.table
        id="budgets"
        rows={@streams.budgets}
        row_click={fn {_id, budget} -> JS.navigate(~p"/budgets/#{budget}") end}
      >
        <:col :let={{_id, budget}} label="Name">
          {budget.name}
        </:col>

        <:col :let={{_id, budget}} label="Starts on">
          {budget.starts_on}
        </:col>

        <:col :let={{_id, budget}} label="Ends on">
          {budget.ends_on}
        </:col>

        <:col :let={{_id, budget}} label="Status">
          {budget.status}
        </:col>

        <:action :let={{_id, budget}}>
          <div class="sr-only">
            <.link navigate={~p"/budgets/#{budget}"}>Show</.link>
          </div>

          <.link navigate={~p"/budgets/#{budget}/edit"}>
            Edit
          </.link>
        </:action>

        <:action :let={{id, budget}}>
          <.link
            phx-click={JS.push("delete", value: %{id: budget.id}) |> hide("##{id}")}
            data-confirm="Are you sure you want to delete this budget?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Budgets")
     |> stream(:budgets, list_budgets(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    budget = Finance.get_budget!(scope, id)

    case Finance.delete_budget(scope, budget) do
      {:ok, _budget} ->
        {:noreply, stream_delete(socket, :budgets, budget)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The budget could not be deleted.")}
    end
  end

  defp list_budgets(current_scope) do
    Finance.list_budgets(current_scope)
  end
end
