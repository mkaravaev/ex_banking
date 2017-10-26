defmodule ExBanking.User do
  use Agent

  def start_link(name, _opts) do
    Agent.start_link(fn -> name end, [])
  end
end
