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
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"allocation" => allocation_params}, socket) do
    _scope = socket.assigns.current_scope

    changeset =
      %Allocation{}
      |> Allocation.changeset(allocation_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"allocation" => allocation_params}, socket) do
    scope = socket.assigns.current_scope

    case Finance.create_allocation(scope, allocation_params) do
      {:ok, _allocation} ->
        changeset = Finance.change_allocation(scope, %Allocation{})

        {:noreply,
         socket
         |> assign(:allocations, Finance.list_allocations(scope))
         |> assign(:form, to_form(changeset))
         |> put_flash(:info, "Allocation created successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
