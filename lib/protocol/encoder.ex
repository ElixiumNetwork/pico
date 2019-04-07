defmodule Pico.Protocol.Encoder do

  def encode(opname, _) when not is_binary(opname) do
    {:error, "OpName must be a string"}
  end

  def encode(opname, <<0>>), do: encode_formatted(opname, <<0>>)

  def encode(opname, data) when is_map(data) do
    formatted_data = :erlang.term_to_binary(data)
    encode_formatted(opname, formatted_data)
  end

  def encode(opname, _, _, _) when not is_binary(opname) do
    {:error, "OpName must be a string"}
  end

  def encode(opname, <<0>>, key, iv), do: encode_formatted(opname, <<0>>, key, iv)

  def encode(opname, data, key, iv) when is_map(data) do
    formatted_data = :erlang.term_to_binary(data)

    encode_formatted(opname, formatted_data, key, iv)
  end

  defp encode_formatted(opname, data, key, iv) do
    body = Pico.Utilities.pad(opname <> "|" <> data, 32)

    {major, minor} = Application.get_env(:pico, :protocol_version)

    version = <<major::integer-8-unsigned, minor::integer-8-unsigned>>

    {encrypted_body, ciphertag} = :crypto.block_encrypt(:aes_gcm, key, iv, {version, body, 16})

    "PICO" <> version <> ciphertag <> encrypted_body
  end

  defp encode_formatted(opname, data) do
    body = opname <> "|" <> data

    {major, minor} = Application.get_env(:pico, :protocol_version)

    version = <<major::integer-8-unsigned, minor::integer-8-unsigned>>

    ciphertag = String.duplicate(<<0>>, 16)

    "PICO" <> version <> ciphertag <> body
  end
end
