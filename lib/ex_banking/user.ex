defmodule ExBanking.User do
  use GenServer

  @default_demand 0
  @init_account %{}

  def start_link(_, user) do
    case start_user(user) do
      {:error, {:already_started, _}} -> {:error, :user_already_exists}
      {:ok, pid} -> {:ok, pid}
    end
  end

  def init(_) do
    {:ok, {Queue.new(), @default_demand, @init_account}}
  end

  def handle_call({:balance, currency}, _from, {_q, _demand, acc} = state) do
    {:reply, {:ok, Map.get(acc, currency, 0)}, state}
  end

  def handle_call({:insert, _event}, _from, {_q, demand, _acc} = state) when demand >= 10 do
    {:reply, {:error, :too_many_requests_to_user}, state}
  end
  def handle_call({:insert, event}, from, {q, demand, acc}) do
    queue =
      Queue.insert(q, Tuple.append(event, from))
      |> dispatch_events(demand + 1, acc)

    {:noreply, {queue, demand + 1, acc}}
  end

  def handle_info({:deposit, {amount, currency}, from}, {q, demand, acc}) do
    new_acc = add_money(acc, amount, currency)
    GenServer.reply(from, {:ok, new_acc})

    {:noreply, {q, demand - 1, new_acc}}
  end

  def handle_info({:withdraw, {withdraw_amount, currency}, from}, {q, demand, acc}) do
    currency_balance = Map.get(acc, currency, 0)

    case extract_money(currency_balance, withdraw_amount, currency, acc) do

      {:ok, new_acc, new_currency_balance} ->
        GenServer.reply(from, {:ok, new_currency_balance})
        {:noreply, {q, demand - 1, new_acc}}

      {:error, error} ->
        GenServer.reply(from, {:error, error})
        {:noreply, {q, demand - 1, acc}}
    end
  end

  def handle_info({:send, {to_pid, amount, currency}, from}, {q, demand, acc}) do
    [resp|[acc]] =
      with true <- can_withdraw?(amount, currency, acc),
           {:ok, receiver_new_balance} <- GenServer.call(to_pid, {:insert, {:deposit, {amount, currency}}}),
           sender_new_acc <- Map.merge(acc, Map.new([{currency, Map.get(acc, currency, 0) - amount}])) do
        [{:ok, Map.get(sender_new_acc, currency), Map.get(receiver_new_balance, currency)}, sender_new_acc]
      else
        false -> [{:error, :not_enought_money}, acc]
        {:error, :too_many_requests_to_user} -> [{:error, :too_many_requests_to_receiver}, acc]
        {:error, error} -> [{:error, error}, acc]
      end


    GenServer.reply(from, resp)
    {:noreply, {q, demand - 1, acc}}
  end

  defp can_withdraw?(amount, currency, acc) do
    Map.get(acc, currency, 0) >= amount
  end

  defp dispatch_events(queue, 0, _acc), do: queue
  defp dispatch_events(queue, demand, acc) do
    case Queue.pop(queue) do
      {nil, queue}           -> queue
      {event, updated_queue} ->
        send(self(), event)
        dispatch_events(updated_queue, demand - 1, acc)
    end
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
