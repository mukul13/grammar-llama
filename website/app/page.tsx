import Image from "next/image";
import Link from "next/link";
import {
  ArrowDownTrayIcon,
  CursorArrowRaysIcon,
  EyeSlashIcon,
  KeyIcon,
  PencilSquareIcon,
  SparklesIcon,
  Squares2X2Icon,
} from "@heroicons/react/16/solid";
import { Demo } from "./Demo";
import { DOWNLOAD_URL, GITHUB_URL, VERSION } from "./config";

const steps = [
  { n: 1, title: "Select any text", body: "Slack, Mail, Notion, your browser, a code review comment. Anywhere you can highlight." },
  { n: 2, title: "Press ⇧⌘E", body: "Three polished variants stream in under a second. Polite and correct by default, no menus first." },
  { n: 3, title: "Press Return", body: "The chosen variant replaces your selection right where it was. Or press C to copy it." },
];

const features = [
  { icon: SparklesIcon, title: "Results first, no tone menu", body: "You see rewrites before you decide anything. Type “more casual” afterwards only if you want to." },
  { icon: Squares2X2Icon, title: "Three variants, one key each", body: "Minimal, Smoother and Concise. Press 1, 2 or 3. Regenerate one with R." },
  { icon: PencilSquareIcon, title: "Edit before you send", body: "Press E to tweak a word or two in place. A live diff shows exactly what changed." },
  { icon: CursorArrowRaysIcon, title: "Works where you type", body: "Reads your selection through Accessibility and falls back to the clipboard for apps that hide it." },
  { icon: KeyIcon, title: "Your key, your Mac", body: "Bring your own Anthropic API key. It lives in your Keychain. There is no account and no server in between." },
  { icon: EyeSlashIcon, title: "Menu bar only", body: "No Dock icon, no window to manage. Just a small llama waiting for a shortcut." },
];

const tweaks = ["Casual", "Shorter", "Confident", "Formal", "Friendly", "Warmer", "Less apologetic", "Add a thank you", "Drop the last line"];

export default function Home() {
  return (
    <>
      <header className="py-5">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6">
          <a href="/" aria-label="Homepage" className="flex items-center gap-2.5">
            <Image src="/icon.png" alt="" width={28} height={28} className="size-7 rounded-[7px]" priority />
            <span className="text-sm font-semibold">Grammar Llama</span>
          </a>
          <nav className="flex items-center gap-6 text-sm text-ink-2">
            <a href="#how" className="hover:text-ink">How it works</a>
            <a href={GITHUB_URL} className="hover:text-ink">GitHub</a>
            <a href={DOWNLOAD_URL} className="rounded-lg px-3 py-1.5 font-medium text-coral ring-1 ring-coral/30 hover:bg-coral/8">Download</a>
          </nav>
        </div>
      </header>

      <main className="flex-1">
        {/* Hero */}
        <section className="pt-10 pb-24 sm:pt-16">
          <div className="mx-auto grid max-w-6xl items-center gap-12 px-6 lg:grid-cols-[21fr_19fr]">
            <div className="flex flex-col gap-6">
              <p className="text-sm font-medium text-coral">For Mac. Free while in beta.</p>
              <h1 className="max-w-[20ch] text-5xl font-bold tracking-tight text-balance sm:text-6xl">Sound right in one keystroke.</h1>
              <p className="max-w-[48ch] text-lg text-pretty text-ink-2">
                Grammar Llama fixes grammar and tone in any Mac app. Select text, press ⇧⌘E, pick a variant, and it replaces what you wrote. Polite by default, adjustable after.
              </p>
              <div className="flex flex-wrap items-center gap-4">
                <a href={DOWNLOAD_URL} className="inline-flex items-center gap-2 rounded-xl bg-coral py-3 pr-4 pl-3 text-sm font-semibold text-white shadow-[0_8px_24px_-8px_var(--coral)] hover:bg-coral-deep focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-coral">
                  <ArrowDownTrayIcon className="size-4 shrink-0 fill-white" />
                  Download for Mac
                </a>
                <a href="#how" className="text-sm font-medium text-ink-2 hover:text-ink">See how it works →</a>
              </div>
              <p className="text-sm text-ink-3">macOS 14 or later · Apple silicon · Bring your own Anthropic API key</p>
            </div>

            <div className="relative mx-auto w-full max-w-[520px] lg:mx-0">
              <Image src="/llama.png" alt="" width={300} height={300} className="float absolute top-4 -right-2 z-10 w-36 -rotate-6 drop-shadow-[0_12px_24px_rgba(43,29,22,0.18)] sm:w-44 lg:-right-8" priority />
              <div className="mt-28 sm:mt-32">
                <Demo />
              </div>
              
            </div>
          </div>
        </section>

        {/* How it works */}
        <section id="how" className="py-20">
          <div className="mx-auto max-w-6xl px-6">
            <h2 className="max-w-[35ch] text-3xl font-bold tracking-tight text-balance sm:text-4xl">Three steps, and the third one is Return.</h2>
            <ol role="list" className="mt-12 grid gap-8 sm:grid-cols-3">
              {steps.map((s) => (
                <li key={s.n} className="flex flex-col gap-3 border-t border-line pt-6">
                  <span className="text-sm font-semibold text-coral tabular-nums">Step {s.n}</span>
                  <h3 className="text-lg font-semibold">{s.title}</h3>
                  <p className="text-sm/6 text-pretty text-ink-2">{s.body}</p>
                </li>
              ))}
            </ol>
          </div>
        </section>

        {/* Tweaks */}
        <section className="py-20">
          <div className="mx-auto grid max-w-6xl gap-8 px-6 lg:grid-cols-[21fr_19fr] lg:items-center">
            <div className="flex flex-col gap-4">
              <h2 className="max-w-[35ch] text-3xl font-bold tracking-tight text-balance sm:text-4xl">Change it after, not before.</h2>
              <p className="max-w-[56ch] text-base/7 text-pretty text-ink-2">
                Tone pickers make you decide before you have seen anything. Grammar Llama shows the polite version first and lets you react to it: click a chip or type a plain sentence. Tweaks stack and each one can be removed.
              </p>
            </div>
            <div className="flex flex-wrap gap-2 rounded-[20px] bg-cream-2 p-6">
              {tweaks.map((t, i) => (
                <span key={t} className={`rounded-full px-3.5 py-1.5 text-sm font-medium ${i < 2 ? "bg-coral text-white" : "bg-panel text-ink-2 ring-1 ring-ink/8"}`}>
                  {t}
                </span>
              ))}
              <span className="mt-2 w-full text-sm text-ink-3">Casual and Shorter applied. Everything else is one click away.</span>
            </div>
          </div>
        </section>

        {/* Features */}
        <section className="py-20">
          <div className="mx-auto max-w-6xl px-6">
            <h2 className="max-w-[35ch] text-3xl font-bold tracking-tight text-balance sm:text-4xl">Small app. Considered details.</h2>
            <dl className="mt-12 grid gap-8 sm:grid-cols-2 lg:grid-cols-3">
              {features.map((f) => (
                <div key={f.title} className="flex flex-col gap-2 border-t border-line pt-6">
                  <dt className="flex items-start gap-2 text-base font-semibold">
                    <f.icon className="size-4 h-lh shrink-0 fill-coral" />
                    {f.title}
                  </dt>
                  <dd className="text-sm/6 text-pretty text-ink-2">{f.body}</dd>
                </div>
              ))}
            </dl>
          </div>
        </section>

        {/* CTA */}
        <section className="py-24">
          <div className="mx-auto max-w-6xl px-6">
            <div className="flex flex-col items-center gap-6 rounded-[28px] bg-linear-to-br from-mango to-coral px-6 py-16 text-center text-white">
              <Image src="/mark.png" alt="" width={96} height={96} className="size-24 rounded-[22px] ring-1 ring-white/25" />
              <h2 className="max-w-[24ch] text-4xl font-bold tracking-tight text-balance sm:text-5xl">Get the llama.</h2>
              <p className="max-w-[48ch] text-lg text-pretty text-white/85">Version {VERSION}. Download, drag to Applications, allow Accessibility, paste your API key. Two minutes.</p>
              <a href={DOWNLOAD_URL} className="inline-flex items-center gap-2 rounded-xl bg-white py-3 pr-4 pl-3 text-sm font-semibold text-coral-deep shadow-[0_8px_24px_-8px_rgba(0,0,0,0.35)] hover:bg-cream focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white">
                <ArrowDownTrayIcon className="size-4 shrink-0 fill-coral-deep" />
                Download for Mac
              </a>
              <a href={GITHUB_URL} className="text-sm font-medium text-white/85 hover:text-white">Source on GitHub →</a>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-line py-10">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-6 text-sm text-ink-2">
          <div className="flex items-center gap-2.5">
            <Image src="/icon.png" alt="" width={20} height={20} className="size-5 rounded-[5px]" />
            <span>© 2026 Sidepanda</span>
          </div>
          <div className="flex gap-6">
            <a href={GITHUB_URL} className="hover:text-ink">GitHub</a>
            <Link href="#how" className="hover:text-ink">How it works</Link>
            <span>Text leaves your Mac only when you press the shortcut, and only to Anthropic.</span>
          </div>
        </div>
      </footer>
    </>
  );
}
