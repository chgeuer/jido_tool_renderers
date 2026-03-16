defmodule Jido.ToolRenderers.UpdateTodo do
  @moduledoc "Renderer for `update_todo` and `task_complete` tools."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = assigns.args || %{}
    tool = assigns.tool

    case tool do
      "task_complete" -> render_task_complete(assigns, args)
      "update_todo" -> render_update_todo(assigns, args)
      _ -> render_update_todo(assigns, args)
    end
  end

  defp render_task_complete(assigns, args) do
    summary = args["summary"] || ""
    assigns = assign(assigns, summary: summary)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-success badge-sm">✅ task_complete</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <%= if @summary != "" do %>
      <div class="mt-1 text-sm border-l-2 border-success pl-3">{@summary}</div>
    <% end %>
    <Generic.error_display error_msg={@error_msg} />
    """
  end

  defp render_update_todo(assigns, args) do
    raw_todos = args["todos"] || args["status"] || ""

    todos =
      cond do
        is_binary(raw_todos) -> raw_todos
        is_list(raw_todos) -> format_todos_as_markdown(raw_todos)
        is_map(raw_todos) -> Jason.encode!(raw_todos, pretty: true)
        true -> inspect(raw_todos)
      end

    md_id = "todo-#{assigns.tool_call_id || System.unique_integer([:positive])}"
    assigns = assign(assigns, todos: todos, md_id: md_id)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">📝 update_todo</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <%= if @todos != "" do %>
      <div class="mt-1 p-2 bg-base-100 border border-base-300 rounded">
        <div
          class="markdown-body text-sm"
          id={@md_id}
          phx-hook="MarkdownContent"
          data-markdown={@todos}
        >
        </div>
      </div>
    <% end %>
    <Generic.error_display error_msg={@error_msg} />
    """
  end

  defp format_todos_as_markdown(todos) when is_list(todos) do
    Enum.map_join(todos, "\n", fn
      %{"content" => content, "status" => status} ->
        marker = if status == "done", do: "- [x]", else: "- [ ]"
        "#{marker} #{content}"

      %{"status" => status} = todo ->
        content =
          todo["content"] || todo["activeForm"] || todo["description"] || todo["title"] || ""

        marker = if status == "done", do: "- [x]", else: "- [ ]"
        "#{marker} #{content}"

      item when is_binary(item) ->
        "- #{item}"

      item when is_map(item) ->
        "- #{Jason.encode!(item)}"

      item ->
        "- #{inspect(item)}"
    end)
  end
end
