defmodule ShilingiGuardWeb.PageController do
  use ShilingiGuardWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
