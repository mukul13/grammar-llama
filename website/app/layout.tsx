import type { Metadata } from "next";
import { Figtree } from "next/font/google";
import "./globals.css";

const figtree = Figtree({
  variable: "--font-figtree",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
});

export const metadata: Metadata = {
  title: "Grammar Llama",
  description:
    "Fix grammar and tone in any Mac app. Select text, press ⇧⌘E, pick a variant, replace. Polite by default.",
  openGraph: {
    title: "Grammar Llama",
    description: "Sound right in one keystroke. A menu bar rewrite tool for macOS.",
    images: ["/icon.png"],
  },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${figtree.variable} h-full antialiased`}>
      <body className="isolate min-h-full flex flex-col font-sans">{children}</body>
    </html>
  );
}
