defmodule Permit.Absinthe.MixProject do
  use Mix.Project

  @source_url "https://github.com/curiosum-dev/permit_absinthe"

  def project do
    [
      app: :permit_absinthe,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: [
        main: "Permit.Absinthe",
        extras: ["README.md", "LICENSE"]
      ],
      test_coverage: [tool: ExCoveralls]
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
      {:dataloader, "~> 2.0"},
      {:postgrex, "~> 0.21", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Michał Buszkiewicz"],
      description:
        "Permit.Absinthe provides integration between the Permit authorization library and Absinthe GraphQL for Elixir."
    ]
  end
end
