defmodule AccountabotWeb.Layouts do
  use AccountabotWeb, :html

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <link rel="icon" href="data:," />
        <title>{assigns[:page_title] || "Accountabot"}</title>
        <style>
          <%= Phoenix.HTML.raw(css()) %>
        </style>
        <script defer src="/assets/phoenix/phoenix.min.js">
        </script>
        <script defer src="/assets/live_view/phoenix_live_view.min.js">
        </script>
        <script>
          window.addEventListener("DOMContentLoaded", () => {
            const csrf = document.querySelector("meta[name='csrf-token']").content
            new LiveView.LiveSocket("/live", Phoenix.Socket, {params: {_csrf_token: csrf}}).connect()
          })
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end

  attr(:flash, :map, required: true)
  attr(:cpa, :string, required: true)
  slot(:inner_block, required: true)

  def app(assigns) do
    ~H"""
    <header class="topbar">
      <span class="brand">accountabot</span>
      <nav>
        <.link navigate={~p"/review/#{@cpa}"}>Review</.link>
        <.link navigate={~p"/onboarding/#{@cpa}"}>How I work</.link>
      </nav>
    </header>
    <main class="page">
      <p :if={msg = Phoenix.Flash.get(@flash, :error)} class="flash" role="alert">{msg}</p>
      {render_slot(@inner_block)}
    </main>
    """
  end

  defp css do
    """
    :root {
      --bg: #f7f6f3; --surface: #ffffff; --ink: #1c1b19; --muted: #6b6860; --line: #e4e1da;
      --accent: #2f5d50; --accent-ink: #ffffff; --accent-soft: #e3eeea;
      --urgent: #9a3b1f; --urgent-soft: #f8e7e0; --ok: #2f5d50; --radius: 14px;
      --font: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      --mono: ui-monospace, "SF Mono", Menlo, monospace;
      color-scheme: light;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #141413; --surface: #1d1d1b; --ink: #ecebe6; --muted: #9c998f; --line: #2e2d2a;
        --accent: #7fb8a4; --accent-ink: #10201b; --accent-soft: #1f2e29;
        --urgent: #f0a585; --urgent-soft: #3a2219; --ok: #7fb8a4;
        color-scheme: dark;
      }
    }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--bg); color: var(--ink); font: 16px/1.5 var(--font); }
    a { color: var(--accent); }
    .topbar { display: flex; justify-content: space-between; align-items: center; padding: 14px 20px;
      border-bottom: 1px solid var(--line); background: var(--surface); }
    .brand { font-weight: 650; letter-spacing: -0.01em; }
    .topbar nav { display: flex; gap: 18px; font-size: 15px; }
    .topbar nav a { text-decoration: none; color: var(--muted); }
    .topbar nav a:hover { color: var(--ink); }
    .page { max-width: 720px; margin: 0 auto; padding: 28px 16px 64px; }
    h1 { font-size: 26px; line-height: 1.2; letter-spacing: -0.02em; margin: 0 0 6px; }
    h2 { font-size: 15px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); margin: 32px 0 12px; }
    .lede { color: var(--muted); margin: 0 0 24px; }
    .flash { background: var(--urgent-soft); color: var(--urgent); padding: 10px 14px; border-radius: 10px; }
    .card { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 18px; margin: 0 0 12px; }
    .card.urgent { border-color: color-mix(in srgb, var(--urgent) 45%, var(--line)); }
    .meta { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; color: var(--muted); font-size: 14px; }
    .badge { font-size: 12px; font-weight: 600; padding: 2px 8px; border-radius: 999px; background: var(--accent-soft); color: var(--accent); }
    .badge.urgent { background: var(--urgent-soft); color: var(--urgent); }
    .amount { margin-left: auto; font-family: var(--mono); color: var(--ink); }
    .summary { font-size: 18px; font-weight: 550; margin: 10px 0 4px; }
    .section { margin-top: 14px; }
    .section h3 { font-size: 13px; color: var(--muted); font-weight: 600; margin: 0 0 4px; }
    .section p, .section ul { margin: 0; }
    .section ul { padding-left: 18px; }
    .section table { border-collapse: collapse; width: 100%; font-size: 14px; }
    .section td, .section th { text-align: left; padding: 4px 8px 4px 0; border-bottom: 1px solid var(--line); }
    .section th { color: var(--muted); font-weight: 500; }
    .muted { color: var(--muted); }
    .actions { display: flex; gap: 10px; margin-top: 16px; }
    button, .button { font: inherit; font-weight: 600; border-radius: 10px; padding: 10px 18px; cursor: pointer;
      border: 1px solid var(--line); background: var(--surface); color: var(--ink); text-decoration: none;
      transition: transform .08s ease, background .15s ease; }
    button:hover { background: var(--bg); }
    button:active { transform: scale(0.98); }
    button.primary, .button.primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
    button.primary:hover { filter: brightness(1.05); }
    button:focus-visible, .option:focus-within { outline: 2px solid var(--accent); outline-offset: 2px; }
    .progress { height: 4px; background: var(--line); border-radius: 4px; margin: 0 0 24px; overflow: hidden; }
    .progress > span { display: block; height: 100%; background: var(--accent); transition: width .3s ease; }
    .step { color: var(--muted); font-size: 14px; margin: 0 0 8px; }
    .options { display: grid; gap: 10px; margin: 20px 0; }
    .option { display: flex; gap: 12px; align-items: flex-start; padding: 14px 16px; border: 1px solid var(--line);
      border-radius: 12px; background: var(--surface); cursor: pointer; transition: border-color .15s ease; }
    .option:hover { border-color: var(--accent); }
    .option:has(input:checked) { border-color: var(--accent); background: var(--accent-soft); }
    .option input { margin-top: 4px; accent-color: var(--accent); }
    .option strong { display: block; font-weight: 600; }
    .option small { color: var(--muted); font-size: 14px; }
    .plan { list-style: none; padding: 0; margin: 0; }
    .plan li { padding: 12px 0; border-bottom: 1px solid var(--line); }
    .answers { display: grid; gap: 8px; }
    .answer { display: flex; justify-content: space-between; align-items: center; gap: 12px; }
    .answer button { padding: 6px 12px; font-size: 14px; }
    .empty { text-align: center; padding: 40px 16px; color: var(--muted); }
    """
  end
end
