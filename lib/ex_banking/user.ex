defmodule ExBanking.User do
  use Agent

  alias Registry.Users

  @default_deposit %{}

  def start_link([], {:name, user}) do
    case start_user(user) do
      {:error, {:already_started, _}} -> {:error, :user_already_exists}
      {:ok, pid} -> {:ok, pid}
    end
  end

  def balance(user, currency) do
    with pid <- find_user(user),
         {:ok, balance} <- get_balance(pid, currency) do
      {:ok, balance, currency}
    else
      {:error, error} -> {:error, error}
    end
  end

  def deposit(pid, amount) do
    Agent.update(pid, &(&1 + amount))
  end

  defp get_balance(pid, currency) do
    Agent.get(pid, &(&1))
    |> Map.get(currency, 0)
  end

  defp start_user(name) do
    name = {:via, Registry, {Registry.Users, name}}
    Agent.start_link(fn -> @default_deposit end, name: name)
  end

  defp find_user(name) do
    case search_by_name(name) |> Task.await() do
      [{pid, _}] -> pid
      [] -> {:error, :user_does_not_exist}
    end
  end

  defp search_by_name(name) do
    Task.async fn ->
      Registry.lookup(Users, name)
    end
  end

end
