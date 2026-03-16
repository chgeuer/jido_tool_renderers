defmodule Jido.ToolRenderers.Bash do
  @moduledoc "Renderer for `bash`, `read_bash`, `write_bash`, `stop_bash`, `list_bash` tools."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = if is_map(assigns.args), do: assigns.args, else: %{}

    command =
      args["command"] || args["cmd"] || args["input"] || args["chars"] ||
        if(is_binary(assigns.args), do: assigns.args, else: "")

    description = args["description"] || ""

    shell_id =
      (args["shellId"] || args["shell_id"] || args["session_id"])
      |> format_shell_id()

    mode = args["mode"]
    workdir = args["workdir"] || args["cwd"] || ""
    max_output_tokens = args["max_output_tokens"] || args["maxOutputTokens"]
    wait_ms = args["yield_time_ms"] || args["delay"]
    display_tool = display_tool_name(assigns.tool, args)

    icon =
      case display_tool do
        "bash" -> "💻"
        "read_bash" -> "📖"
        "write_bash" -> "⌨️"
        "stop_bash" -> "⏹"
        "list_bash" -> "📋"
        _ -> "💻"
      end

    # Auto-collapse long output
    output_lines =
      if assigns.content != "", do: length(String.split(assigns.content, "\n")), else: 0

    auto_collapse = output_lines > 20

    assigns =
      assign(assigns,
        command: command,
        description: description,
        shell_id: shell_id,
        mode: mode,
        workdir: workdir,
        max_output_tokens: max_output_tokens,
        wait_ms: wait_ms,
        display_tool: display_tool,
        icon: icon,
        auto_collapse: auto_collapse,
        output_lines: output_lines
      )

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">{@icon} {@display_tool}</span>
      <%= if @description != "" do %>
        <span class="text-sm text-base-content/70">{@description}</span>
      <% end %>
      <%= if @mode do %>
        <span class="badge badge-ghost badge-xs">{@mode}</span>
      <% end %>
      <%= if @max_output_tokens do %>
        <span class="badge badge-outline badge-xs">{@max_output_tokens} tok</span>
      <% end %>
      <%= if @wait_ms do %>
        <span class="badge badge-ghost badge-xs">{@wait_ms} ms</span>
      <% end %>
      <%= if @shell_id != "" do %>
        <span class="text-xs font-mono text-base-content/40">{@shell_id}</span>
      <% end %>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <%= if @workdir != "" do %>
      <div class="mt-1 text-xs font-mono text-base-content/50">cd {@workdir}</div>
    <% end %>
    <%= if @command != "" do %>
      <pre class="mt-1 p-2 bg-neutral text-neutral-content rounded text-xs overflow-x-auto font-mono"><span class="text-success/70">$ </span>{@command}</pre>
    <% end %>
    <Generic.error_display error_msg={@error_msg} />
    <%= if @completed && @content != "" do %>
      <details class="text-xs" open={!@auto_collapse}>
        <summary class="cursor-pointer text-base-content/50">
          Output ({@output_lines} lines)
        </summary>
        <pre class="mt-1 p-2 bg-base-200 text-base-content rounded text-xs overflow-x-auto whitespace-pre-wrap max-h-64 overflow-y-auto font-mono">{@content}</pre>
      </details>
    <% end %>
    """
  end

  defp display_tool_name(tool, args) do
    tool = Jido.ToolRenderers.canonical_tool_name(tool)

    case {tool, Map.get(args, "chars", nil)} do
      {"write_bash", ""} -> "read_bash"
      {"write_bash", nil} -> "write_bash"
      _ -> tool
    end
  end

  defp format_shell_id(nil), do: ""
  defp format_shell_id(id), do: to_string(id)
end
