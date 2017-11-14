defmodule ExBanking.UserSupervisor do
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    children = [
      ExBanking.User
    ]

    Supervisor.init(children, strategy: :simple_one_for_one)
  end

  def new_user(user) do
    Supervisor.start_child(ExBanking.UserSupervisor, [user])
  end
end
