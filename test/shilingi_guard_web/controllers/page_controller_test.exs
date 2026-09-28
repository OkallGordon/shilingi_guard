defmodule ShilingiGuardWeb.PageControllerTest do
  use ShilingiGuardWeb.ConnCase

  test "GET / redirects unauthenticated users to login", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
