defmodule AgentmancerWeb.WebhookController do
  use AgentmancerWeb, :controller

  require Logger

  alias Agentmancer.Workflows

  def receive(conn, %{"path_token" => path_token}) do
    with {:ok, endpoint} <- fetch_endpoint(path_token),
         :ok <- validate_signature(conn, endpoint) do
      event_type = extract_event_type(conn, endpoint.source)

      {:ok, event} =
        Workflows.create_trigger_event(%{
          event_type: event_type,
          payload: conn.body_params,
          headers: sanitize_headers(conn.req_headers),
          source_ip: to_string(:inet_parse.ntoa(conn.remote_ip)),
          signature_valid: true,
          project_id: endpoint.project_id,
          webhook_endpoint_id: endpoint.id
        })

      Oban.insert(Agentmancer.Workers.WebhookProcessorWorker.new(%{trigger_event_id: event.id}))

      json(conn, %{ok: true, event_id: event.id})
    else
      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      {:error, :disabled} ->
        conn |> put_status(403) |> json(%{error: "endpoint_disabled"})

      {:error, :invalid_signature} ->
        conn |> put_status(401) |> json(%{error: "invalid_signature"})
    end
  end

  defp fetch_endpoint(path_token) do
    case Agentmancer.Repo.get_by(Workflows.WebhookEndpoint, path_token: path_token) do
      nil -> {:error, :not_found}
      %{enabled: false} -> {:error, :disabled}
      endpoint -> {:ok, endpoint}
    end
  end

  defp validate_signature(conn, %{source: :github, secret_ciphertext: secret})
       when is_binary(secret) and secret != "" do
    signature_header =
      conn
      |> get_req_header("x-hub-signature-256")
      |> List.first()

    raw_body = conn.assigns[:raw_body] || ""

    expected =
      "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, raw_body) |> Base.encode16(case: :lower))

    if Plug.Crypto.secure_compare(expected, signature_header || "") do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp validate_signature(_conn, _endpoint), do: :ok

  defp extract_event_type(conn, :github) do
    conn |> get_req_header("x-github-event") |> List.first() || "push"
  end

  defp extract_event_type(conn, _source) do
    conn |> get_req_header("x-event-type") |> List.first() || "webhook"
  end

  defp sanitize_headers(headers) do
    headers
    |> Enum.reject(fn {key, _} -> String.downcase(key) in ["authorization", "cookie"] end)
    |> Map.new()
  end
end
