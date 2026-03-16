defmodule Jido.ToolRenderers.SessionViewer.Terminal do
  @moduledoc """
  Terminal/xterm.js conversation renderer for coding agent sessions.

  Renders `SessionEvent` structs as ANSI-colored text pushed to an
  xterm.js terminal via LiveView hooks.

  Usage in a LiveView:

      <Terminal.terminal_view id="session-term" events={@events} />

  The component uses `phx-hook="XtermSession"` to initialize an xterm.js
  terminal and receives ANSI data via `push_event/3`.
  """

  use Phoenix.Component

  alias Jido.ToolRenderers.AnsiFormatter
  alias Jido.ToolRenderers.SessionEvent

  @doc """
  Renders the xterm.js terminal container.

  The `XtermSession` hook initializes the terminal and listens for
  `xterm:write` events to append ANSI content.
  """
  attr :id, :string, required: true
  attr :events, :list, default: []
  attr :class, :string, default: ""

  def terminal_view(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="XtermSession"
      phx-update="ignore"
      data-initial={initial_content(@events)}
      class={["w-full h-full min-h-[300px] rounded-lg overflow-hidden bg-[#1e1e1e]", @class]}
    >
    </div>
    """
  end

  @doc """
  Formats a single event to ANSI and returns the string.
  Used by host LiveViews to push incremental updates.

  ## Example

      ansi = Terminal.format_event(event)
      socket = push_event(socket, "xterm:write", %{data: ansi, target: "session-term"})
  """
  @spec format_event(SessionEvent.t()) :: String.t()
  def format_event(%SessionEvent{} = event) do
    event
    |> AnsiFormatter.format()
    |> IO.iodata_to_binary()
  end

  @doc """
  Formats all events into a single ANSI string for initial terminal content.
  """
  @spec format_all([SessionEvent.t()]) :: String.t()
  def format_all(events) do
    events
    |> AnsiFormatter.format_all()
    |> IO.iodata_to_binary()
  end

  defp initial_content([]), do: ""

  defp initial_content(events) do
    format_all(events)
  end
end
