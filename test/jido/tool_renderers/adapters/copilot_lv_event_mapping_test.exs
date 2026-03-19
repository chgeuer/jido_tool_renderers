defmodule Jido.ToolRenderers.Adapters.CopilotLvEventMappingTest do
  use ExUnit.Case, async: true

  alias Jido.ToolRenderers.Adapters.CopilotLv

  describe "system.notification" do
    test "maps to :session_info with extracted content" do
      event = %{
        type: "system.notification",
        data: %{
          "data" => %{
            "content" =>
              "Agent \"agent-0\" (explore) has completed successfully.",
            "kind" => %{
              "agentType" => "explore",
              "description" => "Read spec docs",
              "status" => "completed",
              "type" => "agent_completed"
            }
          },
          "id" => "notif-1",
          "timestamp" => "2026-03-09T20:39:42.094Z"
        }
      }

      result = CopilotLv.convert_event(event)

      assert result.type == :session_info
      assert result.data["content"] =~ "Agent \"agent-0\" (explore) has completed successfully."
      assert result.data["content"] =~ "📢"
    end

    test "falls back to default message when content is missing" do
      event = %{
        type: "system.notification",
        data: %{"data" => %{}}
      }

      result = CopilotLv.convert_event(event)

      assert result.type == :session_info
      assert result.data["content"] =~ "System notification"
    end
  end

  describe "session.task_complete" do
    test "maps to :session_info with summary content" do
      event = %{
        type: "session.task_complete",
        data: %{
          "data" => %{
            "summary" => "Implemented event handling improvements across four work items."
          },
          "id" => "task-1",
          "timestamp" => "2026-03-09T19:13:35.853Z"
        }
      }

      result = CopilotLv.convert_event(event)

      assert result.type == :session_info
      assert result.data["content"] =~ "Implemented event handling improvements"
      assert result.data["content"] =~ "🏁"
    end

    test "falls back to default message when summary is missing" do
      event = %{
        type: "session.task_complete",
        data: %{"data" => %{}}
      }

      result = CopilotLv.convert_event(event)

      assert result.type == :session_info
      assert result.data["content"] =~ "Task completed"
    end
  end

  describe "external_tool.requested" do
    test "maps ask_user to :ask_user with question and comma-separated choices" do
      event = %{
        type: "external_tool.requested",
        data: %{
          "arguments" => %{
            "question" => "Who is your favorite Elixir hero?",
            "choices" => "José Valim, Chris McCord, Saša Jurić"
          },
          "toolName" => "ask_user",
          "toolCallId" => "call-1",
          "requestId" => "req-1"
        }
      }

      result = CopilotLv.convert_event(event)

      assert result.type == :ask_user
      assert result.data["question"] == "Who is your favorite Elixir hero?"
      assert result.data["choices"] == ["José Valim", "Chris McCord", "Saša Jurić"]
    end

    test "handles list-format choices" do
      event = %{
        type: "external_tool.requested",
        data: %{
          "arguments" => %{
            "question" => "Pick a color",
            "choices" => ["Red", "Green", "Blue"]
          }
        }
      }

      result = CopilotLv.convert_event(event)

      assert result.type == :ask_user
      assert result.data["choices"] == ["Red", "Green", "Blue"]
    end

    test "handles missing choices gracefully" do
      event = %{
        type: "external_tool.requested",
        data: %{
          "arguments" => %{
            "question" => "What do you think?"
          }
        }
      }

      result = CopilotLv.convert_event(event)

      assert result.type == :ask_user
      assert result.data["question"] == "What do you think?"
      assert result.data["choices"] == []
    end

    test "handles empty arguments gracefully" do
      event = %{
        type: "external_tool.requested",
        data: %{}
      }

      result = CopilotLv.convert_event(event)

      assert result.type == :ask_user
      assert result.data["question"] == ""
      assert result.data["choices"] == []
    end
  end

  describe "catch-all no longer fires for mapped types" do
    test "system.notification does not produce raw type string" do
      event = %{
        type: "system.notification",
        data: %{"data" => %{"content" => "test notification"}}
      }

      result = CopilotLv.convert_event(event)

      refute result.data["content"] == "system.notification"
    end

    test "session.task_complete does not produce raw type string" do
      event = %{
        type: "session.task_complete",
        data: %{"data" => %{"summary" => "test summary"}}
      }

      result = CopilotLv.convert_event(event)

      refute result.data["content"] == "session.task_complete"
    end

    test "external_tool.requested does not produce raw type string" do
      event = %{
        type: "external_tool.requested",
        data: %{"arguments" => %{"question" => "test?"}}
      }

      result = CopilotLv.convert_event(event)

      refute result.type == :session_info
      assert result.type == :ask_user
    end
  end
end
