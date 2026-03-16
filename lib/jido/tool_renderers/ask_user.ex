defmodule Jido.ToolRenderers.AskUser do
  use Phoenix.Component
  alias Jido.ToolRenderers.Generic

  def render(assigns) do
    args = assigns.args || %{}
    question = args["question"] || ""
    choices = args["choices"] || []
    response = assigns.content

    selected =
      cond do
        String.starts_with?(response, "User selected: ") ->
          String.trim_leading(response, "User selected: ")

        String.starts_with?(response, "User responded: ") ->
          String.trim_leading(response, "User responded: ")

        true ->
          response
      end

    assigns =
      assign(assigns,
        question: question,
        choices: choices,
        response: selected,
        has_response: response != ""
      )

    ~H"""
    <div class="flex items-center gap-2">
      <span class="badge badge-warning badge-sm">❓ ask_user</span>
      <Generic.status_indicator completed={@completed} error_msg={@error_msg} />
    </div>
    <div class="mt-1 p-3 bg-base-100 border border-base-300 rounded">
      <div class="border-l-4 border-warning/50 pl-3">
        <div
          class="markdown-body text-sm"
          id={"ask-q-#{@tool_call_id}"}
          phx-hook="MarkdownContent"
          data-markdown={@question}
        >
        </div>
      </div>
      <%= if @choices != [] do %>
        <div class="mt-2 space-y-1">
          <%= for choice <- @choices do %>
            <div class="flex items-start gap-2 text-sm">
              <%= if @has_response && choice == @response do %>
                <span class="text-success mt-0.5">☑</span>
                <span class="font-medium">{choice}</span>
              <% else %>
                <span class="text-base-content/30 mt-0.5">☐</span>
                <span class="text-base-content/60">{choice}</span>
              <% end %>
            </div>
          <% end %>
          <%= if @has_response && @response not in @choices do %>
            <div class="flex items-start gap-2 text-sm">
              <span class="text-success mt-0.5">✎</span>
              <span class="font-medium italic">{@response}</span>
            </div>
          <% end %>
        </div>
      <% else %>
        <%= if @has_response do %>
          <div class="mt-2 text-sm font-medium border-l-2 border-success pl-3">{@response}</div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
