defmodule ShilingiGuardWeb.SpendingRuleLive.IndexTest do
  use ShilingiGuardWeb.ConnCase

  import Phoenix.LiveViewTest
  import ShilingiGuard.AccountsFixtures
  import ShilingiGuard.FinanceFixtures

  alias ShilingiGuard.Finance

  describe "Index" do
    test "requires authentication", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, "/spending-rules")
    end

    test "renders the spending rules page", %{conn: conn} do
      scope = user_scope_fixture()
      conn = log_in_user(conn, scope.user)

      {:ok, _view, html} = live(conn, "/spending-rules")

      assert html =~ "Spending Rules"
      assert html =~ "Add a spending rule"
      assert html =~ "Your spending rules"
    end

    test "renders existing spending rules", %{conn: conn} do
      scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule =
        spending_rule_fixture(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, _view, html} = live(conn, "/spending-rules")

      assert html =~ "Food"
      assert html =~ spending_rule.period
      assert html =~ "300"
    end

    test "does not render another user's spending rules", %{conn: conn} do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()

      other_allocation =
        allocation_fixture(other_scope, %{
          name: "Other user's Food",
          amount: "9000",
          type: "spending"
        })

      _other_rule =
        spending_rule_fixture(other_scope, %{
          allocation_id: other_allocation.id,
          period: "daily",
          limit_amount: "300"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, _view, html} = live(conn, "/spending-rules")

      refute html =~ "Other user's Food"
    end

    test "validates spending rule form", %{conn: conn} do
      scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, view, _html} = live(conn, "/spending-rules")

      html =
        view
        |> form("#spending_rule_form", spending_rule: %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "0"
        })
        |> render_change()

      assert html =~ "must be greater than 0"
    end

    test "creates a spending rule", %{conn: conn} do
      scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, view, _html} = live(conn, "/spending-rules")

      html =
        view
        |> form("#spending_rule_form", spending_rule: %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300"
        })
        |> render_submit()

      assert html =~ "Spending rule created successfully."
      assert html =~ "Food"

      rules = Finance.list_spending_rules(scope)

      assert [%{period: "daily"} = rule] = rules
      assert Decimal.equal?(rule.limit_amount, Decimal.new("300"))
      assert rule.allocation_id == allocation.id
    end

    test "rejects invalid spending rule data", %{conn: conn} do
      scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, view, _html} = live(conn, "/spending-rules")

      html =
        view
        |> form("#spending_rule_form", spending_rule: %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "-100"
        })
        |> render_submit()

      assert html =~ "must be greater than 0"
      assert Finance.list_spending_rules(scope) == []
    end

    test "cannot create a spending rule for another user's allocation", %{} do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()

      other_allocation =
        allocation_fixture(other_scope, %{
          name: "Other user's Food",
          amount: "9000",
          type: "spending"
        })

      assert_raise Ecto.NoResultsError, fn ->
        Finance.create_spending_rule(scope, %{
          "allocation_id" => other_allocation.id,
          "period" => "daily",
          "limit_amount" => "300"
        })
      end

      assert Finance.list_spending_rules(scope) == []
      assert Finance.list_spending_rules(other_scope) == []
    end

    test "edits a spending rule", %{conn: conn} do
      scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule =
        spending_rule_fixture(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, view, html} = live(conn, "/spending-rules")

      assert html =~ "Add a spending rule"

      html =
        view
        |> element("button", "Edit")
        |> render_click()

      assert html =~ "Edit spending rule"
      assert html =~ "Save changes"
      assert html =~ "300"
      assert html =~ "daily"

      assert has_element?(view, "#spending_rule_form")
      assert has_element?(view, "button", "Cancel")
      assert spending_rule.id
    end

    test "updates a spending rule", %{conn: conn} do
      scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule =
        spending_rule_fixture(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, view, _html} = live(conn, "/spending-rules")

      view
      |> element("button", "Edit")
      |> render_click()

      html =
       view
      |> form("#spending_rule_form", spending_rule: %{
      period: "weekly",
      limit_amount: "1000"
       })
      |> render_submit()

      assert html =~ "Spending rule updated successfully."
      assert html =~ "Weekly"

      updated_rule = Finance.get_spending_rule!(scope, spending_rule.id)

      assert updated_rule.period == "weekly"
      assert Decimal.equal?(updated_rule.limit_amount, Decimal.new("1000"))
      assert updated_rule.allocation_id == allocation.id
    end

    test "cancels editing a spending rule", %{conn: conn} do
      scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      _spending_rule =
        spending_rule_fixture(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, view, _html} = live(conn, "/spending-rules")

      view
      |> element("button", "Edit")
      |> render_click()

      assert has_element?(view, "button", "Cancel")
      assert has_element?(view, "button", "Save changes")

      html =
        view
        |> element("button", "Cancel")
        |> render_click()

      assert html =~ "Add a spending rule"
      refute has_element?(view, "button", "Cancel")
      assert has_element?(view, "button", "Add spending rule")
    end

    test "deletes a spending rule", %{conn: conn} do
      scope = user_scope_fixture()

      allocation =
        allocation_fixture(scope, %{
          name: "Food",
          amount: "9000",
          type: "spending"
        })

      spending_rule =
        spending_rule_fixture(scope, %{
          allocation_id: allocation.id,
          period: "daily",
          limit_amount: "300"
        })

      conn = log_in_user(conn, scope.user)

      {:ok, view, html} = live(conn, "/spending-rules")

      assert html =~ "Food"
      assert html =~ "300"

      html =
        view
        |> element("button", "Delete")
        |> render_click()

      assert html =~ "Spending rule deleted successfully."
      assert html =~ "You don&#39;t have any spending rules yet."

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_spending_rule!(scope, spending_rule.id)
      end
    end
  end
end
