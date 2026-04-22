defmodule Agentmancer.Integrations.GitHub do
  @base_url "https://api.github.com"

  def get_pull_request(owner, repo, pr_number, token) do
    request(:get, "/repos/#{owner}/#{repo}/pulls/#{pr_number}", token)
  end

  def list_pr_files(owner, repo, pr_number, token) do
    request(:get, "/repos/#{owner}/#{repo}/pulls/#{pr_number}/files", token)
  end

  def create_review(owner, repo, pr_number, review_params, token) do
    request(:post, "/repos/#{owner}/#{repo}/pulls/#{pr_number}/reviews", token,
      json: review_params
    )
  end

  def create_comment(owner, repo, pr_number, comment_params, token) do
    request(:post, "/repos/#{owner}/#{repo}/issues/#{pr_number}/comments", token,
      json: comment_params
    )
  end

  def get_ref(owner, repo, ref, token) do
    request(:get, "/repos/#{owner}/#{repo}/git/ref/heads/#{ref}", token)
  end

  def verify_signature(payload_body, signature, secret) do
    expected =
      "sha256=" <>
        (:crypto.mac(:hmac, :sha256, secret, payload_body) |> Base.encode16(case: :lower))

    Plug.Crypto.secure_compare(expected, signature)
  end

  defp request(method, path, token, opts \\ []) do
    [
      base_url: @base_url,
      method: method,
      url: path,
      headers: [
        {"authorization", "Bearer #{token}"},
        {"accept", "application/vnd.github+json"},
        {"x-github-api-version", "2022-11-28"}
      ]
    ]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
