defmodule ShilingiGuardWeb.SpendingRuleLive.Index do
  use ShilingiGuardWeb, :live_view

  alias ShilingiGuard.Finance

  alias ShilingiGuard.Finance.SpendingRule

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    changeset = Finance.change_spending_rule(scope, %SpendingRule{})

    {:ok,
     socket
     |> assign(:allocations, Finance.list_allocations(scope))
     |> assign(:spending_rules, Finance.list_spending_rules(scope))
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"spending_rule" => spending_rule_params}, socket) do
    changeset =
      %SpendingRule{}
      |> SpendingRule.changeset(spending_rule_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"spending_rule" => spending_rule_params}, socket) do
    scope = socket.assigns.current_scope

    case Finance.create_spending_rule(scope, spending_rule_params) do
      {:ok, _spending_rule} ->
        changeset = Finance.change_spending_rule(scope, %SpendingRule{})

        {:noreply,
         socket
         |> assign(:allocations, Finance.list_allocations(scope))
         |> assign(:spending_rules, Finance.list_spending_rules(scope))
         |> assign(:form, to_form(changeset))
         |> put_flash(:info, "Spending rule created successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
