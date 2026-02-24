defmodule Permit.Absinthe.MixProject do
  use Mix.Project

  @source_url "https://github.com/curiosum-dev/permit_absinthe"
  @version "0.2.0"

  def project do
    [
      app: :permit_absinthe,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: docs(),
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
      {:permit, "~> 0.3.3"},
      {:permit_ecto, "~> 0.2.4"},
      {:absinthe, "~> 1.7"},
      {:dataloader, "~> 2.0"},
      {:postgrex, "~> 0.21", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false}
    ]
  end

  defp docs do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/curiosum-dev/permit_absinthe"},
      main: "Permit.Absinthe",
      extras: ["README.md", "LICENSE"],
      maintainers: ["Michał Buszkiewicz"],
      source_ref: "v#{@version}",
      source_url: @source_url,
      groups_for_modules: [
        "Load & Authorize": [
          Permit.Absinthe.Resolvers.LoadAndAuthorize,
          Permit.Absinthe.Middleware
        ],
        Dataloader: [
          Permit.Absinthe.Resolvers.Dataloader
        ],
        "Schema setup": [
          Permit.Absinthe.Schema.Meta,
          Permit.Absinthe.Schema.Prototype
        ]
      ]
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
