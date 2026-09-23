defmodule AccountabotWeb.ReviewLive do
  @moduledoc """
  The CPA's review, shaped by their profile: what only they can decide, what
  waits for approval, and what the agent did alone (reversible). Cards show
  exactly the sections the CPA chose. Updates live as the agent works.
  """
  use AccountabotWeb, :live_view

  alias Accountabot.{Cpas, Engagements, Inbox, Money, Practice, Profile}

  @impl true
  def mount(%{"cpa_id" => cpa}, _session, socket) do
    case Cpas.profile(Accountabot.store(), cpa) do
      {:ok, profile} ->
        if connected?(socket),
          do: Phoenix.PubSub.subscribe(Accountabot.PubSub, Practice.topic(cpa))

        {:ok, socket |> assign(cpa: cpa, profile: profile, page_title: "Review") |> load()}

      {:error, {:incomplete, _}} ->
        {:ok, push_navigate(socket, to: ~p"/onboarding/#{cpa}")}
    end
  end

  @impl true
  def handle_event("resolve", %{"e" => eid, "i" => iid, "d" => d}, socket)
      when d in ["approve", "reject"] do
    socket =
      case Practice.resolve(
             Accountabot.store(),
             socket.assigns.cpa,
             eid,
             iid,
             String.to_existing_atom(d)
           ) do
        {:ok, _, _} -> socket
        {:error, reason} -> put_flash(socket, :error, "Couldn't do that: #{inspect(reason)}")
      end

    {:noreply, load(socket)}
  end

  @impl true
  def handle_info({:engagement, _}, socket), do: {:noreply, load(socket)}

  defp load(%{assigns: %{cpa: cpa, profile: p}} = socket) do
    engs = Engagements.for_cpa(Accountabot.store(), cpa)
    by_id = Map.new(engs, &{&1.id, &1})
    row = fn {eid, item} -> %{eng: by_id[eid], card: Inbox.card(item, p)} end
    queue = Inbox.queue(engs)

    assign(socket,
      reserved: for({_, i} = x <- queue, i.tier == :reserved, do: row.(x)),
      proposed: for({_, i} = x <- queue, i.tier == :propose, do: row.(x)),
      done_alone: for({_, i} = x <- Inbox.digest(engs, p), i.status == :applied, do: row.(x))
    )
  end

  defp heading(%Profile{cadence: :realtime}), do: "Live queue"
  defp heading(%Profile{cadence: :daily}), do: "Today's review"
  defp heading(%Profile{cadence: :weekly}), do: "This week's review"

  defp section_title(s), do: s |> Profile.humanize() |> String.capitalize()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} cpa={@cpa}>
      <h1>{heading(@profile)}</h1>
      <p class="lede">
        {length(@reserved) + length(@proposed)} waiting for you · {length(@done_alone)} done on my own
      </p>

      <div :if={@reserved == [] and @proposed == [] and @done_alone == []} class="empty">
        Nothing needs you right now.
      </div>

      <.group :if={@reserved != []} id="reserved" title="Only you can decide" rows={@reserved} urgent />
      <.group :if={@proposed != []} id="proposed" title="Waiting for your approval" rows={@proposed} />
      <.group :if={@done_alone != []} id="done" title="Done on my own — reverse anything" rows={@done_alone} />
    </Layouts.app>
    """
  end

  attr(:id, :string, required: true)
  attr(:title, :string, required: true)
  attr(:rows, :list, required: true)
  attr(:urgent, :boolean, default: false)

  defp group(assigns) do
    ~H"""
    <section id={@id}>
      <h2>{@title}</h2>
      <article :for={%{eng: e, card: c} <- @rows} id={"item-#{e.id}-#{c.id}"} class={["card", @urgent && "urgent"]}>
        <div class="meta">
          <span class={["badge", @urgent && "urgent"]}>{badge(c.tier)}</span>
          <span>{e.client} · {Profile.humanize(e.type)} · {Profile.humanize(e.stage)}</span>
          <span :if={c.amount > 0} class="amount">{Money.format(c.amount)}</span>
        </div>
        <%= for {section, value} <- c.sections do %>
          <p :if={section == :summary} class="summary">{value}</p>
          <div :if={section != :summary} class="section">
            <h3>{section_title(section)}</h3>
            <.evidence value={value} />
          </div>
        <% end %>
        <div class="actions">
          <%= if c.tier == :auto do %>
            <button phx-click="resolve" phx-value-e={e.id} phx-value-i={c.id} phx-value-d="reject">Reverse</button>
          <% else %>
            <button class="primary" phx-click="resolve" phx-value-e={e.id} phx-value-i={c.id} phx-value-d="approve">
              Approve
            </button>
            <button phx-click="resolve" phx-value-e={e.id} phx-value-i={c.id} phx-value-d="reject">Reject</button>
          <% end %>
        </div>
      </article>
    </section>
    """
  end

  defp badge(:reserved), do: "Only you"
  defp badge(:propose), do: "Needs approval"
  defp badge(:auto), do: "Done · reversible"
end
