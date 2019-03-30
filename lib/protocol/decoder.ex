defmodule Pico.Protocol.Decoder do

  def decode(msg, secret \\ nil)

  def decode(<<"PICO", major::bytes-size(1), minor::bytes-size(1), body::binary>>, secret) do
    <<major::integer-8-unsigned>> = major
    <<minor::integer-8-unsigned>> = minor

    {version, _} = Float.parse("#{major}.#{minor}")

    body =
      if secret do
        :crypto.block_decrypt(:aes_ecb, secret, body)
      else
        body
      end

    [opname, data] = String.split(body, "|", [parts: 2])

    data =
      case data do
        <<0>> -> nil
        <<0, _::binary>> -> nil
        _ -> :erlang.binary_to_term(data)
      end

    {opname, data}
  end

  def decode(s, _) do
    {:error, :protocol_mismatch}
  end

end
