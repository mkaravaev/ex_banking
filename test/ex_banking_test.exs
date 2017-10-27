defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

  describe "&create_user/1" do
    test "should create new user when args is string" do
      ExBanking.create_user("hello")
      refute Registry.lookup(Registry.Users, "hello") == []
    end

    test "should response with error when user already exists" do
      ExBanking.create_user("hello")
      assert ExBanking.create_user("hello") == {:error, :user_already_exists}
    end

    test "should response with error when args are bad" do
      assert ExBanking.create_user(:hello) == {:error, :wrong_arguments}
    end
  end
end
