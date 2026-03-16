defmodule Jido.ToolRenderers.AnsiFormatter do
  @moduledoc """
  Converts `SessionEvent` structs into ANSI-colored terminal strings.

  Output can be:
  - Pushed to xterm.js via a LiveView hook
  - Written to a real terminal for CLI dashboards
  - Stripped of ANSI codes for plain text logging
  """

  alias Jido.ToolRenderers.SessionEvent

  @reset IO.ANSI.reset()
  @bold IO.ANSI.bright()
  @dim IO.ANSI.faint()
  @italic IO.ANSI.italic()
  @cyan IO.ANSI.cyan()
  @green IO.ANSI.green()
  @yellow IO.ANSI.yellow()
  @red IO.ANSI.red()
  @magenta IO.ANSI.magenta()
  @blue IO.ANSI.blue()
  @gray IO.ANSI.light_black()

  @doc """
  Formats a single `SessionEvent` into an ANSI-colored iolist.
  """
  @spec format(SessionEvent.t()) :: iolist()
  def format(%SessionEvent{type: :user_message, data: data}) do
    content = Map.get(data, "content", "")
    ["\r\n", @bold, @cyan, "❯ ", @reset, @cyan, content, @reset, "\r\n"]
  end

  def format(%SessionEvent{type: :assistant_message, data: data}) do
    content = Map.get(data, "content", "")
    ["\r\n", content, "\r\n"]
  end

  def format(%SessionEvent{type: :assistant_reasoning, data: data}) do
    content = Map.get(data, "content", "")
    preview = truncate(content, 120)
    [@dim, @italic, "  💭 ", preview, @reset, "\r\n"]
  end

  def format(%SessionEvent{type: :assistant_intent, data: data}) do
    intent = Map.get(data, "intent", "")
    [@dim, "  ▸ ", @magenta, intent, @reset, "\r\n"]
  end

  def format(%SessionEvent{type: :tool_call, data: data}) do
    tool =
      data
      |> Map.get("tool", "unknown")
      |> Jido.ToolRenderers.canonical_tool_name()

    data = Map.put(data, "tool", tool)
    completed = Map.get(data, "completed", false)
    error = Map.get(data, "error")
    result = Map.get(data, "result")

    status = format_tool_status(completed, error)
    result_line = format_tool_result(completed, result, error)
    args_summary = format_tool_args_summary(data)

    [
      "  ",
      @green,
      "⚙ ",
      @bold,
      tool,
      @reset,
      @gray,
      args_summary,
      @reset,
      " ",
      status,
      result_line
    ]
  end

  def format(%SessionEvent{type: :tool_group, data: data}) do
    tool_names = Map.get(data, "tool_names", [])
    tool_count = Map.get(data, "tool_count", 0)
    events = Map.get(data, "events", [])

    header = [
      "\r\n",
      @dim,
      "┌─ ",
      @reset,
      @bold,
      "#{tool_count} tool",
      if(tool_count != 1, do: "s", else: ""),
      @reset,
      @gray,
      ": ",
      Enum.join(tool_names, ", "),
      @reset,
      "\r\n"
    ]

    body = Enum.map(events, &format_nested_event/1)
    footer = [@dim, "└─", @reset, "\r\n"]
    [header, body, footer]
  end

  def format(%SessionEvent{type: :assistant_usage, data: data}) do
    input = Map.get(data, "input_tokens", 0)
    output = Map.get(data, "output_tokens", 0)
    cost = Map.get(data, "total_cost")

    cost_str = if cost, do: [" · ", @green, cost, @reset], else: []

    [
      @dim,
      "  tokens: in=",
      @yellow,
      format_number(input),
      @reset,
      @dim,
      " out=",
      @yellow,
      format_number(output),
      @reset,
      cost_str,
      "\r\n"
    ]
  end

  def format(%SessionEvent{type: :turn_start}) do
    [@dim, "── turn ──", @reset, "\r\n"]
  end

  def format(%SessionEvent{type: :turn_end}) do
    [@dim, "── end ──", @reset, "\r\n"]
  end

  def format(%SessionEvent{type: :session_error, data: data}) do
    content = Map.get(data, "content", "")
    [@red, @bold, "✗ Error: ", @reset, @red, content, @reset, "\r\n"]
  end

  def format(%SessionEvent{type: :session_info, data: data}) do
    content = Map.get(data, "content", "")
    [@blue, "ℹ ", content, @reset, "\r\n"]
  end

  def format(%SessionEvent{type: :session_idle}) do
    [@dim, "… idle", @reset, "\r\n"]
  end

  def format(%SessionEvent{type: :ask_user, data: data}) do
    question = Map.get(data, "question", "")
    choices = Map.get(data, "choices", [])

    choice_lines =
      if choices != [] do
        choices
        |> Enum.with_index(1)
        |> Enum.map(fn {choice, i} ->
          ["    ", @yellow, "#{i}. ", @reset, choice, "\r\n"]
        end)
      else
        []
      end

    [
      "\r\n",
      @bold,
      @yellow,
      "? ",
      @reset,
      @bold,
      question,
      @reset,
      "\r\n",
      choice_lines
    ]
  end

  def format(%SessionEvent{}) do
    []
  end

  @doc """
  Formats a list of events into a single ANSI string.
  """
  @spec format_all([SessionEvent.t()]) :: iolist()
  def format_all(events) do
    Enum.map(events, &format/1)
  end

  @doc """
  Strips ANSI escape codes from a string for plain text output.
  """
  @spec strip_ansi(String.t()) :: String.t()
  def strip_ansi(string) when is_binary(string) do
    String.replace(string, ~r/\e\[[0-9;]*[a-zA-Z]/, "")
  end

  # ── Private helpers ──

  defp format_nested_event(%SessionEvent{} = event), do: format(event)

  defp format_nested_event(%{type: type, data: data}) when is_binary(type) do
    format(%SessionEvent{
      id: "nested",
      type: string_type_to_atom(type),
      data: data
    })
  end

  defp format_nested_event(_), do: []

  defp string_type_to_atom("tool.combined"), do: :tool_call
  defp string_type_to_atom("assistant.message.block"), do: :assistant_message
  defp string_type_to_atom("assistant.reasoning"), do: :assistant_reasoning
  defp string_type_to_atom("assistant.intent"), do: :assistant_intent
  defp string_type_to_atom("user.message"), do: :user_message
  defp string_type_to_atom(_), do: :session_info

  defp format_tool_status(false, _), do: [@yellow, "⏳", @reset, "\r\n"]
  defp format_tool_status(true, nil), do: [@green, "✓", @reset, "\r\n"]
  defp format_tool_status(true, ""), do: [@green, "✓", @reset, "\r\n"]
  defp format_tool_status(true, _error), do: [@red, "✗", @reset, "\r\n"]

  defp format_tool_result(true, result, nil) when is_binary(result) and result != "" do
    preview = truncate(result, 200)
    [@dim, "    → ", preview, @reset, "\r\n"]
  end

  defp format_tool_result(true, _, error) when is_binary(error) and error != "" do
    [@red, "    ✗ ", truncate(error, 200), @reset, "\r\n"]
  end

  defp format_tool_result(_, _, _), do: []

  defp format_tool_args_summary(%{"arguments" => args}) when is_map(args) do
    summary =
      args
      |> Enum.take(3)
      |> Enum.map_join(", ", fn {k, v} -> "#{k}=#{truncate(inspect(v), 30)}" end)

    [" (", summary, ")"]
  end

  defp format_tool_args_summary(%{"arguments" => args}) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, decoded} when is_map(decoded) -> format_tool_args_summary(%{"arguments" => decoded})
      _ -> []
    end
  end

  defp format_tool_args_summary(_), do: []

  defp truncate(str, max) when is_binary(str) and byte_size(str) > max do
    String.slice(str, 0, max) <> "…"
  end

  defp truncate(str, _max) when is_binary(str), do: str
  defp truncate(value, max), do: truncate(inspect(value), max)

  defp format_number(n) when is_integer(n) and n >= 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end

  defp format_number(n) when is_integer(n) and n >= 1_000 do
    "#{Float.round(n / 1_000, 1)}k"
  end

  defp format_number(n), do: to_string(n)
end
