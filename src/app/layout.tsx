import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "OWL-ORCA — AI Gateway with Stream Racing, Protocol Translation & Circuit Breakers",
  description:
    "Self-hosted AI gateway that aggregates free-tier providers into a single OpenAI-compatible endpoint. Race multiple providers, first byte wins.",
  keywords: [
    "OWL-ORCA",
    "AI gateway",
    "stream racing",
    "circuit breakers",
    "protocol translation",
    "free AI",
    "OpenAI compatible",
  ],
  icons: {
    icon: "/favicon.ico",
  },
  openGraph: {
    title: "OWL-ORCA — AI Gateway",
    description: "Free AI for everyone. Race multiple providers. First byte wins.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} dark antialiased`}
      suppressHydrationWarning
    >
      <body className="min-h-screen flex flex-col bg-background text-foreground">
        {children}
      </body>
    </html>
  );
}
