defmodule Jido.ToolRenderers.SessionViewer.Interaction do
  @moduledoc """
  Conditional interaction layer for session viewer components.

  Renders input controls based on `interaction_mode`:
  - `:interactive` — full prompt input, model selector, ask_user modal
  - `:readonly_live` — live status indicator, no input controls
  - `:readonly` — static view, no live indicators or input controls

  The host app provides callbacks via assigns for interactive mode.
  """

  use Phoenix.Component

  @doc """
  Renders the appropriate interaction controls based on mode.
  """
  attr :interaction_mode, :atom, required: true, values: [:interactive, :readonly_live, :readonly]
  attr :status, :atom, default: :unknown
  attr :model, :string, default: nil
  attr :ask_user_request, :map, default: nil

  def interaction_controls(assigns) do
    ~H"""
    <div>
      <%= case @interaction_mode do %>
        <% :interactive -> %>
          <.interactive_controls status={@status} model={@model} ask_user_request={@ask_user_request} />
        <% :readonly_live -> %>
          <.live_status_indicator status={@status} />
        <% :readonly -> %>
          <.static_indicator />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders the prompt input form for interactive sessions.
  """
  attr :status, :atom, default: :idle
  attr :model, :string, default: nil
  attr :ask_user_request, :map, default: nil

  def interactive_controls(assigns) do
    ~H"""
    <div class="border-t border-base-300 bg-base-200 p-3">
      <%= if @ask_user_request do %>
        <.ask_user_modal request={@ask_user_request} />
      <% end %>
      <form phx-submit="send_prompt" class="flex gap-2 items-end">
        <div class="flex-1">
          <textarea
            name="prompt"
            id="prompt-input"
            placeholder="Send a message..."
            class="textarea textarea-bordered w-full min-h-[60px] text-sm"
            rows="2"
            disabled={@status == :thinking}
          ></textarea>
        </div>
        <button
          type="submit"
          class="btn btn-primary btn-sm"
          disabled={@status == :thinking}
        >
          <%= if @status == :thinking do %>
            <span class="loading loading-spinner loading-xs"></span>
          <% else %>
            Send
          <% end %>
        </button>
      </form>
    </div>
    """
  end

  @doc """
  Live status badge for readonly_live mode.
  """
  attr :status, :atom, default: :unknown

  def live_status_indicator(assigns) do
    ~H"""
    <div class="border-t border-base-300 bg-base-200 px-3 py-2 flex items-center gap-2 text-sm text-base-content/60">
      <span class={["badge badge-sm", status_badge_class(@status)]}>{status_label(@status)}</span>
      <%= if @status in [:thinking, :tool_running] do %>
        <span class="loading loading-dots loading-xs"></span>
      <% end %>
    </div>
    """
  end

  defp static_indicator(assigns) do
    ~H"""
    <div class="border-t border-base-300 bg-base-200 px-3 py-2 text-xs text-base-content/40">
      Historical session
    </div>
    """
  end

  defp ask_user_modal(assigns) do
    question = Map.get(assigns.request, "question", "")
    choices = Map.get(assigns.request, "choices", [])
    request_id = Map.get(assigns.request, "request_id")
    assigns = assign(assigns, question: question, choices: choices, request_id: request_id)

    ~H"""
    <div class="alert alert-warning mb-2">
      <div class="w-full">
        <p class="font-bold">{@question}</p>
        <%= if @choices != [] do %>
          <div class="flex flex-wrap gap-2 mt-2">
            <%= for choice <- @choices do %>
              <button
                class="btn btn-sm btn-outline"
                phx-click="respond_ask_user"
                phx-value-request_id={@request_id}
                phx-value-response={choice}
              >
                {choice}
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_badge_class(:idle), do: "badge-success"
  defp status_badge_class(:thinking), do: "badge-warning"
  defp status_badge_class(:tool_running), do: "badge-info"
  defp status_badge_class(:error), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"

  defp status_label(:idle), do: "Idle"
  defp status_label(:thinking), do: "Thinking"
  defp status_label(:tool_running), do: "Running tools"
  defp status_label(:starting), do: "Starting"
  defp status_label(:error), do: "Error"
  defp status_label(:unknown), do: "Unknown"
  defp status_label(status), do: to_string(status)
end
