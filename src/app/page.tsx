"use client";

import { useEffect, useRef, useState, useCallback, useMemo } from "react";
import Image from "next/image";
import {
  Zap,
  ArrowRightLeft,
  Shield,
  GitBranch,
  HardHat,
  RefreshCw,
  Lock,
  Download,
  ChevronRight,
  Copy,
  Check,
  ExternalLink,
  Menu,
  X,
  Trophy,
  Bug,
  Wrench,
  AlertTriangle,
  Clock,
  ArrowRight,
  Terminal,
} from "lucide-react";

/* Simple GitHub SVG icon since lucide-react doesn't export one */
function GithubIcon({ className }: { className?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65S8.93 17.38 9 18v4" />
      <path d="M9 18c-4.51 2-5-2-7-2" />
    </svg>
  );
}
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";

/* ────────────────────────────────────────────
   SECTION REVEAL HOOK
   ──────────────────────────────────────────── */
function useSectionReveal() {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.unobserve(el);
        }
      },
      { threshold: 0.12 }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return { ref, visible };
}

/* ────────────────────────────────────────────
   FLOATING PARTICLES BACKGROUND
   ──────────────────────────────────────────── */
function FloatingParticles() {
  // Pre-computed particle data to avoid Math.random() during render
  const particles = useMemo(() => {
    const seededRandom = (seed: number) => {
      const x = Math.sin(seed * 9301 + 49297) * 49297;
      return x - Math.floor(x);
    };
    return Array.from({ length: 20 }, (_, i) => ({
      width: 2 + seededRandom(i * 3 + 1) * 4,
      height: 2 + seededRandom(i * 3 + 2) * 4,
      left: seededRandom(i * 3 + 3) * 100,
      top: seededRandom(i * 3 + 4) * 100,
      duration: 12 + seededRandom(i * 3 + 5) * 18,
      delay: seededRandom(i * 3 + 6) * -20,
      colorIndex: i % 3,
    }));
  }, []);

  const orbs = useMemo(() => {
    const seededRandom = (seed: number) => {
      const x = Math.sin(seed * 9301 + 49297) * 49297;
      return x - Math.floor(x);
    };
    return Array.from({ length: 6 }, (_, i) => ({
      width: 40 + seededRandom(i * 5 + 10) * 60,
      height: 40 + seededRandom(i * 5 + 11) * 60,
      left: 10 + seededRandom(i * 5 + 12) * 80,
      top: 10 + seededRandom(i * 5 + 13) * 80,
      duration: 6 + seededRandom(i * 5 + 14) * 6,
      delay: seededRandom(i * 5 + 15) * -10,
      colorIndex: i % 3,
    }));
  }, []);

  const particleColors = [
    { bg: "rgba(0,212,255,0.4)", shadow: "0 0 6px rgba(0,212,255,0.3)" },
    { bg: "rgba(16,185,129,0.4)", shadow: "0 0 6px rgba(16,185,129,0.3)" },
    { bg: "rgba(224,64,251,0.4)", shadow: "0 0 6px rgba(224,64,251,0.3)" },
  ];

  const orbGradients = [
    "radial-gradient(circle, rgba(0,212,255,0.08) 0%, transparent 70%)",
    "radial-gradient(circle, rgba(16,185,129,0.06) 0%, transparent 70%)",
    "radial-gradient(circle, rgba(224,64,251,0.06) 0%, transparent 70%)",
  ];

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
      {/* Radial gradient overlays */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_20%_50%,rgba(0,212,255,0.06)_0%,transparent_50%)]" />
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_80%_20%,rgba(224,64,251,0.05)_0%,transparent_50%)]" />
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_80%,rgba(16,185,129,0.04)_0%,transparent_50%)]" />

      {/* Floating orbs */}
      {particles.map((p, i) => (
        <div
          key={i}
          className="absolute rounded-full"
          style={{
            width: `${p.width}px`,
            height: `${p.height}px`,
            left: `${p.left}%`,
            top: `${p.top}%`,
            background: particleColors[p.colorIndex].bg,
            animation: `particle-drift ${p.duration}s linear infinite`,
            animationDelay: `${p.delay}s`,
            boxShadow: particleColors[p.colorIndex].shadow,
          }}
        />
      ))}

      {/* Larger slow-moving orbs - autopoietic breathing */}
      {orbs.map((orb, i) => (
        <div
          key={`orb-${i}`}
          className="absolute rounded-full"
          style={{
            width: `${orb.width}px`,
            height: `${orb.height}px`,
            left: `${orb.left}%`,
            top: `${orb.top}%`,
            background: orbGradients[orb.colorIndex],
            animation: `breathe ${orb.duration}s ease-in-out infinite`,
            animationDelay: `${orb.delay}s`,
            filter: "blur(20px)",
          }}
        />
      ))}

      {/* Morphing blob */}
      <div
        className="absolute"
        style={{
          width: "300px",
          height: "300px",
          left: "60%",
          top: "20%",
          background: "radial-gradient(circle, rgba(0,212,255,0.04) 0%, transparent 60%)",
          animation: "morph 12s ease-in-out infinite, breathe 8s ease-in-out infinite",
          filter: "blur(40px)",
        }}
      />
      <div
        className="absolute"
        style={{
          width: "200px",
          height: "200px",
          left: "15%",
          top: "60%",
          background: "radial-gradient(circle, rgba(224,64,251,0.04) 0%, transparent 60%)",
          animation: "morph 15s ease-in-out infinite reverse, breathe 10s ease-in-out infinite",
          animationDelay: "-5s",
          filter: "blur(30px)",
        }}
      />
    </div>
  );
}

/* ────────────────────────────────────────────
   OWL EYES ANIMATION
   ──────────────────────────────────────────── */
function OwlEyes() {
  return (
    <div className="flex items-center justify-center gap-4 mb-6" aria-hidden="true">
      {/* Left eye */}
      <div className="relative w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-gradient-to-br from-[#0a0a1a] to-[#1a1a3e] border-2 border-owl-cyan/30 shadow-[0_0_20px_rgba(0,212,255,0.2)]">
        <div
          className="absolute inset-0 flex items-center justify-center"
          style={{ animation: "owl-blink 4s ease-in-out infinite" }}
        >
          <div
            className="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-owl-cyan/80 shadow-[0_0_15px_rgba(0,212,255,0.6)]"
            style={{ animation: "owl-look 6s ease-in-out infinite" }}
          >
            <div
              className="w-4 h-4 sm:w-5 sm:h-5 rounded-full bg-[#0a0a1a] absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
              style={{ animation: "owl-dilate 5s ease-in-out infinite" }}
            />
            <div className="w-1.5 h-1.5 rounded-full bg-white absolute top-2 left-2 opacity-80" />
          </div>
        </div>
      </div>

      {/* Right eye */}
      <div className="relative w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-gradient-to-br from-[#0a0a1a] to-[#1a1a3e] border-2 border-owl-green/30 shadow-[0_0_20px_rgba(16,185,129,0.2)]">
        <div
          className="absolute inset-0 flex items-center justify-center"
          style={{ animation: "owl-blink 4s ease-in-out infinite", animationDelay: "0.2s" }}
        >
          <div
            className="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-owl-green/80 shadow-[0_0_15px_rgba(16,185,129,0.6)]"
            style={{ animation: "owl-look 6s ease-in-out infinite", animationDelay: "0.3s" }}
          >
            <div
              className="w-4 h-4 sm:w-5 sm:h-5 rounded-full bg-[#0a0a1a] absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
              style={{ animation: "owl-dilate 5s ease-in-out infinite", animationDelay: "0.5s" }}
            />
            <div className="w-1.5 h-1.5 rounded-full bg-white absolute top-2 left-2 opacity-80" />
          </div>
        </div>
      </div>
    </div>
  );
}

/* ────────────────────────────────────────────
   NAV BAR
   ──────────────────────────────────────────── */
const NAV_ITEMS = [
  { label: "Architecture", href: "#architecture" },
  { label: "StreamRacer", href: "#streamracer" },
  { label: "Features", href: "#features" },
  { label: "Timeline", href: "#timeline" },
  { label: "Install", href: "#install" },
  { label: "Matrix", href: "#matrix" },
];

function NavBar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <nav
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? "glass-strong shadow-lg shadow-black/20"
          : "bg-transparent"
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-14 sm:h-16">
          {/* Logo */}
          <a href="#" className="flex items-center gap-2 group">
            <span className="text-owl-cyan font-bold text-lg sm:text-xl tracking-tight group-hover:text-glow-cyan transition-all">
              🦉 OWL-ORCA
            </span>
            <Badge
              variant="outline"
              className="text-[10px] sm:text-xs border-owl-cyan/40 text-owl-cyan bg-owl-cyan/10"
            >
              v8.0
            </Badge>
          </a>

          {/* Desktop nav */}
          <div className="hidden md:flex items-center gap-1">
            {NAV_ITEMS.map((item) => (
              <a
                key={item.href}
                href={item.href}
                className="px-3 py-1.5 text-sm text-muted-foreground hover:text-owl-cyan transition-colors rounded-lg hover:bg-white/5"
              >
                {item.label}
              </a>
            ))}
            <Separator orientation="vertical" className="mx-2 h-5 bg-white/10" />
            <a
              href="https://github.com/marktantongco/owl-orca"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-muted-foreground hover:text-white transition-colors"
            >
              <GithubIcon className="w-4 h-4" />
              GitHub
            </a>
          </div>

          {/* Mobile hamburger */}
          <button
            className="md:hidden p-2 text-muted-foreground hover:text-white"
            onClick={() => setMobileOpen(!mobileOpen)}
            aria-label={mobileOpen ? "Close menu" : "Open menu"}
          >
            {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      {mobileOpen && (
        <div className="md:hidden glass-strong border-t border-white/5">
          <div className="px-4 py-3 space-y-1">
            {NAV_ITEMS.map((item) => (
              <a
                key={item.href}
                href={item.href}
                onClick={() => setMobileOpen(false)}
                className="block px-3 py-2 text-sm text-muted-foreground hover:text-owl-cyan transition-colors rounded-lg hover:bg-white/5"
              >
                {item.label}
              </a>
            ))}
            <a
              href="https://github.com/marktantongco/owl-orca"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 px-3 py-2 text-sm text-muted-foreground hover:text-white transition-colors"
            >
              <GithubIcon className="w-4 h-4" />
              GitHub
            </a>
          </div>
        </div>
      )}
    </nav>
  );
}

/* ────────────────────────────────────────────
   HERO SECTION
   ──────────────────────────────────────────── */
function HeroSection() {
  const { ref, visible } = useSectionReveal();

  return (
    <section
      ref={ref}
      className="relative min-h-screen flex flex-col items-center justify-center px-4 pt-20 pb-16 overflow-hidden"
    >
      <FloatingParticles />

      <div
        className={`relative z-10 text-center max-w-4xl mx-auto transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        {/* Owl Eyes */}
        <OwlEyes />

        {/* Title */}
        <h1 className="text-5xl sm:text-7xl md:text-8xl lg:text-9xl font-black tracking-tighter mb-4">
          <span className="bg-gradient-to-r from-owl-cyan via-owl-green to-owl-magenta bg-clip-text text-transparent">
            OWL-ORCA
          </span>
        </h1>

        {/* Subtitle */}
        <p className="text-lg sm:text-xl md:text-2xl text-muted-foreground max-w-2xl mx-auto mb-6 leading-relaxed">
          AI Gateway with{" "}
          <span className="text-owl-cyan font-semibold">Stream Racing</span>,{" "}
          <span className="text-owl-green font-semibold">Protocol Translation</span> &{" "}
          <span className="text-owl-magenta font-semibold">Circuit Breakers</span>
        </p>

        {/* Tagline */}
        <p className="text-sm sm:text-base text-muted-foreground/70 mb-8">
          Free AI for everyone. Race multiple providers. First byte wins.
        </p>

        {/* CTA Buttons */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-3 sm:gap-4">
          <a
            href="#install"
            className="group flex items-center gap-2 px-6 py-3 rounded-xl bg-owl-cyan/10 border border-owl-cyan/30 text-owl-cyan hover:bg-owl-cyan/20 hover:border-owl-cyan/50 transition-all hover:shadow-[0_0_20px_rgba(0,212,255,0.2)]"
          >
            <Terminal className="w-4 h-4" />
            Quick Install
            <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
          </a>
          <a
            href="https://github.com/marktantongco/owl-orca"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 px-6 py-3 rounded-xl bg-white/5 border border-white/10 text-muted-foreground hover:text-white hover:bg-white/10 transition-all"
          >
            <GithubIcon className="w-4 h-4" />
            View on GitHub
          </a>
        </div>

        {/* Badges */}
        <div className="flex flex-wrap items-center justify-center gap-2 mt-8">
          <Badge variant="outline" className="border-owl-cyan/30 text-owl-cyan bg-owl-cyan/5 text-xs">
            v8.0.0
          </Badge>
          <Badge variant="outline" className="border-owl-green/30 text-owl-green bg-owl-green/5 text-xs">
            MIT License
          </Badge>
          <Badge variant="outline" className="border-owl-magenta/30 text-owl-magenta bg-owl-magenta/5 text-xs">
            8GB RAM Optimized
          </Badge>
          <Badge variant="outline" className="border-yellow-400/30 text-yellow-400 bg-yellow-400/5 text-xs">
            Python 3.10+
          </Badge>
        </div>
      </div>

      {/* Scroll indicator */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 animate-bounce opacity-40">
        <div className="w-5 h-8 rounded-full border-2 border-white/20 flex items-start justify-center p-1">
          <div className="w-1 h-2 rounded-full bg-white/40" />
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────
   ARCHITECTURE SECTION
   ──────────────────────────────────────────── */
function ArchitectureSection() {
  const { ref, visible } = useSectionReveal();

  return (
    <section
      id="architecture"
      ref={ref}
      className="relative py-20 sm:py-28 px-4"
    >
      <div
        className={`max-w-6xl mx-auto transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        <div className="text-center mb-12">
          <Badge variant="outline" className="border-owl-cyan/30 text-owl-cyan bg-owl-cyan/5 mb-4">
            System Design
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-owl-cyan to-owl-green bg-clip-text text-transparent">
              Architecture
            </span>
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            OWL-ORCA routes AI requests through a local proxy and router stack, racing multiple
            free-tier providers simultaneously. The first provider to respond wins.
          </p>
        </div>

        {/* Architecture Image */}
        <div className="glass-depth p-3 sm:p-4 mb-12 overflow-hidden">
          <Image
            src="/architecture-schematic.png"
            alt="OWL-ORCA Architecture Schematic"
            width={1200}
            height={600}
            className="w-full h-auto rounded-xl"
            priority
          />
        </div>

        {/* Interactive Flow Diagram */}
        <div className="glass p-6 sm:p-8">
          <h3 className="text-lg font-semibold text-owl-cyan mb-6 text-center">Request Flow</h3>
          <div className="flex flex-col md:flex-row items-center justify-between gap-4 md:gap-2">
            {/* Client */}
            <FlowNode
              icon={<Terminal className="w-5 h-5" />}
              label="Client"
              sublabel="IDE / CLI"
              color="cyan"
            />
            <FlowArrow />
            {/* Forward Proxy */}
            <FlowNode
              icon={<Shield className="w-5 h-5" />}
              label="Forward Proxy"
              sublabel="Port 60000"
              color="magenta"
            />
            <FlowArrow />
            {/* Orca Router */}
            <div className="glass-strong p-4 rounded-xl text-center min-w-[160px] glow-cyan">
              <div className="flex items-center justify-center gap-2 mb-2">
                <div className="w-8 h-8 rounded-lg bg-owl-cyan/20 flex items-center justify-center">
                  <Zap className="w-4 h-4 text-owl-cyan" />
                </div>
              </div>
              <p className="text-sm font-bold text-owl-cyan">Orca Router</p>
              <p className="text-xs text-muted-foreground">Port 60001</p>
              <div className="mt-2 space-y-1">
                <div className="text-[10px] px-2 py-0.5 rounded bg-owl-cyan/10 text-owl-cyan inline-block mr-1">
                  Radix Tree
                </div>
                <div className="text-[10px] px-2 py-0.5 rounded bg-owl-green/10 text-owl-green inline-block mr-1">
                  Stream Racer
                </div>
                <div className="text-[10px] px-2 py-0.5 rounded bg-owl-magenta/10 text-owl-magenta inline-block">
                  Translator
                </div>
              </div>
            </div>
            <FlowArrow />
            {/* Providers */}
            <div className="flex flex-col gap-2">
              <FlowNode
                icon={<Zap className="w-4 h-4" />}
                label="GitHub Copilot"
                sublabel="Free Tier"
                color="green"
                small
              />
              <FlowNode
                icon={<Zap className="w-4 h-4" />}
                label="Antigravity"
                sublabel="Free Tier"
                color="green"
                small
              />
              <FlowNode
                icon={<Zap className="w-4 h-4" />}
                label="Kiro Gateway"
                sublabel="AWS Builder"
                color="green"
                small
              />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function FlowNode({
  icon,
  label,
  sublabel,
  color,
  small = false,
}: {
  icon: React.ReactNode;
  label: string;
  sublabel: string;
  color: "cyan" | "green" | "magenta";
  small?: boolean;
}) {
  const colorMap = {
    cyan: "border-owl-cyan/30 text-owl-cyan bg-owl-cyan/5 hover:border-owl-cyan/50",
    green: "border-owl-green/30 text-owl-green bg-owl-green/5 hover:border-owl-green/50",
    magenta: "border-owl-magenta/30 text-owl-magenta bg-owl-magenta/5 hover:border-owl-magenta/50",
  };

  return (
    <div
      className={`${small ? "p-2.5" : "p-4"} rounded-xl border text-center min-w-[120px] transition-all hover:scale-105 ${colorMap[color]}`}
    >
      <div
        className={`flex items-center justify-center mb-1 ${small ? "" : "mb-2"}`}
      >
        <div
          className={`${small ? "w-6 h-6" : "w-8 h-8"} rounded-lg bg-current/10 flex items-center justify-center [&>svg]:text-current`}
        >
          {icon}
        </div>
      </div>
      <p className={`${small ? "text-xs" : "text-sm"} font-semibold`}>{label}</p>
      <p className="text-[10px] text-muted-foreground">{sublabel}</p>
    </div>
  );
}

function FlowArrow() {
  return (
    <div className="flex items-center justify-center text-muted-foreground/40">
      <div className="hidden md:block">
        <ArrowRight className="w-5 h-5" />
      </div>
      <div className="md:hidden">
        <ChevronRight className="w-5 h-5 rotate-90" />
      </div>
    </div>
  );
}

/* ────────────────────────────────────────────
   STREAM RACER SECTION
   ──────────────────────────────────────────── */
function StreamRacerSection() {
  const { ref, visible } = useSectionReveal();

  return (
    <section
      id="streamracer"
      ref={ref}
      className="relative py-20 sm:py-28 px-4 overflow-hidden"
    >
      {/* Background gradient */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(0,212,255,0.04)_0%,transparent_60%)] pointer-events-none" />

      <div
        className={`max-w-6xl mx-auto relative z-10 transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        <div className="text-center mb-12">
          <Badge variant="outline" className="border-owl-cyan/30 text-owl-cyan bg-owl-cyan/5 mb-4">
            Core Engine
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-owl-cyan to-owl-green bg-clip-text text-transparent">
              StreamRacer
            </span>
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Fire requests to ALL eligible providers simultaneously. The first byte wins — all other
            streams are immediately cancelled. Zero wasted latency.
          </p>
        </div>

        {/* Race Visualization */}
        <div className="glass-depth p-6 sm:p-8 mb-8">
          <div className="flex items-center gap-2 mb-6">
            <Trophy className="w-5 h-5 text-owl-cyan" />
            <h3 className="text-lg font-semibold text-white">Live Race Simulation</h3>
          </div>

          <RaceTrack
            name="GitHub Copilot"
            color="#00d4ff"
            delay={0}
            duration={3}
            winner
          />
          <RaceTrack
            name="Antigravity"
            color="#e040fb"
            delay={0.3}
            duration={3.5}
          />
          <RaceTrack
            name="Kiro Gateway"
            color="#10b981"
            delay={0.6}
            duration={4}
          />

          {/* Winner callout */}
          <div className="mt-6 flex items-center gap-3 p-3 rounded-lg bg-owl-cyan/5 border border-owl-cyan/20">
            <Trophy className="w-5 h-5 text-owl-cyan shrink-0" />
            <div>
              <p className="text-sm font-semibold text-owl-cyan">Copilot wins the race!</p>
              <p className="text-xs text-muted-foreground">
                Stream translated from OpenAI SSE → Client. Loser streams cancelled.
              </p>
            </div>
          </div>
        </div>

        {/* How it works steps */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            {
              step: "1",
              title: "Request Arrives",
              desc: "Client sends request to Orca Router with race strategy",
              color: "cyan" as const,
            },
            {
              step: "2",
              title: "Fire All Providers",
              desc: "Simultaneously request from every eligible provider",
              color: "magenta" as const,
            },
            {
              step: "3",
              title: "First Byte Wins",
              desc: "Provider with first translated SSE chunk wins the race",
              color: "green" as const,
            },
            {
              step: "4",
              title: "Cancel Losers",
              desc: "Loser streams cancelled immediately to free resources",
              color: "cyan" as const,
            },
          ].map((item) => (
            <div key={item.step} className="glass p-4 text-center group hover:scale-[1.02] transition-transform">
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center mx-auto mb-3 font-bold text-lg ${
                  item.color === "cyan"
                    ? "bg-owl-cyan/10 text-owl-cyan border border-owl-cyan/30"
                    : item.color === "magenta"
                      ? "bg-owl-magenta/10 text-owl-magenta border border-owl-magenta/30"
                      : "bg-owl-green/10 text-owl-green border border-owl-green/30"
                }`}
              >
                {item.step}
              </div>
              <p className="text-sm font-semibold mb-1">{item.title}</p>
              <p className="text-xs text-muted-foreground">{item.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function RaceTrack({
  name,
  color,
  delay,
  winner = false,
}: {
  name: string;
  color: string;
  delay: number;
  duration?: number;
  winner?: boolean;
}) {
  return (
    <div className="mb-3 last:mb-0">
      <div className="flex items-center gap-3 mb-1">
        <span
          className="text-xs font-mono w-28 sm:w-32 shrink-0 truncate"
          style={{ color }}
        >
          {name}
        </span>
        {winner && (
          <Badge
            variant="outline"
            className="text-[10px] py-0 px-1.5"
            style={{ borderColor: color, color, backgroundColor: `${color}10` }}
          >
            WINNER
          </Badge>
        )}
      </div>
      <div className="relative h-3 rounded-full bg-white/5 overflow-hidden">
        {/* Track background */}
        <div
          className="absolute inset-y-0 left-0 rounded-full opacity-10"
          style={{ backgroundColor: color, width: "100%" }}
        />
        {/* Racing stream */}
        <div
          className="absolute inset-y-0 left-0 rounded-full"
          style={{
            backgroundColor: color,
            animation: winner
              ? "race-stream-winner 3s ease-out infinite"
              : "race-stream-2 3s ease-out infinite",
            animationDelay: `${delay}s`,
            boxShadow: `0 0 12px ${color}`,
            width: winner ? "30%" : "20%",
          }}
        />
        {/* Pulse dot at head */}
        <div
          className="absolute top-1/2 -translate-y-1/2 w-2 h-2 rounded-full"
          style={{
            backgroundColor: color,
            boxShadow: `0 0 8px ${color}`,
            animation: winner
              ? "race-stream-winner 3s ease-out infinite"
              : "race-stream-2 3s ease-out infinite",
            animationDelay: `${delay}s`,
          }}
        />
      </div>
    </div>
  );
}

/* ────────────────────────────────────────────
   FEATURES GRID
   ──────────────────────────────────────────── */
const FEATURES = [
  {
    icon: Zap,
    title: "Stream Racing",
    subtitle: "First Byte Wins",
    desc: "Fire requests to all providers simultaneously. The first provider to return a translated SSE chunk wins — losers cancelled instantly.",
    color: "cyan" as const,
  },
  {
    icon: ArrowRightLeft,
    title: "Protocol Translation",
    subtitle: "Anthropic ↔ OpenAI",
    desc: "Real-time, chunk-by-chunk SSE translation between Anthropic and OpenAI formats. Zero buffering, zero-copy streaming.",
    color: "green" as const,
  },
  {
    icon: Shield,
    title: "Half-Open Circuit Breakers",
    subtitle: "Probe-Based Recovery",
    desc: "Automatic fault detection with probe-based recovery. 5 consecutive failures → circuit opens. 60s cooldown, then one probe request.",
    color: "magenta" as const,
  },
  {
    icon: GitBranch,
    title: "Radix Tree Routing",
    subtitle: "O(1) Path Matching",
    desc: "No regex, no loops — just tree traversal for all API routes. Lightning-fast path matching with zero overhead.",
    color: "cyan" as const,
  },
  {
    icon: HardHat,
    title: "Safe-Mode",
    subtitle: "IDE Protection",
    desc: "Detects running IDEs and preserves active connections during updates. Updated code activates on next restart — no dropped connections.",
    color: "green" as const,
  },
  {
    icon: RefreshCw,
    title: "SIGHUP Hot-Reload",
    subtitle: "Zero-Drop Config Swap",
    desc: "Swap routing configuration without dropping a single TCP connection. systemctl --user reload is always safe.",
    color: "magenta" as const,
  },
  {
    icon: Lock,
    title: "Fernet Token Encryption",
    subtitle: "Encrypted at Rest",
    desc: "OAuth tokens encrypted at rest using Fernet symmetric encryption with auto-generated keys. Secure file permissions (0600).",
    color: "cyan" as const,
  },
  {
    icon: Download,
    title: "Zero-Downtime Installs",
    subtitle: "Atomic File Writes",
    desc: "Every file update uses write-to-temp + mv for inode swap. Prevents IDE file watcher crashes and partial reads.",
    color: "green" as const,
  },
];

function FeaturesSection() {
  const { ref, visible } = useSectionReveal();

  return (
    <section id="features" ref={ref} className="relative py-20 sm:py-28 px-4">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_30%_50%,rgba(224,64,251,0.03)_0%,transparent_50%)] pointer-events-none" />

      <div
        className={`max-w-6xl mx-auto relative z-10 transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        <div className="text-center mb-12">
          <Badge variant="outline" className="border-owl-magenta/30 text-owl-magenta bg-owl-magenta/5 mb-4">
            Capabilities
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-owl-magenta to-owl-cyan bg-clip-text text-transparent">
              Feature Set
            </span>
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Battle-tested through five audit passes. Every feature is production-hardened.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {FEATURES.map((feature, i) => (
            <FeatureCard key={feature.title} feature={feature} index={i} />
          ))}
        </div>
      </div>
    </section>
  );
}

function FeatureCard({
  feature,
  index,
}: {
  feature: (typeof FEATURES)[number];
  index: number;
}) {
  const colorMap = {
    cyan: {
      iconBg: "bg-owl-cyan/10",
      iconColor: "text-owl-cyan",
      borderHover: "hover:border-owl-cyan/30",
      glowHover: "hover:shadow-[0_0_20px_rgba(0,212,255,0.1)]",
      badge: "border-owl-cyan/20 text-owl-cyan bg-owl-cyan/5",
    },
    green: {
      iconBg: "bg-owl-green/10",
      iconColor: "text-owl-green",
      borderHover: "hover:border-owl-green/30",
      glowHover: "hover:shadow-[0_0_20px_rgba(16,185,129,0.1)]",
      badge: "border-owl-green/20 text-owl-green bg-owl-green/5",
    },
    magenta: {
      iconBg: "bg-owl-magenta/10",
      iconColor: "text-owl-magenta",
      borderHover: "hover:border-owl-magenta/30",
      glowHover: "hover:shadow-[0_0_20px_rgba(224,64,251,0.1)]",
      badge: "border-owl-magenta/20 text-owl-magenta bg-owl-magenta/5",
    },
  };

  const c = colorMap[feature.color];

  return (
    <div
      className={`glass-depth p-5 transition-all duration-300 group ${c.borderHover} ${c.glowHover} hover:scale-[1.02]`}
      style={{ animationDelay: `${index * 80}ms` }}
    >
      <div className={`w-10 h-10 rounded-xl ${c.iconBg} flex items-center justify-center mb-3 group-hover:scale-110 transition-transform`}>
        <feature.icon className={`w-5 h-5 ${c.iconColor}`} />
      </div>
      <h3 className="text-sm font-bold mb-1">{feature.title}</h3>
      <Badge variant="outline" className={`text-[10px] py-0 px-1.5 mb-2 ${c.badge}`}>
        {feature.subtitle}
      </Badge>
      <p className="text-xs text-muted-foreground leading-relaxed">{feature.desc}</p>
    </div>
  );
}

/* ────────────────────────────────────────────
   VERSION TIMELINE SECTION
   ──────────────────────────────────────────── */
const VERSIONS = [
  { version: "6.2", codename: "Base", date: "May 2025", key: "Podman, swap guard, memory accounting", color: "cyan" as const },
  { version: "6.3", codename: "Provider Integration", date: "May 2025", key: "Copilot Free, Antigravity, Fernet tokens", color: "green" as const },
  { version: "6.4", codename: "Orca-Router", date: "May 2025", key: "Stream Racing, Radix Tree, Circuit Breakers", color: "magenta" as const },
  { version: "7.0", codename: "Protocol Translation", date: "Jun 2025", key: "Anthropic ↔ OpenAI SSE translation", color: "cyan" as const },
  { version: "7.1", codename: "Safe-Mode", date: "Jun 2025", key: "Atomic swaps, IDE preservation, SIGHUP", color: "green" as const },
  { version: "7.2", codename: "Audit-Hardened", date: "Jun 2025", key: "JSONC parser, port conflict detection", color: "magenta" as const },
  { version: "7.3", codename: "Two-Pass-Final", date: "Jun 2025", key: "Kiro Gateway, 7 bugs fixed", color: "cyan" as const },
  { version: "7.4", codename: "Two-Pass-Final+", date: "Jun 2025", key: "Harden, retry logic, 7 more bugs", color: "green" as const },
  { version: "7.5", codename: "Three-Pass-Final", date: "Jun 2025", key: "Dedup, dead code removed, 20 bugs", color: "magenta" as const },
  { version: "7.6", codename: "Four-Pass-Final", date: "Jun 2025", key: "Optimization, memory tuning, 12 bugs", color: "cyan" as const },
  { version: "8.0", codename: "Five-Pass-Final", date: "Jun 2025", key: "15 more bugs, SIGHUP async I/O", color: "green" as const },
];

function TimelineSection() {
  const { ref, visible } = useSectionReveal();
  const scrollRef = useRef<HTMLDivElement>(null);

  return (
    <section id="timeline" ref={ref} className="relative py-20 sm:py-28 px-4">
      <div
        className={`max-w-6xl mx-auto transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        <div className="text-center mb-12">
          <Badge variant="outline" className="border-owl-green/30 text-owl-green bg-owl-green/5 mb-4">
            Evolution
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-owl-green to-owl-cyan bg-clip-text text-transparent">
              Version Timeline
            </span>
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            From base infrastructure to five-pass audit final. Every version battle-tested.
          </p>
        </div>

        {/* Version Timeline Image */}
        <div className="glass-depth p-3 sm:p-4 mb-8 overflow-hidden">
          <Image
            src="/version-timeline.png"
            alt="OWL-ORCA Version Timeline"
            width={1200}
            height={400}
            className="w-full h-auto rounded-xl"
          />
        </div>

        {/* Horizontal Scrollable Timeline */}
        <div
          ref={scrollRef}
          className="flex gap-4 overflow-x-auto pb-4 custom-scrollbar snap-x snap-mandatory"
        >
          {VERSIONS.map((v) => {
            const colorStyles = {
              cyan: {
                dot: "bg-owl-cyan shadow-[0_0_8px_rgba(0,212,255,0.5)]",
                line: "bg-gradient-to-r from-owl-cyan/50 to-transparent",
                badge: "border-owl-cyan/30 text-owl-cyan",
              },
              green: {
                dot: "bg-owl-green shadow-[0_0_8px_rgba(16,185,129,0.5)]",
                line: "bg-gradient-to-r from-owl-green/50 to-transparent",
                badge: "border-owl-green/30 text-owl-green",
              },
              magenta: {
                dot: "bg-owl-magenta shadow-[0_0_8px_rgba(224,64,251,0.5)]",
                line: "bg-gradient-to-r from-owl-magenta/50 to-transparent",
                badge: "border-owl-magenta/30 text-owl-magenta",
              },
            };
            const s = colorStyles[v.color];

            return (
              <div
                key={v.version}
                className="glass-depth p-4 min-w-[200px] sm:min-w-[220px] snap-start shrink-0 group hover:scale-[1.02] transition-transform"
              >
                <div className="flex items-center gap-2 mb-2">
                  <div className={`w-3 h-3 rounded-full ${s.dot}`} />
                  <Badge variant="outline" className={`text-[10px] py-0 ${s.badge}`}>
                    v{v.version}
                  </Badge>
                </div>
                <p className="text-sm font-bold mb-1">{v.codename}</p>
                <p className="text-[10px] text-muted-foreground mb-2 flex items-center gap-1">
                  <Clock className="w-3 h-3" />
                  {v.date}
                </p>
                <p className="text-xs text-muted-foreground leading-relaxed">{v.key}</p>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────
   QUICK INSTALL SECTION
   ──────────────────────────────────────────── */
function QuickInstallSection() {
  const { ref, visible } = useSectionReveal();
  const [copied, setCopied] = useState(false);

  const installCmd =
    'curl -fsSL https://raw.githubusercontent.com/marktantongco/owl-orca/main/install.sh | bash';

  const handleCopy = useCallback(() => {
    navigator.clipboard.writeText(installCmd).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }, []);

  return (
    <section id="install" ref={ref} className="relative py-20 sm:py-28 px-4">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_50%,rgba(16,185,129,0.04)_0%,transparent_60%)] pointer-events-none" />

      <div
        className={`max-w-4xl mx-auto relative z-10 transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        <div className="text-center mb-8">
          <Badge variant="outline" className="border-owl-green/30 text-owl-green bg-owl-green/5 mb-4">
            Get Started
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-owl-green to-owl-cyan bg-clip-text text-transparent">
              Quick Install
            </span>
          </h2>
          <p className="text-muted-foreground">
            One line. That&apos;s all it takes.
          </p>
        </div>

        {/* Code block */}
        <div className="glass-depth p-1">
          <div className="bg-black/40 rounded-xl overflow-hidden">
            {/* Terminal header */}
            <div className="flex items-center justify-between px-4 py-2 border-b border-white/5">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-red-500/60" />
                <div className="w-3 h-3 rounded-full bg-yellow-500/60" />
                <div className="w-3 h-3 rounded-full bg-green-500/60" />
                <span className="text-xs text-muted-foreground ml-2 font-mono">bash</span>
              </div>
              <button
                onClick={handleCopy}
                className="flex items-center gap-1.5 px-3 py-1 rounded-md text-xs transition-all hover:bg-white/5"
                aria-label="Copy install command"
              >
                {copied ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-owl-green" />
                    <span className="text-owl-green">Copied!</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5 text-muted-foreground" />
                    <span className="text-muted-foreground">Copy</span>
                  </>
                )}
              </button>
            </div>
            {/* Code */}
            <div className="p-4 sm:p-6 overflow-x-auto">
              <code className="text-sm sm:text-base font-mono text-owl-green leading-relaxed">
                <span className="text-muted-foreground">$</span>{" "}
                <span className="text-owl-cyan">curl</span>{" "}
                <span className="text-owl-magenta">-fsSL</span>{" "}
                <span className="text-yellow-400">
                  https://raw.githubusercontent.com/marktantongco/owl-orca/main/install.sh
                </span>{" "}
                <span className="text-owl-magenta">|</span>{" "}
                <span className="text-owl-cyan">bash</span>
              </code>
            </div>
          </div>
        </div>

        {/* Alternative install options */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-6">
          {[
            { flag: "--skip-proxy", desc: "Skip forward proxy" },
            { flag: "--skip-kiro", desc: "Skip Kiro Gateway" },
            { flag: "--with-providers", desc: "Configure provider auth" },
          ].map((opt) => (
            <div key={opt.flag} className="glass p-3 text-center">
              <code className="text-xs font-mono text-owl-cyan">{opt.flag}</code>
              <p className="text-[10px] text-muted-foreground mt-1">{opt.desc}</p>
            </div>
          ))}
        </div>

        {/* More options */}
        <div className="glass-subtle p-4 mt-6 rounded-xl">
          <p className="text-xs text-muted-foreground mb-2 font-semibold">More install options:</p>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            {[
              { flag: "--upgrade", desc: "Upgrade existing" },
              { flag: "--dry-run", desc: "Preview changes" },
              { flag: "--version=8.0.0", desc: "Pin version" },
              { flag: "--uninstall", desc: "Remove install" },
            ].map((opt) => (
              <div key={opt.flag} className="flex flex-col gap-0.5">
                <code className="text-[10px] font-mono text-owl-green">{opt.flag}</code>
                <span className="text-[10px] text-muted-foreground">{opt.desc}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────
   FEATURE MATRIX SECTION
   ──────────────────────────────────────────── */
function FeatureMatrixSection() {
  const { ref, visible } = useSectionReveal();

  const providerData = [
    {
      provider: "GitHub Copilot (Free)",
      format: "OpenAI",
      auth: "Device Flow",
      storage: "Fernet encrypted",
      streaming: "SSE (native)",
      thinking: "Not supported",
      toolCalling: "Supported",
      circuit: "5 failures → open",
      canary: "90 (default)",
      fallback: "→ Kiro",
    },
    {
      provider: "Antigravity (Free)",
      format: "Anthropic",
      auth: "OAuth PKCE / API Key",
      storage: "Fernet encrypted",
      streaming: "SSE (requires translation)",
      thinking: "Supported (thinking_delta)",
      toolCalling: "Supported",
      circuit: "5 failures → open",
      canary: "10 (default)",
      fallback: "→ Kiro",
    },
    {
      provider: "Kiro Gateway (AWS)",
      format: "OpenAI",
      auth: "AWS Builder ID OIDC",
      storage: ".env (0600)",
      streaming: "SSE (native)",
      thinking: "Not supported",
      toolCalling: "Supported",
      circuit: "5 failures → open",
      canary: "Fallback",
      fallback: "Last resort",
    },
  ];

  const strategyData = [
    { strategy: "race", desc: "Fire ALL providers, first byte wins", use: "Chat completions", latency: "Lowest", cost: "Higher" },
    { strategy: "single", desc: "Route to first available", use: "Model listing", latency: "Normal", cost: "Normal" },
    { strategy: "canary", desc: "Weighted random (A/B testing)", use: "Gradual rollout", latency: "Normal", cost: "Normal" },
    { strategy: "fallback", desc: "Try in order, fall back on circuit-open", use: "Critical paths", latency: "Variable", cost: "Normal" },
  ];

  return (
    <section id="matrix" ref={ref} className="relative py-20 sm:py-28 px-4">
      <div
        className={`max-w-6xl mx-auto transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        <div className="text-center mb-12">
          <Badge variant="outline" className="border-owl-cyan/30 text-owl-cyan bg-owl-cyan/5 mb-4">
            Comparison
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-owl-cyan to-owl-magenta bg-clip-text text-transparent">
              Feature Matrix
            </span>
          </h2>
        </div>

        {/* Provider comparison */}
        <div className="glass-depth p-1 mb-8 overflow-x-auto">
          <table className="w-full min-w-[700px]">
            <thead>
              <tr className="border-b border-white/5">
                <th className="text-left text-xs font-semibold text-muted-foreground p-3">Feature</th>
                {providerData.map((p) => (
                  <th key={p.provider} className="text-left text-xs font-semibold text-owl-cyan p-3">
                    {p.provider}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {[
                { label: "API Format", key: "format" as const },
                { label: "Auth Method", key: "auth" as const },
                { label: "Token Storage", key: "storage" as const },
                { label: "Streaming", key: "streaming" as const },
                { label: "Extended Thinking", key: "thinking" as const },
                { label: "Tool Calling", key: "toolCalling" as const },
                { label: "Circuit Breaker", key: "circuit" as const },
                { label: "Canary Weight", key: "canary" as const },
                { label: "Auto-Fallback", key: "fallback" as const },
              ].map((row, i) => (
                <tr
                  key={row.key}
                  className={`border-b border-white/3 ${i % 2 === 0 ? "bg-white/[0.02]" : ""}`}
                >
                  <td className="text-xs font-medium p-3 text-muted-foreground">{row.label}</td>
                  {providerData.map((p) => (
                    <td key={`${p.provider}-${row.key}`} className="text-xs p-3">
                      {p[row.key]}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Routing strategy comparison */}
        <div className="glass-depth p-1 overflow-x-auto">
          <table className="w-full min-w-[600px]">
            <thead>
              <tr className="border-b border-white/5">
                <th className="text-left text-xs font-semibold text-muted-foreground p-3">Strategy</th>
                <th className="text-left text-xs font-semibold text-muted-foreground p-3">Description</th>
                <th className="text-left text-xs font-semibold text-muted-foreground p-3">Use Case</th>
                <th className="text-left text-xs font-semibold text-muted-foreground p-3">Latency</th>
                <th className="text-left text-xs font-semibold text-muted-foreground p-3">Cost</th>
              </tr>
            </thead>
            <tbody>
              {strategyData.map((s, i) => (
                <tr
                  key={s.strategy}
                  className={`border-b border-white/3 ${i % 2 === 0 ? "bg-white/[0.02]" : ""}`}
                >
                  <td className="text-xs font-mono font-bold text-owl-green p-3">{s.strategy}</td>
                  <td className="text-xs p-3">{s.desc}</td>
                  <td className="text-xs p-3">{s.use}</td>
                  <td className="text-xs p-3">
                    <span
                      className={
                        s.latency === "Lowest"
                          ? "text-owl-cyan font-semibold"
                          : "text-muted-foreground"
                      }
                    >
                      {s.latency}
                    </span>
                  </td>
                  <td className="text-xs p-3 text-muted-foreground">{s.cost}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────
   KNOWN ISSUES SECTION
   ──────────────────────────────────────────── */
function KnownIssuesSection() {
  const { ref, visible } = useSectionReveal();

  const fixedBugs = [
    { id: "B1", desc: "SSE extended thinking blocks silently dropped", fix: "Map thinking_delta → reasoning_content", ver: "v7.3" },
    { id: "B2", desc: "Uninstall opencode.jsonc cleanup used naive regex", fix: "State-machine JSONC parser", ver: "v7.3" },
    { id: "B3", desc: "glibc/musl detection logic inverted", fix: "Check ldd output for musl string", ver: "v7.3" },
    { id: "B8", desc: "httpx client connections leak on shutdown", fix: "Added aclose() in finally block", ver: "v7.4" },
    { id: "B9", desc: "SIGHUP reload blocked when IDE running", fix: "SIGHUP is always safe", ver: "v7.4" },
    { id: "B10", desc: "Config directories lack secure permissions", fix: "chmod 700 on CONFIG_DIR", ver: "v7.4" },
    { id: "N2", desc: "Forward proxy hardcodes ~/.owl-agent", fix: "Use OWL_INSTALL_DIR env var", ver: "v8.0" },
    { id: "N8", desc: "SIGHUP file I/O blocks event loop", fix: "Thread executor for I/O", ver: "v8.0" },
    { id: "N9", desc: "All-streams-fail raises non-standard exception", fix: "OpenAI-compliant error chunk", ver: "v8.0" },
  ];

  const pendingIssues = [
    { desc: "Antigravity OAuth PKCE requires manual code paste", status: "By design", workaround: "Use --api-key flag" },
    { desc: "Copilot device flow tokens expire after 24h", status: "Pending", workaround: "Re-run owl-token auth" },
    { desc: "Running install.sh twice may cause race conditions", status: "Known", workaround: "Use flock or run sequentially" },
    { desc: "No Windows support (systemd required)", status: "Not planned", workaround: "Use WSL2 with systemd" },
  ];

  return (
    <section ref={ref} className="relative py-20 sm:py-28 px-4">
      <div
        className={`max-w-4xl mx-auto transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        <div className="text-center mb-12">
          <Badge variant="outline" className="border-yellow-400/30 text-yellow-400 bg-yellow-400/5 mb-4">
            Transparency
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-yellow-400 to-owl-magenta bg-clip-text text-transparent">
              Known Issues
            </span>
          </h2>
          <p className="text-muted-foreground">
            Full transparency. Every bug we&apos;ve fixed and every limitation we acknowledge.
          </p>
        </div>

        <Accordion multiple defaultValue={["fixed", "pending"]} className="space-y-3">
          {/* Fixed bugs */}
          <AccordionItem value="fixed" className="glass-depth !border-0 rounded-xl overflow-hidden">
            <AccordionTrigger className="px-6 py-4 hover:no-underline hover:bg-white/[0.02] [&>svg]:text-owl-green">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-owl-green/10 flex items-center justify-center">
                  <Bug className="w-4 h-4 text-owl-green" />
                </div>
                <div className="text-left">
                  <p className="text-sm font-semibold">Fixed Bugs</p>
                  <p className="text-xs text-muted-foreground">
                    {fixedBugs.length} bugs fixed across 5 audit passes
                  </p>
                </div>
              </div>
            </AccordionTrigger>
            <AccordionContent className="px-6 pb-4">
              <div className="space-y-2 max-h-96 overflow-y-auto custom-scrollbar">
                {fixedBugs.map((bug) => (
                  <div
                    key={bug.id}
                    className="flex items-start gap-3 p-3 rounded-lg bg-white/[0.02] border border-white/5"
                  >
                    <Badge
                      variant="outline"
                      className="text-[10px] py-0 shrink-0 border-owl-green/30 text-owl-green bg-owl-green/5"
                    >
                      {bug.id}
                    </Badge>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs text-foreground/90">{bug.desc}</p>
                      <p className="text-[10px] text-muted-foreground mt-0.5">
                        Fix: {bug.fix} • {bug.ver}
                      </p>
                    </div>
                    <Wrench className="w-3.5 h-3.5 text-owl-green shrink-0 mt-0.5" />
                  </div>
                ))}
              </div>
            </AccordionContent>
          </AccordionItem>

          {/* Pending issues */}
          <AccordionItem value="pending" className="glass-depth !border-0 rounded-xl overflow-hidden">
            <AccordionTrigger className="px-6 py-4 hover:no-underline hover:bg-white/[0.02] [&>svg]:text-yellow-400">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-yellow-400/10 flex items-center justify-center">
                  <AlertTriangle className="w-4 h-4 text-yellow-400" />
                </div>
                <div className="text-left">
                  <p className="text-sm font-semibold">Pending / Known Limitations</p>
                  <p className="text-xs text-muted-foreground">
                    {pendingIssues.length} items — workarounds available
                  </p>
                </div>
              </div>
            </AccordionTrigger>
            <AccordionContent className="px-6 pb-4">
              <div className="space-y-2">
                {pendingIssues.map((issue, i) => (
                  <div
                    key={i}
                    className="flex items-start gap-3 p-3 rounded-lg bg-white/[0.02] border border-white/5"
                  >
                    <Badge
                      variant="outline"
                      className={`text-[10px] py-0 shrink-0 ${
                        issue.status === "Pending"
                          ? "border-yellow-400/30 text-yellow-400 bg-yellow-400/5"
                          : issue.status === "Known"
                            ? "border-owl-magenta/30 text-owl-magenta bg-owl-magenta/5"
                            : "border-muted-foreground/30 text-muted-foreground bg-muted-foreground/5"
                      }`}
                    >
                      {issue.status}
                    </Badge>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs text-foreground/90">{issue.desc}</p>
                      <p className="text-[10px] text-muted-foreground mt-0.5">
                        Workaround: {issue.workaround}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </AccordionContent>
          </AccordionItem>
        </Accordion>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────
   INFOGRAPHIC SECTION
   ──────────────────────────────────────────── */
function InfographicSection() {
  const { ref, visible } = useSectionReveal();

  return (
    <section ref={ref} className="relative py-20 sm:py-28 px-4">
      <div
        className={`max-w-6xl mx-auto transition-all duration-1000 ${
          visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"
        }`}
      >
        <div className="text-center mb-12">
          <h2 className="text-3xl sm:text-4xl font-bold mb-4">
            <span className="bg-gradient-to-r from-owl-cyan via-owl-green to-owl-magenta bg-clip-text text-transparent">
              Feature Infographic
            </span>
          </h2>
        </div>

        <div className="glass-depth p-3 sm:p-4 overflow-hidden">
          <Image
            src="/infographic-illustration.png"
            alt="OWL-ORCA Feature Infographic"
            width={1200}
            height={800}
            className="w-full h-auto rounded-xl"
          />
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────
   FOOTER
   ──────────────────────────────────────────── */
function Footer() {
  return (
    <footer className="relative mt-auto border-t border-white/5">
      <div className="max-w-6xl mx-auto px-4 py-12 sm:py-16">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
          {/* Brand */}
          <div className="sm:col-span-2 lg:col-span-1">
            <div className="flex items-center gap-2 mb-3">
              <span className="text-xl">🦉</span>
              <span className="text-lg font-bold text-owl-cyan">OWL-ORCA</span>
            </div>
            <p className="text-xs text-muted-foreground leading-relaxed">
              Self-hosted AI gateway that aggregates free-tier providers into a single
              OpenAI-compatible API endpoint. Free AI for everyone.
            </p>
          </div>

          {/* Project */}
          <div>
            <h4 className="text-sm font-semibold mb-3">Project</h4>
            <div className="space-y-2">
              <a
                href="https://github.com/marktantongco/owl-orca"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 text-xs text-muted-foreground hover:text-owl-cyan transition-colors"
              >
                <GithubIcon className="w-3.5 h-3.5" />
                GitHub Repository
              </a>
              <a
                href="https://github.com/marktantongco/owl-orca/blob/main/LICENSE"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 text-xs text-muted-foreground hover:text-owl-cyan transition-colors"
              >
                <ExternalLink className="w-3.5 h-3.5" />
                MIT License
              </a>
              <a
                href="https://github.com/marktantongco/owl-orca/issues"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 text-xs text-muted-foreground hover:text-owl-cyan transition-colors"
              >
                <Bug className="w-3.5 h-3.5" />
                Report an Issue
              </a>
            </div>
          </div>

          {/* Sections */}
          <div>
            <h4 className="text-sm font-semibold mb-3">Sections</h4>
            <div className="space-y-2">
              {NAV_ITEMS.map((item) => (
                <a
                  key={item.href}
                  href={item.href}
                  className="block text-xs text-muted-foreground hover:text-owl-cyan transition-colors"
                >
                  {item.label}
                </a>
              ))}
            </div>
          </div>

          {/* Tech Stack */}
          <div>
            <h4 className="text-sm font-semibold mb-3">Built With</h4>
            <div className="flex flex-wrap gap-1.5">
              {["Python 3.10+", "Bash", "asyncio", "httpx", "aiohttp", "systemd", "Fernet"].map(
                (tech) => (
                  <Badge
                    key={tech}
                    variant="outline"
                    className="text-[10px] py-0 border-white/10 text-muted-foreground"
                  >
                    {tech}
                  </Badge>
                )
              )}
            </div>
          </div>
        </div>

        {/* Bottom bar */}
        <Separator className="my-8 bg-white/5" />
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-muted-foreground">
          <p>OWL-ORCA v8.0.0 — Five-Pass-Audit-Final Edition</p>
          <p>
            Stream Racing • Protocol Translation • Safe-Mode • Radix Routing • Circuit Breakers •
            Zero-Downtime
          </p>
        </div>
      </div>
    </footer>
  );
}

/* ────────────────────────────────────────────
   MAIN PAGE
   ──────────────────────────────────────────── */
export default function HomePage() {
  return (
    <div className="min-h-screen flex flex-col animated-gradient-bg">
      <NavBar />
      <main className="flex-1">
        <HeroSection />
        <ArchitectureSection />
        <StreamRacerSection />
        <FeaturesSection />
        <InfographicSection />
        <TimelineSection />
        <QuickInstallSection />
        <FeatureMatrixSection />
        <KnownIssuesSection />
      </main>
      <Footer />
    </div>
  );
}
