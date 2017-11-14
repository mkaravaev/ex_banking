defmodule ExBanking.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      ExBanking.UserSupervisor,
      {Registry, keys: :unique, name: Registry.Users},
      :poolboy.child_spec(pool_name(), poolboy_conf(), [])
    ]

    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp poolboy_conf do
    [{:name, {:local, pool_name()}},
      {:worker_module, ExBanking.UserWorker},
      {:size, 10},
      {:max_overflow, 0}]

  end

  def pool_name do
    :user_worker
  end
end
