defmodule Jido.ToolRenderers.Task do
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic
  alias Jido.ToolRenderers.Components

  def render(assigns) do
    args = assigns.args || %{}
    agent_type = args["agent_type"] || "unknown"
    description = args["description"] || ""
    prompt = args["prompt"] || ""
    mode = args["mode"]

    md_id = "task-#{assigns.tool_call_id || System.unique_integer([:positive])}"
    {badge_class, icon} = agent_badge(agent_type)

    assigns =
      assign(assigns,
        agent_type: agent_type,
        description: description,
        prompt: prompt,
        mode: mode,
        md_id: md_id,
        badge_class: badge_class,
        icon: icon
      )

    ~H"""
    <div class="flex items-center gap-2">
      <span class={"badge badge-sm #{@badge_class}"}>{@icon} {@agent_type}</span>
      <span class="text-sm font-medium">{@description}</span>
      <%= if @mode == "background" do %>
        <span class="badge badge-ghost badge-xs">bg</span>
      <% end %>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <details class="text-xs">
      <summary class="cursor-pointer text-base-content/50">Prompt</summary>
      <div class="mt-1 p-3 bg-base-100 border border-base-300 rounded max-h-48 overflow-y-auto">
        <Components.markdown_content
          id={"task-p-#{@md_id}"}
          content={@prompt}
          class="text-xs"
        />
      </div>
    </details>
    <Generic.error_display error_msg={@error_msg} />
    <Generic.result_markdown content={@content} completed={@completed} md_id={@md_id} />
    """
  end

  defp agent_badge("explore"), do: {"badge-info", "🔍"}
  defp agent_badge("general-purpose"), do: {"badge-secondary", "🧠"}
  defp agent_badge("code-review"), do: {"badge-warning", "👁"}
  defp agent_badge("task"), do: {"badge-success", "⚡"}
  defp agent_badge(_), do: {"badge-neutral", "🤖"}
end
