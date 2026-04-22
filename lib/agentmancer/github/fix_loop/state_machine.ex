defmodule Agentmancer.GitHub.FixLoop.StateMachine do
  @type state ::
          :pending
          | :reviewing
          | :fixing
          | :pushing
          | :re_reviewing
          | :completed
          | :failed
          | :stale
          | :passed

  @type event ::
          :start_review
          | :review_has_findings
          | :review_no_findings
          | :review_failed
          | :fix_applied
          | :fix_failed
          | :fix_stale
          | :push_ok
          | :push_failed
          | :push_stale
          | :rereview_has_findings
          | :rereview_no_findings
          | :rereview_failed

  @type context :: %{cycle: non_neg_integer(), max_cycles: pos_integer()}

  @terminal_states [:completed, :failed, :stale, :passed]

  def initial_state, do: {:pending, %{cycle: 0, max_cycles: 3}}

  @spec terminal?(state()) :: boolean()
  def terminal?(state), do: state in @terminal_states

  @spec transition(state(), event(), context()) ::
          {:ok, state(), context()} | {:error, :invalid_transition}
  def transition(:pending, :start_review, ctx), do: {:ok, :reviewing, ctx}

  def transition(:reviewing, :review_has_findings, ctx), do: {:ok, :fixing, ctx}
  def transition(:reviewing, :review_no_findings, ctx), do: {:ok, :passed, ctx}
  def transition(:reviewing, :review_failed, ctx), do: {:ok, :failed, ctx}

  def transition(:fixing, :fix_applied, ctx), do: {:ok, :pushing, ctx}
  def transition(:fixing, :fix_failed, ctx), do: {:ok, :failed, ctx}
  def transition(:fixing, :fix_stale, ctx), do: {:ok, :stale, ctx}

  def transition(:pushing, :push_ok, %{cycle: cycle, max_cycles: max} = ctx)
      when cycle >= max,
      do: {:ok, :completed, ctx}

  def transition(:pushing, :push_ok, ctx),
    do: {:ok, :re_reviewing, %{ctx | cycle: ctx.cycle + 1}}

  def transition(:pushing, :push_failed, ctx), do: {:ok, :failed, ctx}
  def transition(:pushing, :push_stale, ctx), do: {:ok, :stale, ctx}

  def transition(:re_reviewing, :rereview_has_findings, %{cycle: cycle, max_cycles: max} = ctx)
      when cycle >= max,
      do: {:ok, :completed, ctx}

  def transition(:re_reviewing, :rereview_has_findings, ctx), do: {:ok, :fixing, ctx}
  def transition(:re_reviewing, :rereview_no_findings, ctx), do: {:ok, :completed, ctx}
  def transition(:re_reviewing, :rereview_failed, ctx), do: {:ok, :failed, ctx}

  def transition(_state, _event, _ctx), do: {:error, :invalid_transition}
end
