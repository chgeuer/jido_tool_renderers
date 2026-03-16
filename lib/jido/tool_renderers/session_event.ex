defmodule Jido.ToolRenderers.SessionEvent do
  @moduledoc """
  Normalized event struct for coding agent session conversations.

  Both copilot_lv and jido_symphony normalize their agent-specific events
  (Claude, Codex, Gemini, Copilot) into this common format before passing
  them to the session viewer components.

  ## Event Types

  ### User
  - `:user_message` — user prompt text, optional attachments

  ### Assistant
  - `:assistant_message` — LLM output text (accumulated from chunks)
  - `:assistant_reasoning` — internal thinking/reasoning blocks
  - `:assistant_intent` — reported intent/status update
  - `:assistant_usage` — token usage stats for a turn

  ### Tools
  - `:tool_call` — individual tool invocation with args and optional result
  - `:tool_group` — grouped consecutive tool calls (collapsible section)

  ### Session Lifecycle
  - `:turn_start` — beginning of an assistant turn
  - `:turn_end` — end of an assistant turn
  - `:session_error` — error message
  - `:session_info` — informational status message
  - `:session_idle` — session is idle/waiting

  ### Interaction
  - `:ask_user` — agent requesting user input (question + optional choices)
  """

  @type event_type ::
          :user_message
          | :assistant_message
          | :assistant_reasoning
          | :assistant_intent
          | :assistant_usage
          | :tool_call
          | :tool_group
          | :turn_start
          | :turn_end
          | :session_error
          | :session_info
          | :session_idle
          | :ask_user

  @type t :: %__MODULE__{
          id: String.t(),
          type: event_type(),
          data: map(),
          timestamp: DateTime.t() | nil,
          metadata: map()
        }

  @enforce_keys [:id, :type, :data]
  defstruct [:id, :type, :data, :timestamp, metadata: %{}]

  @doc """
  Creates a user message event.
  """
  @spec user_message(String.t(), keyword()) :: t()
  def user_message(content, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: :user_message,
      data: %{
        "content" => content,
        "attachments" => Keyword.get(opts, :attachments, [])
      },
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates an assistant message event.
  """
  @spec assistant_message(String.t(), keyword()) :: t()
  def assistant_message(content, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: :assistant_message,
      data: %{"content" => content},
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates an assistant reasoning/thinking event.
  """
  @spec assistant_reasoning(String.t(), keyword()) :: t()
  def assistant_reasoning(content, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: :assistant_reasoning,
      data: %{"content" => content},
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates an assistant intent/status event.
  """
  @spec assistant_intent(String.t(), keyword()) :: t()
  def assistant_intent(intent, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: :assistant_intent,
      data: %{"intent" => intent},
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a tool call event.

  ## Data Fields
  - `"tool"` — tool name string
  - `"arguments"` — tool arguments (map or string)
  - `"tool_call_id"` — unique identifier for the tool invocation
  - `"completed"` — whether the tool has finished
  - `"result"` — tool output (nil if not completed)
  - `"error"` — error message if tool failed
  """
  @spec tool_call(String.t(), map() | String.t(), keyword()) :: t()
  def tool_call(tool_name, arguments, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: :tool_call,
      data: %{
        "tool" => tool_name,
        "arguments" => arguments,
        "tool_call_id" => Keyword.get(opts, :tool_call_id, generate_id()),
        "completed" => Keyword.get(opts, :completed, false),
        "result" => Keyword.get(opts, :result),
        "error" => Keyword.get(opts, :error)
      },
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a tool group event wrapping multiple tool calls.

  ## Data Fields
  - `"events"` — list of child SessionEvent structs or raw event maps
  - `"tool_names"` — list of unique tool names in the group
  - `"tool_count"` — number of tool calls in the group
  - `"all_completed"` — whether all tools have finished
  """
  @spec tool_group(list(), keyword()) :: t()
  def tool_group(events, opts \\ []) do
    tool_names = Keyword.get(opts, :tool_names, [])
    tool_count = Keyword.get(opts, :tool_count, length(events))

    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: :tool_group,
      data: %{
        "events" => events,
        "tool_names" => tool_names,
        "tool_count" => tool_count,
        "all_completed" => Keyword.get(opts, :all_completed, false)
      },
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a usage stats event.

  ## Data Fields
  - `"input_tokens"` — tokens consumed by input
  - `"output_tokens"` — tokens produced as output
  - `"total_cost"` — estimated cost string
  """
  @spec usage(map(), keyword()) :: t()
  def usage(stats, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: :assistant_usage,
      data: stats,
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates an ask_user event.
  """
  @spec ask_user(String.t(), keyword()) :: t()
  def ask_user(question, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: :ask_user,
      data: %{
        "question" => question,
        "choices" => Keyword.get(opts, :choices, []),
        "request_id" => Keyword.get(opts, :request_id)
      },
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a session lifecycle event.
  """
  @spec lifecycle(event_type(), keyword()) :: t()
  def lifecycle(type, opts \\ [])
      when type in [:turn_start, :turn_end, :session_idle, :session_error, :session_info] do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      type: type,
      data: %{"content" => Keyword.get(opts, :content, "")},
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp generate_id, do: "evt-#{System.unique_integer([:positive, :monotonic])}"
end
