defmodule ExBanking.User do
  use GenServer
  alias Registry.Users

  #CLIENT
  def start_link(_, user) do
    case start_user(user) do
      {:error, {:already_started, _}} -> {:error, :user_already_exists}
      {:ok, pid} -> {:ok, pid}
    end
  end

  def get_balance(user, currency) do
    perform(user, {:balance, currency})
  end

  def deposit(user, amount, currency) do
    perform(user, {:deposit, amount, currency})
  end

  def withdraw(user, amount, currency) do
    perform(user, {:withdraw, amount, currency})
  end

  def send(from_user, to_user, amount, currency) do
    perform(from_user, {:send, to_user, amount, currency})
  end

  #SERVER
  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:balance, currency}, _from, acc) do
    {:reply, {:ok, Map.get(acc, currency, 0)}, acc}
  end

  def handle_call({:deposit, amount, currency}, _from, acc) do
    new_acc = add_money(acc, amount, currency)
    {:reply, {:ok, new_acc}, new_acc}
  end

  def handle_call({:withdraw, amount, currency}, _from, acc) do
    currency_balance = Map.get(acc, currency, 0)

    case extract_money(currency_balance, amount, currency, acc) do
      {:ok, new_acc, new_currency_balance} -> {:reply, {:ok, new_currency_balance}, new_acc}
      {:error, error} -> {:reply, {:error, error}, acc}
    end
  end

  def handle_call({:send, to_user, amount, currency}, _from, acc) do
    [resp|[new_acc]] =
      with true <- can_withdraw?(amount, currency, acc),
           {:ok, receiver_new_balance} <- perform(to_user, {:deposit, amount, currency}),
           sender_new_acc <- Map.merge(acc, Map.new([{currency, Map.get(acc, currency, 0) - amount}])) do
        [{:ok, Map.get(sender_new_acc, currency), Map.get(receiver_new_balance, currency)}, sender_new_acc]
      else
        false -> [{:error, :not_enought_money}, acc]
        {:error, :too_many_requests_to_user} -> [{:error, :too_many_requests_to_receiver}, acc]
        {:error, error} -> [{:error, error}, acc]
      end

    {:reply, resp, new_acc}
  end

  def perform(user, request) do
    with {:ok, pid} <- user_exist?(user),
         :ok <- limit_exceed?(pid) do
      GenServer.call(pid, request)
    else
      err -> err
    end
  end

  defp limit_exceed?(pid) do
    {_, length} = :erlang.process_info(pid, :message_queue_len)

    case length < 10 do
      true -> :ok
      false -> {:error, :too_many_reuests_to_user}
    end
  end

  defp user_exist?(name) do
    case Registry.lookup(Users, name) do
      [] -> {:error, :user_does_not_exist}
      [{pid, _}] -> {:ok, pid}
    end
  end

  defp can_withdraw?(amount, currency, acc) do
    Map.get(acc, currency, 0) >= amount
  end

  defp start_user(name) do
    GenServer.start_link(__MODULE__, [], name: via_tuple(name))
  end

  defp via_tuple(name) do
    {:via, Registry, {Registry.Users, name}}
  end

  defp add_money(account, amount, currency) do
    map = Map.new([{currency, amount}])

    Map.merge(account, map, fn(_currency, old_amount, new_amount) ->
      old_amount + new_amount
    end)
  end

  defp extract_money(old_amount, new_amount, currency, acc) do
    new_balance = old_amount - new_amount
    new_currency_state = Map.new([{currency, new_balance}])

    {:ok, Map.merge(acc, new_currency_state), new_balance}
  end
end
