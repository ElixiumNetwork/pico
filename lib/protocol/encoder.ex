defmodule Pico.Protocol.Encoder do

  def encode(opname, _) when not is_binary(opname) do
    {:error, "OpName must be a string"}
  end

  def encode(opname, <<0>>), do: encode_formatted(opname, <<0>>)

  def encode(opname, data) when is_map(data) do
    formatted_data = :erlang.term_to_binary(data)
    encode_formatted(opname, formatted_data)
  end

  def encode(opname, _, _) when not is_binary(opname) do
    {:error, "OpName must be a string"}
  end

  def encode(opname, <<0>>, key), do: encode_formatted(opname, <<0>>, key)

  def encode(opname, data, key) when is_map(data) do
    formatted_data = :erlang.term_to_binary(data)
    encode_formatted(opname, formatted_data, key)
  end

  defp encode_formatted(opname, data, key) do
    body = Pico.Utilities.pad(opname <> "|" <> data, 32)

    encrypted_body = :crypto.block_encrypt(:aes_ecb, key, body)
    header = generate_header(encrypted_body)

    header <> encrypted_body
  end

  defp encode_formatted(opname, data) do
    body = opname <> "|" <> data
    header = generate_header(body)

    header <> body
  end

  defp generate_header(body) do
    {major, minor} = Application.get_env(:pico, :protocol_version)

    <<"PICO", major::integer-8-unsigned, minor::integer-8-unsigned>>
  end
end
