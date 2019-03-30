defmodule Pico.Utilities do

  def pad(data, block_size) do
    to_add = block_size - rem(byte_size(data), block_size)
    data <> String.duplicate(<<to_add>>, to_add)
  end

end
