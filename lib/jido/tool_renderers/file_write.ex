defmodule Jido.ToolRenderers.FileWrite do
  @moduledoc "Renderer for `create` and `edit` tools."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = if is_map(assigns.args), do: assigns.args, else: %{}
    path = args["path"] || args["file_path"] || ""
    file_text = args["file_text"] || args["new_str"] || args["content"] || ""
    is_md = String.ends_with?(path, ".md")
    is_edit = assigns.tool in ["edit", "Edit", "replace"]
    old_str = args["old_str"] || args["old_string"] || ""

    md_id = "fw-#{assigns.tool_call_id || System.unique_integer([:positive])}"
    icon = if is_edit, do: "✏️ edit", else: "📝 create"

    assigns =
      assign(assigns,
        path: path,
        file_text: file_text,
        is_md: is_md,
        is_edit: is_edit,
        old_str: old_str,
        md_id: md_id,
        icon: icon
      )

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">{@icon}</span>
      <span class="text-sm font-mono text-base-content/70 truncate">{@path}</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <%= if @is_edit && @old_str != "" do %>
      <details class="text-xs">
        <summary class="cursor-pointer text-base-content/50">Diff</summary>
        <div class="mt-1 p-2 bg-base-200 text-base-content rounded text-xs overflow-x-auto max-h-48 overflow-y-auto font-mono">
          <pre class="text-error/70 line-through">- {String.trim(@old_str)}</pre>
          <pre class="text-success/70">+ {String.trim(@file_text)}</pre>
        </div>
      </details>
    <% else %>
      <%= if @is_md && @file_text != "" do %>
        <details class="text-xs">
          <summary class="cursor-pointer text-base-content/50">
            File content ({String.length(@file_text)} chars)
          </summary>
          <div class="mt-1 p-3 bg-base-100 border border-base-300 rounded max-h-96 overflow-y-auto">
            <div
              class="markdown-body"
              id={@md_id}
              phx-hook="MarkdownContent"
              data-markdown={@file_text}
            >
            </div>
            <div class="flex justify-end mt-1">
              <button
                class="btn btn-ghost btn-xs"
                phx-hook="CopyMarkdown"
                id={"copy-#{@md_id}"}
                data-target={@md_id}
              >
                📋 Copy
              </button>
            </div>
          </div>
        </details>
      <% else %>
        <%= if @file_text != "" do %>
          <details class="text-xs">
            <summary class="cursor-pointer text-base-content/50">
              Content ({String.length(@file_text)} chars)
            </summary>
            <pre class="mt-1 p-2 bg-base-200 text-base-content rounded text-xs overflow-x-auto whitespace-pre-wrap max-h-48 overflow-y-auto">{@file_text}</pre>
          </details>
        <% end %>
      <% end %>
    <% end %>
    <Generic.error_display error_msg={@error_msg} />
    """
  end
end
