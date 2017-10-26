defmodule ExBanking do
  @moduledoc """
  Documentation for ExBanking.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ExBanking.hello
      :world

  """

  @type user :: String.t
  @type currency :: String.t
  @type amount :: number
  @type banking_error :: {:error,
    :wrong_arguments                |
    :user_already_exists            |
    :user_does_not_exist            |
    :not_enough_money               |
    :sender_does_not_exist          |
    :receiver_does_not_exist        |
    :too_many_requests_to_user      |
    :too_many_requests_to_sender    |
    :too_many_requests_to_receiver
  }

  @spec create_user(user) :: :ok | banking_error
  def create_user(user) do
  end

  @spec deposit(user, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | banking_error
  def deposit(user, amount, currency) do
  end

  @spec withdraw(user :: String.t, amount, currency) :: {:ok, new_balance :: number} | banking_error
  def withdraw(user, amount, currency) do
  end

  @spec get_balance(user, currency) :: {:ok, balance :: number} | banking_error
  def get_balance(user, currency) do
  end

  @spec send(from_user :: String.t, to_user :: String.t, amount, currency) :: {:ok, from_user_balance_number :: number, to_user_balance_number :: number} | banking_error
  def send(from_user, to_user, amount, currency) do
  end
end
