defmodule Agentmancer.Workers.DeliveryWorker do
  use Oban.Worker, queue: :delivery, max_attempts: 3

  require Logger

  alias Agentmancer.Delivery

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
    delivery = Delivery.get_delivery!(delivery_id)

    case dispatch(delivery.channel, delivery.config, delivery.payload) do
      {:ok, response} ->
        Delivery.mark_delivered(delivery, response)
        :ok

      {:error, reason} ->
        Logger.warning("Delivery #{delivery_id} failed: #{inspect(reason)}")
        Delivery.mark_failed(delivery, to_string(reason))
        {:error, reason}
    end
  end

  defp dispatch(:slack, config, payload) do
    webhook_url = Map.fetch!(config, "webhook_url")

    case Req.post(webhook_url, json: payload) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, %{"status" => status}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Slack returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch(:github_pr_comment, config, payload) do
    owner = Map.fetch!(config, "owner")
    repo = Map.fetch!(config, "repo")
    pr_number = Map.fetch!(config, "pr_number")
    token = Map.fetch!(config, "token")

    url = "https://api.github.com/repos/#{owner}/#{repo}/issues/#{pr_number}/comments"

    case Req.post(url,
           json: %{body: payload["body"]},
           headers: [
             {"authorization", "Bearer #{token}"},
             {"accept", "application/vnd.github+json"}
           ]
         ) do
      {:ok, %Req.Response{status: 201, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "GitHub returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch(:github_pr_review, config, payload) do
    owner = Map.fetch!(config, "owner")
    repo = Map.fetch!(config, "repo")
    pr_number = Map.fetch!(config, "pr_number")
    token = Map.fetch!(config, "token")

    url = "https://api.github.com/repos/#{owner}/#{repo}/pulls/#{pr_number}/reviews"

    case Req.post(url,
           json: payload,
           headers: [
             {"authorization", "Bearer #{token}"},
             {"accept", "application/vnd.github+json"}
           ]
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..201 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "GitHub returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch(:webhook, config, payload) do
    url = Map.fetch!(config, "url")
    headers = Map.get(config, "headers", %{})

    header_list = Enum.map(headers, fn {k, v} -> {k, v} end)

    case Req.post(url, json: payload, headers: header_list) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, %{"status" => status}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Webhook returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch(channel, _config, _payload) do
    {:error, "unsupported delivery channel: #{channel}"}
  end
end
