defmodule Jido.ToolRenderers.Adapters.Symphony do
  @moduledoc """
  Converts jido_symphony's event maps into `SessionEvent` structs.

  Symphony uses atom-keyed event maps with a `:type` field containing atoms
  like `:agent_text`, `:tool_call`, etc. This adapter converts those to
  `SessionEvent` structs for session viewer components.

  It also converts coalesced "block" maps (with `:kind` field) that
  `agent_session_live.ex` produces.

  ## Usage

      # Convert raw events
      events = Symphony.convert_events(raw_events)

      # Convert a coalesced block
      event = Symphony.convert_block(block)
  """

  alias Jido.ToolRenderers.SessionEvent

  @doc """
  Converts a list of symphony raw events to `SessionEvent` structs.
  """
  @spec convert_events([map()]) :: [SessionEvent.t()]
  def convert_events(events) when is_list(events) do
    Enum.map(events, &convert_event/1)
  end

  @doc """
  Converts a single symphony raw event (atom-keyed) to a `SessionEvent` struct.
  """
  @spec convert_event(map()) :: SessionEvent.t()
  def convert_event(%{type: type} = event) do
    id = Map.get(event, :id) || "evt-#{System.unique_integer([:positive, :monotonic])}"
    timestamp = Map.get(event, :timestamp)

    case type do
      :agent_text ->
        %SessionEvent{
          id: id,
          type: :assistant_message,
          data: %{"content" => Map.get(event, :text, "")},
          timestamp: timestamp
        }

      :agent_thought ->
        %SessionEvent{
          id: id,
          type: :assistant_reasoning,
          data: %{"content" => Map.get(event, :text, "")},
          timestamp: timestamp
        }

      :tool_call ->
        %SessionEvent{
          id: id,
          type: :tool_call,
          data: %{
            "tool" =>
              event
              |> Map.get(:tool_name, "unknown")
              |> Jido.ToolRenderers.canonical_tool_name(),
            "arguments" => Map.get(event, :arguments, %{}),
            "tool_call_id" => Map.get(event, :tool_call_id),
            "completed" => false,
            "result" => nil,
            "error" => nil
          },
          timestamp: timestamp
        }

      :tool_call_completed ->
        %SessionEvent{
          id: id,
          type: :tool_call,
          data: %{
            "tool" =>
              event
              |> Map.get(:tool_name, "unknown")
              |> Jido.ToolRenderers.canonical_tool_name(),
            "arguments" => Map.get(event, :arguments, %{}),
            "tool_call_id" => Map.get(event, :tool_call_id),
            "completed" => true,
            "result" => Map.get(event, :result),
            "error" => nil
          },
          timestamp: timestamp
        }

      :session_started ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "Session started: #{Map.get(event, :session_id, "")}"},
          timestamp: timestamp
        }

      :turn_completed ->
        %SessionEvent{
          id: id,
          type: :turn_end,
          data: %{"content" => ""},
          timestamp: timestamp
        }

      :turn_ended_with_error ->
        %SessionEvent{
          id: id,
          type: :session_error,
          data: %{"content" => inspect(Map.get(event, :reason, "Unknown error"), limit: 200)},
          timestamp: timestamp
        }

      :plan ->
        entries = Map.get(event, :entries, [])

        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "📋 Plan updated (#{length(entries)} entries)"},
          timestamp: timestamp
        }

      :approval_auto_approved ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "✔ Auto-approved: #{Map.get(event, :decision, "")}"},
          timestamp: timestamp
        }

      _ ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "#{type}"},
          timestamp: timestamp
        }
    end
  end

  @doc """
  Converts a coalesced block map (as produced by `agent_session_live.ex`) to a `SessionEvent`.
  """
  @spec convert_block(map()) :: SessionEvent.t()
  def convert_block(%{kind: kind} = block) do
    id = Map.get(block, :id, "blk-#{System.unique_integer([:positive, :monotonic])}")
    timestamp = Map.get(block, :timestamp)

    case kind do
      :message ->
        %SessionEvent{
          id: id,
          type: :assistant_message,
          data: %{"content" => Map.get(block, :text, "")},
          timestamp: timestamp
        }

      :thought ->
        %SessionEvent{
          id: id,
          type: :assistant_reasoning,
          data: %{"content" => Map.get(block, :text, "")},
          timestamp: timestamp
        }

      :tool ->
        %SessionEvent{
          id: id,
          type: :tool_call,
          data: %{
            "tool" =>
              block
              |> Map.get(:tool_name, "unknown")
              |> Jido.ToolRenderers.canonical_tool_name(),
            "arguments" => Map.get(block, :arguments, %{}),
            "tool_call_id" => Map.get(block, :tool_call_id),
            "completed" => Map.get(block, :completed, false),
            "result" => Map.get(block, :result),
            "error" => nil
          },
          timestamp: timestamp
        }

      :tool_done ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "✔ Tool completed"},
          timestamp: timestamp
        }

      :session_started ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "🚀 Session started: #{Map.get(block, :session_id, "")}"},
          timestamp: timestamp
        }

      :turn_completed ->
        %SessionEvent{
          id: id,
          type: :turn_end,
          data: %{"content" => ""},
          timestamp: timestamp
        }

      :error ->
        %SessionEvent{
          id: id,
          type: :session_error,
          data: %{"content" => Map.get(block, :reason, "Unknown error")},
          timestamp: timestamp
        }

      :plan ->
        entries = Map.get(block, :entries, [])

        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "📋 Plan updated (#{length(entries)} entries)"},
          timestamp: timestamp
        }

      :approved ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "✔ Auto-approved: #{Map.get(block, :decision, "")}"},
          timestamp: timestamp
        }

      _ ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "#{kind}"},
          timestamp: timestamp
        }
    end
  end

  @doc """
  Converts a list of coalesced blocks to `SessionEvent` structs.
  """
  @spec convert_blocks([map()]) :: [SessionEvent.t()]
  def convert_blocks(blocks) when is_list(blocks) do
    Enum.map(blocks, &convert_block/1)
  end
end
