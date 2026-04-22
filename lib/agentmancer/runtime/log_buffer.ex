defmodule Agentmancer.Runtime.LogBuffer do
  alias Agentmancer.Execution

  @flush_threshold 50
  @flush_interval_ms 5_000

  defstruct [:run_attempt_id, :project_id, :timer_ref, entries: []]

  @spec new(String.t(), String.t() | nil) :: %__MODULE__{}
  def new(run_attempt_id, project_id \\ nil) do
    timer_ref = Process.send_after(self(), :flush_log_buffer, @flush_interval_ms)

    %__MODULE__{
      run_attempt_id: run_attempt_id,
      project_id: project_id,
      timer_ref: timer_ref,
      entries: []
    }
  end

  @spec append(%__MODULE__{}, String.t(), String.t()) ::
          {%__MODULE__{}, :flushed | :buffered}
  def append(buffer, level, text) do
    entry = %{
      run_attempt_id: buffer.run_attempt_id,
      project_id: buffer.project_id,
      timestamp: DateTime.utc_now(),
      level: level,
      source: "agent",
      message: text
    }

    buffer = %{buffer | entries: [entry | buffer.entries]}

    if length(buffer.entries) >= @flush_threshold do
      {flush(buffer), :flushed}
    else
      {buffer, :buffered}
    end
  end

  @spec flush(%__MODULE__{}) :: %__MODULE__{}
  def flush(%{entries: []} = buffer), do: reset_timer(buffer)

  def flush(buffer) do
    entries = Enum.reverse(buffer.entries)
    Execution.insert_log_batch(entries)
    reset_timer(%{buffer | entries: []})
  end

  defp reset_timer(buffer) do
    if buffer.timer_ref, do: Process.cancel_timer(buffer.timer_ref)
    timer_ref = Process.send_after(self(), :flush_log_buffer, @flush_interval_ms)
    %{buffer | timer_ref: timer_ref}
  end
end
