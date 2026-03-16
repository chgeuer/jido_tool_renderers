defmodule Jido.ToolRenderers.ReportIntent do
  @moduledoc "Renderer for `report_intent` tool."
  use Phoenix.Component

  def render(assigns) do
    args = assigns.args || %{}
    intent = args["intent"] || ""
    assigns = assign(assigns, intent: intent)

    ~H"""
    <div class="flex items-center gap-2 text-sm text-base-content/50 italic">
      <span>💭</span>
      <span>{@intent}</span>
    </div>
    """
  end
end
