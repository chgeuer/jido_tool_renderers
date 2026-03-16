defmodule Jido.ToolRenderers.Adapters.CopilotLv do
  @moduledoc """
  Converts copilot_lv's normalized event maps into `SessionEvent` structs.

  copilot_lv normalizes events from different agents (Claude, Codex, Gemini, Copilot)
  into maps with string `type` fields like `"user.message"`, `"assistant.message.block"`,
  `"tool.combined"`, etc. This adapter converts those maps to `SessionEvent` structs
  for use with the session viewer components.

  ## Usage

      events = CopilotLv.convert_events(raw_events)
      # => [%SessionEvent{type: :user_message, ...}, ...]

      event = CopilotLv.convert_event(raw_event)
      # => %SessionEvent{type: :tool_call, ...}
  """

  alias Jido.ToolRenderers.SessionEvent

  @doc """
  Converts a list of copilot_lv event maps to `SessionEvent` structs.
  """
  @spec convert_events([map()]) :: [SessionEvent.t()]
  def convert_events(events) when is_list(events) do
    Enum.map(events, &convert_event/1)
  end

  @doc """
  Converts a single copilot_lv event map to a `SessionEvent` struct.
  """
  @spec convert_event(map()) :: SessionEvent.t()
  def convert_event(%{type: type, data: data} = event) do
    id = Map.get(event, :dom_id) || "evt-#{System.unique_integer([:positive, :monotonic])}"

    case type do
      "user.message" ->
        %SessionEvent{
          id: id,
          type: :user_message,
          data: data,
          metadata: extract_metadata(event)
        }

      "assistant.message.block" ->
        %SessionEvent{
          id: id,
          type: :assistant_message,
          data: data,
          metadata: extract_metadata(event)
        }

      "assistant.reasoning" ->
        %SessionEvent{
          id: id,
          type: :assistant_reasoning,
          data: data,
          metadata: extract_metadata(event)
        }

      "assistant.intent" ->
        %SessionEvent{
          id: id,
          type: :assistant_intent,
          data: data,
          metadata: extract_metadata(event)
        }

      "assistant.usage" ->
        %SessionEvent{
          id: id,
          type: :assistant_usage,
          data: normalize_usage_data(data),
          metadata: extract_metadata(event)
        }

      "tool.combined" ->
        %SessionEvent{
          id: id,
          type: :tool_call,
          data: normalize_tool_data(data),
          metadata: extract_metadata(event)
        }

      "tool.group" ->
        child_events = Map.get(data, "events", [])

        converted_children =
          Enum.map(child_events, fn child ->
            if is_map(child) and Map.has_key?(child, :type) do
              convert_event(child)
            else
              child
            end
          end)

        %SessionEvent{
          id: id,
          type: :tool_group,
          data: %{
            "events" => converted_children,
            "tool_names" =>
              data
              |> Map.get("tool_names", [])
              |> Enum.map(&Jido.ToolRenderers.canonical_tool_name/1)
              |> Enum.filter(&(is_binary(&1) && &1 != ""))
              |> Enum.uniq(),
            "tool_count" => Map.get(data, "tool_count", 0),
            "all_completed" =>
              Enum.all?(converted_children, fn
                %SessionEvent{type: :tool_call, data: d} -> Map.get(d, "completed", false)
                %{type: "tool.combined", data: d} -> Map.get(d, "completed", false)
                _ -> true
              end)
          },
          metadata: extract_metadata(event)
        }

      "assistant.turn_start" ->
        %SessionEvent{id: id, type: :turn_start, data: data, metadata: extract_metadata(event)}

      "assistant.turn_end" ->
        %SessionEvent{id: id, type: :turn_end, data: data, metadata: extract_metadata(event)}

      "session.idle" ->
        %SessionEvent{id: id, type: :session_idle, data: data, metadata: extract_metadata(event)}

      "session.error" ->
        %SessionEvent{
          id: id,
          type: :session_error,
          data: %{"content" => Map.get(data, "message", "")},
          metadata: extract_metadata(event)
        }

      "error" ->
        %SessionEvent{
          id: id,
          type: :session_error,
          data: %{"content" => Map.get(data, "message", Map.get(data, "content", ""))},
          metadata: extract_metadata(event)
        }

      "session.warning" ->
        %SessionEvent{
          id: id,
          type: :session_error,
          data: %{"content" => Map.get(data, "message", Map.get(data, "content", ""))},
          metadata: extract_metadata(event)
        }

      "session.info" ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => Map.get(data, "message", "")},
          metadata: extract_metadata(event)
        }

      "abort" ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "⛔ Cancelled"},
          metadata: extract_metadata(event)
        }

      "skill.invoked" ->
        skill_name = Map.get(data, "skill", Map.get(data, "name", "unknown"))

        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "🔌 Skill loaded: #{skill_name}"},
          metadata: extract_metadata(event)
        }

      "subagent.started" ->
        name = Map.get(data, "agentDisplayName", Map.get(data, "agentName", "agent"))

        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "🚀 #{name} started"},
          metadata: extract_metadata(event)
        }

      "subagent.completed" ->
        name = Map.get(data, "agentDisplayName", Map.get(data, "agentName", "agent"))

        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => "✅ #{name} completed"},
          metadata: extract_metadata(event)
        }

      "subagent.failed" ->
        name = Map.get(data, "agentDisplayName", Map.get(data, "agentName", "agent"))
        error = Map.get(data, "error", "unknown error")

        %SessionEvent{
          id: id,
          type: :session_error,
          data: %{"content" => "#{name} failed: #{error}"},
          metadata: extract_metadata(event)
        }

      "ask_user_request" ->
        %SessionEvent{
          id: id,
          type: :ask_user,
          data: data,
          metadata: extract_metadata(event)
        }

      _ ->
        %SessionEvent{
          id: id,
          type: :session_info,
          data: %{"content" => type},
          metadata: extract_metadata(event)
        }
    end
  end

  defp normalize_tool_data(data) do
    %{
      "tool" =>
        data
        |> Map.get("toolName", "unknown")
        |> Jido.ToolRenderers.canonical_tool_name(),
      "arguments" => normalize_tool_arguments(Map.get(data, "arguments")),
      "tool_call_id" => Map.get(data, "toolCallId"),
      "completed" => Map.get(data, "completed", false),
      "result" => Map.get(data, "result"),
      "error" => Map.get(data, "error")
    }
  end

  defp normalize_tool_arguments(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _ -> arguments
    end
  end

  defp normalize_tool_arguments(arguments), do: arguments

  defp normalize_usage_data(data) do
    %{
      "input_tokens" => Map.get(data, "inputTokens", 0),
      "output_tokens" => Map.get(data, "outputTokens", 0),
      "total_cost" => Map.get(data, "cost"),
      "model" => Map.get(data, "model")
    }
  end

  defp extract_metadata(event) do
    Map.take(event, [:agent, :model, :session_id])
  end
end
