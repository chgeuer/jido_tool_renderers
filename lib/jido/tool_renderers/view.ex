defmodule Jido.ToolRenderers.View do
  @moduledoc "Renderer for the `view` tool. Renders .md content as markdown."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = if is_map(assigns.args), do: assigns.args, else: %{}
    path = args["path"] || args["file_path"] || ""
    is_md = String.ends_with?(path, ".md")

    md_id = "vw-#{assigns.tool_call_id || System.unique_integer([:positive])}"
    assigns = assign(assigns, path: path, is_md: is_md, md_id: md_id)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">👁 view</span>
      <span class="text-sm font-mono text-base-content/70 truncate">{@path}</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
      <%= if @completed && @content != "" do %>
        <span class="text-xs text-base-content/50">{String.length(@content)} chars</span>
      <% end %>
    </div>
    <Generic.error_display error_msg={@error_msg} />
    <%= if @completed && @content != "" do %>
      <%= if @is_md do %>
        <Generic.result_markdown content={@content} completed={@completed} md_id={@md_id} />
      <% else %>
        <Generic.result_pre content={@content} completed={@completed} />
      <% end %>
    <% end %>
    """
  end
end
