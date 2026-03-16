defmodule Jido.ToolRenderers.GitHub do
  @moduledoc "Renderer for GitHub MCP server tools (search_code, get_file_contents, etc)."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = assigns.args || %{}
    # Extract common GitHub params
    owner = args["owner"] || ""
    repo = args["repo"] || ""
    method = args["method"] || ""
    query = args["query"] || ""

    # Short tool name (strip github-mcp-server- prefix)
    short_name =
      assigns.tool
      |> String.replace("github-mcp-server-", "")
      |> String.replace("_", " ")

    repo_ref = if owner != "" && repo != "", do: "#{owner}/#{repo}", else: ""

    md_id = "gh-#{assigns.tool_call_id || System.unique_integer([:positive])}"

    assigns =
      assign(assigns,
        short_name: short_name,
        repo_ref: repo_ref,
        method: method,
        query: query,
        md_id: md_id
      )

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">{@short_name}</span>
      <%= if @repo_ref != "" do %>
        <span class="text-sm font-mono text-base-content/70">{@repo_ref}</span>
      <% end %>
      <%= if @method != "" do %>
        <span class="badge badge-ghost badge-xs">{@method}</span>
      <% end %>
      <%= if @query != "" do %>
        <span class="text-sm text-base-content/60">"{@query}"</span>
      <% end %>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <Generic.error_display error_msg={@error_msg} />
    <Generic.result_markdown content={@content} completed={@completed} md_id={@md_id} />
    """
  end
end
