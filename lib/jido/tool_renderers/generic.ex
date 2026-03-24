defmodule Jido.ToolRenderers.Generic do
  @moduledoc """
  Default tool renderer. Shows tool name, arguments as JSON, and result as pre-formatted text.
  All specialized renderers follow the same callback pattern.
  """
  use Phoenix.Component
  alias Jido.ToolRenderers.Components

  def render(assigns) do
    args_str =
      if is_map(assigns.args),
        do: Jason.encode!(assigns.args, pretty: true),
        else: inspect(assigns.args)

    full_length = String.length(assigns.content)
    assigns = assign(assigns, args_str: args_str, full_length: full_length)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-info badge-sm">🔧 {@tool}</span>
      <.status_indicator completed={@completed} error_msg={@error_msg} />
      <%= if @completed && @full_length > 0 do %>
        <span class="text-xs text-base-content/50">{@full_length} chars</span>
      <% end %>
    </div>
    <details class="text-xs">
      <summary class="cursor-pointer text-base-content/50">Arguments</summary>
      <pre class="mt-1 p-2 bg-base-200 text-base-content rounded text-xs overflow-x-auto">{@args_str}</pre>
    </details>
    <.error_display error_msg={@error_msg} />
    <.result_pre content={@content} completed={@completed} />
    """
  end

  # ── Shared sub-components used by all renderers ──

  attr :completed, :boolean, required: true
  attr :error_msg, :string, default: ""

  def status_indicator(assigns) do
    ~H"""
    <%= if @completed do %>
      <%= if @error_msg == "" do %>
        <span class="badge badge-success badge-sm">✓</span>
      <% else %>
        <span class="badge badge-error badge-sm">✗</span>
      <% end %>
    <% else %>
      <span class="loading loading-dots loading-xs"></span>
    <% end %>
    """
  end

  attr :error_msg, :string, required: true

  def error_display(assigns) do
    ~H"""
    <%= if @error_msg != "" do %>
      <div class="text-error text-xs mt-1">{@error_msg}</div>
    <% end %>
    """
  end

  attr :content, :string, required: true
  attr :completed, :boolean, required: true

  def result_pre(assigns) do
    ~H"""
    <%= if @completed && @content != "" do %>
      <details class="text-xs">
        <summary class="cursor-pointer text-base-content/50">Result</summary>
        <pre class="mt-1 p-2 bg-base-200 text-base-content rounded text-xs overflow-x-auto whitespace-pre-wrap max-h-64 overflow-y-auto">{@content}</pre>
      </details>
    <% end %>
    """
  end

  attr :content, :string, required: true
  attr :completed, :boolean, required: true
  attr :md_id, :string, required: true

  def result_markdown(assigns) do
    ~H"""
    <%= if @completed && @content != "" do %>
      <details class="text-xs" open>
        <summary class="cursor-pointer text-base-content/50">Result</summary>
        <div class="mt-1 p-3 bg-base-100 border border-base-300 rounded max-h-96 overflow-y-auto">
          <Components.markdown_content id={@md_id} content={@content} />
        </div>
      </details>
    <% end %>
    """
  end
end
