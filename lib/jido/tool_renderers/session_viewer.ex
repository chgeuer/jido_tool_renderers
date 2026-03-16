defmodule Jido.ToolRenderers.SessionViewer do
  @moduledoc """
  Main session viewer component with dual-mode rendering and interaction controls.

  Supports two view modes (`:rich` and `:terminal`) and three interaction modes
  (`:interactive`, `:readonly_live`, `:readonly`).

  ## Usage

  ### Historical replay (readonly)

      <SessionViewer.session_view
        id="session-1"
        view_mode={:rich}
        interaction_mode={:readonly}
        session_metadata={@session_meta}
      >
        <:events>
          <div id="events" phx-update="stream">
            <div :for={{dom_id, event} <- @streams.events} id={dom_id}>
              <Rich.event_item event={event} />
            </div>
          </div>
        </:events>
      </SessionViewer.session_view>

  ### Active driving (interactive)

      <SessionViewer.session_view
        id="session-1"
        view_mode={@view_mode}
        interaction_mode={:interactive}
        status={@status}
        model={@model}
        session_metadata={@session_meta}
      >
        <:events>...</:events>
      </SessionViewer.session_view>

  ### Passive watching (readonly_live)

      <SessionViewer.session_view
        id="session-1"
        view_mode={@view_mode}
        interaction_mode={:readonly_live}
        status={@status}
        session_metadata={@session_meta}
      >
        <:events>...</:events>
      </SessionViewer.session_view>
  """

  use Phoenix.Component

  alias Jido.ToolRenderers.SessionViewer.Interaction
  alias Jido.ToolRenderers.SessionViewer.Terminal

  @doc """
  Renders the session viewer with mode toggle, event area, and interaction controls.
  """
  attr :id, :string, required: true
  attr :view_mode, :atom, default: :rich, values: [:rich, :terminal]
  attr :interaction_mode, :atom, default: :readonly, values: [:interactive, :readonly_live, :readonly]
  attr :status, :atom, default: :unknown
  attr :model, :string, default: nil
  attr :session_metadata, :any, default: nil
  attr :ask_user_request, :map, default: nil
  attr :terminal_events, :list, default: []

  slot :events, doc: "Slot for the streamed event list (rich mode)"

  def session_view(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col h-full">
      <.view_mode_header
        id={@id}
        view_mode={@view_mode}
        session_metadata={@session_metadata}
        status={@status}
      />

      <div class="flex-1 overflow-y-auto">
        <%= if @view_mode == :rich do %>
          <div class="p-2 space-y-1">
            {render_slot(@events)}
          </div>
        <% else %>
          <Terminal.terminal_view
            id={"#{@id}-term"}
            events={@terminal_events}
            class="h-full"
          />
        <% end %>
      </div>

      <Interaction.interaction_controls
        interaction_mode={@interaction_mode}
        status={@status}
        model={@model}
        ask_user_request={@ask_user_request}
      />
    </div>
    """
  end

  @doc """
  Renders the toggle header bar.
  """
  attr :id, :string, required: true
  attr :view_mode, :atom, required: true
  attr :session_metadata, :any, default: nil
  attr :status, :atom, default: :unknown

  def view_mode_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between border-b border-base-300 bg-base-200 px-3 py-1.5">
      <div class="flex items-center gap-2 text-sm">
        <%= if @session_metadata do %>
          <span class="font-mono text-xs text-base-content/50">
            {session_title(@session_metadata)}
          </span>
        <% end %>
        <%= if @status not in [:unknown, nil] do %>
          <span class={["badge badge-xs", status_class(@status)]}>{@status}</span>
        <% end %>
      </div>
      <div class="flex items-center gap-1">
        <button
          phx-click="toggle_view_mode"
          phx-value-id={@id}
          class={[
            "btn btn-xs",
            if(@view_mode == :rich, do: "btn-primary", else: "btn-ghost")
          ]}
        >
          Rich
        </button>
        <button
          phx-click="toggle_view_mode"
          phx-value-id={@id}
          class={[
            "btn btn-xs",
            if(@view_mode == :terminal, do: "btn-primary", else: "btn-ghost")
          ]}
        >
          Terminal
        </button>
      </div>
    </div>
    """
  end

  defp session_title(%{title: title}) when is_binary(title) and title != "", do: title
  defp session_title(%{session_id: id}) when is_binary(id), do: String.slice(id, 0, 12) <> "…"
  defp session_title(_), do: "Session"

  defp status_class(:idle), do: "badge-success"
  defp status_class(:thinking), do: "badge-warning"
  defp status_class(:tool_running), do: "badge-info"
  defp status_class(:error), do: "badge-error"
  defp status_class(_), do: "badge-ghost"
end
