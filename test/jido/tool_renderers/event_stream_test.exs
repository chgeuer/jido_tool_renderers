defmodule Jido.ToolRenderers.EventStreamTest do
  use ExUnit.Case, async: true

  alias Jido.ToolRenderers.EventStream

  describe "noise_event_types/0" do
    test "includes session lifecycle events" do
      noise = EventStream.noise_event_types()
      assert MapSet.member?(noise, "session.truncation")
      assert MapSet.member?(noise, "session.start")
      assert MapSet.member?(noise, "session.shutdown")
    end

    test "noise?/1 returns true for noise types" do
      assert EventStream.noise?("hook.start")
      assert EventStream.noise?("pending_messages.modified")
      refute EventStream.noise?("assistant.message")
      refute EventStream.noise?("user.message")
    end
  end

  describe "build_events/2 for :copilot" do
    test "accumulates assistant message chunks into blocks" do
      events = [
        %{type: "assistant.message", data: %{"content" => "Hello "}, dom_id: "e1"},
        %{type: "assistant.message", data: %{"content" => "world"}, dom_id: "e2"}
      ]

      result = EventStream.build_events(events, :copilot)
      msg = Enum.find(result, &(&1.type == "assistant.message.block"))
      assert msg.data["content"] == "Hello world"
    end

    test "extracts reasoningText into assistant.reasoning events" do
      events = [
        %{
          type: "assistant.message",
          data: %{"content" => "answer", "reasoningText" => "Let me think..."},
          dom_id: "e1"
        }
      ]

      result = EventStream.build_events(events, :copilot)
      reasoning = Enum.find(result, &(&1.type == "assistant.reasoning"))
      assert reasoning.data["content"] == "Let me think..."
    end

    test "combines tool start and complete into tool.combined inside a group" do
      events = [
        %{
          type: "tool.execution_start",
          data: %{"toolCallId" => "c1", "toolName" => "bash", "arguments" => "ls"},
          dom_id: "e1"
        },
        %{
          type: "tool.execution_complete",
          data: %{"toolCallId" => "c1", "success" => true, "result" => "file.txt"},
          dom_id: "e2"
        }
      ]

      result = EventStream.build_events(events, :copilot)
      group = Enum.find(result, &(&1.type == "tool.group"))
      assert group
      tool = Enum.find(group.data["events"], &(&1.type == "tool.combined"))
      assert tool.data["completed"] == true
      assert tool.data["result"] == "file.txt"
    end

    test "filters noise events" do
      events = [
        %{type: "session.start", data: %{}, dom_id: "e1"},
        %{type: "hook.start", data: %{}, dom_id: "e2"},
        %{type: "assistant.message", data: %{"content" => "hi"}, dom_id: "e3"}
      ]

      result = EventStream.build_events(events, :copilot)
      types = Enum.map(result, & &1.type)
      refute "session.start" in types
      refute "hook.start" in types
    end

    test "groups tool calls into collapsible tool.group" do
      events = [
        %{type: "user.message", data: %{"content" => "do stuff"}, dom_id: "e0"},
        %{
          type: "tool.execution_start",
          data: %{"toolCallId" => "c1", "toolName" => "bash", "arguments" => "ls"},
          dom_id: "e1"
        },
        %{
          type: "tool.execution_complete",
          data: %{"toolCallId" => "c1", "success" => true, "result" => "ok"},
          dom_id: "e2"
        },
        %{type: "assistant.message", data: %{"content" => "Done!"}, dom_id: "e3"}
      ]

      result = EventStream.build_events(events, :copilot)
      group = Enum.find(result, &(&1.type == "tool.group"))
      assert group
      assert group.data["tool_count"] == 1
    end
  end

  describe "build_events/2 for :claude" do
    test "extracts thinking blocks as assistant.reasoning" do
      events = [
        %{
          type: "assistant",
          data: %{
            "message" => %{
              "content" => [
                %{"type" => "thinking", "thinking" => "I need to analyze this"},
                %{"type" => "text", "text" => "Here's my answer"}
              ]
            }
          },
          dom_id: "e1"
        }
      ]

      result = EventStream.build_events(events, :claude)
      reasoning = Enum.find(result, &(&1.type == "assistant.reasoning"))
      assert reasoning.data["content"] == "I need to analyze this"
      msg = Enum.find(result, &(&1.type == "assistant.message.block"))
      assert msg.data["content"] == "Here's my answer"
    end

    test "extracts user messages from content blocks" do
      events = [
        %{
          type: "user",
          data: %{"message" => %{"content" => "Hello Claude"}},
          dom_id: "e1"
        }
      ]

      result = EventStream.build_events(events, :claude)
      msg = Enum.find(result, &(&1.type == "user.message"))
      assert msg.data["content"] == "Hello Claude"
    end
  end

  describe "build_events/2 for :codex" do
    test "extracts reasoning from response_item events" do
      events = [
        %{
          type: "response_item",
          data: %{
            "payload" => %{
              "type" => "reasoning",
              "text" => "Let me think about this"
            }
          },
          dom_id: "e1"
        }
      ]

      result = EventStream.build_events(events, :codex)
      reasoning = Enum.find(result, &(&1.type == "assistant.reasoning"))
      assert reasoning.data["content"] == "Let me think about this"
    end
  end

  describe "build_events/2 for :gemini" do
    test "extracts thoughts as reasoning" do
      events = [
        %{
          type: "gemini",
          data: %{
            "content" => "Result text",
            "thoughts" => [
              %{"subject" => "Analysis", "description" => "considering options"}
            ]
          },
          dom_id: "e1"
        }
      ]

      result = EventStream.build_events(events, :gemini)
      reasoning = Enum.find(result, &(&1.type == "assistant.reasoning"))
      assert reasoning.data["content"] =~ "Analysis"
    end
  end

  describe "build_events/2 for :pi" do
    test "extracts thinking from assistant messages" do
      events = [
        %{
          type: "message",
          data: %{
            "message" => %{
              "role" => "assistant",
              "content" => [
                %{"type" => "thinking", "thinking" => "Pi thinking..."},
                %{"type" => "text", "text" => "Here's the result"}
              ]
            }
          },
          dom_id: "e1"
        }
      ]

      result = EventStream.build_events(events, :pi)
      reasoning = Enum.find(result, &(&1.type == "assistant.reasoning"))
      assert reasoning.data["content"] == "Pi thinking..."
    end
  end
end
