"use client";

import { useEffect, useState } from "react";
import { PanelMock } from "./PanelMock";

/**
 * Looping in-page demo of the real flow. Roughly 18 seconds:
 * select → ⇧⌘E → panel unfolds → three variants stream → pick 2 → toggle diff →
 * apply the Casual chip (variants re-stream) → Return → text replaced → toast.
 * Falls back to the static panel when the visitor prefers reduced motion.
 */

const ORIGINAL = "hey can u send me the report tomorow pls, i need it before the meeting";

const POLITE = [
  { key: "1", label: "Minimal", text: "Hey, could you send me the report tomorrow, please? I need it before the meeting." },
  { key: "2", label: "Smoother", text: "Hi, would you mind sending me the report tomorrow? I'd like to have it before the meeting." },
  { key: "3", label: "Concise", text: "Could you send me the report tomorrow, before the meeting? Thanks." },
];

const CASUAL = [
  { key: "1", label: "Minimal", text: "Hey! Can you send me the report tomorrow? I need it before the meeting." },
  { key: "2", label: "Smoother", text: "Hey, could you shoot me the report tomorrow? Want to have it before the meeting." },
  { key: "3", label: "Concise", text: "Can you send the report tomorrow, before the meeting? Thanks!" },
];

const CHIPS = ["Casual", "Shorter", "Confident", "Formal", "Friendly"];

type Phase =
  | "idle" | "select" | "shortcut" | "unfold" | "stream" | "pick" | "diff"
  | "chip" | "restream" | "enter" | "done";

const TIMELINE: [Phase, number][] = [
  ["idle", 900], ["select", 1400], ["shortcut", 1200], ["unfold", 600], ["stream", 2600],
  ["pick", 1100], ["diff", 1900], ["chip", 900], ["restream", 2600], ["enter", 700], ["done", 2600],
];

const ORDER = TIMELINE.map(([p]) => p);
const at = (p: Phase) => ORDER.indexOf(p);

export function Demo() {
  const [phase, setPhase] = useState<Phase>("idle");
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduced(mq.matches);
    const onChange = () => setReduced(mq.matches);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);

  useEffect(() => {
    if (reduced) return;
    let i = 0;
    let t: ReturnType<typeof setTimeout>;
    const step = () => {
      const [p, d] = TIMELINE[i];
      setPhase(p);
      i = (i + 1) % TIMELINE.length;
      t = setTimeout(step, d);
    };
    step();
    return () => clearTimeout(t);
  }, [reduced]);

  if (reduced) {
    return (
      <div className="rounded-[20px] bg-cream-2 p-5">
        <Composer text={ORIGINAL} selected />
        <div className="mt-3"><PanelMock /></div>
      </div>
    );
  }

  const idx = at(phase);
  const selected = idx >= at("select") && idx <= at("enter");
  const panelOpen = idx >= at("unfold") && idx <= at("enter");
  const chosen = idx >= at("pick") ? 1 : 0;
  const showDiff = idx >= at("diff") && idx < at("chip");
  const casual = idx >= at("chip");
  const streaming = phase === "stream" || phase === "restream";
  const variants = casual ? CASUAL : POLITE;
  const done = phase === "done";

  return (
    <div className="relative rounded-[20px] bg-cream-2 p-5" aria-label="Demo of Grammar Llama replacing a message">
      <Composer text={done ? CASUAL[1].text : ORIGINAL} selected={selected} selecting={phase === "select"} replaced={done} />

      {/* shortcut keycaps, pressed one after another */}
      <div className="pointer-events-none absolute top-3 right-5 flex gap-1" aria-hidden="true">
        {["⇧", "⌘", "E"].map((k, i) => (
          <span
            key={k}
            className={`flex h-8 min-w-8 items-center justify-center rounded-lg bg-panel px-2 font-mono text-sm font-semibold text-ink shadow-[0_4px_12px_-4px_rgba(43,29,22,0.4)] ring-1 ring-ink/10 transition-all duration-300 ease-out ${
              phase === "shortcut" ? "translate-y-0 opacity-100" : "-translate-y-1 opacity-0"
            }`}
            style={{ transitionDelay: phase === "shortcut" ? `${i * 180}ms` : "0ms" }}
          >
            {k}
          </span>
        ))}
      </div>

      {/* panel unfolds from zero height so the idle state is compact */}
      <div
        className={`grid transition-[grid-template-rows,opacity,transform] duration-500 ease-[cubic-bezier(.2,.8,.2,1)] ${
          panelOpen ? "mt-3 grid-rows-[1fr] translate-y-0 opacity-100" : "grid-rows-[0fr] translate-y-2 opacity-0"
        }`}
      >
        <div className="min-h-0 overflow-hidden">
          <div className="w-full rounded-panel bg-panel/90 p-3.5 shadow-[0_24px_60px_-20px_rgba(43,29,22,0.35)] ring-1 ring-ink/8 backdrop-blur-xl">
            <div className="flex items-center gap-2 text-xs">
              <span className="size-4 rounded-[4px] bg-coral" aria-hidden="true" />
              <span className="font-semibold">Grammar Llama</span>
              <span className="truncate text-ink-3">{ORIGINAL}</span>
              {streaming && <span className="ml-auto size-3 shrink-0 animate-spin rounded-full border-[1.5px] border-ink/15 border-t-ink-2" aria-hidden="true" />}
            </div>

            <ul role="list" className="mt-2.5 flex flex-col gap-1">
              {variants.map((v, i) => {
                const isSel = i === chosen;
                return (
                  <li key={v.key} className={`grid grid-cols-[18px_1fr] gap-2.5 rounded-[9px] px-2.5 py-2 transition-colors duration-300 ${isSel ? "bg-coral/10 ring-1 ring-coral/55" : ""}`}>
                    <span className={`kbd transition-transform duration-200 ${isSel ? "bg-coral! text-white!" : ""} ${phase === "pick" && i === 1 ? "scale-125" : ""}`}>{v.key}</span>
                    <div>
                      <div className={`mb-0.5 text-[0.6875rem] font-medium transition-colors duration-300 ${isSel ? "text-coral" : "text-ink-2"}`}>{v.label}</div>
                      <p className="min-h-10 text-[0.8125rem]/5 text-pretty">
                        {phase === "unfold" ? (
                          <Shimmer />
                        ) : showDiff && i === 1 ? (
                          <DiffSmoother />
                        ) : (
                          <Typewriter key={`${casual}-${i}`} text={v.text} active={streaming} delay={i * 160} />
                        )}
                      </p>
                    </div>
                  </li>
                );
              })}
            </ul>

            {/* tweak row */}
            <div className="mt-2.5 flex items-center gap-1.5">
              {casual && (
                <span className="rounded-full bg-coral/12 px-2.5 py-1 text-[0.6875rem] font-medium text-coral">Casual ×</span>
              )}
              <div className="flex-1 rounded-lg bg-ink/5 px-2.5 py-1.5 text-xs text-ink-3">Change something…</div>
            </div>
            <div className="mt-1.5 flex gap-1.5 overflow-hidden">
              {CHIPS.filter((c) => !(casual && c === "Casual")).map((c) => (
                <span
                  key={c}
                  className={`shrink-0 rounded-full px-2.5 py-1 text-[0.6875rem] font-medium transition-all duration-200 ${
                    phase === "chip" && c === "Casual" ? "scale-105 bg-coral text-white" : "bg-ink/6 text-ink-2"
                  }`}
                >
                  {c}
                </span>
              ))}
            </div>

            <div className="mt-3 flex items-center gap-3 text-[0.6875rem] text-ink-2">
              <span className="flex items-center gap-1"><span className={`kbd transition-all duration-200 ${phase === "enter" ? "scale-125 bg-coral! text-white!" : ""}`}>↩</span>Replace</span>
              <span className="flex items-center gap-1"><span className="kbd">C</span>Copy</span>
              <span className="flex items-center gap-1"><span className="kbd">E</span>Edit</span>
              <span className="flex items-center gap-1"><span className={`kbd transition-all duration-200 ${showDiff ? "bg-coral! text-white!" : ""}`}>D</span>Diff</span>
              <span className="ml-auto rounded-md px-2.5 py-1 text-xs font-medium text-ink-2">Copy</span>
              <span className={`rounded-md bg-coral px-2.5 py-1 text-xs font-medium text-white transition-transform duration-200 ${phase === "enter" ? "scale-95" : ""}`}>Replace</span>
            </div>
          </div>
        </div>
      </div>

      {/* caption line explains each beat */}
      <p className="mt-3 h-5 text-center text-xs text-ink-3 transition-opacity duration-300">
        <Caption phase={phase} />
      </p>

      {/* toast */}
      <div className={`absolute bottom-12 left-5 flex items-center gap-1.5 rounded-full bg-panel px-3 py-1.5 text-xs font-medium shadow-[0_8px_24px_-8px_rgba(43,29,22,0.4)] ring-1 ring-ink/8 transition-all duration-300 ${done ? "translate-y-0 opacity-100" : "translate-y-2 opacity-0"}`} role="status">
        <span className="size-3.5 rounded-full bg-good" aria-hidden="true" />
        Replaced
      </div>
    </div>
  );
}

function Caption({ phase }: { phase: Phase }) {
  const text: Record<Phase, string> = {
    idle: "A message that needs a little help.",
    select: "Select the text.",
    shortcut: "Press ⇧⌘E.",
    unfold: "Grammar Llama appears.",
    stream: "Three polite variants stream in.",
    pick: "Press 2 to pick one.",
    diff: "Press D to see what changed.",
    chip: "Want it more casual? One click.",
    restream: "Everything re-streams with the tweak.",
    enter: "Press Return.",
    done: "Replaced, right where it was.",
  };
  return <span key={phase} className="inline-block animate-[fadeIn_.3s_ease-out]">{text[phase]}</span>;
}

function Composer({ text, selected, selecting, replaced }: { text: string; selected?: boolean; selecting?: boolean; replaced?: boolean }) {
  return (
    <div className="rounded-lg bg-panel px-3 py-2.5 text-sm ring-1 ring-ink/8">
      <div className="mb-1.5 flex items-center gap-2 text-xs text-ink-3">
        <span className="size-4 rounded-[5px] bg-linear-to-br from-mango to-coral" aria-hidden="true" />
        Message #design-review
      </div>
      <p className="relative text-pretty">
        <span
          className={`rounded-sm bg-coral/20 box-decoration-clone transition-[background-size] ease-out ${
            selected ? "bg-[length:100%_100%] duration-[1200ms]" : "bg-[length:0%_100%] duration-300"
          }`}
          style={{ backgroundRepeat: "no-repeat" }}
        >
          <span key={text} className={`inline-block ${replaced ? "animate-[fadeIn_.5s_ease-out]" : ""}`}>{text}</span>
        </span>
        {selecting && <span className="ml-0.5 inline-block h-4 w-px translate-y-0.5 animate-pulse bg-ink" aria-hidden="true" />}
      </p>
    </div>
  );
}

function Shimmer() {
  return (
    <span className="flex flex-col gap-1.5 pt-1" aria-label="Loading">
      <span className="block h-2.5 w-full animate-pulse rounded bg-ink/8" />
      <span className="block h-2.5 w-3/5 animate-pulse rounded bg-ink/8 [animation-delay:150ms]" />
    </span>
  );
}

function DiffSmoother() {
  return (
    <>
      <span className="rounded-sm bg-bad-soft text-ink-3 line-through">hey can u</span>{" "}
      <span className="rounded-sm bg-good-soft text-good">Hi, would you mind</span>{" "}
      send<span className="rounded-sm bg-good-soft text-good">ing</span> me the report{" "}
      <span className="rounded-sm bg-bad-soft text-ink-3 line-through">tomorow pls, i need it</span>{" "}
      <span className="rounded-sm bg-good-soft text-good">tomorrow? I'd like to have it</span> before the meeting
      <span className="rounded-sm bg-good-soft text-good">.</span>
    </>
  );
}

function Typewriter({ text, active, delay }: { text: string; active: boolean; delay: number }) {
  const [n, setN] = useState(active ? 0 : text.length);
  useEffect(() => {
    if (!active) { setN(text.length); return; }
    setN(0);
    let raf = 0;
    const start = performance.now() + delay;
    const tick = (now: number) => {
      const i = now < start ? 0 : Math.min(text.length, Math.floor((now - start) / 22));
      setN(i);
      if (i < text.length) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [text, active, delay]);
  return (
    <>
      {text.slice(0, n)}
      {active && n < text.length ? <span className="ml-px inline-block h-3.5 w-1.5 translate-y-0.5 rounded-sm bg-coral/60" aria-hidden="true" /> : null}
    </>
  );
}
