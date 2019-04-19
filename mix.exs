defmodule Pico.MixProject do
  use Mix.Project

  def project do
    [
      app: :pico,
      version: "0.1.2",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Pico",
      description: "An implementation of the Pico zero-knowledge peer to peer protocol",
      source_url: "https://github.com/ElixiumNetwork/pico",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [
        :logger,
        :crypto
      ],
      env: [
        protocol_version: {1, 0}
      ]
    ]
  end

  defp deps do
    [
        {:strap, "~> 0.1.1"},
        {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "pico",
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Alex Dovzhanyn"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ElixiumNetwork/pico"}
    ]
  end
end
