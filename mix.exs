defmodule JidoToolRenderers.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_tool_renderers,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
