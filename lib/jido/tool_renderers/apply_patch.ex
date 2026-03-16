defmodule Jido.ToolRenderers.ApplyPatch do
  @moduledoc "Renderer for the `apply_patch` tool — shows unified diff with color."
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = assigns.args
    # args is the raw patch text (string, not map)
    patch_text = if is_binary(args), do: args, else: inspect(args)

    # Parse files from the patch header
    files =
      Regex.scan(~r/\*\*\* Update File: (.+)/, patch_text)
      |> Enum.map(fn [_, path] -> path end)

    # Result often contains a proper git diff
    diff_text = assigns.content

    assigns = assign(assigns, patch_text: patch_text, files: files, diff_text: diff_text)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-warning badge-sm">📋 apply_patch</span>
      <%= for file <- @files do %>
        <span class="text-sm font-mono text-base-content/70 truncate">{file}</span>
      <% end %>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <%= if @diff_text != "" do %>
      <pre class="mt-1 p-2 bg-base-200 text-base-content rounded text-xs overflow-x-auto max-h-64 overflow-y-auto font-mono"><%= for line <- String.split(@diff_text, "\n") do %><span class={diff_line_class(line)}>{line}
      </span><% end %></pre>
    <% else %>
      <pre class="mt-1 p-2 bg-base-200 text-base-content rounded text-xs overflow-x-auto max-h-48 overflow-y-auto font-mono">{@patch_text}</pre>
    <% end %>
    <Generic.error_display error_msg={@error_msg} />
    """
  end

  defp diff_line_class(line) do
    cond do
      String.starts_with?(line, "+") && !String.starts_with?(line, "+++") -> "text-success"
      String.starts_with?(line, "-") && !String.starts_with?(line, "---") -> "text-error"
      String.starts_with?(line, "@@") -> "text-info"
      String.starts_with?(line, "diff ") -> "text-base-content/50 font-bold"
      true -> ""
    end
  end
end
