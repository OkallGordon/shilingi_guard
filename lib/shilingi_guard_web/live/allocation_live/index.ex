defmodule ShilingiGuardWeb.AllocationLive.Index do
  use ShilingiGuardWeb, :live_view

  alias ShilingiGuard.Finance
  alias ShilingiGuard.Finance.Allocation

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    changeset = Finance.change_allocation(scope, %Allocation{})

    {:ok,
     socket
     |> assign(:allocations, Finance.list_allocations(scope))
     |> assign(:form, to_form(changeset))
     |> assign(:editing_allocation, nil)}
  end

  @impl true
  def handle_event("validate", %{"allocation" => allocation_params}, socket) do
    allocation = socket.assigns.editing_allocation || %Allocation{}

    changeset =
      allocation
      |> Allocation.changeset(allocation_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"allocation" => allocation_params}, socket) do
    scope = socket.assigns.current_scope

    case socket.assigns.editing_allocation do
      nil ->
        create_allocation(socket, scope, allocation_params)

      allocation ->
        update_allocation(socket, scope, allocation, allocation_params)
    end
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    allocation = Finance.get_allocation!(scope, id)
    changeset = Finance.change_allocation(scope, allocation)

    {:noreply,
     socket
     |> assign(:editing_allocation, allocation)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    scope = socket.assigns.current_scope
    changeset = Finance.change_allocation(scope, %Allocation{})

    {:noreply,
     socket
     |> assign(:editing_allocation, nil)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    allocation = Finance.get_allocation!(scope, id)

    case Finance.delete_allocation(scope, allocation) do
      {:ok, _allocation} ->
        changeset = Finance.change_allocation(scope, %Allocation{})

        {:noreply,
         socket
         |> assign(:allocations, Finance.list_allocations(scope))
         |> assign(:form, to_form(changeset))
         |> assign(:editing_allocation, nil)
         |> put_flash(:info, "Allocation deleted successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp create_allocation(socket, scope, allocation_params) do
    case Finance.create_allocation(scope, allocation_params) do
      {:ok, _allocation} ->
        changeset = Finance.change_allocation(scope, %Allocation{})

        {:noreply,
         socket
         |> assign(:allocations, Finance.list_allocations(scope))
         |> assign(:form, to_form(changeset))
         |> assign(:editing_allocation, nil)
         |> put_flash(:info, "Allocation created successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        changeset = %{changeset | action: :insert}

        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp update_allocation(socket, scope, allocation, allocation_params) do
    case Finance.update_allocation(scope, allocation, allocation_params) do
      {:ok, _allocation} ->
        changeset = Finance.change_allocation(scope, %Allocation{})

        {:noreply,
         socket
         |> assign(:allocations, Finance.list_allocations(scope))
         |> assign(:form, to_form(changeset))
         |> assign(:editing_allocation, nil)
         |> put_flash(:info, "Allocation updated successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        changeset = %{changeset | action: :update}

        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
