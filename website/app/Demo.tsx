"use client";

import { useEffect, useState } from "react";
import { PanelMock } from "./PanelMock";

/**
 * Looping, in-page demo of the real flow: select text, press ⇧⌘E, variants stream in,
 * press 2 then Return, the text is replaced. Falls back to the static panel when the
 * visitor prefers reduced motion.
 */

const ORIGINAL = "hey can u send me the report tomorow pls, i need it before the meeting";
const VARIANTS = [
  { key: "1", label: "Minimal", text: "Hey, could you send me the report tomorrow, please? I need it before the meeting." },
  { key: "2", label: "Smoother", text: "Hi, would you mind sending me the report tomorrow? I'd like to have it before the meeting." },
  { key: "3", label: "Concise", text: "Could you send me the report tomorrow, before the meeting? Thanks." },
];

// phase: 0 idle · 1 selecting · 2 shortcut pressed · 3 panel + streaming · 4 pick variant 2 · 5 return · 6 replaced
const TIMELINE: [number, number][] = [
  [0, 600], [1, 1100], [2, 700], [3, 2300], [4, 900], [5, 500], [6, 2200],
];

export function Demo() {
  const [phase, setPhase] = useState(0);
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

  const selected = phase >= 1 && phase <= 5;
  const panelVisible = phase >= 3 && phase <= 5;
  const chosen = phase >= 4 ? 1 : 0;

  return (
    <div className="relative rounded-[20px] bg-cream-2 p-5" aria-label="Demo of Grammar Llama replacing a message">
      <Composer text={phase === 6 ? VARIANTS[1].text : ORIGINAL} selected={selected} selecting={phase === 1} replaced={phase === 6} />

      {/* shortcut keycaps */}
      <div className={`absolute top-3 right-5 flex gap-1 transition-all duration-200 ${phase === 2 ? "scale-100 opacity-100" : "scale-90 opacity-0"}`} aria-hidden="true">
        {["⇧", "⌘", "E"].map((k) => (
          <span key={k} className="flex h-8 min-w-8 items-center justify-center rounded-lg bg-panel px-2 font-mono text-sm font-semibold text-ink shadow-[0_4px_12px_-4px_rgba(43,29,22,0.4)] ring-1 ring-ink/10">{k}</span>
        ))}
      </div>

      {/* panel */}
      <div className={`mt-3 transition-all duration-200 ${panelVisible ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-1 opacity-0"}`}>
        <div className="w-full rounded-panel bg-panel/90 p-3.5 shadow-[0_24px_60px_-20px_rgba(43,29,22,0.35)] ring-1 ring-ink/8 backdrop-blur-xl">
          <div className="flex items-center gap-2 text-xs">
            <span className="size-4 rounded-[4px] bg-coral" aria-hidden="true" />
            <span className="font-semibold">Grammar Llama</span>
            <span className="truncate text-ink-3">{ORIGINAL}</span>
          </div>
          <ul role="list" className="mt-2.5 flex flex-col gap-1">
            {VARIANTS.map((v, i) => {
              const isSel = i === chosen;
              return (
                <li key={v.key} className={`grid grid-cols-[18px_1fr] gap-2.5 rounded-[9px] px-2.5 py-2 transition-colors duration-150 ${isSel ? "bg-coral/10 ring-1 ring-coral/55" : ""}`}>
                  <span className={`kbd transition-transform ${isSel ? "bg-coral! text-white!" : ""} ${phase === 4 && i === 1 ? "scale-110" : ""}`}>{v.key}</span>
                  <div>
                    <div className={`mb-0.5 text-[0.6875rem] font-medium ${isSel ? "text-coral" : "text-ink-2"}`}>{v.label}</div>
                    <p className="min-h-10 text-[0.8125rem]/5 text-pretty">
                      {panelVisible ? <Typewriter text={v.text} active={phase === 3} delay={i * 120} /> : ""}
                    </p>
                  </div>
                </li>
              );
            })}
          </ul>
          <div className="mt-3 flex items-center gap-3 text-[0.6875rem] text-ink-2">
            <span className="flex items-center gap-1"><span className={`kbd ${phase === 5 ? "bg-coral! text-white!" : ""}`}>↩</span>Replace</span>
            <span className="flex items-center gap-1"><span className="kbd">C</span>Copy</span>
            <span className="flex items-center gap-1"><span className="kbd">E</span>Edit</span>
            <span className="ml-auto rounded-md bg-coral px-2.5 py-1 text-xs font-medium text-white">Replace</span>
          </div>
        </div>
      </div>

      {/* toast */}
      <div className={`absolute bottom-5 left-5 flex items-center gap-1.5 rounded-full bg-panel px-3 py-1.5 text-xs font-medium shadow-[0_8px_24px_-8px_rgba(43,29,22,0.4)] ring-1 ring-ink/8 transition-all duration-200 ${phase === 6 ? "translate-y-0 opacity-100" : "translate-y-1 opacity-0"}`} role="status">
        <span className="size-3.5 rounded-full bg-good" aria-hidden="true" />
        Replaced
      </div>
    </div>
  );
}

function Composer({ text, selected, selecting, replaced }: { text: string; selected?: boolean; selecting?: boolean; replaced?: boolean }) {
  return (
    <div className="rounded-lg bg-panel px-3 py-2.5 text-sm ring-1 ring-ink/8">
      <div className="mb-1.5 flex items-center gap-2 text-xs text-ink-3">
        <span className="size-4 rounded-[5px] bg-linear-to-br from-mango to-coral" aria-hidden="true" />
        Message #design-review
      </div>
      <p className={`text-pretty transition-colors duration-300 ${replaced ? "text-ink" : ""}`}>
        <span
          className={`rounded-sm bg-coral/20 box-decoration-clone transition-[background-size] ease-out ${selected ? "bg-[length:100%_100%] duration-700" : "bg-[length:0%_100%] duration-100"} ${selecting ? "" : ""}`}
          style={{ backgroundRepeat: "no-repeat" }}
        >
          {text}
        </span>
      </p>
    </div>
  );
}

function Typewriter({ text, active, delay }: { text: string; active: boolean; delay: number }) {
  const [n, setN] = useState(active ? 0 : text.length);
  useEffect(() => {
    if (!active) { setN(text.length); return; }
    setN(0);
    let i = 0;
    let raf = 0;
    const start = performance.now() + delay;
    const tick = (now: number) => {
      if (now >= start) {
        i = Math.min(text.length, Math.floor((now - start) / 14));
        setN(i);
      }
      if (i < text.length) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [text, active, delay]);
  return <>{text.slice(0, n)}{n < text.length && active ? <span className="ml-px inline-block h-3.5 w-1.5 translate-y-0.5 rounded-sm bg-coral/60" aria-hidden="true" /> : null}</>;
}
