defmodule Accountabot.Workflow do
  @moduledoc """
  Workflow definitions as data: ordered stages, and per-stage gates — reserved
  item kinds that must be CPA-approved before the engagement may leave the stage.
  """

  @workflows %{
    monthly_close: [
      intake: [:accept_engagement],
      gather: [],
      categorize: [],
      reconcile: [],
      adjust: [],
      review: [:sign_off],
      deliver: []
    ],
    tax_return: [
      intake: [:accept_engagement],
      organizer: [],
      gather: [],
      workpapers: [],
      draft: [],
      review: [:sign_off],
      file: [:file_return],
      deliver: []
    ],
    onboarding: [
      intake: [:accept_engagement],
      engagement_letter: [:engagement_letter],
      kyc: [],
      chart_of_accounts: [],
      document_collection: []
    ]
  }

  def types, do: Map.keys(@workflows)
  def stages(type), do: Keyword.keys(Map.fetch!(@workflows, type))
  def gates(type, stage), do: Keyword.fetch!(Map.fetch!(@workflows, type), stage)

  @doc "The stage after `stage`, or `nil` if it is the last."
  def next(type, stage) do
    type |> stages() |> Enum.drop_while(&(&1 != stage)) |> Enum.at(1)
  end
end
