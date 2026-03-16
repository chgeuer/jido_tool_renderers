defmodule Jido.ToolRenderers.WebFetch do
  @moduledoc "Renderer for the `web_fetch` tool."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = assigns.args || %{}
    url = args["url"] || ""
    raw = args["raw"] || false

    md_id = "wf-#{assigns.tool_call_id || System.unique_integer([:positive])}"
    assigns = assign(assigns, url: url, raw: raw, md_id: md_id)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-accent badge-sm">🌐 web_fetch</span>
      <a href={@url} target="_blank" class="text-sm link link-primary truncate max-w-lg">{@url}</a>
      <%= if @raw do %>
        <span class="badge badge-ghost badge-xs">raw</span>
      <% end %>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <Generic.error_display error_msg={@error_msg} />
    <Generic.result_markdown content={@content} completed={@completed} md_id={@md_id} />
    """
  end
end
