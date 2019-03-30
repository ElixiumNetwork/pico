defmodule PicoTest do
  use ExUnit.Case, async: false
  require IEx
  doctest Pico

  @test_key <<54, 105, 70, 202, 147, 53, 149, 151, 195, 245,
              254, 171, 119, 71, 127, 88, 41, 86, 116, 157, 164,
              67, 89, 55, 126, 47, 30, 230, 221, 62, 61, 132>>

  test "can encode a message properly" do
    expected =
      <<
        80, 73, 67, 79, 1, 0, 141, 46, 207, 71, 108,
        188, 79, 60, 0, 235, 176, 123, 209, 27, 246,
        238, 47, 179, 218, 21, 221, 253, 135, 24, 91,
        220, 139, 47, 240, 227, 46, 4
      >>

    assert expected == Pico.encode("SAY_HELLO", %{name: "Bob"}, @test_key)
  end

  test "can encode a message with no data" do
    expected =
      <<
        80, 73, 67, 79, 1, 0, 137, 100, 65, 3, 109, 249,
        159, 159, 139, 113, 122, 226, 57, 237, 212, 121,
        45, 40, 223, 145, 141, 89, 16, 190, 30, 144, 154,
        202, 220, 206, 168, 250
      >>

    assert expected == Pico.encode("EMPTY", @test_key)
  end

  test "rejects non-string opnames when encoding message" do
    assert {:error, _} = Pico.encode(1, %{name: "Bob"})
  end
end
