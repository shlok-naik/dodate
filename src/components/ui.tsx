import { AnimatePresence, motion, useDragControls, type PanInfo } from 'framer-motion'
import { useId, useState, type CSSProperties, type ReactNode } from 'react'
import { Check } from './Icons'
import { softSpring, spring } from './motion'


// Progress ring whose arc springs to the new value.
export function Ring({ size, stroke = 4, value, color = 'var(--accent)', children, label }: { size: number; stroke?: number; value: number; color?: string; children?: ReactNode; label?: string }) {
  const r = (size - stroke) / 2
  return (
    <div role="img" aria-label={label} style={{ flex: 'none', position: 'relative', width: size, height: size }}>
      <svg aria-hidden width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--alt)" strokeWidth={stroke} />
        <motion.circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round"
          initial={{ pathLength: 0 }} animate={{ pathLength: Math.max(0.0001, Math.min(1, value)), opacity: value > 0 ? 1 : 0 }} transition={softSpring} />
      </svg>
      {children && <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{children}</div>}
    </div>
  )
}

// Text that rolls vertically when its value changes.
export function Flip({ value, style }: { value: string | number; style?: CSSProperties }) {
  return (
    <span style={{ display: 'inline-flex', overflow: 'hidden', position: 'relative', verticalAlign: 'bottom', ...style }}>
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.span key={value} initial={{ y: '100%', opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: '-100%', opacity: 0 }} transition={spring}>
          {value}
        </motion.span>
      </AnimatePresence>
    </span>
  )
}

// Round checkbox: fills, draws the tick and throws a ring when completed.
export function CheckDot({ done, color }: { done: boolean; color: string }) {
  return (
    <motion.span className="check" animate={{ scale: done ? [1, 0.8, 1.12, 1] : 1 }} transition={{ duration: 0.4 }}
      style={{ boxShadow: `inset 0 0 0 2px ${done ? 'var(--accent)' : color}` }}>
      <motion.span initial={false} animate={{ scale: done ? 1 : 0, opacity: done ? 1 : 0 }} transition={spring}
        style={{ position: 'absolute', inset: 0, borderRadius: 13, background: 'var(--accent)' }} />
      <svg aria-hidden width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--on-accent)" strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" style={{ position: 'relative' }}>
        <motion.path d="M5 12.5l4.5 4.5L19 7.5" initial={false} animate={{ pathLength: done ? 1 : 0 }} transition={{ duration: 0.25, delay: done ? 0.08 : 0 }} />
      </svg>
      <AnimatePresence>
        {done && (
          <motion.span key="burst" initial={{ scale: 1, opacity: 0.5 }} animate={{ scale: 2.2, opacity: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.5 }}
            style={{ position: 'absolute', inset: 0, borderRadius: 13, boxShadow: '0 0 0 2px var(--accent)', pointerEvents: 'none' }} />
        )}
      </AnimatePresence>
    </motion.span>
  )
}

// A group of options; the selected chip's fill slides between them.
export function Chips<T extends string | number>({ options, value, onPick, height = 48, cols, render, ariaLabel }: {
  options: { v: T; label: ReactNode; aria?: string }[]; value: T | null; onPick: (v: T) => void; height?: number; cols?: number; render?: (o: { v: T; label: ReactNode }, on: boolean) => ReactNode; ariaLabel?: string
}) {
  const id = useId()
  return (
    <div role="group" aria-label={ariaLabel} style={{ display: 'grid', gridTemplateColumns: `repeat(${cols ?? options.length}, minmax(0, 1fr))`, gap: 8 }}>
      {options.map((o) => {
        const on = o.v === value
        return (
          <motion.button key={String(o.v)} className="chip" aria-pressed={on} aria-label={o.aria} onClick={() => onPick(o.v)} whileTap={{ scale: 0.94 }}
            style={{ height, borderRadius: height >= 64 ? 16 : height / 2 }}>
            {on && <motion.span layoutId={id} className="chip-on" transition={spring} />}
            <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%' }}>{render ? render(o, on) : o.label}</span>
          </motion.button>
        )
      })}
    </div>
  )
}

// Bottom sheet with spring entry and drag-down-to-dismiss.
export function Sheet({ open, onClose, children, tall, label }: { open: boolean; onClose: () => void; children: ReactNode; tall?: boolean; label: string }) {
  const controls = useDragControls()
  const end = (_: unknown, info: PanInfo) => { if (info.offset.y > 120 || info.velocity.y > 600) onClose() }
  return (
    <AnimatePresence>
      {open && (
        <motion.div key="scrim" className="scrim" aria-hidden onClick={onClose} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.25 }} />
      )}
      {open && (
        <motion.div key="sheet" role="dialog" aria-modal aria-label={label} className={'sheet' + (tall ? ' tall' : '')}
          initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }} transition={{ type: 'spring', stiffness: 420, damping: 40 }}
          drag="y" dragListener={false} dragControls={controls} dragConstraints={{ top: 0, bottom: 0 }} dragElastic={{ top: 0.05, bottom: 0.8 }} onDragEnd={end}>
          <div className="grabber" onPointerDown={(e) => controls.start(e)}><span /></div>
          {children}
        </motion.div>
      )}
    </AnimatePresence>
  )
}

export function Toast({ toast, onUndo }: { toast: { id: number; msg: string; undo?: unknown; tone?: string } | null; onUndo: () => void }) {
  return (
    <AnimatePresence>
      {toast && (
        <motion.div key={toast.id} role="status" className="toast" initial={{ y: 24, opacity: 0, scale: 0.96 }} animate={{ y: 0, opacity: 1, scale: 1 }}
          exit={{ y: 16, opacity: 0, scale: 0.98 }} transition={spring} layout>
          {toast.tone === 'done' && (
            <motion.span className="t-icon" initial={{ scale: 0, rotate: -45 }} animate={{ scale: 1, rotate: 0 }} transition={{ ...spring, delay: 0.05 }}>
              <Check size={14} />
            </motion.span>
          )}
          <span style={{ flex: 1, padding: '6px 0' }}>{toast.msg}</span>
          {toast.undo ? <button className="t-undo" onClick={onUndo}>Undo</button> : null}
        </motion.div>
      )}
    </AnimatePresence>
  )
}

const COLORS = ['var(--tint-0)', 'var(--tint-1)', 'var(--tint-2)', 'var(--tint-3)', 'var(--tint-4)', 'var(--tint-5)', 'var(--accent)', 'var(--warn-bar)']

// A one-shot confetti burst; remount with a new key to fire again.
export function Confetti({ count = 60 }: { count?: number }) {
  const [pieces] = useState(() => Array.from({ length: count }, (_, i) => ({
    x: Math.random() * 100, drift: (Math.random() - 0.5) * 160, rot: Math.random() * 720 - 360, delay: Math.random() * 0.25,
    dur: 1.6 + Math.random() * 1.2, w: 6 + Math.random() * 6, h: 4 + Math.random() * 8, c: COLORS[i % COLORS.length], round: Math.random() > 0.7,
  })))
  return (
    <div className="confetti" aria-hidden>
      {pieces.map((p, i) => (
        <motion.i key={i} style={{ left: `${p.x}%`, width: p.w, height: p.round ? p.w : p.h, background: p.c, borderRadius: p.round ? 99 : 2 }}
          initial={{ y: -20, x: 0, rotate: 0, opacity: 1 }} animate={{ y: 900, x: p.drift, rotate: p.rot, opacity: [1, 1, 0] }}
          transition={{ duration: p.dur, delay: p.delay, ease: [0.2, 0.6, 0.4, 1] }} />
      ))}
    </div>
  )
}
