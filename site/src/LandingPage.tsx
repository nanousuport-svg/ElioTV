import { useEffect, useRef, useState, type ReactNode } from 'react'
import {
  AnimatePresence,
  MotionConfig,
  motion,
  useMotionValueEvent,
  useScroll,
  useTransform,
  type Variants,
} from 'framer-motion'

// Landing page d'ElioTV : Tailwind CSS pour le design, Framer Motion pour les animations.
// Les « captures » sont des maquettes dessinées en HTML (chaînes fictives) qui s'adaptent à toutes les tailles.

const REPO = 'https://github.com/nanousuport-svg/ElioTV'
const REL = `${REPO}/releases/latest/download/`
const APK_URL = `${REL}ElioTV-Android.apk`
// Préfixe des fichiers de public/ (« /ElioTV/ » une fois publié sur GitHub Pages).
const BASE = import.meta.env.BASE_URL

// ─── Animations communes ────────────────────────────────────────────────────

const fadeUp: Variants = {
  hidden: { opacity: 0, y: 18 },
  show: { opacity: 1, y: 0, transition: { duration: 0.8, ease: [0.2, 0.8, 0.2, 1] } },
}

const stagger: Variants = {
  hidden: {},
  show: { transition: { staggerChildren: 0.09, delayChildren: 0.05 } },
}

const popIn: Variants = {
  hidden: { opacity: 0, y: 28, scale: 0.97 },
  show: { opacity: 1, y: 0, scale: 1, transition: { duration: 0.7, ease: [0.2, 0.8, 0.2, 1] } },
}

const inView = { initial: 'hidden', whileInView: 'show', viewport: { once: true, margin: '0px 0px -10% 0px' } } as const

function Reveal({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <motion.div variants={fadeUp} {...inView} className={className}>
      {children}
    </motion.div>
  )
}

// ─── Données ────────────────────────────────────────────────────────────────

type Channel = { code: string; name: string; now: string; color: string }

const CHANNELS: Channel[] = [
  { code: 'INFO', name: 'Info 24', now: 'Le journal du soir', color: 'bg-[#2B5BE0]' },
  { code: 'SP1', name: 'Sport 1 HD', now: 'Match en direct', color: 'bg-[#12A150]' },
  { code: 'CIN+', name: 'Cinéma+', now: 'Nuit blanche', color: 'bg-[#C2185B]' },
  { code: 'DOC', name: 'Docu Monde', now: 'Les grands fleuves', color: 'bg-[#D98E04]' },
  { code: 'KIDS', name: 'Kids Club', now: 'Dessins animés', color: 'bg-[#7C3AED]' },
  { code: 'MUS', name: 'Musique Live', now: 'Concert acoustique', color: 'bg-[#0E9AA7]' },
]

const POSTERS = [
  { title: 'Horizon', year: 2025, from: '#5C45FA', to: '#1a1446' },
  { title: 'Nuit blanche', year: 2024, from: '#ED409E', to: '#3b0f2a' },
  { title: 'Le Phare', year: 2024, from: '#0E9AA7', to: '#082a2e' },
  { title: "Sable d'or", year: 2023, from: '#D98E04', to: '#3a2400' },
  { title: 'Station 9', year: 2025, from: '#2B5BE0', to: '#0b1a44' },
  { title: 'Grand air', year: 2023, from: '#12A150', to: '#062b15' },
  { title: 'Écho', year: 2022, from: '#7C3AED', to: '#1e0b44' },
  { title: 'Rouge vif', year: 2024, from: '#C2185B', to: '#3a0619' },
  { title: 'Brume', year: 2021, from: '#4b5563', to: '#111827' },
  { title: 'Dernier été', year: 2025, from: '#f97316', to: '#3b1405' },
]

const FAQ = [
  {
    q: 'ElioTV fournit-il des chaînes ?',
    a: (
      <>
        Non. ElioTV est un <b className="font-semibold text-white">lecteur</b> : il affiche le contenu de l'abonnement IPTV que tu
        as déjà souscrit chez ton fournisseur, avec tes codes Xtream ou ton lien M3U.
      </>
    ),
  },
  {
    q: "Comment l'installer sur un Fire TV Stick ou une Android TV ?",
    a: (
      <>
        Installe l'app gratuite <b className="font-semibold text-white">Downloader</b> depuis le store de ta TV, autorise
        l'installation d'apps inconnues (Paramètres › Ma Fire TV › Options pour les développeurs), puis tape ce lien dans
        Downloader :
        <code className="mt-3 block break-all rounded-lg bg-white/[.07] px-3 py-2 font-mono text-[.88em]">{APK_URL}</code>
      </>
    ),
  },
  {
    q: 'Windows ou macOS affiche un avertissement. Est-ce normal ?',
    a: (
      <>
        Oui : l'app n'est pas encore signée par un certificat payant. Sur <b className="font-semibold text-white">Windows</b>,
        clique sur « Informations complémentaires » puis « Exécuter quand même ». Sur{' '}
        <b className="font-semibold text-white">Mac</b>, va dans Réglages Système › Confidentialité et sécurité, puis « Ouvrir
        quand même ». C'est à faire une seule fois.
      </>
    ),
  },
  {
    q: 'Est-ce vraiment gratuit ?',
    a: (
      <>
        Oui, entièrement : pas de publicité, pas d'abonnement, pas de version payante. Le code est consultable sur{' '}
        <a className="underline hover:text-white" href={REPO}>
          GitHub
        </a>
        .
      </>
    ),
  },
  { q: 'Et sur iPhone, iPad ou Apple TV ?', a: <>La version iPhone et iPad est en préparation. Apple TV viendra ensuite.</> },
]

const DOWNLOADS = [
  { os: 'android', name: 'Android', detail: 'Téléphone, tablette, Android TV, Fire TV · 92 Mo', file: 'ElioTV-Android.apk', cta: "Télécharger l'APK" },
  { os: 'windows', name: 'Windows', detail: 'Windows 10 et 11, 64 bits · 31 Mo', file: 'ElioTV-Windows.zip', cta: 'Télécharger' },
  { os: 'mac', name: 'Mac', detail: 'Puce Apple ou Intel, macOS 12+ · 34 Mo', file: 'ElioTV-Mac.zip', cta: 'Télécharger' },
] as const

type Os = (typeof DOWNLOADS)[number]['os'] | 'ios' | null

// Détecte l'appareil du visiteur pour proposer le bon fichier.
function useDevice() {
  const [os, setOs] = useState<Os>(null)
  useEffect(() => {
    const ua = navigator.userAgent
    if (/Android|AFT|BRAVIA|SMART-TV/i.test(ua)) setOs('android')
    else if (/iPhone|iPad|iPod/i.test(ua)) setOs('ios')
    else if (/Windows/i.test(ua)) setOs('windows')
    else if (/Macintosh|Mac OS X/i.test(ua) && navigator.maxTouchPoints < 2) setOs('mac')
  }, [])
  const match = DOWNLOADS.find(d => d.os === os)
  return {
    os,
    href: match ? REL + match.file : '#telecharger',
    label: match ? `Télécharger pour ${match.name}` : os === 'ios' ? 'Bientôt sur iPhone' : 'Télécharger gratuitement',
  }
}

// ─── Petits éléments ────────────────────────────────────────────────────────

const GRADIENT = 'bg-gradient-to-r from-brand-violet to-brand-pink'
const GRADIENT_TEXT = 'bg-gradient-to-r from-brand-violet to-brand-pink bg-clip-text text-transparent'

function DownloadIcon() {
  return (
    <svg viewBox="0 0 24 24" className="size-[18px] shrink-0" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 4v12m0 0-5-5m5 5 5-5M5 20h14" />
    </svg>
  )
}

function PrimaryButton({ href, children, className = '' }: { href: string; children: ReactNode; className?: string }) {
  return (
    <motion.a
      href={href}
      whileHover={{ y: -2, boxShadow: '0 16px 50px -10px rgba(237,64,158,.7)' }}
      whileTap={{ scale: 0.97 }}
      transition={{ type: 'spring', stiffness: 400, damping: 25 }}
      className={`inline-flex h-[52px] items-center justify-center gap-2.5 rounded-full px-[26px] text-base font-semibold whitespace-nowrap shadow-[0_10px_40px_-10px_rgba(92,69,250,.8)] ${GRADIENT} ${className}`}
    >
      {children}
    </motion.a>
  )
}

function GhostButton({ children, onClick, href, className = '' }: { children: ReactNode; onClick?: () => void; href?: string; className?: string }) {
  const cls = `inline-flex h-[52px] items-center justify-center gap-2.5 rounded-full border border-white/15 bg-white/[.03] px-[26px] text-base font-semibold whitespace-nowrap transition-colors hover:bg-white/[.08] ${className}`
  const motionProps = { whileHover: { y: -2 }, whileTap: { scale: 0.97 }, transition: { type: 'spring', stiffness: 400, damping: 25 } } as const
  return href ? (
    <motion.a href={href} className={cls} {...motionProps}>
      {children}
    </motion.a>
  ) : (
    <motion.button type="button" onClick={onClick} className={cls} {...motionProps}>
      {children}
    </motion.button>
  )
}

function Eyebrow({ children }: { children: ReactNode }) {
  return <div className="mb-4 text-sm font-semibold tracking-[.08em] text-white/40 uppercase">{children}</div>
}

function SectionHead({ eyebrow, title, text }: { eyebrow: string; title: ReactNode; text?: string }) {
  return (
    <Reveal className="mx-auto mb-11 max-w-[760px] text-center md:mb-16">
      <Eyebrow>{eyebrow}</Eyebrow>
      <h2 className="text-[clamp(36px,5.4vw,64px)] leading-[1.04] font-bold tracking-[-0.03em]">{title}</h2>
      {text && <p className="mt-5 text-lg text-white/65 md:text-xl">{text}</p>}
    </Reveal>
  )
}

function Halo({ className }: { className: string }) {
  return <div aria-hidden className={`pointer-events-none absolute -z-10 rounded-full blur-[120px] ${className}`} />
}

function ChannelLogo({ c, className = '' }: { c: Channel; className?: string }) {
  return (
    <span className={`grid shrink-0 place-items-center rounded-[.5em] font-extrabold tracking-tight ${c.color} ${className}`}>{c.code}</span>
  )
}

function Chip({ children, on = false, className = '' }: { children: ReactNode; on?: boolean; className?: string }) {
  return (
    <span
      className={`rounded-full border px-[.9em] py-[.45em] whitespace-nowrap ${
        on ? 'border-brand-violet/80 bg-brand-violet/35' : 'border-white/15 bg-white/[.06]'
      } ${className}`}
    >
      {children}
    </span>
  )
}

function ProgressBar({ value, className = '' }: { value: number; className?: string }) {
  return (
    <div className={`h-[.25em] overflow-hidden rounded-full bg-white/15 ${className}`}>
      <div className="h-full rounded-full bg-brand-pink" style={{ width: `${value}%` }} />
    </div>
  )
}

// ─── Scènes vidéo fictives ──────────────────────────────────────────────────

function SportScene() {
  return (
    <div className="absolute inset-0 overflow-hidden" style={{ background: 'repeating-linear-gradient(90deg,#1d7a3c 0 9%,#22894a 9% 18%)' }}>
      <div className="absolute inset-x-0 top-0 h-[38%] bg-gradient-to-b from-[#0c1730] to-[#1d3a5e]" />
      <div
        className="absolute top-[62%] left-1/2 aspect-square w-[26%] -translate-x-1/2 -translate-y-1/2 rounded-full border-[.25em] border-white/55"
        style={{ transform: 'translate(-50%,-50%) perspective(300px) rotateX(60deg)' }}
      />
      <div className="absolute inset-x-0 bottom-0 h-1/3 bg-[radial-gradient(60%_80%_at_50%_120%,rgba(255,255,255,.25),transparent_70%)]" />
    </div>
  )
}

const BUILDINGS = [
  [4, 9, 70], [15, 7, 95], [25, 11, 55], [39, 6, 100], [48, 12, 75], [63, 8, 90], [74, 10, 60], [87, 7, 85], [97, 8, 65],
]

function CityScene() {
  return (
    <div className="absolute inset-0 overflow-hidden bg-gradient-to-b from-[#1a1446] via-brand-violet to-brand-pink">
      <div className="absolute top-[18%] left-[62%] aspect-square w-[12%] rounded-full bg-[#ffe6f0]/85 shadow-[0_0_4em_1em_rgba(255,200,230,.4)]" />
      <div className="absolute inset-x-0 bottom-0 h-[45%]">
        {BUILDINGS.map(([x, w, h]) => (
          <div key={x} className="absolute bottom-0 bg-screen" style={{ left: `${x - w / 2}%`, width: `${w}%`, height: `${h}%` }} />
        ))}
      </div>
    </div>
  )
}

function LiveBadge() {
  return (
    <span className="absolute top-[.9em] left-[.9em] z-10 flex items-center gap-[.45em] rounded-[.4em] bg-black/55 px-[.7em] py-[.35em] text-[.7em] font-bold tracking-[.08em]">
      <span className="size-[.6em] rounded-full bg-[#FF3B5C]" />
      EN DIRECT
    </span>
  )
}

// ─── Maquettes d'écrans (tout est en em : la maquette garde ses proportions à toutes les tailles) ──

function SideNav({ active, counts }: { active: 'TV' | 'Films'; counts: [string, string, [string, string][]] }) {
  const [all, favs, cats] = counts
  return (
    <div className="flex flex-col gap-[.35em] border-r border-white/[.08] px-[1em] py-[1.4em]">
      <div className="mx-auto mb-[1.2em] flex overflow-hidden rounded-full border border-white/15 text-[1.05em] font-semibold">
        {['TV', 'Films', 'Séries'].map(t => (
          <span key={t} className={`border-l border-white/15 px-[1.05em] py-[.5em] first:border-l-0 ${t === active ? 'bg-white/[.12]' : ''}`}>
            {t}
          </span>
        ))}
      </div>
      <div className="flex items-center gap-[.8em] rounded-[.7em] bg-brand-violet/30 px-[.9em] py-[.7em]">
        <i className="size-[1.1em] rounded-[.25em] bg-white/75" />
        Tout<small className="ml-auto text-[.85em] text-white/40">{all}</small>
      </div>
      <div className="flex items-center gap-[.8em] px-[.9em] py-[.7em] text-white/90">
        <span className="text-[1.05em] leading-none">★</span>Favoris<small className="ml-auto text-[.85em] text-white/40">{favs}</small>
      </div>
      <div className="flex items-center gap-[.8em] px-[.9em] py-[.7em] text-white/90">
        <i className="size-[1.1em] rounded-full border-[.15em] border-white/75" />
        Récents
      </div>
      <div className="mx-[.9em] mt-[1em] mb-[.3em] text-[.75em] font-semibold tracking-[.1em] text-white/40">CATÉGORIES</div>
      {cats.map(([name, n]) => (
        <div key={name} className="flex items-center px-[.9em] py-[.7em] text-white/90">
          {name}
          <small className="ml-auto text-[.85em] text-white/40">{n}</small>
        </div>
      ))}
    </div>
  )
}

function TvHomeScreen() {
  const sport = CHANNELS[1]
  return (
    <div className="@container relative text-left aspect-video overflow-hidden rounded-[8px] bg-screen md:rounded-[14px]">
      <div className="absolute inset-0 grid grid-cols-[28%_40%_32%] text-[1.5cqw] leading-[1.3]">
        <div className="flex flex-col">
          <SideNav active="TV" counts={['248', '12', [['Info', '18'], ['Sport', '24'], ['Cinéma', '36'], ['Jeunesse', '12']]]} />
          <div className="mt-auto flex items-center gap-[.7em] border-t border-r border-white/[.08] px-[1.6em] py-[.8em] text-[.85em]">
            <img src={`${BASE}icon.png`} alt="" className="size-[2.2em] rounded-[.5em]" />
            <div>
              Mon fournisseur<small className="block text-white/40">Abonnement actif</small>
            </div>
          </div>
        </div>
        <div className="flex flex-col gap-[.3em] border-r border-white/[.08] px-[1em] py-[1.4em]">
          <div className="mb-[.6em] flex items-center gap-[.7em] rounded-[.8em] bg-white/[.06] px-[1em] py-[.75em] text-white/40">
            <i className="size-[.9em] rounded-full border-[.16em] border-white/40" />
            Rechercher…
          </div>
          <div className="mx-[.3em] mb-[.4em] text-[.85em] text-white/40">248 chaînes</div>
          {CHANNELS.map(c => (
            <div
              key={c.code}
              className={`flex items-center gap-[.9em] rounded-[.8em] px-[.6em] py-[.55em] ${c === sport ? 'bg-[#4733D6] ring-[.12em] ring-white/20' : ''}`}
            >
              <ChannelLogo c={c} className="h-[2.3em] w-[3.4em] text-[.8em]" />
              <div>
                <b className="block font-medium">{c.name}</b>
                <span className="text-[.78em] text-white/55">{c.now}</span>
              </div>
            </div>
          ))}
        </div>
        <div className="flex flex-col">
          <div className="relative flex-1">
            <SportScene />
            <LiveBadge />
          </div>
          <div className="flex items-center gap-[.8em] bg-[#15151F] p-[1em]">
            <ChannelLogo c={sport} className="h-[2.6em] w-[3.6em] text-[.8em]" />
            <div className="min-w-0 flex-1">
              <b className="block text-[1.05em]">Sport 1 HD</b>
              <small className="block text-[.8em] text-white/65">20:00 – 22:00 · Match en direct</small>
              <ProgressBar value={62} className="my-[.35em]" />
              <small className="block text-[.8em] text-white/65">Ensuite : Le débrief</small>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

type PhoneRow = { c: Channel; title: string; sub: string }

function PhoneScreen({ heading, chips, rows, playing, tab, scene }: {
  heading: string
  chips: string[]
  rows: PhoneRow[]
  playing: [string, string]
  tab: 'TV' | 'Films' | 'Séries'
  scene: ReactNode
}) {
  return (
    <div className="@container relative text-left aspect-[9/19.5] overflow-hidden rounded-[10%/4.6%] bg-screen">
      <div className="absolute inset-0 flex flex-col text-[4.2cqw] leading-[1.3]">
        <div className="flex justify-between bg-[#171828] px-[1.6em] pt-[1.1em] pb-[.4em] text-[.75em] font-semibold">
          <span>20:41</span>
          <span className="tracking-[.1em]">●●● ▮</span>
        </div>
        <div className="flex items-center justify-between bg-[#171828] px-[1.1em] pt-[.7em] pb-[1em] text-[1.25em] font-medium">
          {heading} ▾<i className="size-[.8em] rounded-full border-[.13em] border-white" />
        </div>
        <div className="flex gap-[.45em] overflow-hidden px-[1em] pt-[.9em] pb-[.3em] text-[.72em]">
          {chips.map((c, i) => (
            <Chip key={c} on={i === 0}>
              {c}
            </Chip>
          ))}
        </div>
        <div className="flex flex-1 flex-col gap-[.2em] overflow-hidden px-[.6em] py-[.4em]">
          {rows.map(r => (
            <div key={r.title} className="flex items-center gap-[.8em] px-[.5em] py-[.55em]">
              <ChannelLogo c={r.c} className="h-[2.3em] w-[3.4em] text-[.72em]" />
              <div>
                <b className="block font-medium">{r.title}</b>
                <small className="text-[.8em] text-white/40">{r.sub}</small>
              </div>
            </div>
          ))}
        </div>
        <div className="mx-[.6em] mb-[.6em] flex items-center gap-[.7em] rounded-[.8em] bg-[#1C1C2B] p-[.55em]">
          <div className="relative aspect-video w-[4.2em] shrink-0 overflow-hidden rounded-[.4em] text-[.5em]">{scene}</div>
          <div>
            <b className="block text-[.85em]">{playing[0]}</b>
            <small className="text-[.7em] text-white/65">{playing[1]}</small>
          </div>
          <span className={`ml-auto grid size-[1.9em] shrink-0 place-items-center rounded-full ${GRADIENT}`}>
            <span className="h-[.6em] w-[.5em] border-x-[.17em] border-white" />
          </span>
        </div>
        <div className="grid grid-cols-3 bg-[#1A1A26] pt-[.7em] pb-[1.2em] text-center text-[.72em] font-semibold text-white/65">
          {(['TV', 'Films', 'Séries'] as const).map(t => (
            <span key={t} className={t === tab ? 'text-white' : ''}>
              <span className={`mx-auto mb-[.35em] block h-[1.2em] w-[1.9em] rounded-[.3em] ${t === tab ? 'bg-white ring-[.5em] ring-white/[.12]' : 'bg-white/55'}`} />
              {t}
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}

function PhoneFrame({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={`rounded-[13%/6%] bg-gradient-to-b from-[#2a2a3c] to-[#15151f] p-[3.2%] shadow-[0_0_0_1px_rgba(255,255,255,.14),0_40px_80px_-20px_rgba(0,0,0,.8),0_30px_90px_-30px_rgba(237,64,158,.45)] ${className}`}
    >
      {children}
    </div>
  )
}

function TvFrame({ children }: { children: ReactNode }) {
  return (
    <>
      <div className="relative rounded-xl bg-gradient-to-b from-[#26263a] to-[#14141f] p-[5px] shadow-[0_0_0_1px_rgba(255,255,255,.14),0_60px_140px_-30px_rgba(92,69,250,.55)] md:rounded-[22px] md:p-2.5">
        {children}
      </div>
      <div className="mx-auto h-2.5 w-[26%] rounded-b-[14px] bg-gradient-to-b from-[#20202e] to-[#111119] md:h-3.5" />
    </>
  )
}

function ZapScreen() {
  const cinema = CHANNELS[2]
  return (
    <div className="@container relative text-left aspect-video overflow-hidden rounded-[8px] bg-screen md:rounded-[14px]">
      <div className="absolute inset-0 text-[1.5cqw] leading-[1.3]">
        <CityScene />
        <div className={`absolute top-[2.2em] left-[2.2em] z-10 rounded-[.8em] px-[1.4em] py-[.7em] text-[1.5em] font-bold shadow-[0_1em_3em_-1em_rgba(0,0,0,.6)] ${GRADIENT}`}>
          Cinéma+
        </div>
        <div className="absolute top-[2.2em] right-[2.2em] z-10 flex flex-col items-center gap-[.4em]">
          {['↑', '↓'].map(k => (
            <span key={k} className="grid size-[2.6em] place-items-center rounded-[.6em] border border-white/15 bg-white/[.12] font-bold">
              {k}
            </span>
          ))}
          <small className="text-[.75em] text-white/65">Zapper</small>
        </div>
        <div className="absolute inset-x-[2.2em] bottom-[2em] z-10 flex items-center gap-[1.4em] rounded-[1.2em] border border-white/15 bg-[#0E0E16]/80 px-[1.4em] py-[1.2em] backdrop-blur-md">
          <ChannelLogo c={cinema} className="h-[3.4em] w-[5em]" />
          <div className="min-w-0 flex-1">
            <b className="text-[1.25em]">Nuit blanche</b>
            <small className="block text-white/65">21:00 – 22:50 · Ensuite : Court-métrage</small>
            <ProgressBar value={38} className="mt-[.35em]" />
          </div>
          <div className="flex shrink-0 gap-[.6em] text-[.8em]">
            <Chip>Audio : VF</Chip>
            <Chip>ST : Aucun</Chip>
          </div>
        </div>
      </div>
    </div>
  )
}

function FilmsScreen() {
  return (
    <div className="@container relative text-left aspect-[16/10] overflow-hidden rounded-[6px] bg-screen">
      <div className="absolute inset-0 grid grid-cols-[24%_1fr] text-[1.45cqw] leading-[1.3]">
        <SideNav active="Films" counts={['1 240', '8', [['Nouveautés', '64'], ['Action', '210'], ['Comédie', '185'], ['Animation', '92']]]} />
        <div className="flex min-w-0 flex-col gap-[1em] p-[1.4em]">
          <div className="flex items-center gap-[.7em] rounded-[.8em] bg-white/[.06] px-[1em] py-[.75em] text-white/40">
            <i className="size-[.9em] rounded-full border-[.16em] border-white/40" />
            Rechercher un film…
          </div>
          <div className="flex flex-wrap gap-[.6em] text-[.85em]">
            <Chip on>Pays : France ▾</Chip>
            <Chip>Genre : Tous ▾</Chip>
            <Chip>Année : Toutes ▾</Chip>
            <Chip>Trier : Récents ▾</Chip>
          </div>
          <div className="grid grid-cols-5 gap-[.9em]">
            {POSTERS.map((p, i) => (
              <div
                key={p.title}
                className={`relative flex aspect-[2/3] items-end overflow-hidden rounded-[.6em] p-[.6em] text-[.85em] leading-[1.1] font-bold ${
                  i === 0 ? 'shadow-[0_0_0_.2em_#fff,0_0_2em_rgba(92,69,250,.8)]' : 'shadow-[inset_0_0_0_1px_rgba(255,255,255,.08)]'
                }`}
                style={{ background: `linear-gradient(160deg, ${p.from}, ${p.to})` }}
              >
                <div className="absolute inset-0 bg-gradient-to-b from-transparent from-45% to-black/70" />
                <span className="relative">
                  {p.title}
                  <small className="mt-[.2em] block text-[.8em] font-medium text-white/70">{p.year}</small>
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}

// ─── Sections ───────────────────────────────────────────────────────────────

function Nav() {
  const { scrollY } = useScroll()
  const [scrolled, setScrolled] = useState(false)
  useMotionValueEvent(scrollY, 'change', y => setScrolled(y > 8))
  const links = [
    ['#fonctionnalites', 'Fonctionnalités'],
    ['#ecrans', 'Écrans'],
    ['#comment', 'Comment ça marche'],
    ['#faq', 'FAQ'],
  ]
  return (
    <header
      className={`sticky top-0 z-50 border-b bg-night/70 backdrop-blur-lg backdrop-saturate-[1.8] transition-colors duration-300 ${
        scrolled ? 'border-white/[.08]' : 'border-transparent'
      }`}
    >
      <div className="mx-auto flex h-16 max-w-[1200px] items-center gap-8 px-4 md:px-6">
        <a href="#top" className="flex items-center gap-2.5 text-[19px] font-bold tracking-tight">
          <img src={`${BASE}icon.png`} alt="" className="size-[30px] rounded-lg" />
          ElioTV
        </a>
        <nav aria-label="Sections" className="ml-auto hidden gap-7 text-[15px] text-white/65 md:flex">
          {links.map(([href, label]) => (
            <a key={href} href={href} className="transition-colors hover:text-white">
              {label}
            </a>
          ))}
        </nav>
        <GhostButton href="#telecharger" className="ml-auto !h-[38px] !px-[18px] !text-sm md:ml-0">
          Télécharger
        </GhostButton>
      </div>
    </header>
  )
}

function Hero({ onVideo }: { onVideo: () => void }) {
  const device = useDevice()
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const phoneY = useTransform(scrollYProgress, [0, 1], [60, -60])
  const tvScale = useTransform(scrollYProgress, [0, 0.5], [0.94, 1])

  return (
    <section className="relative overflow-x-clip pt-16 text-center md:pt-24">
      <Halo className="-top-[260px] -left-[260px] size-[720px] bg-brand-violet/45" />
      <Halo className="top-[280px] -right-[240px] size-[600px] bg-brand-pink/30" />

      <motion.div variants={stagger} initial="hidden" animate="show" className="mx-auto max-w-[1200px] px-4 md:px-6">
        <motion.span
          variants={fadeUp}
          className="inline-flex items-center gap-2.5 rounded-full border border-white/15 bg-white/[.03] py-1.5 pr-4 pl-2 text-sm text-white/65"
        >
          <b className={`rounded-full px-2.5 py-[3px] text-xs font-semibold text-white ${GRADIENT}`}>Nouveau</b>
          Gratuit · Sans publicité · Version 1.0
        </motion.span>
        <motion.h1 variants={fadeUp} className="mx-auto mt-7 text-[clamp(52px,9.5vw,112px)] leading-[.98] font-bold tracking-[-0.045em]">
          Ta télé,
          <br />
          <span className={GRADIENT_TEXT}>simplement.</span>
        </motion.h1>
        <motion.p variants={fadeUp} className="mx-auto mt-7 max-w-[640px] text-[clamp(18px,2vw,21px)] text-white/65">
          Le lecteur IPTV élégant et ultra-rapide. Connecte ton abonnement Xtream ou M3U, et retrouve tes chaînes, films et séries
          sur tous tes écrans.
        </motion.p>
        <motion.div variants={fadeUp} className="mt-10 flex flex-col justify-center gap-3.5 sm:flex-row">
          <PrimaryButton href={device.href}>
            <DownloadIcon />
            {device.label}
          </PrimaryButton>
          <GhostButton onClick={onVideo}>
            <svg viewBox="0 0 24 24" className="size-[18px]" fill="currentColor">
              <path d="M8 5.5v13l11-6.5z" />
            </svg>
            Voir la vidéo
          </GhostButton>
        </motion.div>
        <motion.p variants={fadeUp} className="mt-5 text-sm text-white/40">
          Android · Android TV · Fire TV · Windows · Mac
        </motion.p>
      </motion.div>

      <motion.div
        ref={ref}
        initial={{ opacity: 0, y: 60 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 1.1, delay: 0.45, ease: [0.2, 0.8, 0.2, 1] }}
        className="relative mx-auto mt-14 max-w-[1080px] px-2 md:mt-[88px] md:px-6"
        aria-label="Aperçu d'ElioTV sur une télévision et un téléphone"
      >
        <motion.div style={{ scale: tvScale }}>
          <TvFrame>
            <TvHomeScreen />
          </TvFrame>
        </motion.div>
        <motion.div style={{ y: phoneY }} className="absolute right-0 -bottom-9 w-[30%] md:-bottom-14 md:w-[21%] xl:-right-[90px]">
          <PhoneFrame>
            <PhoneScreen
              heading="TV en direct"
              chips={['Tout', 'Info', 'Sport', 'Cinéma']}
              rows={CHANNELS.map((c, i) => ({ c, title: c.name, sub: String(i + 1) }))}
              playing={['Sport 1 HD', 'Match en direct']}
              tab="TV"
              scene={<SportScene />}
            />
          </PhoneFrame>
        </motion.div>
      </motion.div>
    </section>
  )
}

const PLATFORMS: [string, ReactNode, boolean?][] = [
  ['Android', <><rect x="6" y="2.5" width="12" height="19" rx="2.5" /><path d="M10.5 18.5h3" /></>],
  ['Android TV', <><rect x="2.5" y="4" width="19" height="13" rx="2" /><path d="M8 20.5h8" /></>],
  ['Fire TV Stick', <><rect x="3" y="9" width="14" height="6" rx="1.5" /><path d="M17 12h4" /></>],
  ['Windows', <><rect x="2.5" y="3.5" width="19" height="13" rx="1.5" /><path d="M9 20.5h6M12 16.5v4" /></>],
  ['Mac', <><rect x="4" y="4.5" width="16" height="11" rx="1.5" /><path d="M2 19.5h20" /></>],
  ['iPhone & iPad', <><rect x="4.5" y="2.5" width="15" height="19" rx="2.5" /><path d="M11 18.5h2" /></>, true],
]

function Platforms() {
  return (
    <section className="pt-24 md:pt-[120px]">
      <motion.div variants={stagger} {...inView} className="mx-auto max-w-[1200px] px-4 md:px-6">
        <motion.p variants={fadeUp} className="mb-7 text-center text-sm font-semibold tracking-[.08em] text-white/40 uppercase">
          Un seul lecteur, tous tes écrans
        </motion.p>
        <div className="flex flex-wrap justify-center gap-x-[26px] gap-y-3.5 md:gap-x-11">
          {PLATFORMS.map(([name, icon, soon]) => (
            <motion.span key={name} variants={fadeUp} className={`flex items-center gap-2.5 text-base font-medium ${soon ? 'text-white/40' : 'text-white/70'}`}>
              <svg viewBox="0 0 24 24" className="size-[22px]" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                {icon}
              </svg>
              {name}
              {soon && <em className="rounded-full border border-white/15 px-2 py-0.5 text-xs not-italic">Bientôt</em>}
            </motion.span>
          ))}
        </div>
      </motion.div>
    </section>
  )
}

function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <motion.article
      variants={popIn}
      whileHover={{ y: -4, borderColor: 'rgba(255,255,255,.16)' }}
      transition={{ type: 'spring', stiffness: 300, damping: 24 }}
      className={`relative flex flex-col overflow-hidden rounded-3xl border border-white/[.08] bg-gradient-to-b from-white/[.045] to-white/[.015] p-6 md:p-[30px] ${className}`}
    >
      {children}
    </motion.article>
  )
}

function CardTitle({ children, big = false }: { children: ReactNode; big?: boolean }) {
  return <h3 className={`mb-2.5 leading-[1.04] font-bold tracking-[-0.03em] ${big ? 'text-[clamp(30px,3.2vw,40px)]' : 'text-[26px]'}`}>{children}</h3>
}

function CardText({ children }: { children: ReactNode }) {
  return <p className="max-w-[34ch] text-base text-white/65">{children}</p>
}

function Waveform() {
  return (
    <div aria-hidden className="flex h-[110px] items-center gap-[5px]">
      {Array.from({ length: 32 }, (_, i) => (
        <motion.i
          key={i}
          className={`flex-1 origin-center rounded ${GRADIENT}`}
          style={{ height: `${30 + Math.round(70 * Math.abs(Math.sin(i * 0.7)))}%` }}
          animate={{ scaleY: [0.35, 1, 0.35] }}
          transition={{ duration: 1.6, repeat: Infinity, ease: 'easeInOut', delay: (i % 16) * 0.09 }}
        />
      ))}
    </div>
  )
}

function ZapDemo() {
  const list = [CHANNELS[0], CHANNELS[1], CHANNELS[2], CHANNELS[0]]
  return (
    <div aria-hidden className="flex items-center gap-5">
      <div className="grid gap-2">
        <span className="grid size-11 place-items-center rounded-xl border border-white/15 bg-white/[.12] text-lg font-bold">↑</span>
        <motion.span
          className="grid size-11 place-items-center rounded-xl border border-white/15 text-lg font-bold"
          animate={{ backgroundColor: ['rgba(255,255,255,.12)', 'rgba(92,69,250,1)', 'rgba(255,255,255,.12)'] }}
          transition={{ duration: 3, times: [0.3, 0.38, 0.5], repeat: Infinity }}
        >
          ↓
        </motion.span>
      </div>
      <div className="relative h-[120px] flex-1 overflow-hidden rounded-2xl border border-white/[.08] bg-black/20">
        <motion.div
          className="absolute inset-0"
          animate={{ y: [0, 0, -120, -120, -240, -240, -360] }}
          transition={{ duration: 9, times: [0, 0.28, 0.33, 0.61, 0.66, 0.95, 1], repeat: Infinity, ease: [0.7, 0, 0.2, 1] }}
        >
          {list.map((c, i) => (
            <div key={i} className="flex h-[120px] items-center gap-3.5 px-[18px]">
              <ChannelLogo c={c} className="h-[38px] w-14 rounded-[9px] text-[13px]" />
              <span>
                <b className="block text-base">{c.name}</b>
                <small className="text-[13px] text-white/65">{c.now}</small>
              </span>
            </div>
          ))}
        </motion.div>
      </div>
    </div>
  )
}

function SearchDemo() {
  const word = 'sport'
  const [n, setN] = useState(0)
  useEffect(() => {
    // Tape le mot lettre par lettre, marque une pause, puis recommence.
    const id = setInterval(() => setN(v => (v + 1) % (word.length + 6)), 260)
    return () => clearInterval(id)
  }, [])
  return (
    <div aria-hidden>
      <div className="flex items-center gap-2.5 rounded-[14px] border border-white/[.08] bg-black/25 px-3.5 py-3 text-[15px]">
        <i className="size-[13px] shrink-0 rounded-full border-2 border-white/40" />
        <span>{word.slice(0, Math.min(n, word.length))}</span>
        <motion.span className="-ml-2 h-[1.1em] w-0.5 bg-brand-pink" animate={{ opacity: [1, 0] }} transition={{ duration: 0.6, repeat: Infinity, repeatType: 'reverse' }} />
      </div>
      <div className="mt-2.5 grid gap-1.5 pl-1 text-sm text-white/65">
        {['Sport 1 HD', 'Sport 2', 'Sport Extrême'].map((r, i) => (
          <motion.span key={r} animate={{ opacity: n >= 3 ? 1 : 0.25 }} transition={{ delay: i * 0.05 }}>
            {r}
          </motion.span>
        ))}
      </div>
    </div>
  )
}

function Features() {
  return (
    <section id="fonctionnalites" className="pt-24 md:pt-40">
      <div className="mx-auto max-w-[1200px] px-4 md:px-6">
        <SectionHead
          eyebrow="Fonctionnalités"
          title={
            <>
              Tout ce qu'il faut.
              <br />
              <span className={GRADIENT_TEXT}>Rien de plus.</span>
            </>
          }
          text="Une interface pensée pour aller droit au but, de la télécommande au clavier."
        />

        <motion.div
          variants={stagger}
          {...inView}
          className="grid auto-rows-[minmax(250px,auto)] grid-cols-1 gap-[18px] md:grid-cols-2 lg:grid-cols-4"
        >
          <Card className="md:col-span-2 lg:row-span-2">
            <div aria-hidden className="absolute -right-1/4 -bottom-[30%] aspect-square w-[70%] bg-[radial-gradient(circle,rgba(92,69,250,.35),transparent_65%)]" />
            <CardTitle big>Lit vraiment tout.</CardTitle>
            <CardText>
              Le moteur mpv ouvre les flux les plus exigeants, en direct comme à la demande. Choisis ta langue et tes sous-titres en un
              clic.
            </CardText>
            <div className="relative mt-auto pt-7">
              <Waveform />
              <div className="mt-6 flex flex-wrap gap-2 text-[13px] text-white/85">
                {['HLS', 'MPEG-TS', 'MKV', 'HEVC', 'H.264', 'AC3', 'DTS'].map(f => (
                  <Chip key={f}>{f}</Chip>
                ))}
              </div>
              <div className="mt-[18px] grid grid-cols-2 gap-2.5">
                {[
                  ['Audio', 'Français · 5.1'],
                  ['Sous-titres', 'Anglais'],
                ].map(([k, v]) => (
                  <div key={k} className="rounded-[14px] border border-white/[.08] bg-black/20 px-3.5 py-3 text-sm text-white/65">
                    {k}
                    <b className="block text-[15px] font-semibold text-white">{v}</b>
                  </div>
                ))}
              </div>
            </div>
          </Card>

          <Card className="md:col-span-2">
            <CardTitle>Zappe d'un geste.</CardTitle>
            <CardText>En plein écran, ↑ ↓ change de chaîne. À la télécommande comme au clavier.</CardText>
            <div className="mt-auto pt-7">
              <ZapDemo />
            </div>
          </Card>

          <Card>
            <CardTitle>Trié pour toi.</CardTitle>
            <CardText>Par pays, genre et année.</CardText>
            <div aria-hidden className="mt-auto flex flex-wrap gap-2 pt-7">
              {['FR', 'BE', 'CH', 'CA', 'MA', 'UK', 'Comédie', '2024'].map((p, i) => (
                <span
                  key={p}
                  className={`rounded-full border px-3 py-[7px] text-[13px] font-semibold ${i === 0 ? `border-transparent ${GRADIENT}` : 'border-white/[.08] bg-white/[.06]'}`}
                >
                  {p}
                </span>
              ))}
            </div>
          </Card>

          <Card>
            <CardTitle>Le guide TV.</CardTitle>
            <CardText>Ce qui passe, et ce qui suit.</CardText>
            <div aria-hidden className="mt-auto grid gap-2.5 pt-7 text-sm">
              <div className="rounded-xl border border-white/[.08] bg-black/25 px-3 py-2.5">
                <small className="text-white/40">Maintenant · 20:00</small>
                <b className="block text-[15px]">Match en direct</b>
                <ProgressBar value={62} className="mt-2 !h-1" />
              </div>
              <div className="rounded-xl border border-white/[.08] bg-black/25 px-3 py-2.5">
                <small className="text-white/40">Ensuite · 22:00</small>
                <b className="block text-[15px]">Le débrief</b>
              </div>
            </div>
          </Card>

          <Card className="md:col-span-1 lg:col-span-2">
            <CardTitle>Recherche éclair.</CardTitle>
            <CardText>Trois lettres suffisent.</CardText>
            <div className="mt-auto pt-7">
              <SearchDemo />
            </div>
          </Card>

          <Card className="md:col-span-1 lg:col-span-2">
            <CardTitle>Favoris et récents.</CardTitle>
            <CardText>Tes chaînes préférées, toujours à portée.</CardText>
            <div aria-hidden className="mt-auto flex gap-2.5 pt-7">
              {[CHANNELS[1], CHANNELS[2], CHANNELS[0]].map((c, i) => (
                <motion.span
                  key={c.code}
                  className={`relative grid size-11 place-items-center rounded-xl text-xs font-extrabold ${c.color}`}
                  animate={{ y: [0, -6, 0] }}
                  transition={{ duration: 2.4, repeat: Infinity, delay: i * 0.25, ease: 'easeInOut' }}
                >
                  {c.code}
                  <span className="absolute -top-2 -right-1.5 text-sm text-[#FFD25E] drop-shadow">★</span>
                </motion.span>
              ))}
            </div>
          </Card>
        </motion.div>
      </div>
    </section>
  )
}

const TABS = [
  {
    id: 'tv',
    label: 'TV',
    caption: (
      <>
        <b className="font-semibold text-white">Sur la TV</b>, tout se fait à la télécommande : ↑ ↓ pour zapper, ← → pour avancer ou
        reculer, OK pour mettre en pause.
      </>
    ),
  },
  {
    id: 'pc',
    label: 'Ordinateur',
    caption: (
      <>
        <b className="font-semibold text-white">Sur ordinateur</b>, filtre tes films par pays, genre et année, puis trie-les comme tu
        veux. Ton filtre de langue est conservé.
      </>
    ),
  },
  {
    id: 'mob',
    label: 'Mobile',
    caption: (
      <>
        <b className="font-semibold text-white">Sur mobile</b>, tout tient dans la main : la lecture continue en bas de l'écran
        pendant que tu parcours le catalogue.
      </>
    ),
  },
] as const

const SERIES: PhoneRow[] = [
  { c: CHANNELS[4], title: 'Les Veilleurs', sub: '3 saisons' },
  { c: CHANNELS[2], title: 'Rive gauche', sub: '2 saisons' },
  { c: CHANNELS[5], title: 'Cap Nord', sub: '1 saison' },
  { c: CHANNELS[3], title: "L'Atelier", sub: '4 saisons' },
  { c: CHANNELS[0], title: 'Ligne 7', sub: '2 saisons' },
].map((r, i) => ({ ...r, c: { ...r.c, code: `S${i + 1}` } }))

function Showcase() {
  const [tab, setTab] = useState<(typeof TABS)[number]['id']>('tv')
  const current = TABS.find(t => t.id === tab)!
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([])

  function onKey(e: React.KeyboardEvent, i: number) {
    const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0
    if (!d) return
    const n = (i + d + TABS.length) % TABS.length
    setTab(TABS[n].id)
    tabRefs.current[n]?.focus()
  }

  return (
    <section id="ecrans" className="relative overflow-x-clip pt-24 md:pt-40">
      <Halo className="top-[300px] left-1/2 size-[700px] -translate-x-1/2 bg-brand-violet/25" />
      <div className="mx-auto max-w-[1200px] px-4 md:px-6">
        <SectionHead
          eyebrow="Écrans"
          title={
            <>
              Pensé pour
              <br />
              <span className={GRADIENT_TEXT}>chaque écran.</span>
            </>
          }
        />

        <Reveal className="mb-12 text-center">
          <div role="tablist" aria-label="Choisir un écran" className="inline-flex gap-1 rounded-full border border-white/15 bg-white/[.03] p-[5px]">
            {TABS.map((t, i) => (
              <button
                key={t.id}
                ref={el => {
                  tabRefs.current[i] = el
                }}
                role="tab"
                aria-selected={tab === t.id}
                tabIndex={tab === t.id ? 0 : -1}
                onClick={() => setTab(t.id)}
                onKeyDown={e => onKey(e, i)}
                className={`relative h-[42px] rounded-full px-4 text-sm font-semibold transition-colors md:px-[22px] md:text-[15px] ${
                  tab === t.id ? 'text-white' : 'text-white/65 hover:text-white'
                }`}
              >
                {tab === t.id && (
                  <motion.span layoutId="tab-pill" className="absolute inset-0 rounded-full bg-white/[.12]" transition={{ type: 'spring', stiffness: 400, damping: 32 }} />
                )}
                <span className="relative">{t.label}</span>
              </button>
            ))}
          </div>
        </Reveal>

        <Reveal>
          <div role="tabpanel" aria-label={current.label} className="flex flex-col items-center">
            <AnimatePresence mode="wait">
              <motion.div
                key={tab}
                initial={{ opacity: 0, y: 16, scale: 0.985 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: -10, scale: 0.985 }}
                transition={{ duration: 0.45, ease: [0.2, 0.8, 0.2, 1] }}
                className="flex w-full flex-col items-center"
              >
                {tab === 'tv' && (
                  <div className="w-full max-w-[980px]">
                    <TvFrame>
                      <ZapScreen />
                    </TvFrame>
                  </div>
                )}
                {tab === 'pc' && (
                  <div className="w-full max-w-[920px]">
                    <div className="rounded-t-xl bg-gradient-to-b from-[#2a2a3c] to-[#1a1a26] px-1.5 pt-1.5 pb-2 shadow-[0_0_0_1px_rgba(255,255,255,.14),0_50px_120px_-30px_rgba(92,69,250,.5)] md:rounded-t-[18px] md:px-3 md:pt-3 md:pb-3.5">
                      <FilmsScreen />
                    </div>
                    <div className="relative -mx-[6%] h-2.5 rounded-b-[22px] bg-gradient-to-b from-[#3a3a4e] to-[#1b1b27] md:h-4">
                      <div className="absolute inset-x-[42%] top-0 h-1.5 rounded-b-lg bg-[#15151f]" />
                    </div>
                  </div>
                )}
                {tab === 'mob' && (
                  <PhoneFrame className="w-[300px] max-w-[72vw]">
                    <PhoneScreen
                      heading="Séries"
                      chips={['France', 'Drame', '2024']}
                      rows={SERIES}
                      playing={['Les Veilleurs', 'S2 · É4']}
                      tab="Séries"
                      scene={<CityScene />}
                    />
                  </PhoneFrame>
                )}
                <p className="mt-9 max-w-[560px] text-center text-base text-white/65">{current.caption}</p>
              </motion.div>
            </AnimatePresence>
          </div>
        </Reveal>
      </div>
    </section>
  )
}

function Steps() {
  const steps = [
    ['Télécharge', 'ElioTV pour ton appareil, gratuitement.'],
    ['Connecte', 'Ton fournisseur : codes Xtream, lien ou fichier M3U.'],
    ['Regarde.', "C'est tout. Vraiment."],
  ]
  return (
    <section id="comment" className="pt-24 md:pt-40">
      <div className="mx-auto max-w-[1200px] px-4 md:px-6">
        <SectionHead
          eyebrow="Comment ça marche"
          title={
            <>
              Prêt en <span className={GRADIENT_TEXT}>30 secondes.</span>
            </>
          }
        />
        <motion.div variants={stagger} {...inView} className="relative grid grid-cols-1 gap-11 md:grid-cols-3 md:gap-10">
          {/* Ligne qui relie les étapes : verticale sur mobile, horizontale sur ordinateur. */}
          <motion.div
            aria-hidden
            variants={{ hidden: { scaleX: 0, scaleY: 0 }, show: { scaleX: 1, scaleY: 1, transition: { duration: 1.2, ease: [0.2, 0.8, 0.2, 1] } } }}
            className="absolute top-7 bottom-7 left-1/2 w-px origin-top bg-gradient-to-b from-transparent via-brand-violet to-transparent md:inset-x-[16%] md:top-7 md:bottom-auto md:h-px md:w-auto md:origin-left md:bg-gradient-to-r md:via-brand-pink"
          />
          {steps.map(([title, text], i) => (
            <motion.div key={title} variants={fadeUp} className="relative text-center">
              <div
                className={`relative mx-auto mb-[26px] grid size-14 place-items-center rounded-full text-xl font-bold ${
                  i === 2 ? GRADIENT : 'border border-white/15 bg-night'
                }`}
              >
                {i + 1}
              </div>
              <h3 className="mb-2.5 text-[26px] font-bold tracking-[-0.03em]">{title}</h3>
              <p className="mx-auto max-w-[30ch] text-base text-white/65">{text}</p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

function Trust() {
  const items: [string, string, ReactNode][] = [
    [
      'Aucune chaîne fournie',
      "ElioTV lit l'abonnement que tu as déjà chez ton fournisseur IPTV. Rien de plus.",
      <><rect x="3" y="5" width="18" height="12" rx="2" /><path d="M8 21h8M5 3l14 16" /></>,
    ],
    [
      '100 % gratuit',
      'Ni publicité, ni abonnement, ni compte à créer. Le code source est public.',
      <path d="M20 12v8H4v-8M2 7h20v5H2zM12 22V7M12 7H8a2.5 2.5 0 1 1 0-5c3 0 4 5 4 5zM12 7h4a2.5 2.5 0 1 0 0-5c-3 0-4 5-4 5z" />,
    ],
    [
      'Tes codes restent chez toi',
      "Ils sont enregistrés uniquement sur ton appareil et ne sont envoyés qu'à ton fournisseur.",
      <><rect x="4" y="10" width="16" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3" /></>,
    ],
  ]
  return (
    <section className="pt-24 md:pt-40">
      <div className="mx-auto max-w-[1200px] px-4 md:px-6">
        <SectionHead
          eyebrow="Transparence"
          title={
            <>
              Un lecteur. <span className={GRADIENT_TEXT}>Point.</span>
            </>
          }
        />
        <motion.div variants={stagger} {...inView} className="grid grid-cols-1 gap-[18px] md:grid-cols-3">
          {items.map(([title, text, icon]) => (
            <Card key={title}>
              <div className="mb-[22px] grid size-12 place-items-center rounded-[14px] bg-brand-violet/20">
                <svg viewBox="0 0 24 24" className="size-6 stroke-[#B7AAFF]" fill="none" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
                  {icon}
                </svg>
              </div>
              <h3 className="mb-2.5 text-[22px] font-bold tracking-[-0.03em]">{title}</h3>
              <CardText>{text}</CardText>
            </Card>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

function Faq() {
  const [open, setOpen] = useState<number | null>(null)
  return (
    <section id="faq" className="pt-24 md:pt-40">
      <div className="mx-auto max-w-[1200px] px-4 md:px-6">
        <SectionHead eyebrow="FAQ" title="Questions fréquentes" />
        <Reveal className="mx-auto max-w-[820px]">
          {FAQ.map((item, i) => {
            const isOpen = open === i
            return (
              <div key={item.q} className="border-b border-white/[.08]">
                <button
                  type="button"
                  aria-expanded={isOpen}
                  onClick={() => setOpen(isOpen ? null : i)}
                  className="flex w-full items-center justify-between gap-4 py-[26px] text-left text-lg font-semibold tracking-[-0.01em] md:text-xl"
                >
                  {item.q}
                  <motion.span animate={{ rotate: isOpen ? 45 : 0 }} className="shrink-0 text-[28px] leading-none font-light text-white/65">
                    +
                  </motion.span>
                </button>
                <AnimatePresence initial={false}>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.35, ease: [0.2, 0.8, 0.2, 1] }}
                      className="overflow-hidden"
                    >
                      <div className="pb-[26px] text-[17px] text-white/65">{item.a}</div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            )
          })}
        </Reveal>
      </div>
    </section>
  )
}

function FinalCta() {
  const device = useDevice()
  const [copied, setCopied] = useState<string | null>(null)

  async function copy() {
    try {
      await navigator.clipboard.writeText(APK_URL)
      setCopied('Copié ✓')
    } catch {
      setCopied('Sélectionne le lien')
    }
    setTimeout(() => setCopied(null), 2000)
  }

  return (
    <section id="telecharger" className="pt-24 pb-10 text-center md:pt-40">
      <div className="mx-auto max-w-[1200px] px-4 md:px-6">
        <motion.div
          variants={stagger}
          {...inView}
          className="relative overflow-hidden rounded-[28px] border border-white/[.08] bg-night-2 px-[18px] pt-[72px] pb-[18px] md:rounded-[36px] md:px-7 md:pt-[110px] md:pb-14"
          style={{
            backgroundImage:
              'radial-gradient(70% 90% at 20% 0%, rgba(92,69,250,.42), transparent 60%), radial-gradient(60% 80% at 90% 100%, rgba(237,64,158,.32), transparent 60%)',
          }}
        >
          <motion.img
            variants={popIn}
            src={`${BASE}icon.png`}
            alt="Logo ElioTV"
            className="mx-auto mb-8 size-24 rounded-3xl shadow-[0_20px_60px_-10px_rgba(92,69,250,.8)]"
          />
          <motion.h2 variants={fadeUp} className="text-[clamp(44px,7vw,88px)] leading-[1.04] font-bold tracking-[-0.045em]">
            Ta télé t'attend.
          </motion.h2>
          <motion.p variants={fadeUp} className="mx-auto mt-5 mb-10 max-w-[520px] text-lg text-white/65 md:text-xl">
            Gratuit, sans publicité, prêt en 30 secondes.
          </motion.p>
          <motion.div variants={fadeUp}>
            <PrimaryButton href={device.os && device.os !== 'ios' ? device.href : '#downloads'} className="w-full sm:w-auto">
              <DownloadIcon />
              {device.os && device.os !== 'ios' ? device.label : 'Télécharger ElioTV'}
            </PrimaryButton>
          </motion.div>

          <motion.div variants={stagger} id="downloads" className="mx-auto mt-16 grid max-w-[900px] grid-cols-1 gap-3.5 text-left lg:grid-cols-3">
            {DOWNLOADS.map(d => (
              <motion.a
                key={d.os}
                variants={popIn}
                whileHover={{ y: -3 }}
                href={REL + d.file}
                className={`flex flex-col gap-1 rounded-[20px] border bg-night/55 p-[22px] transition-colors hover:bg-night/75 ${
                  device.os === d.os ? 'border-brand-violet ring-1 ring-brand-violet ring-inset' : 'border-white/15 hover:border-white/30'
                }`}
              >
                <b className="text-lg">{d.name}</b>
                <small className="text-sm text-white/40">{d.detail}</small>
                <span className="mt-3.5 text-[15px] font-semibold text-[#C9BFFF]">{d.cta} →</span>
              </motion.a>
            ))}
          </motion.div>

          <motion.div
            variants={fadeUp}
            className="mx-auto mt-3.5 flex max-w-[900px] flex-wrap items-center gap-4 rounded-[20px] border border-dashed border-white/15 px-[22px] py-5 text-left text-[15px] text-white/65"
          >
            <span>
              <b className="text-white">Fire TV / Android TV :</b> dans l'app Downloader, tape
            </span>
            <code className="min-w-[220px] flex-1 rounded-md bg-white/[.07] px-2 py-1 font-mono text-[.88em] break-all">{APK_URL}</code>
            <motion.button
              type="button"
              whileTap={{ scale: 0.95 }}
              onClick={copy}
              className="h-9 rounded-full border border-white/15 px-4 text-sm font-semibold transition-colors hover:bg-white/[.08]"
            >
              {copied ?? 'Copier'}
            </motion.button>
          </motion.div>
        </motion.div>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="mt-20 border-t border-white/[.08] pt-9 pb-12 text-sm text-white/40">
      <div className="mx-auto flex max-w-[1200px] flex-wrap items-center gap-x-8 gap-y-5 px-4 md:px-6">
        <span className="flex items-center gap-2.5 text-base font-bold text-white">
          <img src={`${BASE}icon.png`} alt="" className="size-6 rounded-md" />
          ElioTV
        </span>
        <span>ElioTV est un lecteur et ne fournit aucun contenu.</span>
        <div className="flex gap-6 md:ml-auto">
          <a href={REPO} className="hover:text-white">
            GitHub
          </a>
          <a href={`${REPO}/releases`} className="hover:text-white">
            Versions
          </a>
          <span>© 2026</span>
        </div>
      </div>
    </footer>
  )
}

function VideoModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    addEventListener('keydown', onKey)
    document.body.style.overflow = 'hidden'
    return () => {
      removeEventListener('keydown', onKey)
      document.body.style.overflow = ''
    }
  }, [open, onClose])

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          role="dialog"
          aria-modal="true"
          aria-label="Vidéo de présentation"
          className="fixed inset-0 z-[100] grid place-items-center bg-[#05050a]/80 p-4 backdrop-blur-md"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
        >
          <motion.div
            className="relative w-full max-w-[1100px]"
            initial={{ scale: 0.92, y: 20 }}
            animate={{ scale: 1, y: 0 }}
            exit={{ scale: 0.95, y: 10 }}
            transition={{ type: 'spring', stiffness: 260, damping: 26 }}
            onClick={e => e.stopPropagation()}
          >
            <button
              type="button"
              aria-label="Fermer"
              onClick={onClose}
              className="absolute -top-12 right-0 grid size-[38px] place-items-center rounded-full bg-white/[.12] text-xl hover:bg-white/20"
            >
              ✕
            </button>
            <video
              src={`${BASE}ElioTV-presentation.mp4`}
              poster={`${BASE}video-poster.jpg`}
              controls
              autoPlay
              playsInline
              className="w-full rounded-[18px] bg-black shadow-[0_40px_120px_rgba(0,0,0,.7)]"
            />
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

// ─── Page ───────────────────────────────────────────────────────────────────

export default function LandingPage() {
  const [video, setVideo] = useState(false)
  return (
    <MotionConfig reducedMotion="user">
      <div className="min-h-screen overflow-x-clip bg-night font-sans text-[17px] leading-[1.55] text-white antialiased md:text-lg">
        <Nav />
        <main id="top">
          <Hero onVideo={() => setVideo(true)} />
          <Platforms />
          <Features />
          <Showcase />
          <Steps />
          <Trust />
          <Faq />
          <FinalCta />
        </main>
        <Footer />
        <VideoModal open={video} onClose={() => setVideo(false)} />
      </div>
    </MotionConfig>
  )
}
