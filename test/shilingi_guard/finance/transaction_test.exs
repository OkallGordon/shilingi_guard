defmodule ShilingiGuard.Finance.TransactionTest do
  use ShilingiGuard.DataCase

  alias ShilingiGuard.Finance.Transaction

  describe "changeset/2" do
    test "accepts valid transaction data" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          amount: "150.00",
          description: "Lunch"
        })

      assert changeset.valid?
    end

    test "requires amount" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          description: "Lunch"
        })

      refute changeset.valid?
      assert %{amount: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires description" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          amount: "150.00"
        })

      refute changeset.valid?
      assert %{description: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects zero amount" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          amount: "0",
          description: "Lunch"
        })

      refute changeset.valid?
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects negative amount" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          amount: "-50",
          description: "Lunch"
        })

      refute changeset.valid?
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end
  end
end
