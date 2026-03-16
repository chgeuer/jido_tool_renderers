defmodule Jido.ToolRenderers.Grep do
  @moduledoc "Renderer for `grep` and `rg` tools."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = if is_map(assigns.args), do: assigns.args, else: %{}
    pattern = args["pattern"] || args["search_pattern"] || args["query"] || ""
    path = args["path"] || args["dir_path"] || ""
    file_glob = args["glob"] || ""
    file_type = args["type"] || ""

    context =
      [path, file_glob, file_type]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")

    assigns = assign(assigns, pattern: pattern, context: context)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">🔎 grep</span>
      <code class="text-sm font-mono bg-base-200 text-base-content px-1 rounded">{@pattern}</code>
      <%= if @context != "" do %>
        <span class="text-xs text-base-content/50">{@context}</span>
      <% end %>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <Generic.error_display error_msg={@error_msg} />
    <Generic.result_pre content={@content} completed={@completed} />
    """
  end
end
