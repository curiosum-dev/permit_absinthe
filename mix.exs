defmodule Permit.Absinthe.MixProject do
  use Mix.Project

  def project do
    [
      app: :permit_absinthe,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:permit, "~> 0.2.1"},
      {:permit_ecto, "~> 0.2.3"},
      {:absinthe, "~> 1.7"},
      {:dataloader, "~> 2.0"}
    ]
  end
end
