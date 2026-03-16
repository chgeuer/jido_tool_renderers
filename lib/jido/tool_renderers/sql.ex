defmodule Jido.ToolRenderers.Sql do
  @moduledoc "Renderer for the `sql` tool. Detects tabular results."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = assigns.args || %{}
    query = args["query"] || ""
    description = args["description"] || ""
    database = args["database"] || "session"
    md_id = "sql-result-#{System.unique_integer([:positive])}"

    assigns =
      assign(assigns, query: query, description: description, database: database, md_id: md_id)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">🗃️ sql</span>
      <%= if @description != "" do %>
        <span class="text-sm text-base-content/70">{@description}</span>
      <% end %>
      <span class="badge badge-ghost badge-xs">{@database}</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <pre class="mt-1 p-2 bg-base-200 text-base-content rounded text-xs overflow-x-auto font-mono">{@query}</pre>
    <Generic.error_display error_msg={@error_msg} />
    <%= if @completed && @content != "" do %>
      <div class="mt-1 p-3 bg-base-100 border border-base-300 rounded max-h-96 overflow-x-auto overflow-y-auto">
        <div
          class="markdown-body"
          id={@md_id}
          phx-hook="MarkdownContent"
          phx-update="ignore"
          data-markdown={@content}
        >
        </div>
      </div>
    <% end %>
    """
  end
end
