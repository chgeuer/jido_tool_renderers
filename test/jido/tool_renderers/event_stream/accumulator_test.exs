defmodule Jido.ToolRenderers.EventStream.AccumulatorTest do
  use ExUnit.Case, async: true

  alias Jido.ToolRenderers.EventStream.Accumulator

  describe "new/0" do
    test "returns empty accumulator" do
      acc = Accumulator.new()
      assert acc.assistant_text == ""
      assert acc.assistant_msg_id == nil
      assert acc.pending_tools == %{}
      assert acc.tool_group_events == []
      assert acc.tool_group_id == nil
    end
  end

  describe "process_event/3 — noise filtering" do
    test "skips noise events" do
      acc = Accumulator.new()
      {acc2, actions} = Accumulator.process_event(acc, "session.start", %{})
      assert actions == :skip
      assert acc2 == acc
    end

    test "skips user.message events" do
      acc = Accumulator.new()
      {_acc, actions} = Accumulator.process_event(acc, "user.message", %{"content" => "hi"})
      assert actions == :skip
    end
  end

  describe "process_event/3 — assistant.message" do
    test "accumulates text chunks" do
      acc = Accumulator.new()

      {acc, actions1} =
        Accumulator.process_event(acc, "assistant.message", %{"content" => "Hello "})

      stream_inserts = for {:stream_insert, e} <- actions1, do: e
      msg = Enum.find(stream_inserts, &(&1.type == "assistant.message.block"))
      assert msg.data["content"] == "Hello "

      {_acc, actions2} =
        Accumulator.process_event(acc, "assistant.message", %{"content" => "world"})

      stream_inserts2 = for {:stream_insert, e} <- actions2, do: e
      msg2 = Enum.find(stream_inserts2, &(&1.type == "assistant.message.block"))
      assert msg2.data["content"] == "Hello world"
    end

    test "emits scroll-bottom push event" do
      acc = Accumulator.new()
      {_acc, actions} = Accumulator.process_event(acc, "assistant.message", %{"content" => "hi"})
      assert {:push_event, "scroll-bottom", %{}} in actions
    end
  end

  describe "process_event/3 — tool lifecycle" do
    test "creates tool group on tool start" do
      acc = Accumulator.new()

      {acc, actions} =
        Accumulator.process_event(acc, "tool.execution_start", %{
          "toolCallId" => "c1",
          "toolName" => "bash",
          "arguments" => "ls"
        })

      assert Map.has_key?(acc.pending_tools, "c1")
      assert length(acc.tool_group_events) == 1

      group = for {:stream_insert, %{type: "tool.group"} = g} <- actions, do: g
      assert length(group) == 1
    end

    test "updates tool on complete and clears pending" do
      acc = Accumulator.new()

      {acc, _} =
        Accumulator.process_event(acc, "tool.execution_start", %{
          "toolCallId" => "c1",
          "toolName" => "bash",
          "arguments" => "ls"
        })

      {acc, actions} =
        Accumulator.process_event(acc, "tool.execution_complete", %{
          "toolCallId" => "c1",
          "success" => true,
          "result" => "file.txt"
        })

      refute Map.has_key?(acc.pending_tools, "c1")

      [group] = for {:stream_insert, %{type: "tool.group"} = g} <- actions, do: g
      tool = Enum.find(group.data["events"], &(&1.type == "tool.combined"))
      assert tool.data["completed"] == true
      assert tool.data["result"] == "file.txt"
    end
  end

  describe "process_event/3 — turn boundaries" do
    test "resets all state on assistant.turn_start" do
      acc = %Accumulator{
        assistant_text: "some text",
        assistant_msg_id: "msg-1",
        tool_group_events: [%{type: "tool.combined", data: %{}}],
        tool_group_id: "group-1"
      }

      {acc, actions} = Accumulator.process_event(acc, "assistant.turn_start", %{})

      assert acc.assistant_text == ""
      assert acc.assistant_msg_id == nil
      assert acc.tool_group_events == []
      assert acc.tool_group_id == nil
      assert actions == []
    end
  end

  describe "process_event/3 — fallthrough" do
    test "adds unknown event types to tool group" do
      acc = Accumulator.new()

      {acc, actions} =
        Accumulator.process_event(acc, "assistant.usage", %{
          "inputTokens" => 100,
          "outputTokens" => 50
        })

      assert length(acc.tool_group_events) == 1
      [group] = for {:stream_insert, %{type: "tool.group"} = g} <- actions, do: g
      assert group.data["tool_count"] == 0
    end
  end
end
