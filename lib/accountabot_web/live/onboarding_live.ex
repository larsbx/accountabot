defmodule AccountabotWeb.OnboardingLive do
  @moduledoc """
  One question at a time until onboarding is complete, then a plain-language
  account of how the agent will work, with every answer editable.
  """
  use AccountabotWeb, :live_view

  alias Accountabot.{Cpas, Onboarding, Profile}
  alias AccountabotWeb.Copy

  @impl true
  def mount(%{"cpa_id" => cpa}, _session, socket) do
    {:ok,
     socket
     |> assign(cpa: cpa, editing: nil, error: nil, page_title: "How I work with you")
     |> refresh()}
  end

  @impl true
  def handle_event("answer", params, socket) do
    %{question: q, cpa: cpa} = socket.assigns

    with {:ok, value} <- Onboarding.cast(q, Map.get(params, "value", default(q))),
         {:ok, _, _} <- Cpas.answer(Accountabot.store(), cpa, q.id, value) do
      {:noreply, socket |> assign(editing: nil, error: nil) |> refresh()}
    else
      _ -> {:noreply, assign(socket, error: error_for(q))}
    end
  end

  def handle_event("edit", %{"q" => raw}, socket) do
    q = Enum.find(Onboarding.questions(), &(Atom.to_string(&1.id) == raw))
    {:noreply, socket |> assign(editing: q && q.id, error: nil) |> refresh()}
  end

  def handle_event("cancel", _, socket),
    do: {:noreply, socket |> assign(editing: nil, error: nil) |> refresh()}

  defp refresh(%{assigns: %{cpa: cpa, editing: editing}} = socket) do
    answers = Cpas.answers(Accountabot.store(), cpa)
    applicable = Enum.filter(Onboarding.questions(), &Onboarding.applicable?(&1, answers))

    assign(socket,
      answers: answers,
      question: if(editing, do: Onboarding.question(editing), else: Onboarding.next(answers)),
      profile: with({:ok, p} <- Profile.from_answers(answers), do: p, else: (_ -> nil)),
      applicable: applicable,
      answered: Enum.count(applicable, &Map.has_key?(answers, &1.id))
    )
  end

  defp default(%{type: :multi}), do: []
  defp default(_), do: ""

  defp error_for(%{type: :multi}), do: "Pick at least one."
  defp error_for(_), do: "Pick one option."

  defp step(%{applicable: a, question: q}), do: Enum.find_index(a, &(&1.id == q.id)) + 1

  @impl true
  def render(%{question: %{}} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} cpa={@cpa}>
      <div class="progress" aria-hidden="true">
        <span style={"width: #{round(@answered / max(length(@applicable), 1) * 100)}%"}></span>
      </div>
      <p class="step">
        {if @editing, do: "Change your answer", else: "Question #{step(assigns)} of #{length(@applicable)}"}
      </p>
      <h1>{@question.prompt}</h1>
      <p :if={@question.type == :multi} class="lede">Choose all that apply.</p>

      <form id="question" phx-submit="answer">
        <div class="options" role={if @question.type == :multi, do: "group", else: "radiogroup"}>
          <label :for={opt <- @question.options} class="option">
            <input
              type={if @question.type == :multi, do: "checkbox", else: "radio"}
              name={if @question.type == :multi, do: "value[]", else: "value"}
              value={opt}
              checked={opt in List.wrap(@answers[@question.id])}
            />
            <span>
              <strong>{Copy.label(@question.id, opt)}</strong>
              <small>{elem(Copy.option(@question.id, opt), 1)}</small>
            </span>
          </label>
        </div>
        <p :if={@error} class="flash" role="alert">{@error}</p>
        <div class="actions">
          <button type="submit" class="primary">{if @editing, do: "Save", else: "Continue"}</button>
          <button :if={@editing} type="button" phx-click="cancel">Cancel</button>
        </div>
      </form>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} cpa={@cpa}>
      <h1>Here's how I'll work with you</h1>
      <p class="lede">Change any answer and I'll adapt straight away.</p>

      <ul class="plan" id="plan">
        <li :for={line <- Profile.describe(@profile)}>{line}</li>
      </ul>

      <h2>Your answers</h2>
      <div class="answers">
        <div :for={q <- @applicable} class="card answer">
          <span>
            <span class="muted">{q.prompt}</span><br />
            <strong>{Copy.answer(q.id, @answers[q.id])}</strong>
          </span>
          <button phx-click="edit" phx-value-q={q.id} aria-label={"Change: #{q.prompt}"}>Change</button>
        </div>
      </div>

      <div class="actions">
        <.link navigate={~p"/review/#{@cpa}"} class="button primary">Open your review</.link>
      </div>
    </Layouts.app>
    """
  end
end
