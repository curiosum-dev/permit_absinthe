defmodule PermitAbsinthe.MixProject do
  use Mix.Project

  def project do
    [
      app: :permit_absinthe,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:permit, path: "../permit"},
      {:permit_ecto, path: "../permit_ecto", only: :test},
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5", only: :test},
      {:dataloader, "~> 2.0", only: :test}
    ]
  end
end
