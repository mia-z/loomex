defmodule Loomex.MixProject do
  use Mix.Project

  def project do
    [
      app: :loomex,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps(),
      application: application(),
      elixirc_paths: elixirc_paths(Mix.env()),
    ]
  end

  def application do
    [
      extra_applications: extra_apps(Mix.env()),
      mod: {Loomex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps, do: [
    
  ]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
  
  defp extra_apps(env) do
    case env do
      :prod -> [:logger,:public_key,:crypto,:asn1,:ssl]
      :dev -> [:logger,:public_key,:crypto,:asn1,:ssl,:wx,:runtime_tools,:observer]
      :test -> [:logger,:public_key,:crypto,:asn1,:ssl,:wx,:runtime_tools,:observer, :inets]
    end
  end
end
