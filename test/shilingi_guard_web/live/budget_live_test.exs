defmodule ShilingiGuardWeb.BudgetLiveTest do
  use ShilingiGuardWeb.ConnCase

  import Phoenix.LiveViewTest
  import ShilingiGuard.FinanceFixtures

  @create_attrs %{
    name: "some name",
    status: "active",
    starts_on: "2026-10-01",
    ends_on: "2026-10-01"
  }

  @update_attrs %{
    name: "some updated name",
    status: "completed",
    starts_on: "2026-10-02",
    ends_on: "2026-10-02"
  }

  @invalid_attrs %{
    name: nil,
    status: "active",
    starts_on: nil,
    ends_on: nil
  }

  setup :register_and_log_in_user

  defp create_budget(%{scope: scope}) do
    budget = budget_fixture(scope)

    %{budget: budget}
  end

  describe "Index" do
    setup [:create_budget]

    test "lists all budgets", %{conn: conn, budget: budget} do
      {:ok, _index_live, html} = live(conn, ~p"/budgets")

      assert html =~ "Budgets"
      assert html =~ budget.name
    end

    test "saves new budget", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/budgets")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Budget")
               |> render_click()
               |> follow_redirect(conn, ~p"/budgets/new")

      assert render(form_live) =~ "New Budget"

      assert form_live
             |> form("#budget-form", budget: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#budget-form", budget: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/budgets")

      html = render(index_live)
      assert html =~ "Budget created successfully"
      assert html =~ "some name"
    end

    test "updates budget in listing", %{conn: conn, budget: budget} do
      {:ok, index_live, _html} = live(conn, ~p"/budgets")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#budgets-#{budget.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/budgets/#{budget}/edit")

      assert render(form_live) =~ "Edit Budget"

      assert form_live
             |> form("#budget-form", budget: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#budget-form", budget: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/budgets")

      html = render(index_live)
      assert html =~ "Budget updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes budget in listing", %{conn: conn, budget: budget} do
      {:ok, index_live, _html} = live(conn, ~p"/budgets")

      assert index_live
             |> element("#budgets-#{budget.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#budgets-#{budget.id}")
    end
  end

  describe "Show" do
    setup [:create_budget]

    test "displays budget", %{conn: conn, budget: budget} do
      {:ok, _show_live, html} = live(conn, ~p"/budgets/#{budget}")

      assert html =~ budget.name
      assert html =~ "Starts on"
      assert html =~ "Ends on"
      assert html =~ "Status"
    end

    test "updates budget and returns to show", %{conn: conn, budget: budget} do
      {:ok, show_live, _html} = live(conn, ~p"/budgets/#{budget}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit budget")
               |> render_click()
               |> follow_redirect(conn, ~p"/budgets/#{budget}/edit?return_to=show")

      assert render(form_live) =~ "Edit Budget"

      assert form_live
             |> form("#budget-form", budget: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#budget-form", budget: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/budgets/#{budget}")

      html = render(show_live)
      assert html =~ "Budget updated successfully"
      assert html =~ "some updated name"
    end
  end
end
