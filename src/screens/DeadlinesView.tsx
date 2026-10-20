import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { Dodo } from '../components/Dodo'
import { Check, Sliders } from '../components/Icons'
import { Ring } from '../components/ui'
import { itemV, listV, softSpring } from '../components/motion'
import { useModel } from '../lib/model'
import { dayInfo, fmt, rel } from '../lib/plan'

export function DeadlinesView() {
  const m = useModel()
  const { data, setUI, plan, active, say } = m
  const [scrolled, setScrolled] = useState(false)
  const sorted = active.slice().sort((a, b) => a.due - b.due)
  const nx = sorted[0]
  const left = (t: { minutes: number; logged: number }) => Math.max(0, t.minutes - t.logged)
  const handed = data.tasks.filter((t) => t.done)

  return (
    <>
      <header className={'head' + (scrolled ? ' scrolled' : '')} style={{ paddingBottom: 16 }}>
        <div className="head-row">
          <h1 className="display" style={{ flex: 1, minWidth: 0 }}>Deadlines</h1>
          <motion.button whileTap={{ rotate: 90 }} className="icon-btn" aria-label="Settings" onClick={() => setUI({ sheet: 'settings' })} style={{ marginRight: -12 }}><Sliders /></motion.button>
        </div>
        <div className="sub" style={{ marginTop: 4, height: 24 }}>{sorted.length ? sorted.length + ' to hand in · next ' + rel(nx.due) : 'All handed in'}</div>
      </header>
      <div className="scroll" style={{ padding: '16px 24px 136px' }} onScroll={(e) => setScrolled(e.currentTarget.scrollTop > 0)}>
        <motion.div variants={listV} initial="hidden" animate="show">
          {sorted.length === 0 && (
            <motion.div variants={itemV} style={{ paddingTop: 24, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <Dodo mood="party" size={140} />
              <div className="h3" style={{ marginTop: 16 }}>Nothing to hand in!</div>
              <div className="muted" style={{ marginTop: 4 }}>Everything’s in. Enjoy it.</div>
            </motion.div>
          )}

          {nx && (() => {
            const short = !!plan.short[nx.id]
            return (
              <>
                <motion.button variants={itemV} whileTap={{ scale: 0.98 }} onClick={() => m.openDetail(nx.id)} className="card"
                  style={{ width: '100%', textAlign: 'left', position: 'relative', overflow: 'hidden', background: short ? 'var(--warn-bg)' : 'var(--alt)' }}>
                  <Dodo mood={short ? 'sweat' : left(nx) ? 'write' : 'party'} size={80} />
                  <span style={{ flex: 1, minWidth: 0 }}>
                    <span className="kicker" style={{ display: 'block', color: short ? 'var(--warn-text)' : 'var(--muted)' }}>{short ? 'Next up · won’t fit' : 'Next up'}</span>
                    <span className="h3" style={{ display: 'block', marginTop: 4 }}>{nx.title}</span>
                    <span className="small muted" style={{ display: 'block', marginTop: 4 }}>Due {rel(nx.due)} · {left(nx) ? fmt(left(nx)) + ' left' : 'ready to hand in'}</span>
                  </span>
                </motion.button>
                <motion.h2 variants={itemV} className="kicker section-label" style={{ marginTop: 24 }}>To hand in</motion.h2>
              </>
            )
          })()}

          {sorted.map((t) => {
            const i = dayInfo(t.due), pct = Math.min(1, t.logged / Math.max(1, t.minutes)), short = !!plan.short[t.id]
            return (
              <motion.button key={t.id} variants={itemV} layout whileTap={{ scale: 0.98 }} onClick={() => m.openDetail(t.id)} className="row" style={{ height: 72 }}>
                <span style={{ flex: 'none', width: 56 }}>
                  <span style={{ display: 'block', fontSize: 12, lineHeight: '16px', fontWeight: 700, color: 'var(--muted)' }}>{i.wd.toUpperCase()}</span>
                  <span style={{ display: 'block', fontFamily: 'var(--display)', fontWeight: 800, fontSize: 20, lineHeight: '24px', color: m.tint(t) }}>{i.num}</span>
                </span>
                <span style={{ flex: 1, minWidth: 0 }}>
                  <span className="ellipsis" style={{ display: 'block', fontWeight: 600 }}>{t.title}</span>
                  <span className="small ellipsis" style={{ display: 'block', color: short ? 'var(--warn-text)' : 'var(--muted)' }}>
                    {short ? 'Won’t fit · ' + fmt(plan.short[t.id]) + ' over' : (t.due <= 0 ? 'Due today' : t.due === 1 ? 'Due tomorrow' : 'In ' + t.due + ' days') + ' · ' + fmt(Math.min(t.logged, t.minutes)) + ' of ' + fmt(t.minutes)}
                  </span>
                </span>
                <span style={{ marginLeft: 16 }}><Ring size={32} value={pct} color={m.tint(t)} label={Math.round(pct * 100) + ' percent done'} /></span>
              </motion.button>
            )
          })}

          {handed.length > 0 && <motion.h2 variants={itemV} className="kicker section-label" style={{ marginTop: 32 }}>Handed in</motion.h2>}
          <AnimatePresence initial={false}>
            {handed.map((t) => (
              <motion.div key={t.id} layout initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 48 }} exit={{ opacity: 0, height: 0 }} transition={softSpring}
                className="row" style={{ overflow: 'hidden' }}>
                <span style={{ flex: 'none', width: 56, display: 'flex', alignItems: 'center', color: 'var(--accent)' }}><Check size={16} /></span>
                <span className="muted ellipsis" style={{ flex: 1, minWidth: 0, textDecoration: 'line-through' }}>{t.title}</span>
                <button className="text-btn" style={{ marginRight: -12, color: 'var(--accent)', fontWeight: 700 }}
                  onClick={() => { m.setHandedIn(t.id, false); say('Back on your plan') }}>Undo</button>
              </motion.div>
            ))}
          </AnimatePresence>
        </motion.div>
      </div>
    </>
  )
}
