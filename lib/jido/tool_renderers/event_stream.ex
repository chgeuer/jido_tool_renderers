defmodule Jido.ToolRenderers.EventStream do
  @moduledoc """
  Transforms raw agent events into normalized stream events for rendering.

  Each coding agent (Copilot, Claude, Codex, Gemini, Pi) stores events in
  its own format. This module normalizes them into a common set of event types:

  - `"user.message"` — user prompt
  - `"assistant.message.block"` — accumulated assistant text
  - `"assistant.reasoning"` — thinking/reasoning blocks
  - `"tool.combined"` — tool call with merged result
  - `"tool.group"` — collapsible group of tool calls
  - `"assistant.turn_start"` / `"assistant.turn_end"` — turn boundaries

  ## Usage

      events = EventStream.build_events(raw_db_events, :copilot)
      # => [%{type: "user.message", data: %{...}, dom_id: "..."}]
  """

  @noise_event_types MapSet.new([
    "session.truncation",
    "session.start",
    "session.model_change",
    "session.compaction_start",
    "session.compaction_complete",
    "session.plan_changed",
    "session.resume",
    "session.shutdown",
    "session.context_changed",
    "session.mode_changed",
    "session.workspace_file_changed",
    "session.usage_info",
    "file-history-snapshot",
    "progress",
    "queue-operation",
    "compacted",
    "custom-title",
    "hook.start",
    "hook.end",
    "permission.requested",
    "permission.completed",
    "tool.user_requested",
    "tool.execution_partial_result",
    "external_tool.completed",
    "session.background_tasks_changed",
    "session.tools_updated",
    "pending_messages.modified",
    # Codex-specific noise events
    "codex_event",
    "codex_token_update",
    "codex_rate_limits_updated",
    "codex_turn_diff_updated",
    "codex_turn_plan_updated",
    "codex_mcp_tool_progress",
    "codex_request_user_input",
    "codex_warning",
    "codex_turn_continuation",
    # File changes (tracked separately)
    "file.change"
  ])

  @doc "Returns the set of event types that are filtered as noise."
  def noise_event_types, do: @noise_event_types

  @doc "Returns true if the given event type is noise."
  def noise?(type), do: MapSet.member?(@noise_event_types, type)

  @doc """
  Builds normalized stream events from raw DB events for the given agent.

  Returns a list of normalized event maps ready for rendering.
  """
  @spec build_events([map()], atom()) :: [map()]
  def build_events(events, agent) do
    {stream_events, _, _} =
      case agent do
        :claude -> build_claude_events(events)
        :codex -> build_codex_events(events)
        :gemini -> build_gemini_events(events)
        :pi -> build_pi_events(events)
        _ -> build_copilot_events(events)
      end

    stream_events
  end

  # ── Generic/Copilot event processing ──

  @doc false
  def build_copilot_events(events) do
    {flat, _text, _msg_id, _msg_idx, _pending} =
      events
      |> Enum.reject(fn e -> MapSet.member?(@noise_event_types, e.type) end)
      |> Enum.reduce({[], "", nil, nil, %{}}, fn event, {acc, text, msg_id, msg_idx, pending} ->
        case event.type do
          "assistant.message" ->
            reasoning = event.data["reasoningText"]

            acc =
              if is_binary(reasoning) and String.trim(reasoning) != "" do
                acc ++
                  [
                    %{
                      type: "assistant.reasoning",
                      data: %{"content" => reasoning},
                      dom_id: "copilot-reasoning-#{System.unique_integer([:positive])}"
                    }
                  ]
              else
                acc
              end

            chunk = event.data["chunkContent"] || event.data["content"] || ""
            new_text = text <> chunk
            new_id = msg_id || "assistant-msg-replay-#{System.unique_integer([:positive])}"

            block = %{
              type: "assistant.message.block",
              data: %{"content" => new_text},
              dom_id: new_id
            }

            {updated_acc, new_idx} =
              if msg_idx do
                {List.replace_at(acc, msg_idx, block), msg_idx}
              else
                {acc ++ [block], length(acc)}
              end

            {updated_acc, new_text, new_id, new_idx, pending}

          "tool.execution_start" ->
            tool_call_id = event.data["toolCallId"]
            dom_id = "tool-replay-#{tool_call_id || System.unique_integer([:positive])}"

            combined = %{
              type: "tool.combined",
              data: %{
                "toolName" => event.data["toolName"],
                "arguments" => event.data["arguments"],
                "toolCallId" => tool_call_id,
                "completed" => false
              },
              dom_id: dom_id
            }

            new_pending = Map.put(pending, tool_call_id, %{dom_id: dom_id, index: length(acc)})
            {acc ++ [combined], text, msg_id, msg_idx, new_pending}

          "tool.execution_complete" ->
            tool_call_id = event.data["toolCallId"]
            tool_info = Map.get(pending, tool_call_id)

            if tool_info do
              existing = Enum.at(acc, tool_info.index)

              updated = %{
                existing
                | data:
                    Map.merge(existing.data, %{
                      "completed" => true,
                      "success" => event.data["success"],
                      "result" => event.data["result"],
                      "error" => event.data["error"]
                    })
              }

              updated_acc = List.replace_at(acc, tool_info.index, updated)
              new_pending = Map.delete(pending, tool_call_id)
              {updated_acc, text, msg_id, msg_idx, new_pending}
            else
              {acc ++ [event], text, msg_id, msg_idx, pending}
            end

          t when t in ["assistant.turn_start", "user.message"] ->
            {acc ++ [event], "", nil, nil, pending}

          _ ->
            {acc ++ [event], text, msg_id, msg_idx, pending}
        end
      end)

    grouped = group_into_collapsible(flat)
    {grouped, "", nil}
  end

  # ── Collapsible grouping ──

  @doc false
  def group_into_collapsible(events) do
    {acc, current_group} =
      Enum.reduce(events, {[], []}, fn event, {acc, group} ->
        if event.type == "user.message" do
          acc = flush_tool_group_with_trailing_message(acc, group)
          {acc ++ [event], []}
        else
          {acc, group ++ [event]}
        end
      end)

    flush_tool_group_with_trailing_message(acc, current_group)
  end

  defp flush_tool_group_with_trailing_message(acc, []), do: acc

  defp flush_tool_group_with_trailing_message(acc, events) do
    last_msg_idx =
      events
      |> Enum.with_index()
      |> Enum.filter(fn {e, _} ->
        e.type == "assistant.message.block" && String.trim(e.data["content"] || "") != ""
      end)
      |> List.last()

    case last_msg_idx do
      {msg, idx} ->
        group_events = List.delete_at(events, idx)
        acc = if group_events != [], do: flush_tool_group(acc, group_events), else: acc
        acc ++ [msg]

      nil ->
        flush_tool_group(acc, events)
    end
  end

  defp flush_tool_group(acc, []), do: acc

  defp flush_tool_group(acc, events) do
    tool_events = Enum.filter(events, &(&1.type == "tool.combined"))

    if tool_events == [] do
      visible =
        Enum.filter(events, &(&1.type in ["assistant.message.block", "assistant.reasoning"]))

      acc ++ visible
    else
      tool_names = tool_events |> Enum.map(& &1.data["toolName"]) |> Enum.uniq()
      tool_count = length(tool_events)

      group = %{
        type: "tool.group",
        data: %{
          "events" => events,
          "tool_names" => tool_names,
          "tool_count" => tool_count
        },
        dom_id: "tool-group-#{System.unique_integer([:positive])}"
      }

      acc ++ [group]
    end
  end

  # ── Shared tool result merger ──

  defp merge_tool_results(events) do
    outputs =
      events
      |> Enum.filter(&(&1.type == "tool.execution_complete"))
      |> Map.new(&{&1.data["toolCallId"], &1.data})

    Enum.flat_map(events, fn event ->
      case event.type do
        "tool.combined" ->
          case Map.get(outputs, event.data["toolCallId"]) do
            nil ->
              [event]

            output_data ->
              [
                %{
                  event
                  | data:
                      Map.merge(event.data, %{
                        "completed" => true,
                        "success" => output_data["success"],
                        "result" => output_data["result"],
                        "error" => output_data["error"]
                      })
                }
              ]
          end

        "tool.execution_complete" ->
          if Map.has_key?(outputs, event.data["toolCallId"]) &&
               Enum.any?(
                 events,
                 &(&1.type == "tool.combined" && &1.data["toolCallId"] == event.data["toolCallId"])
               ) do
            []
          else
            [event]
          end

        _ ->
          [event]
      end
    end)
  end

  # ── Claude event processing ──

  @doc false
  def build_claude_events(events) do
    flat =
      events
      |> Enum.reject(fn e ->
        e.type in ["file-history-snapshot", "summary", "system"]
      end)
      |> Enum.flat_map(&claude_event_to_stream/1)
      |> merge_tool_results()

    grouped = group_into_collapsible(flat)
    {grouped, "", nil}
  end

  defp claude_event_to_stream(%{type: "user", data: data} = event) do
    content = get_in(data, ["message", "content"])

    cond do
      is_list(content) && Enum.any?(content, &(is_map(&1) && &1["type"] == "tool_result")) ->
        Enum.flat_map(content, fn
          %{"type" => "tool_result", "tool_use_id" => id} = block ->
            result = block["content"]

            result_text =
              cond do
                is_binary(result) -> result
                is_list(result) ->
                  Enum.map_join(result, "\n", fn
                    %{"text" => t} when is_binary(t) -> t
                    other -> inspect(other)
                  end)
                true -> inspect(result)
              end

            is_error =
              case block["is_error"] do
                true -> true
                _ ->
                  case data["toolUseResult"] do
                    %{"is_error" => true} -> true
                    _ -> false
                  end
              end

            [
              %{
                type: "tool.execution_complete",
                data: %{
                  "toolCallId" => id,
                  "result" => result_text,
                  "success" => !is_error,
                  "error" => if(is_error, do: result_text)
                },
                dom_id: "claude-tool-result-#{id}"
              }
            ]

          _ ->
            []
        end)

      is_binary(content) ->
        [%{type: "user.message", data: %{"content" => content}, dom_id: event.dom_id}]

      is_list(content) ->
        text =
          content
          |> Enum.flat_map(fn
            %{"type" => "text", "text" => t} -> [t]
            _ -> []
          end)
          |> Enum.join("\n")

        if String.trim(text) != "" do
          [%{type: "user.message", data: %{"content" => text}, dom_id: event.dom_id}]
        else
          []
        end

      true ->
        []
    end
  end

  defp claude_event_to_stream(%{type: "assistant", data: data}) do
    content = get_in(data, ["message", "content"])

    if is_list(content) do
      content
      |> Enum.flat_map(fn
        %{"type" => "text", "text" => text} when is_binary(text) and text != "" ->
          [
            %{
              type: "assistant.message.block",
              data: %{"content" => text},
              dom_id: "claude-text-#{System.unique_integer([:positive])}"
            }
          ]

        %{"type" => "thinking", "thinking" => thinking}
        when is_binary(thinking) and thinking != "" ->
          [
            %{
              type: "assistant.reasoning",
              data: %{"content" => thinking},
              dom_id: "claude-thinking-#{System.unique_integer([:positive])}"
            }
          ]

        %{"type" => "tool_use", "id" => id, "name" => name, "input" => input} ->
          [
            %{
              type: "tool.combined",
              data: %{
                "toolName" => name,
                "toolCallId" => id,
                "arguments" => input,
                "completed" => false
              },
              dom_id: "claude-tool-#{id}"
            }
          ]

        _ ->
          []
      end)
    else
      []
    end
  end

  defp claude_event_to_stream(_event), do: []

  # ── Codex event processing ──

  @doc false
  def build_codex_events(events) do
    flat =
      events
      |> Enum.reject(fn e -> e.type in ["session_meta", "turn_context"] end)
      |> Enum.flat_map(&codex_event_to_stream/1)
      |> merge_tool_results()

    grouped = group_into_collapsible(flat)
    {grouped, "", nil}
  end

  defp codex_event_to_stream(%{type: "response_item", data: data} = event) do
    payload = data["payload"] || %{}
    role = payload["role"]
    content = payload["content"]
    payload_type = payload["type"]

    cond do
      role == "user" && is_list(content) ->
        text =
          content
          |> Enum.flat_map(fn
            %{"type" => "input_text", "text" => t} when is_binary(t) -> [t]
            _ -> []
          end)
          |> Enum.join("\n")
          |> String.trim()

        if text != "" && !String.starts_with?(text, "#") && !String.starts_with?(text, "<") do
          [%{type: "user.message", data: %{"content" => text}, dom_id: event.dom_id}]
        else
          []
        end

      role == "assistant" && is_list(content) ->
        Enum.flat_map(content, fn
          %{"type" => "output_text", "text" => t} when is_binary(t) and t != "" ->
            [
              %{
                type: "assistant.message.block",
                data: %{"content" => t},
                dom_id: "codex-text-#{System.unique_integer([:positive])}"
              }
            ]

          %{"type" => "text", "text" => t} when is_binary(t) and t != "" ->
            [
              %{
                type: "assistant.message.block",
                data: %{"content" => t},
                dom_id: "codex-text-#{System.unique_integer([:positive])}"
              }
            ]

          _ ->
            []
        end)

      payload_type in ["function_call", "custom_tool_call"] ->
        name = payload["name"] || payload["function"] || "tool"
        call_id = payload["call_id"] || payload["id"]
        args = payload["arguments"]

        args_str =
          cond do
            is_binary(args) -> args
            is_map(args) -> Jason.encode!(args, pretty: true)
            true -> inspect(args)
          end

        [
          %{
            type: "tool.combined",
            data: %{
              "toolName" => name,
              "toolCallId" => call_id,
              "arguments" => args_str,
              "completed" => false
            },
            dom_id: "codex-tool-#{call_id || System.unique_integer([:positive])}"
          }
        ]

      payload_type in ["function_call_output", "custom_tool_call_output"] ->
        call_id = payload["call_id"] || payload["id"]
        output = payload["output"] || ""

        [
          %{
            type: "tool.execution_complete",
            data: %{
              "toolCallId" => call_id,
              "result" => if(is_binary(output), do: output, else: Jason.encode!(output)),
              "success" => true,
              "error" => nil
            },
            dom_id: "codex-tool-result-#{call_id || System.unique_integer([:positive])}"
          }
        ]

      payload_type == "reasoning" ->
        text = payload["text"] || payload["content"]

        if is_binary(text) && String.trim(text) != "" do
          [
            %{
              type: "assistant.reasoning",
              data: %{"content" => text},
              dom_id: "codex-reasoning-#{System.unique_integer([:positive])}"
            }
          ]
        else
          []
        end

      true ->
        []
    end
  end

  defp codex_event_to_stream(%{type: "event_msg", data: _data}), do: []

  defp codex_event_to_stream(_event), do: []

  # ── Gemini event processing ──

  @doc false
  def build_gemini_events(events) do
    flat =
      events
      |> Enum.reject(fn e -> e.type in ["session_meta", "info"] end)
      |> Enum.flat_map(&gemini_event_to_stream/1)

    grouped = group_into_collapsible(flat)
    {grouped, "", nil}
  end

  defp gemini_event_to_stream(%{type: "user", data: data} = event) do
    text = data["content"]

    if is_binary(text) && String.trim(text) != "" do
      [%{type: "user.message", data: %{"content" => text}, dom_id: event.dom_id}]
    else
      []
    end
  end

  defp gemini_event_to_stream(%{type: type, data: data} = _event)
       when type in ["assistant", "gemini"] do
    result = []

    result =
      case data["thoughts"] do
        thoughts when is_list(thoughts) and thoughts != [] ->
          thinking_text =
            Enum.map_join(thoughts, "\n\n", fn t ->
              subject = if is_binary(t["subject"]), do: "**#{t["subject"]}**: ", else: ""
              "#{subject}#{t["description"] || ""}"
            end)

          [
            %{
              type: "assistant.reasoning",
              data: %{"content" => thinking_text},
              dom_id: "gemini-thinking-#{System.unique_integer([:positive])}"
            }
            | result
          ]

        _ ->
          result
      end

    result =
      case data["toolCalls"] do
        calls when is_list(calls) and calls != [] ->
          tool_events =
            Enum.flat_map(calls, fn call ->
              name = call["name"] || call["toolName"] || "tool"
              args = call["args"] || call["input"] || %{}
              call_id = call["id"] || "gemini-call-#{System.unique_integer([:positive])}"
              output = extract_gemini_tool_output(call)

              args_str =
                if is_map(args), do: Jason.encode!(args, pretty: true), else: inspect(args)

              [
                %{
                  type: "tool.combined",
                  data: %{
                    "toolName" => name,
                    "toolCallId" => call_id,
                    "arguments" => args_str,
                    "completed" => output != nil,
                    "success" => call["status"] != "error",
                    "result" => output || ""
                  },
                  dom_id: "gemini-tool-#{call_id}"
                }
              ]
            end)

          tool_events ++ result

        _ ->
          result
      end

    result =
      case data["content"] do
        text when is_binary(text) and text != "" ->
          [
            %{
              type: "assistant.message.block",
              data: %{"content" => text},
              dom_id: "gemini-text-#{System.unique_integer([:positive])}"
            }
            | result
          ]

        _ ->
          result
      end

    Enum.reverse(result)
  end

  defp gemini_event_to_stream(_event), do: []

  defp extract_gemini_tool_output(call) do
    cond do
      is_binary(call["output"]) ->
        call["output"]

      is_list(call["result"]) ->
        call["result"]
        |> Enum.flat_map(fn
          %{"functionResponse" => %{"response" => %{"output" => output}}}
          when is_binary(output) ->
            [output]

          %{"functionResponse" => %{"response" => resp}} when is_map(resp) ->
            [Jason.encode!(resp, pretty: true)]

          _ ->
            []
        end)
        |> Enum.join("\n")
        |> case do
          "" -> nil
          text -> text
        end

      is_map(call["result"]) ->
        Jason.encode!(call["result"], pretty: true)

      true ->
        nil
    end
  end

  # ── Pi event processing ──

  @doc false
  def build_pi_events(events) do
    flat =
      events
      |> Enum.reject(fn e ->
        e.type in ["session", "model_change", "thinking_level_change"]
      end)
      |> Enum.flat_map(&pi_event_to_stream/1)
      |> merge_tool_results()

    grouped = group_into_collapsible(flat)
    {grouped, "", nil}
  end

  defp pi_event_to_stream(%{type: "message", data: data} = event) do
    role = get_in(data, ["message", "role"])
    content = get_in(data, ["message", "content"]) || []

    case role do
      "user" ->
        text =
          content
          |> Enum.flat_map(fn
            %{"type" => "text", "text" => t} when is_binary(t) -> [t]
            _ -> []
          end)
          |> Enum.join("\n")

        if String.trim(text) != "" do
          [%{type: "user.message", data: %{"content" => text}, dom_id: event.dom_id}]
        else
          []
        end

      "assistant" ->
        Enum.flat_map(content, fn
          %{"type" => "thinking", "thinking" => thinking}
          when is_binary(thinking) and thinking != "" ->
            [
              %{
                type: "assistant.reasoning",
                data: %{"content" => thinking},
                dom_id: "pi-thinking-#{System.unique_integer([:positive])}"
              }
            ]

          %{"type" => "text", "text" => text}
          when is_binary(text) and text != "" ->
            [
              %{
                type: "assistant.message.block",
                data: %{"content" => text},
                dom_id: "pi-text-#{System.unique_integer([:positive])}"
              }
            ]

          %{"type" => "toolCall", "name" => name, "id" => id} = call ->
            [
              %{
                type: "tool.combined",
                data: %{
                  "toolName" => name,
                  "toolCallId" => id,
                  "arguments" => call["arguments"] || %{},
                  "completed" => false
                },
                dom_id: "pi-tool-#{id}"
              }
            ]

          _ ->
            []
        end)

      "toolResult" ->
        tool_call_id = get_in(data, ["message", "toolCallId"])
        tool_name = get_in(data, ["message", "toolName"])
        is_error = get_in(data, ["message", "isError"]) == true

        result_text =
          content
          |> Enum.flat_map(fn
            %{"type" => "text", "text" => t} when is_binary(t) -> [t]
            _ -> []
          end)
          |> Enum.join("\n")

        [
          %{
            type: "tool.execution_complete",
            data: %{
              "toolCallId" => tool_call_id,
              "toolName" => tool_name,
              "result" => result_text,
              "success" => !is_error,
              "error" => if(is_error, do: result_text)
            },
            dom_id: "pi-tool-result-#{tool_call_id || System.unique_integer([:positive])}"
          }
        ]

      _ ->
        []
    end
  end

  defp pi_event_to_stream(_event), do: []
end
