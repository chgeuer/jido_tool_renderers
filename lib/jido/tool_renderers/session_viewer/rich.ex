defmodule Jido.ToolRenderers.SessionViewer.Rich do
  @moduledoc """
  Rich HTML conversation renderer for coding agent sessions.

  Renders `SessionEvent` structs as styled HTML using DaisyUI chat components,
  collapsible tool groups, markdown rendering, and specialized tool renderers.

  This is a function component — the host app wraps it in a stream container:

      <div id="events" phx-update="stream">
        <div :for={{dom_id, event} <- @streams.events} id={dom_id}>
          <Rich.event_item event={event} />
        </div>
      </div>
  """

  use Phoenix.Component

  alias Jido.ToolRenderers.SessionEvent

  @doc """
  Renders a single session event as rich HTML.
  """
  attr(:event, SessionEvent, required: true)

  def event_item(%{event: %SessionEvent{type: :user_message, data: data}} = assigns) do
    msg_id = "user-md-#{assigns.event.id}"
    content = Map.get(data, "content", "")
    pasted = Map.get(data, "pasted_attachments", [])

    assigns =
      assign(assigns,
        msg_id: msg_id,
        content: content,
        pasted_attachments: pasted
      )

    ~H"""
    <div class="chat chat-end">
      <div class="chat-bubble chat-bubble-primary max-w-full overflow-hidden relative">
        <div class="sticky top-0 z-10 flex justify-end gap-1 mb-1">
          <button
            class="btn btn-ghost btn-xs text-primary-content/70 hover:text-primary-content"
            phx-hook="CopyMarkdown"
            id={"copy-#{@msg_id}"}
            data-target={@msg_id}
          >
            📋
          </button>
        </div>
        <div
          id={@msg_id}
          phx-hook="UserMessage"
          data-markdown={@content}
          class="whitespace-pre-wrap overflow-y-auto max-h-96"
        >
          {@content}
        </div>
        <%= if @pasted_attachments != [] do %>
          <div class="flex flex-wrap gap-1.5 mt-2 pt-2 border-t border-primary-content/15">
            <%= for att <- @pasted_attachments do %>
              <button
                class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-primary-content/10 hover:bg-primary-content/20 text-primary-content/80 hover:text-primary-content text-xs font-medium transition-colors cursor-pointer"
                phx-click="view_content"
                phx-value-path={att["artifact_path"]}
                phx-value-session-id={att["source_session_id"] || @event.metadata[:session_id]}
              >
                <span class="opacity-70">📎</span>
                <span class="truncate max-w-48">{Path.basename(att["file"])}</span>
                <span class="opacity-50">{att["size"]}</span>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def event_item(%{event: %SessionEvent{type: :assistant_message, data: data}} = assigns) do
    text = Map.get(data, "content", "")

    if String.trim(text) == "" do
      ~H""
    else
      msg_id = "md-#{assigns.event.id}"
      assigns = assign(assigns, text: text, msg_id: msg_id)

      ~H"""
      <div class="chat chat-start group">
        <div class="chat-bubble bg-base-100 text-base-content border border-base-300 max-w-full overflow-hidden relative">
          <div class="sticky top-0 z-10 flex justify-end opacity-0 group-hover:opacity-100 transition-opacity">
            <button
              class="btn btn-ghost btn-xs text-base-content/50 hover:text-base-content"
              phx-hook="CopyMarkdown"
              id={"copy-#{@msg_id}"}
              data-target={@msg_id}
            >
              📋
            </button>
          </div>
          <div class="markdown-body" id={@msg_id} phx-hook="MarkdownContent" data-markdown={@text}>
          </div>
        </div>
      </div>
      """
    end
  end

  def event_item(%{event: %SessionEvent{type: :assistant_reasoning, data: data}} = assigns) do
    text = Map.get(data, "content", "")
    md_id = "reasoning-#{assigns.event.id}"
    truncated = String.length(text) > 200
    preview = if truncated, do: String.slice(text, 0, 120) <> "…", else: text
    assigns = assign(assigns, text: text, md_id: md_id, truncated: truncated, preview: preview)

    ~H"""
    <details class="ml-2 border-l-2 border-warning/30 pl-3 my-1 group/reasoning">
      <summary class="cursor-pointer text-sm text-base-content/40 italic">
        🧠 {@preview}
      </summary>
      <div class="relative">
        <div class="sticky top-0 z-10 flex justify-end opacity-0 group-hover/reasoning:opacity-100 transition-opacity">
          <button
            class="btn btn-ghost btn-xs text-base-content/50 hover:text-base-content"
            phx-hook="CopyMarkdown"
            id={"copy-#{@md_id}"}
            data-target={@md_id}
          >
            📋
          </button>
        </div>
        <div
          class="markdown-body text-sm text-base-content/60 p-2 bg-base-200/30 rounded"
          id={@md_id}
          phx-hook="MarkdownContent"
          data-markdown={@text}
        >
        </div>
      </div>
    </details>
    """
  end

  def event_item(%{event: %SessionEvent{type: :assistant_intent, data: data}} = assigns) do
    assigns = assign(assigns, :intent, Map.get(data, "intent", ""))

    ~H"""
    <div class="ml-2 px-3 py-1 text-sm text-base-content/50 italic border-l-2 border-base-300">
      💭 {@intent}
    </div>
    """
  end

  def event_item(%{event: %SessionEvent{type: :tool_call, data: data}} = assigns) do
    tool =
      data
      |> Map.get("tool", "unknown")
      |> Jido.ToolRenderers.canonical_tool_name()

    raw_args = Map.get(data, "arguments")

    args =
      cond do
        is_map(raw_args) -> raw_args
        is_binary(raw_args) -> decode_json_or_raw(raw_args)
        true -> raw_args
      end

    completed = Map.get(data, "completed", false) == true
    result = Map.get(data, "result")

    content =
      cond do
        is_map(result) -> result["content"] || ""
        is_binary(result) -> result
        true -> ""
      end

    error = Map.get(data, "error")

    error_msg =
      cond do
        is_map(error) -> error["message"] || ""
        is_binary(error) -> error
        true -> ""
      end

    renderer = Jido.ToolRenderers.renderer_for(tool)

    assigns =
      assign(assigns,
        tool: tool,
        args: args,
        completed: completed,
        content: content,
        error_msg: error_msg,
        tool_call_id: Map.get(data, "tool_call_id"),
        renderer: renderer
      )

    ~H"""
    <div class="card card-compact bg-base-300/50 my-1">
      <div class="card-body py-2 px-3">
        <div class="flex items-center gap-2 mb-1">
          <span class={["font-mono text-xs px-1.5 py-0.5 rounded", tool_badge_class(@tool)]}>
            {@tool}
          </span>
          <%= cond do %>
            <% @completed && @error_msg == "" -> %>
              <span class="text-success text-xs">✓</span>
            <% @completed -> %>
              <span class="text-error text-xs">✗</span>
            <% true -> %>
              <span class="loading loading-spinner loading-xs text-warning"></span>
          <% end %>
        </div>
        {@renderer.render(assigns)}
      </div>
    </div>
    """
  end

  def event_item(%{event: %SessionEvent{type: :tool_group, data: data}} = assigns) do
    events = Map.get(data, "events", [])
    tool_names = Map.get(data, "tool_names", [])
    tool_count = Map.get(data, "tool_count", 0)
    all_completed = Map.get(data, "all_completed", false)

    summary = build_tool_group_summary(tool_names, tool_count, events)
    has_spinner = not all_completed

    assigns =
      assign(assigns,
        group_events: events,
        summary: summary,
        all_completed: all_completed,
        has_spinner: has_spinner
      )

    ~H"""
    <div id={"tg-#{@event.id}"}>
      <details class="my-1 border border-base-300 rounded-lg bg-base-200/30" open={!@all_completed}>
        <summary class="cursor-pointer text-sm text-base-content/60 hover:text-base-content px-3 py-2 flex items-center gap-2 flex-wrap">
          <span class="text-base-content/40">⚙️ {@tool_count}</span>
          <span :for={name <- @tool_names} class={["font-mono text-[0.65rem] px-1.5 py-0.5 rounded", tool_badge_class(name)]}>
            {name}
          </span>
          <%= if @has_spinner do %>
            <span class="loading loading-dots loading-xs"></span>
          <% end %>
        </summary>
        <div class="px-2 pb-2 space-y-1">
          <%= for evt <- @group_events do %>
            <.event_item event={evt} />
          <% end %>
        </div>
      </details>
    </div>
    """
  end

  def event_item(%{event: %SessionEvent{type: :assistant_usage, data: data}} = assigns) do
    inp = Map.get(data, "input_tokens", 0)
    out = Map.get(data, "output_tokens", 0)
    cost = Map.get(data, "total_cost")
    model = Map.get(data, "model", "—")

    assigns = assign(assigns, inp: inp, out: out, cost: cost, model: model)

    ~H"""
    <div class="flex items-center gap-2 text-xs text-base-content/40 px-2 py-1">
      <span>📊</span>
      <span class="font-mono">{format_tokens(@inp)} in → {format_tokens(@out)} out</span>
      <span>{@model}</span>
      <%= if @cost do %>
        <span class="badge badge-ghost badge-xs">{@cost}</span>
      <% end %>
    </div>
    """
  end

  def event_item(%{event: %SessionEvent{type: :turn_start}} = assigns) do
    ~H"""
    <div class="divider text-xs text-base-content/30">Turn</div>
    """
  end

  def event_item(%{event: %SessionEvent{type: :turn_end}} = assigns) do
    ~H""
  end

  def event_item(%{event: %SessionEvent{type: :session_idle}} = assigns) do
    ~H""
  end

  def event_item(%{event: %SessionEvent{type: :session_error, data: data}} = assigns) do
    assigns = assign(assigns, :message, Map.get(data, "content", "Unknown error"))

    ~H"""
    <div class="alert alert-error text-sm">{@message}</div>
    """
  end

  def event_item(%{event: %SessionEvent{type: :session_info, data: data}} = assigns) do
    assigns = assign(assigns, :message, Map.get(data, "content", ""))

    ~H"""
    <div class="alert alert-info text-sm">{@message}</div>
    """
  end

  def event_item(%{event: %SessionEvent{type: :ask_user, data: data}} = assigns) do
    question = Map.get(data, "question", "")
    choices = Map.get(data, "choices", [])
    assigns = assign(assigns, question: question, choices: choices)

    ~H"""
    <div class="alert alert-warning text-sm">
      <div>
        <span class="font-bold">❓ {@question}</span>
        <%= if @choices != [] do %>
          <ul class="mt-1 ml-4 list-disc">
            <%= for choice <- @choices do %>
              <li>{choice}</li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </div>
    """
  end

  def event_item(%{event: %SessionEvent{type: type}} = assigns) do
    assigns = assign(assigns, :type_str, Atom.to_string(type))

    ~H"""
    <div class="text-xs text-base-content/20 px-2">{@type_str}</div>
    """
  end

  # ── Private helpers ──

  defp decode_json_or_raw(str) do
    case Jason.decode(str) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _ -> str
    end
  end

  defp build_tool_group_summary(tool_names, tool_count, events) do
    parts = []

    parts =
      if tool_count > 0 do
        names =
          tool_names
          |> Enum.map(&Jido.ToolRenderers.canonical_tool_name/1)
          |> Enum.filter(&(is_binary(&1) && &1 != ""))
          |> Enum.uniq()
          |> Enum.join(", ")

        parts ++ ["#{tool_count} tool#{if tool_count != 1, do: "s"}: #{names}"]
      else
        parts
      end

    turns = Enum.count(events, &(event_type(&1) in [:turn_start, "assistant.turn_start"]))
    parts = if turns > 1, do: parts ++ ["#{turns} turns"], else: parts

    usage_cost = sum_usage_cost(events)
    parts = if usage_cost > 0, do: parts ++ ["~#{round(usage_cost)} PR"], else: parts

    "⚙️ " <>
      if parts == [],
        do: "#{length(events)} steps",
        else: Enum.join(parts, " · ")
  end

  defp event_type(%SessionEvent{type: type}), do: type
  defp event_type(%{type: type}), do: type
  defp event_type(_), do: nil

  defp sum_usage_cost(events) do
    events
    |> Enum.filter(fn evt ->
      event_type(evt) in [:assistant_usage, "assistant.usage"]
    end)
    |> Enum.reduce(0, fn evt, acc ->
      data = event_data(evt)
      cost = Map.get(data, "total_cost") || Map.get(data, "cost") || 0
      acc + if is_number(cost), do: cost, else: 0
    end)
  end

  defp event_data(%SessionEvent{data: data}), do: data
  defp event_data(%{data: data}), do: data
  defp event_data(_), do: %{}

  defp format_tokens(n) when is_integer(n) and n >= 1_000_000,
    do: "#{Float.round(n / 1_000_000, 1)}M"

  defp format_tokens(n) when is_integer(n) and n >= 1_000,
    do: "#{Float.round(n / 1_000, 1)}k"

  defp format_tokens(n), do: "#{n}"

  defp tool_badge_class(name) do
    canonical = Jido.ToolRenderers.canonical_tool_name(name)

    case canonical do
      # Shell — warm amber
      n when n in ~w[bash read_bash write_bash stop_bash list_bash] ->
        "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300"

      # File write/edit — blue
      n when n in ~w[edit create write apply_patch] ->
        "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300"

      # File read — emerald
      n when n in ~w[view read_file] ->
        "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300"

      # Search — violet
      n when n in ~w[grep glob rg] ->
        "bg-violet-100 text-violet-800 dark:bg-violet-900/40 dark:text-violet-300"

      # Web — cyan
      n when n in ~w[web_search web_fetch] ->
        "bg-cyan-100 text-cyan-800 dark:bg-cyan-900/40 dark:text-cyan-300"

      # Sub-agents — indigo
      n when n in ~w[task read_agent list_agents] ->
        "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/40 dark:text-indigo-300"

      # SQL — teal
      "sql" ->
        "bg-teal-100 text-teal-800 dark:bg-teal-900/40 dark:text-teal-300"

      # GitHub — slate
      n when is_binary(n) and byte_size(n) > 0 ->
        if String.starts_with?(n, "github-mcp-server-") do
          "bg-slate-100 text-slate-800 dark:bg-slate-900/40 dark:text-slate-300"
        else
          "bg-zinc-100 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
        end

      _ ->
        "bg-zinc-100 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
    end
  end
end
