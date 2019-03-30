# Pico

Pico is an end-to-end encrypted zero knowledge messaging protocol. It uses
SRP 6a in combination with AES ECB to establish an encrypted communication
channel between peers through TCP.

## Installation

This package can be installed by adding `pico` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:pico, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/pico](https://hexdocs.pm/pico).
