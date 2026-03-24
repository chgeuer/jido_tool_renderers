defmodule Jido.ToolRenderers.EventStream.Accumulator do
  @moduledoc """
  State machine for accumulating live streaming events into renderable units.

  In live mode, events arrive one at a time. This module tracks the state needed
  to accumulate assistant message chunks, build tool groups, and handle turn
  boundaries — all without any LiveView/socket coupling.

  ## Usage

      acc = Accumulator.new()
      {acc, actions} = Accumulator.process_event(acc, "assistant.message", %{"content" => "Hello"})
      # actions => [{:stream_insert, event_map} | {:push_event, name, payload}]

  The host LiveView applies actions to its socket:

      Enum.reduce(actions, socket, fn
        {:stream_insert, event_map} -> stream_insert(socket, :events, event_map, at: -1)
        {:push_event, name, payload} -> push_event(socket, name, payload)
        {:assign, key, value} -> assign(socket, key, value)
      end)
  """

  alias Jido.ToolRenderers.EventStream

  defstruct assistant_text: "",
            assistant_msg_id: nil,
            pending_tools: %{},
            tool_group_events: [],
            tool_group_id: nil

  @type t :: %__MODULE__{
          assistant_text: String.t(),
          assistant_msg_id: String.t() | nil,
          pending_tools: map(),
          tool_group_events: [map()],
          tool_group_id: String.t() | nil
        }

  @type action ::
          {:stream_insert, map()}
          | {:push_event, String.t(), map()}

  @doc "Creates a new accumulator with empty state."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Processes a single live event and returns updated state + actions to apply.

  Returns `{updated_accumulator, actions}` where actions is a list of
  tuples the host LiveView should apply to its socket.

  Returns `:skip` as the second element when the event should be ignored.
  """
  @spec process_event(t(), String.t(), map()) :: {t(), [action()] | :skip}
  def process_event(acc, type, data) do
    cond do
      type == "user.message" or EventStream.noise?(type) ->
        {acc, :skip}

      type == "assistant.message" ->
        handle_assistant_message(acc, data)

      type == "tool.execution_start" ->
        handle_tool_start(acc, data)

      type == "tool.execution_complete" ->
        handle_tool_complete(acc, data)

      type == "assistant.turn_start" ->
        handle_turn_start(acc)

      true ->
        handle_fallthrough(acc, type, data)
    end
  end

  # ── Private handlers ──

  defp handle_assistant_message(acc, data) do
    reasoning = data["reasoningText"]

    {acc, reasoning_actions} =
      if is_binary(reasoning) and String.trim(reasoning) != "" do
        reasoning_event = %{
          type: "assistant.reasoning",
          data: %{"content" => reasoning},
          dom_id: "copilot-reasoning-#{System.unique_integer([:positive])}"
        }

        {acc, tool_group_actions} = add_to_tool_group(acc, reasoning_event)
        {acc, tool_group_actions}
      else
        {acc, []}
      end

    chunk = data["chunkContent"] || data["content"] || ""
    new_text = acc.assistant_text <> chunk

    msg_id =
      acc.assistant_msg_id || "assistant-msg-#{System.unique_integer([:positive])}"

    event_map = %{
      type: "assistant.message.block",
      data: %{"content" => new_text},
      dom_id: msg_id
    }

    acc = %{acc | assistant_text: new_text, assistant_msg_id: msg_id}

    actions =
      reasoning_actions ++
        [
          {:stream_insert, event_map},
          {:push_event, "scroll-bottom", %{}}
        ]

    {acc, actions}
  end

  defp handle_tool_start(acc, data) do
    tool_call_id = data["toolCallId"]
    tool_name = data["toolName"] || "unknown"
    arguments = data["arguments"]

    combined = %{
      type: "tool.combined",
      data: %{
        "toolName" => tool_name,
        "arguments" => arguments,
        "toolCallId" => tool_call_id,
        "completed" => false
      },
      dom_id: "tool-#{tool_call_id || System.unique_integer([:positive])}"
    }

    pending =
      Map.put(acc.pending_tools, tool_call_id, %{
        tool_name: tool_name,
        arguments: arguments
      })

    acc = %{acc | pending_tools: pending}

    # When the first tool event arrives and there's already a visible assistant
    # message, we steal the message's dom_id for the tool group. This replaces
    # the message in-place (keeping it above the cursor) and re-emits the
    # message with a fresh id so it appears after the tool group.
    {acc, swap_actions} = maybe_swap_message_before_tools(acc)
    {acc, group_actions} = add_to_tool_group(acc, combined)

    {acc, swap_actions ++ group_actions ++ [{:push_event, "scroll-bottom", %{}}]}
  end

  defp handle_tool_complete(acc, data) do
    tool_call_id = data["toolCallId"]
    tool_info = Map.get(acc.pending_tools, tool_call_id)

    if tool_info do
      updates = %{
        "completed" => true,
        "success" => data["success"],
        "result" => data["result"],
        "error" => data["error"]
      }

      pending = Map.delete(acc.pending_tools, tool_call_id)
      acc = %{acc | pending_tools: pending}
      {acc, group_actions} = update_in_tool_group(acc, tool_call_id, updates)

      {acc, group_actions ++ [{:push_event, "scroll-bottom", %{}}]}
    else
      dom_id = "ev-#{System.unique_integer([:positive])}"

      event_map = %{
        type: "tool.execution_complete",
        data: data,
        dom_id: dom_id
      }

      {acc, [{:stream_insert, event_map}, {:push_event, "scroll-bottom", %{}}]}
    end
  end

  defp handle_turn_start(acc) do
    acc = %{acc | assistant_text: "", assistant_msg_id: nil}
    acc = reset_tool_group(acc)
    {acc, []}
  end

  defp handle_fallthrough(acc, type, data) do
    event_map = %{
      type: type,
      data: data,
      dom_id: "ev-#{System.unique_integer([:positive])}"
    }

    {acc, group_actions} = add_to_tool_group(acc, event_map)
    {acc, group_actions ++ [{:push_event, "scroll-bottom", %{}}]}
  end

  # ── Message/tool ordering ──

  # When the first tool event arrives in a turn and there's already a visible
  # assistant message, we need to swap their positions so tools appear first.
  #
  # Strategy: give the tool group the old message's dom_id (replacing it
  # in-place in the stream), then re-emit the message with a new dom_id
  # so it appears at the end (after the tool group).
  defp maybe_swap_message_before_tools(acc) do
    if acc.tool_group_id == nil and acc.assistant_msg_id != nil and acc.assistant_text != "" do
      old_msg_id = acc.assistant_msg_id
      new_msg_id = "assistant-msg-#{System.unique_integer([:positive])}"

      # The tool group will take the old message's position
      acc = %{acc | tool_group_id: old_msg_id, assistant_msg_id: new_msg_id}

      # Re-emit the assistant message with the new dom_id (appears at end)
      msg_event = %{
        type: "assistant.message.block",
        data: %{"content" => acc.assistant_text},
        dom_id: new_msg_id
      }

      {acc, [{:stream_insert, msg_event}]}
    else
      {acc, []}
    end
  end

  # ── Tool group management ──

  defp add_to_tool_group(acc, event_data) do
    group_events = acc.tool_group_events ++ [event_data]

    group_id =
      acc.tool_group_id || "tool-group-live-#{System.unique_integer([:positive])}"

    group = build_tool_group(group_events, group_id)

    acc = %{acc | tool_group_events: group_events, tool_group_id: group_id}
    {acc, [{:stream_insert, group}]}
  end

  defp update_in_tool_group(acc, tool_call_id, updates) do
    group_events =
      Enum.map(acc.tool_group_events, fn evt ->
        if evt.type == "tool.combined" && evt.data["toolCallId"] == tool_call_id do
          %{evt | data: Map.merge(evt.data, updates)}
        else
          evt
        end
      end)

    group = build_tool_group(group_events, acc.tool_group_id)

    acc = %{acc | tool_group_events: group_events}
    {acc, [{:stream_insert, group}]}
  end

  defp reset_tool_group(acc) do
    %{acc | tool_group_events: [], tool_group_id: nil}
  end

  defp build_tool_group(events, group_id) do
    tool_events = Enum.filter(events, &(&1.type == "tool.combined"))
    tool_names = tool_events |> Enum.map(& &1.data["toolName"]) |> Enum.uniq()

    %{
      type: "tool.group",
      data: %{
        "events" => events,
        "tool_names" => tool_names,
        "tool_count" => length(tool_events)
      },
      dom_id: group_id
    }
  end
end
