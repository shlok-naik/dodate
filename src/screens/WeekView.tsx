import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { Dodo } from '../components/Dodo'
import { ChevronL, ChevronR, Flag, Sliders } from '../components/Icons'
import { itemV, listV, spring } from '../components/motion'
import { useModel } from '../lib/model'
import { dayInfo, fmt } from '../lib/plan'

export function WeekView() {
  const m = useModel()
  const { data, ui, setUI, active, byId } = m
  const L = data.limit
  const ws = 7 * ui.weekOffset
  const [scrolled, setScrolled] = useState(false)
  const [dir, setDir] = useState(0)
  const go = (o: number) => { setDir(Math.sign(o - ui.weekOffset)); setUI({ weekOffset: o, selDay: o === 0 ? 0 : 7 * o }) }

  const a0 = dayInfo(ws), a6 = dayInfo(ws + 6)
  const days = Array.from({ length: 7 }, (_, j) => {
    const d = ws + j, its = m.itemsOn(d)
    return { d, i: dayInfo(d), its, mins: its.reduce((a, x) => a + x.m, 0), off: !!data.blocked[d], dues: active.filter((t) => t.due === d) }
  })
  const weekMins = days.reduce((a, x) => a + x.mins, 0)
  const maxMins = Math.max(L, ...days.map((x) => x.mins))
  const title = ui.weekOffset === 0 ? 'This week' : ui.weekOffset === 1 ? 'Next week' : ui.weekOffset === -1 ? 'Last week' : ui.weekOffset > 1 ? 'Later' : 'Earlier'
  const range = a0.mons === a6.mons ? a0.num + '–' + a6.num + ' ' + a6.mons : a0.num + ' ' + a0.mons + ' – ' + a6.num + ' ' + a6.mons

  return (
    <>
      <header className={'head' + (scrolled ? ' scrolled' : '')} style={{ paddingBottom: 16 }}>
        <div className="head-row">
          <h1 className="display" style={{ flex: 1, minWidth: 0 }}>{title}</h1>
          <span style={{ flex: 'none', display: 'flex', marginRight: -12 }}>
            <motion.button whileTap={{ x: -3 }} className="icon-btn" style={{ color: 'var(--ink)' }} aria-label="Previous week" onClick={() => go(ui.weekOffset - 1)}><ChevronL /></motion.button>
            <motion.button whileTap={{ x: 3 }} className="icon-btn" style={{ color: 'var(--ink)' }} aria-label="Next week" onClick={() => go(ui.weekOffset + 1)}><ChevronR /></motion.button>
            <motion.button whileTap={{ rotate: 90 }} className="icon-btn" aria-label="Settings" onClick={() => setUI({ sheet: 'settings' })}><Sliders /></motion.button>
          </span>
        </div>
        <div style={{ marginTop: 4, height: 24, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16 }}>
          <span className="sub ellipsis" style={{ minWidth: 0 }}>{range + ' · ' + (weekMins ? fmt(weekMins) + ' of homework' : 'no homework')}</span>
          <AnimatePresence>
            {ui.weekOffset !== 0 && (
              <motion.button initial={{ opacity: 0, x: 8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 8 }} onClick={() => go(0)}
                style={{ flex: 'none', height: 24, color: 'var(--accent)', fontWeight: 700, fontSize: 14, lineHeight: '20px' }}>Back to this week</motion.button>
            )}
          </AnimatePresence>
        </div>
        {/* Load chart: one bar per day, the dashed line is your daily limit. */}
        <div style={{ marginTop: 16, display: 'flex', gap: 8, alignItems: 'flex-end', height: 32, position: 'relative' }} aria-hidden>
          <div style={{ position: 'absolute', left: 0, right: 0, bottom: (L / maxMins) * 32, borderTop: '1.5px dashed var(--line)' }} />
          {days.map((x, k) => (
            <div key={x.d} style={{ flex: 1, height: '100%', display: 'flex', alignItems: 'flex-end' }}>
              <motion.div key={ws + ':' + x.d} initial={{ height: 0 }} animate={{ height: x.off ? 4 : Math.max(4, (x.mins / maxMins) * 32) }} transition={{ ...spring, delay: k * 0.03 }}
                style={{ width: '100%', borderRadius: 6, background: x.mins > L ? 'var(--warn-bar)' : x.d === 0 ? 'var(--accent)' : x.mins ? 'var(--muted)' : 'var(--line)', opacity: x.d < 0 ? 0.25 : x.d === 0 || x.mins > L ? 1 : 0.35 }} />
            </div>
          ))}
        </div>
      </header>

      <div className="scroll" style={{ padding: '0 24px 136px' }} onScroll={(e) => setScrolled(e.currentTarget.scrollTop > 0)}>
        <AnimatePresence mode="wait" initial={false}>
          <motion.div key={ui.weekOffset} variants={listV} initial="hidden" animate="show" exit={{ opacity: 0, x: dir * -30, transition: { duration: 0.12 } }}>
            {weekMins === 0 && ws + 6 >= 0 && (
              <motion.div variants={itemV} className="card" style={{ marginTop: 16 }}>
                <Dodo mood="chill" size={64} />
                <div style={{ minWidth: 0 }}>
                  <div className="h3">Quiet week.</div>
                  <div className="small muted" style={{ marginTop: 4 }}>Nothing planned. Enjoy the break.</div>
                </div>
              </motion.div>
            )}
            {days.map(({ d, i, its, mins, off, dues }) => (
              <motion.div key={d} variants={itemV} style={{ padding: '16px 0', borderBottom: '1px solid var(--line)', opacity: d < 0 ? 0.4 : 1 }}>
                <motion.button whileTap={{ scale: 0.98 }} aria-label={'Open ' + i.wdl + ' ' + i.num} onClick={() => setUI({ screen: 'day', selDay: d })}
                  style={{ width: '100%', height: 48, display: 'flex', alignItems: 'center', textAlign: 'left' }}>
                  <span style={{ flex: 'none', width: 40, fontFamily: 'var(--display)', fontWeight: 800, fontSize: 28, lineHeight: '32px', letterSpacing: -0.8, color: d === 0 ? 'var(--accent)' : 'var(--ink)' }}>{i.num}</span>
                  <span style={{ flex: 1, fontWeight: 600, color: d === 0 ? 'var(--accent)' : 'var(--muted)' }}>{d === 0 ? 'Today' : d === 1 ? 'Tomorrow' : i.wdl}</span>
                  <span className="small num" style={{ flex: 'none', fontWeight: 600, color: mins > L ? 'var(--warn-text)' : 'var(--muted)' }}>{off ? 'Off' : mins ? fmt(mins) : 'None'}</span>
                </motion.button>
                {dues.map((t) => (
                  <button key={t.id} onClick={() => m.openDetail(t.id)} style={{ width: '100%', height: 40, display: 'flex', alignItems: 'center', textAlign: 'left', color: m.tint(t) }}>
                    <span style={{ flex: 'none', width: 40, display: 'flex', alignItems: 'center' }}>
                      <motion.span animate={{ rotate: [0, -12, 0] }} transition={{ duration: 1.2, repeat: Infinity, repeatDelay: 2 }} style={{ display: 'flex', transformOrigin: '20% 100%' }}><Flag /></motion.span>
                    </span>
                    <span style={{ fontWeight: 700 }}>{t.title} due</span>
                  </button>
                ))}
                {its.map((x) => {
                  const t = byId[x.t], done = m.isDoneItem(x)
                  return (
                    <button key={x.t} onClick={() => m.openItem(x)} style={{ width: '100%', height: 40, display: 'flex', alignItems: 'center', textAlign: 'left' }}>
                      <span style={{ flex: 'none', width: 40, display: 'flex', alignItems: 'center' }}><span style={{ width: 8, height: 8, borderRadius: 4, background: m.tint(t) }} /></span>
                      <span className="ellipsis" style={{ flex: 1, minWidth: 0, color: done ? 'var(--muted)' : 'var(--ink)', textDecoration: done ? 'line-through' : 'none' }}>
                        {t.title} <span className="muted">{x.n > 1 ? x.k + '/' + x.n : ''}</span>
                      </span>
                      <span className="small muted num" style={{ flex: 'none' }}>{fmt(x.m)}</span>
                    </button>
                  )
                })}
                {off && (
                  <div className="muted" style={{ height: 40, display: 'flex', alignItems: 'center' }}>
                    <span style={{ flex: 'none', width: 40, marginLeft: -8 }}><Dodo mood="sleep" size={40} /></span>
                    <span style={{ marginLeft: 8 }}>Day off. Shhh.</span>
                  </div>
                )}
              </motion.div>
            ))}
          </motion.div>
        </AnimatePresence>
      </div>
    </>
  )
}
