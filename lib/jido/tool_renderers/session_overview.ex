defmodule Jido.ToolRenderers.SessionOverview do
  @moduledoc """
  Dashboard grid component showing multiple sessions as mini terminal panels.

  Each cell shows the latest N lines of ANSI output with metadata overlays.
  Clicking a cell navigates to the full session view.

  ## Usage

      <SessionOverview.grid
        sessions={@sessions}
        navigate_fn={fn id -> "/session/\#{id}" end}
      />

  Each session in the list should have:
  - `id` — unique session identifier
  - `metadata` — `SessionMetadata` struct
  - `recent_events` — list of recent `SessionEvent` structs for terminal preview
  """

  use Phoenix.Component

  alias Jido.ToolRenderers.SessionViewer.Terminal

  @doc """
  Renders a responsive grid of mini session terminals.
  """
  attr :sessions, :list, required: true
  attr :navigate_fn, :any, default: nil
  attr :class, :string, default: ""

  def grid(assigns) do
    ~H"""
    <div class={[
      "grid gap-3 auto-rows-fr",
      "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4",
      @class
    ]}>
      <%= for session <- @sessions do %>
        <.session_card session={session} navigate_fn={@navigate_fn} />
      <% end %>
    </div>
    """
  end

  attr :session, :map, required: true
  attr :navigate_fn, :any, default: nil

  defp session_card(assigns) do
    meta = Map.get(assigns.session, :metadata, %{})
    id = Map.get(assigns.session, :id, "unknown")
    events = Map.get(assigns.session, :recent_events, [])
    href = if assigns.navigate_fn, do: assigns.navigate_fn.(id), else: nil

    assigns =
      assign(assigns,
        meta: meta,
        session_id: id,
        events: events,
        href: href
      )

    ~H"""
    <div class="card card-compact bg-base-300 shadow-md hover:shadow-lg transition-shadow cursor-pointer group">
      <div class="card-body p-0">
        <div class="flex items-center justify-between px-3 py-1.5 border-b border-base-content/10">
          <div class="flex items-center gap-2">
            <span class={["badge badge-xs", card_status_class(@meta)]}>
              {card_status_label(@meta)}
            </span>
            <span class="text-xs font-mono text-base-content/60 truncate max-w-[120px]">
              {card_title(@meta, @session_id)}
            </span>
          </div>
          <div class="flex items-center gap-1 text-xs text-base-content/40">
            <%= if model = Map.get(@meta, :model) do %>
              <span class="badge badge-ghost badge-xs">{model}</span>
            <% end %>
          </div>
        </div>

        <%= if @href do %>
          <a href={@href} class="block h-[160px] overflow-hidden">
            <Terminal.terminal_view
              id={"overview-#{@session_id}"}
              events={@events}
              class="h-full pointer-events-none"
            />
          </a>
        <% else %>
          <div class="h-[160px] overflow-hidden">
            <Terminal.terminal_view
              id={"overview-#{@session_id}"}
              events={@events}
              class="h-full"
            />
          </div>
        <% end %>

        <div class="px-3 py-1 text-xs text-base-content/40 flex items-center gap-2 border-t border-base-content/10">
          <%= if tokens = Map.get(@meta, :tokens, %{}) do %>
            <%= if input = Map.get(tokens, :input_tokens) do %>
              <span>↑{format_count(input)}</span>
            <% end %>
            <%= if output = Map.get(tokens, :output_tokens) do %>
              <span>↓{format_count(output)}</span>
            <% end %>
          <% end %>
          <%= if cwd = Map.get(@meta, :cwd) do %>
            <span class="truncate">{Path.basename(cwd)}</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp card_title(%{title: title}, _id) when is_binary(title) and title != "", do: title
  defp card_title(_meta, id), do: String.slice(to_string(id), 0, 12)

  defp card_status_class(%{status: :idle}), do: "badge-success"
  defp card_status_class(%{status: :thinking}), do: "badge-warning"
  defp card_status_class(%{status: :tool_running}), do: "badge-info"
  defp card_status_class(%{status: :error}), do: "badge-error"
  defp card_status_class(_), do: "badge-ghost"

  defp card_status_label(%{status: status}), do: to_string(status)
  defp card_status_label(_), do: "—"

  defp format_count(n) when is_integer(n) and n >= 1_000_000,
    do: "#{Float.round(n / 1_000_000, 1)}M"

  defp format_count(n) when is_integer(n) and n >= 1_000,
    do: "#{Float.round(n / 1_000, 1)}k"

  defp format_count(n), do: "#{n}"
end
