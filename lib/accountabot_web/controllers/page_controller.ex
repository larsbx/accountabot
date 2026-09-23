defmodule AccountabotWeb.PageController do
  use AccountabotWeb, :controller

  def home(conn, _), do: redirect(conn, to: ~p"/review/demo")
end
