defmodule ShilingiGuardWeb.IncomeLive.Index do
  use ShilingiGuardWeb, :live_view

  alias ShilingiGuard.Finance
  alias ShilingiGuard.Finance.Income

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    user = scope.user

    changeset = Finance.change_income(%Income{})

    {:ok,
     socket
     |> assign(:incomes, Finance.list_incomes(user))
     |> assign(:budgets, Finance.list_budgets(scope))
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"income" => income_params}, socket) do
    changeset =
      %Income{}
      |> Income.changeset(income_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"income" => income_params}, socket) do
    user = socket.assigns.current_scope.user

    case Finance.create_income(user, income_params) do
      {:ok, _income} ->
        changeset = Finance.change_income(%Income{})

        {:noreply,
         socket
         |> assign(:incomes, Finance.list_incomes(user))
         |> assign(:form, to_form(changeset))
         |> put_flash(:info, "Income recorded successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end

  defp budget_options(budgets) do
    [
      {"No budget selected", ""}
      | Enum.map(budgets, fn budget ->
          {budget.name, budget.id}
        end)
    ]
  end
end
