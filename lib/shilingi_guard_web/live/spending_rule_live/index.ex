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
     |> assign(:form, to_form(changeset))
     |> assign(:editing_rule, nil)}
  end

  @impl true
  def handle_event("validate", %{"spending_rule" => spending_rule_params}, socket) do
    spending_rule = socket.assigns.editing_rule || %SpendingRule{}

    changeset =
      spending_rule
      |> SpendingRule.changeset(spending_rule_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"spending_rule" => spending_rule_params}, socket) do
    scope = socket.assigns.current_scope

    case socket.assigns.editing_rule do
      nil ->
        create_spending_rule(socket, scope, spending_rule_params)

      spending_rule ->
        update_spending_rule(socket, scope, spending_rule, spending_rule_params)
    end
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    spending_rule = Finance.get_spending_rule!(scope, id)
    changeset = Finance.change_spending_rule(scope, spending_rule)

    {:noreply,
     socket
     |> assign(:editing_rule, spending_rule)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    scope = socket.assigns.current_scope

    changeset = Finance.change_spending_rule(scope, %SpendingRule{})

    {:noreply,
     socket
     |> assign(:editing_rule, nil)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    spending_rule = Finance.get_spending_rule!(scope, id)

    case Finance.delete_spending_rule(scope, spending_rule) do
      {:ok, _spending_rule} ->
        changeset = Finance.change_spending_rule(scope, %SpendingRule{})

        {:noreply,
         socket
         |> assign(:allocations, Finance.list_allocations(scope))
         |> assign(:spending_rules, Finance.list_spending_rules(scope))
         |> assign(:form, to_form(changeset))
         |> assign(:editing_rule, nil)
         |> put_flash(:info, "Spending rule deleted successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp create_spending_rule(socket, scope, spending_rule_params) do
    case Finance.create_spending_rule(scope, spending_rule_params) do
      {:ok, _spending_rule} ->
        changeset = Finance.change_spending_rule(scope, %SpendingRule{})

        {:noreply,
         socket
         |> assign(:allocations, Finance.list_allocations(scope))
         |> assign(:spending_rules, Finance.list_spending_rules(scope))
         |> assign(:form, to_form(changeset))
         |> assign(:editing_rule, nil)
         |> put_flash(:info, "Spending rule created successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp update_spending_rule(socket, scope, spending_rule, spending_rule_params) do
    case Finance.update_spending_rule(scope, spending_rule, spending_rule_params) do
      {:ok, _spending_rule} ->
        changeset = Finance.change_spending_rule(scope, %SpendingRule{})

        {:noreply,
         socket
         |> assign(:allocations, Finance.list_allocations(scope))
         |> assign(:spending_rules, Finance.list_spending_rules(scope))
         |> assign(:form, to_form(changeset))
         |> assign(:editing_rule, nil)
         |> put_flash(:info, "Spending rule updated successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
