defmodule Jido.ToolRenderers.Glob do
  @moduledoc "Renderer for the `glob` tool."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = if is_map(assigns.args), do: assigns.args, else: %{}
    pattern = args["pattern"] || args["search_pattern"] || ""
    path = args["path"] || args["dir_path"] || ""

    assigns = assign(assigns, pattern: pattern, search_path: path)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">📁 glob</span>
      <code class="text-sm font-mono bg-base-200 text-base-content px-1 rounded">{@pattern}</code>
      <%= if @search_path != "" do %>
        <span class="text-xs text-base-content/50">{@search_path}</span>
      <% end %>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <Generic.error_display error_msg={@error_msg} />
    <Generic.result_pre content={@content} completed={@completed} />
    """
  end
end
