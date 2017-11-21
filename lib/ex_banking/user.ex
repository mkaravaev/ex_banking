defmodule ExBanking.User do
  use GenServer
  alias Registry.Users
  import ExBanking.Money

  #CLIENT
  def start_link(_, user) do
    case start_user(user) do
      {:error, {:already_started, _}} -> {:error, :user_already_exists}
      {:ok, pid} -> {:ok, pid}
    end
  end

  def get_balance(user, currency) do
    with {:ok, pid} <- user_exist?(user) do
      perform(pid, {:balance, currency})
    else
      err -> err
    end
  end

  def deposit(user, amount, currency) do
    with {:ok, pid} <- user_exist?(user) do
      perform(pid, {:deposit, amount, currency})
    else
      err -> err
    end
  end

  def withdraw(user, amount, currency) do
    with {:ok, pid} <- user_exist?(user) do
      perform(pid, {:withdraw, amount, currency})
    else
      err -> err
    end
  end

  def send(from_user, to_user, amount, currency) do
    with {:ok, from_pid} <- user_exist?(from_user, role: "sender") do
      perform(from_pid, {:send, to_user, amount, currency})
    else
      err -> err
    end
  end

  #SERVER
  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:balance, currency}, _from, acc) do
    {:reply, {:ok, Map.get(acc, currency, 0)}, acc}
  end

  def handle_call({:deposit, amount, currency}, _from, acc) do
    new_acc = add_money(acc, wrap(amount), currency)
    {:reply, {:ok, Map.get(new_acc, currency)}, new_acc}
  end

  def handle_call({:withdraw, amount, currency}, _from, acc) do
    currency_balance = Map.get(acc, currency, 0)

    with true <- can_withdraw?(amount, currency, acc),
        {:ok, new_acc, new_currency_balance} <- extract_money(currency_balance, amount, currency, acc) do
      {:reply, {:ok, new_currency_balance}, new_acc}
    else
      err -> {:reply, err, acc}
    end
  end

  def handle_call({:send, to_user, amount, currency}, _from, acc) do
    [resp|[new_acc]] =
      with true                        <- can_withdraw?(amount, currency, acc),
           {:ok, pid}                  <- user_exist?(to_user, role: "receiver"),
           {:ok, receiver_new_balance} <- perform(pid, {:deposit, amount, currency}),
           {:ok, sender_new_acc, _}    <- extract_money(Map.get(acc, currency, 0), amount, currency, acc) do
        [{:ok, Map.get(sender_new_acc, currency), receiver_new_balance}, sender_new_acc]
      else
        false -> [{:error, :not_enought_money}, acc]
        {:error, :too_many_requests_to_user} -> [{:error, :too_many_requests_to_receiver}, acc]
        {:error, error} -> [{:error, error}, acc]
      end

    {:reply, resp, new_acc}
  end

  def perform(pid, request) do
    with :none <- limit_exceed?(pid) do
      GenServer.call(pid, request)
    else
      err -> err
    end
  end

  defp limit_exceed?(pid) do
    {_, length} = :erlang.process_info(pid, :message_queue_len)

    case length < 10 do
      true -> :none
      false -> {:error, :too_many_requests_to_user}
    end
  end

  defp make_user_not_exist_msg(opts) do
    str = Keyword.get(opts, :role, "user")
    String.to_atom("#{str}_does_not_exist")
  end

  defp user_exist?(name, opts\\[]) do
    case Registry.lookup(Users, name) do
      [] -> {:error, make_user_not_exist_msg(opts)}
      [{pid, _}] -> {:ok, pid}
    end
  end

  defp start_user(name) do
    GenServer.start_link(__MODULE__, [], name: via_tuple(name))
  end

  defp via_tuple(name) do
    {:via, Registry, {Registry.Users, name}}
  end
end
