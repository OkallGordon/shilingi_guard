defmodule ShilingiGuardWeb.BudgetLive.Form do
  use ShilingiGuardWeb, :live_view

  alias ShilingiGuard.Finance
  alias ShilingiGuard.Finance.Budget

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>
          Set the period that this budget will cover.
        </:subtitle>
      </.header>

      <.form for={@form} id="budget-form" phx-change="validate" phx-submit="save">
        <.input
          field={@form[:name]}
          type="text"
          label="Budget name"
          placeholder="September 2026"
        />

        <.input
          field={@form[:starts_on]}
          type="date"
          label="Start date"
        />

        <.input
          field={@form[:ends_on]}
          type="date"
          label="End date"
        />

        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          options={[
            {"Active", "active"},
            {"Completed", "completed"},
            {"Cancelled", "cancelled"}
          ]}
        />

        <footer class="mt-6 flex gap-3">
          <.button phx-disable-with="Saving..." variant="primary">
            Save Budget
          </.button>

          <.button navigate={return_path(@current_scope, @return_to, @budget)}>
            Cancel
          </.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    budget = Finance.get_budget!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Budget")
    |> assign(:budget, budget)
    |> assign(
      :form,
      to_form(Finance.change_budget(socket.assigns.current_scope, budget))
    )
  end

  defp apply_action(socket, :new, _params) do
    budget = %Budget{status: "active"}

    socket
    |> assign(:page_title, "New Budget")
    |> assign(:budget, budget)
    |> assign(
      :form,
      to_form(Finance.change_budget(socket.assigns.current_scope, budget))
    )
  end

  @impl true
  def handle_event("validate", %{"budget" => budget_params}, socket) do
    changeset =
      Finance.change_budget(
        socket.assigns.current_scope,
        socket.assigns.budget,
        budget_params
      )

    {:noreply,
     assign(
       socket,
       :form,
       to_form(changeset, action: :validate)
     )}
  end

  @impl true
  def handle_event("save", %{"budget" => budget_params}, socket) do
    save_budget(
      socket,
      socket.assigns.live_action,
      budget_params
    )
  end

  defp save_budget(socket, :edit, budget_params) do
    case Finance.update_budget(
           socket.assigns.current_scope,
           socket.assigns.budget,
           budget_params
         ) do
      {:ok, budget} ->
        {:noreply,
         socket
         |> put_flash(:info, "Budget updated successfully.")
         |> push_navigate(
           to:
             return_path(
               socket.assigns.current_scope,
               socket.assigns.return_to,
               budget
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(
           socket,
           :form,
           to_form(changeset, action: :update)
         )}
    end
  end

  defp save_budget(socket, :new, budget_params) do
    case Finance.create_budget(
           socket.assigns.current_scope,
           budget_params
         ) do
      {:ok, budget} ->
        {:noreply,
         socket
         |> put_flash(:info, "Budget created successfully.")
         |> push_navigate(
           to:
             return_path(
               socket.assigns.current_scope,
               socket.assigns.return_to,
               budget
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(
           socket,
           :form,
           to_form(changeset, action: :insert)
         )}
    end
  end

  defp return_path(_scope, "index", _budget), do: ~p"/budgets"
  defp return_path(_scope, "show", budget), do: ~p"/budgets/#{budget}"
end
