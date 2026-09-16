/** A static, CSS-built replica of the Grammar Llama panel. Kept in sync with the SwiftUI layout. */

const variants = [
  {
    key: "1",
    label: "Minimal",
    text: "Hey, could you send me the report tomorrow, please? I need it before the meeting, along with the numbers from last week.",
  },
  {
    key: "2",
    label: "Smoother",
    text: "Hi, would you mind sending me the report tomorrow? I'd like to have it before the meeting, together with last week's numbers.",
    selected: true,
  },
  {
    key: "3",
    label: "Concise",
    text: "Could you send me the report and last week's numbers tomorrow, before the meeting? Thanks.",
  },
];

const chips = ["Casual", "Shorter", "Confident", "Formal", "Friendly", "Warmer"];

export function PanelMock({ className = "" }: { className?: string }) {
  return (
    <div
      className={`w-[480px] max-w-full rounded-panel bg-panel/90 p-3.5 shadow-[0_24px_60px_-20px_rgba(43,29,22,0.35)] ring-1 ring-ink/8 backdrop-blur-xl ${className}`}
      aria-label="Grammar Llama panel"
    >
      <div className="flex items-center gap-2 text-xs">
        <span className="font-semibold">Slack</span>
        <span className="truncate text-ink-3">hey can u send me the report tomorow pls, i need it before the meeting…</span>
      </div>

      <ul role="list" className="mt-2.5 flex flex-col gap-1">
        {variants.map((v, i) => (
          <li
            key={v.key}
            className={`grid grid-cols-[18px_1fr] gap-2.5 rounded-[9px] px-2.5 py-2 ${
              v.selected ? "bg-coral/10 ring-1 ring-coral/55" : i > 0 && !variants[i - 1].selected ? "border-t border-line rounded-t-none" : ""
            }`}
          >
            <span className={`kbd ${v.selected ? "bg-coral! text-white!" : ""}`}>{v.key}</span>
            <div>
              <div className={`mb-0.5 text-[0.6875rem] font-medium ${v.selected ? "text-coral" : "text-ink-2"}`}>{v.label}</div>
              <p className="text-[0.8125rem]/5 text-pretty">{v.text}</p>
            </div>
          </li>
        ))}
      </ul>

      <div className="mt-2.5 rounded-lg bg-ink/5 px-2.5 py-1.5 text-xs text-ink-3">Change something… e.g. more casual, drop the last line</div>
      <div className="mt-1.5 flex gap-1.5 overflow-hidden">
        {chips.map((c) => (
          <span key={c} className="shrink-0 rounded-full bg-ink/6 px-2.5 py-1 text-[0.6875rem] font-medium text-ink-2">
            {c}
          </span>
        ))}
      </div>

      <div className="mt-3 flex items-center gap-3 text-[0.6875rem] text-ink-2">
        <span className="flex items-center gap-1"><span className="kbd">↩</span>Replace</span>
        <span className="flex items-center gap-1"><span className="kbd">C</span>Copy</span>
        <span className="flex items-center gap-1"><span className="kbd">E</span>Edit</span>
        <span className="flex items-center gap-1"><span className="kbd">D</span>Diff</span>
        <span className="ml-auto rounded-md px-2.5 py-1 text-xs font-medium text-ink-2">Copy</span>
        <span className="rounded-md bg-coral px-2.5 py-1 text-xs font-medium text-white">Replace</span>
      </div>
    </div>
  );
}
