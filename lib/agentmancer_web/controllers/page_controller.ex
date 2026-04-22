defmodule AgentmancerWeb.PageController do
  use AgentmancerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
