defmodule ExBanking.Money do
  alias Decimal, as: D

  def add_money(account, amount, currency) do
    map = Map.new([{currency, amount |> D.new |> D.round(2, :down) |> D.to_float}])

    Map.merge(account, map, fn(_currency, old_amount, new_amount) ->
      D.add(D.new(old_amount), D.new(new_amount))
      |> D.round(2, :down)
      |> D.to_float
    end)
  end

  def extract_money(old_amount, new_amount, currency, acc) do
    new_balance = D.sub(D.new(old_amount), D.new(new_amount))
                  |> D.round(2, :down)
                  |> D.to_float
    new_currency_state = Map.new([{currency, new_balance}])

    {:ok, Map.merge(acc, new_currency_state), new_balance}
  end

  def can_withdraw?(amount, currency, acc) do
    current_balance = Map.get(acc, currency, 0) |> wrap()
      case current_balance >= wrap(amount) do
      false -> {:error, :not_enough_money}
      true -> true
    end
  end

  def wrap(val) do
    D.new(val)
    |> D.round(2, :down)
    |> D.to_float
  end
end
