defmodule Pico.Protocol.Decoder do

  def decode(msg, secret \\ nil, iv \\ nil)

  def decode(<<"PICO", major_b::bytes-size(1), minor_b::bytes-size(1), ciphertag::bytes-size(16), body::binary>>, key, iv) do
    <<major::integer-8-unsigned>> = major_b
    <<minor::integer-8-unsigned>> = minor_b

    {version, _} = Float.parse("#{major}.#{minor}")

    body =
      if key do
        :crypto.block_decrypt(:aes_gcm, key, iv, {<<major, minor>>, body, ciphertag})
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

  def decode(s, _, _) do
    {:error, :protocol_mismatch}
  end

end
