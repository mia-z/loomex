defmodule Loomex.MixProject do
  use Mix.Project

  def project do
    [
      app: :loomex,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps(),
      application: application()
    ]
  end

  def application do
    [
      extra_applications: extra_apps(Mix.env),
      mod: {Loomex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps, do: []

  def extra_apps(env) do
    case env do
      :prod -> [:logger,:public_key,:crypto,:asn1,:ssl,:observer]
      :dev -> [:logger,:public_key,:crypto,:asn1,:ssl,:observer,:wx,:runtime_tools,:observer]
      :test -> [:logger,:public_key,:crypto,:asn1,:ssl,:observer,:wx,:runtime_tools,:observer]
    end
  end
end
