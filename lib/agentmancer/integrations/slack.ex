defmodule Agentmancer.Integrations.Slack do
  def post_message(webhook_url, message) when is_binary(message) do
    post_message(webhook_url, %{text: message})
  end

  def post_message(webhook_url, payload) when is_map(payload) do
    Req.post(webhook_url, json: payload)
    |> case do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def format_digest(run_output) when is_map(run_output) do
    sections = Map.get(run_output, "sections", [])
    highlights = Map.get(run_output, "highlights", [])
    period = Map.get(run_output, "period", "Recent")

    blocks = [
      %{type: "header", text: %{type: "plain_text", text: "#{period} Digest"}},
      %{type: "divider"}
    ]

    section_blocks =
      Enum.flat_map(sections, fn section ->
        items = Enum.map_join(section["items"] || [], "\n", &"• #{&1}")

        [%{type: "section", text: %{type: "mrkdwn", text: "*#{section["title"]}*\n#{items}"}}]
      end)

    highlight_block =
      if highlights != [] do
        text = Enum.map_join(highlights, "\n", &"🔹 #{&1}")
        [%{type: "section", text: %{type: "mrkdwn", text: "*Highlights*\n#{text}"}}]
      else
        []
      end

    %{blocks: blocks ++ section_blocks ++ highlight_block}
  end
end
