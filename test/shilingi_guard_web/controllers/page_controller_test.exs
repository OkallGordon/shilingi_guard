defmodule ShilingiGuardWeb.PageControllerTest do
  use ShilingiGuardWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Take control of your money."
  end
end
