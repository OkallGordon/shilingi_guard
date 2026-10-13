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

      <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div class="rounded-lg bg-white p-5 shadow">
          <p class="text-sm text-zinc-500">Total income</p>
          <p class="mt-2 text-2xl font-bold text-green-700">
            KSh {Decimal.round(@summary.total_income, 2)}
          </p>
        </div>

        <div class="rounded-lg bg-white p-5 shadow">
          <p class="text-sm text-zinc-500">Total allocated</p>
          <p class="mt-2 text-2xl font-bold text-zinc-900">
            KSh {Decimal.round(@summary.total_allocated, 2)}
          </p>
        </div>

        <div class="rounded-lg bg-white p-5 shadow">
          <p class="text-sm text-zinc-500">Unallocated money</p>
          <p class="mt-2 text-2xl font-bold text-blue-700">
            KSh {Decimal.round(@summary.unallocated, 2)}
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    budget = Finance.get_budget!(scope, id)
    summary = Finance.budget_summary(scope, budget)

    {:ok,
     socket
     |> assign(:page_title, budget.name)
     |> assign(:budget, budget)
     |> assign(:summary, summary)}
  end
end
