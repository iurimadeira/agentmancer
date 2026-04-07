defmodule Agentmancer.Delivery do
  import Ecto.Query
  alias Agentmancer.Repo
  alias Agentmancer.Delivery.Delivery

  def create_delivery(attrs) do
    %Delivery{} |> Delivery.changeset(attrs) |> Repo.insert()
  end

  def list_pending_deliveries do
    Delivery
    |> where([d], d.status == :pending and d.attempts < d.max_attempts)
    |> order_by(:inserted_at)
    |> Repo.all()
  end

  def mark_delivered(%Delivery{} = delivery, response) do
    delivery
    |> Delivery.changeset(%{
      status: :delivered,
      response: response,
      delivered_at: DateTime.utc_now(),
      attempts: delivery.attempts + 1
    })
    |> Repo.update()
  end

  def mark_failed(%Delivery{} = delivery, error_message) do
    new_attempts = delivery.attempts + 1
    status = if new_attempts >= delivery.max_attempts, do: :failed, else: :pending

    delivery
    |> Delivery.changeset(%{
      status: status,
      error_message: error_message,
      attempts: new_attempts
    })
    |> Repo.update()
  end

  def get_delivery!(id), do: Repo.get!(Delivery, id)
end
