defmodule ShilingiGuardWeb.AllocationLive.IndexTest do
use ShilingiGuardWeb.ConnCase

import Phoenix.LiveViewTest
import ShilingiGuard.AccountsFixtures
import ShilingiGuard.FinanceFixtures

alias ShilingiGuard.Finance

describe "Index" do
test "requires authentication", %{conn: conn} do
assert {:error, {:redirect, %{to: "/users/log-in"}}} =
live(conn, "/allocations")
end

test "renders the allocations page", %{conn: conn} do
  scope = user_scope_fixture()
  conn = log_in_user(conn, scope.user)

  {:ok, _view, html} = live(conn, "/allocations")

  assert html =~ "Your Allocations"
  assert html =~ "Create an allocation"
  assert html =~ "Your allocations"
end

test "renders existing allocations", %{conn: conn} do
  scope = user_scope_fixture()
  allocation = allocation_fixture(scope)

  conn = log_in_user(conn, scope.user)

  {:ok, _view, html} = live(conn, "/allocations")

  assert html =~ allocation.name
  assert html =~ allocation.type
end

test "does not render another user's allocations", %{conn: conn} do
  scope = user_scope_fixture()
  other_scope = user_scope_fixture()

  _other_allocation =
    allocation_fixture(other_scope, %{
      name: "Other user's allocation"
    })

  conn = log_in_user(conn, scope.user)

  {:ok, _view, html} = live(conn, "/allocations")

  refute html =~ "Other user's allocation"
end

test "validates allocation form", %{conn: conn} do
  scope = user_scope_fixture()
  conn = log_in_user(conn, scope.user)

  {:ok, view, _html} = live(conn, "/allocations")

  html =
    view
    |> form("#allocation_form", allocation: %{
      name: "",
      amount: "0",
      type: ""
    })
    |> render_change()

  assert html =~ "can&#39;t be blank"
  assert html =~ "must be greater than 0"
end

test "creates an allocation", %{conn: conn} do
  scope = user_scope_fixture()
  conn = log_in_user(conn, scope.user)

  {:ok, view, _html} = live(conn, "/allocations")

  assert view
         |> form("#allocation_form", allocation: %{
           name: "Food",
           amount: "9000",
           type: "spending"
         })
         |> render_submit() =~ "Allocation created successfully."

  assert render(view) =~ "Food"

  allocations = Finance.list_allocations(scope)

  assert [%{name: "Food", type: "spending"}] = allocations
end

test "rejects invalid allocation data", %{conn: conn} do
  scope = user_scope_fixture()
  conn = log_in_user(conn, scope.user)

  {:ok, view, _html} = live(conn, "/allocations")

  html =
    view
    |> form("#allocation_form", allocation: %{
      name: "",
      amount: "-100",
      type: ""
    })
    |> render_submit()

  assert html =~ "can&#39;t be blank"
  assert html =~ "must be greater than 0"

  assert Finance.list_allocations(scope) == []
end

test "starts editing an allocation", %{conn: conn} do
  scope = user_scope_fixture()

  allocation =
    allocation_fixture(scope, %{
      name: "Food",
      amount: "9000",
      type: "spending"
    })

  conn = log_in_user(conn, scope.user)

  {:ok, view, html} = live(conn, "/allocations")

  assert html =~ "Food"

  html =
    view
    |> element("button[phx-click='edit'][phx-value-id='#{allocation.id}']")
    |> render_click()

  assert html =~ "Edit allocation"
  assert html =~ "Save changes"
  assert html =~ "value=\"Food\""
  assert html =~ "value=\"9000\""
end

test "updates an allocation", %{conn: conn} do
  scope = user_scope_fixture()

  allocation =
    allocation_fixture(scope, %{
      name: "Food",
      amount: "9000",
      type: "spending"
    })

  conn = log_in_user(conn, scope.user)

  {:ok, view, _html} = live(conn, "/allocations")

  view
  |> element("button[phx-click='edit'][phx-value-id='#{allocation.id}']")
  |> render_click()

  html =
    view
    |> form("#allocation_form", allocation: %{
      name: "Groceries",
      amount: "7500",
      type: "spending"
    })
    |> render_submit()

  assert html =~ "Allocation updated successfully."
  assert html =~ "Groceries"

  updated_allocation = Finance.get_allocation!(scope, allocation.id)

  assert updated_allocation.name == "Groceries"
  assert Decimal.equal?(updated_allocation.amount, Decimal.new("7500"))
  assert updated_allocation.type == "spending"
end

test "cancels editing an allocation", %{conn: conn} do
  scope = user_scope_fixture()

  allocation =
    allocation_fixture(scope, %{
      name: "Food",
      amount: "9000",
      type: "spending"
    })

  conn = log_in_user(conn, scope.user)

  {:ok, view, _html} = live(conn, "/allocations")

  view
  |> element("button[phx-click='edit'][phx-value-id='#{allocation.id}']")
  |> render_click()

  html =
    view
    |> element("button[phx-click='cancel_edit']")
    |> render_click()

  assert html =~ "Create an allocation"
  refute html =~ "Save changes"
end

test "deletes an allocation", %{conn: conn} do
  scope = user_scope_fixture()

  allocation =
    allocation_fixture(scope, %{
      name: "Food",
      amount: "9000",
      type: "spending"
    })

  conn = log_in_user(conn, scope.user)

  {:ok, view, html} = live(conn, "/allocations")

  assert html =~ "Food"

  html =
    view
    |> element("button[phx-click='delete'][phx-value-id='#{allocation.id}']")
    |> render_click()

  assert html =~ "Allocation deleted successfully."

  assert html =~
           "Create your first allocation to start giving your money a purpose."

  assert_raise Ecto.NoResultsError, fn ->
    Finance.get_allocation!(scope, allocation.id)
  end
end

test "cannot edit another user's allocation", %{conn: conn} do
  scope = user_scope_fixture()
  other_scope = user_scope_fixture()

  other_allocation =
    allocation_fixture(other_scope, %{
      name: "Other user's Food",
      amount: "9000",
      type: "spending"
    })

  conn = log_in_user(conn, scope.user)

  {:ok, _view, html} = live(conn, "/allocations")

  refute html =~ "Other user's Food"

  assert_raise Ecto.NoResultsError, fn ->
    Finance.get_allocation!(scope, other_allocation.id)
  end

  other_allocation = Finance.get_allocation!(other_scope, other_allocation.id)

  assert other_allocation.name == "Other user's Food"
  assert Decimal.equal?(other_allocation.amount, Decimal.new("9000"))
  assert other_allocation.type == "spending"
end

test "cannot delete another user's allocation", %{conn: conn} do
  scope = user_scope_fixture()
  other_scope = user_scope_fixture()

  other_allocation =
    allocation_fixture(other_scope, %{
      name: "Other user's Food",
      amount: "9000",
      type: "spending"
    })

  conn = log_in_user(conn, scope.user)

  {:ok, _view, html} = live(conn, "/allocations")

  refute html =~ "Other user's Food"

  assert_raise Ecto.NoResultsError, fn ->
    Finance.get_allocation!(scope, other_allocation.id)
  end

  other_allocation = Finance.get_allocation!(other_scope, other_allocation.id)

  assert other_allocation.name == "Other user's Food"
  assert Decimal.equal?(other_allocation.amount, Decimal.new("9000"))
  assert other_allocation.type == "spending"
end
end
end
