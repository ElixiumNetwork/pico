defmodule PicoTest do
  use ExUnit.Case, async: false
  require IEx
  doctest Pico

  @test_key <<54, 105, 70, 202, 147, 53, 149, 151, 195, 245,
              254, 171, 119, 71, 127, 88, 41, 86, 116, 157, 164,
              67, 89, 55, 126, 47, 30, 230, 221, 62, 61, 132>>

  @test_iv <<88, 224, 24, 207, 1, 249, 117, 43, 69, 76, 78, 94, 136, 137, 185, 162>>

  test "can encode a message properly" do
    expected =
      <<80, 73, 67, 79, 1, 0, 136, 113, 199, 119,
        1, 147, 206, 151, 20, 51, 254, 118, 74, 88,
        197, 142, 60, 241, 167, 8, 185, 107, 150,
        163, 132, 44, 228, 20, 49, 195, 95, 236, 221,
        137, 26, 105, 168, 26, 132, 87, 33, 125, 159,
        126, 193, 213, 244>>

    assert expected == Pico.encode("SAY_HELLO", %{name: "Bob"}, @test_key, @test_iv)
  end

  test "can encode a message with no data" do
    expected =
      <<80, 73, 67, 79, 1, 0, 4, 55, 110, 209, 239,
        10, 126, 141, 195, 78, 251, 208, 148, 94,
        174, 109, 42, 253, 174, 3, 168, 82, 218>>

    assert expected == Pico.encode("EMPTY", @test_key, @test_iv)
  end

  test "rejects non-string opnames when encoding message" do
    assert {:error, _} = Pico.encode(1, %{name: "Bob"}, @test_key, @test_iv)
  end
end
