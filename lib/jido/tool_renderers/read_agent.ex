defmodule Jido.ToolRenderers.ReadAgent do
  @moduledoc "Renderer for `read_agent` and `list_agents` tools."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic
  alias Jido.ToolRenderers.Components

  def render(assigns) do
    args = assigns.args || %{}

    case assigns.tool do
      "list_agents" -> render_list(assigns)
      _ -> render_read(assigns, args)
    end
  end

  defp render_read(assigns, args) do
    agent_id = args["agent_id"] || ""
    wait = args["wait"]
    timeout = args["timeout"]

    md_id = "ra-#{assigns.tool_call_id || System.unique_integer([:positive])}"

    # Parse agent result — first line often has metadata
    {meta_line, body} =
      case String.split(assigns.content, "\n", parts: 2) do
        [meta, rest] -> {meta, rest}
        [single] -> {single, ""}
        _ -> {"", ""}
      end

    assigns =
      assign(assigns,
        agent_id: agent_id,
        wait: wait,
        timeout: timeout,
        meta_line: meta_line,
        body: body,
        md_id: md_id
      )

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-secondary badge-sm">📡 read_agent</span>
      <span class="text-sm font-mono text-base-content/70">{@agent_id}</span>
      <%= if @wait do %>
        <span class="badge badge-ghost badge-xs">wait</span>
      <% end %>
      <%= if @timeout do %>
        <span class="badge badge-ghost badge-xs">{@timeout}s</span>
      <% end %>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <%= if @meta_line != "" do %>
      <div class="text-xs text-base-content/50 mt-1 font-mono">{@meta_line}</div>
    <% end %>
    <%= if @body != "" do %>
      <details class="text-xs" open>
        <summary class="cursor-pointer text-base-content/50">Agent result</summary>
        <div class="mt-1 p-3 bg-base-100 border border-base-300 rounded max-h-96 overflow-y-auto">
          <Components.markdown_content
            id={@md_id}
            content={@body}
            class="text-sm"
          />
        </div>
      </details>
    <% end %>
    <Generic.error_display error_msg={@error_msg} />
    """
  end

  defp render_list(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-secondary badge-sm">📋 list_agents</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <Generic.result_pre content={@content} completed={@completed} />
    <Generic.error_display error_msg={@error_msg} />
    """
  end
end
