import { motion } from 'framer-motion'
import { Dodo, type Mood } from '../components/Dodo'
import { ChevronL, Flag } from '../components/Icons'
import { Flip } from '../components/ui'
import { itemV, listV, softSpring } from '../components/motion'
import { useModel } from '../lib/model'
import { dayInfo, fmt } from '../lib/plan'

export function DetailView() {
  const m = useModel()
  const { ui, setUI, setData, say, plan, byId } = m
  const T = ui.detailId ? byId[ui.detailId] : undefined
  if (!T) return null

  const col = m.tint(T), di = dayInfo(T.due), short = !!plan.short[T.id]
  const lg = Math.min(T.logged, T.minutes)
  const tl = plan.items.filter((y) => y.t === T.id)
  const back = () => setUI((u) => ({ screen: u.back || 'day' }))
  const mascot: null | { mood: Mood; title: string; body: string; bg: string; ink: string } = T.done
    ? { mood: 'party', title: 'Handed in. Legend.', body: 'The dodo did a little dance.', bg: 'var(--accent-soft)', ink: 'var(--ink)' }
    : short ? { mood: 'sweat', title: 'This won’t fit yet.', body: fmt(plan.short[T.id]) + ' over your daily limit. Raise the limit in settings or make it shorter.', bg: 'var(--warn-bg)', ink: 'var(--warn-ink)' }
    : lg >= T.minutes ? { mood: 'party', title: 'Ready to hand in!', body: 'All the work is done. Tap below once it’s in.', bg: 'var(--alt)', ink: 'var(--ink)' }
    : null

  const remove = () => {
    const snap = m.data
    setData((d) => ({ ...d, tasks: d.tasks.filter((y) => y.id !== T.id) }))
    back()
    say('Deleted — plan updated', { undo: snap })
  }
  const handIn = () => {
    const nd = !T.done
    const snap = m.setHandedIn(T.id, nd)
    if (nd) { m.celebrate(); navigator.vibrate?.([10, 40, 10]) }
    window.setTimeout(back, nd ? 700 : 0)
    say(nd ? 'Handed in. Nice.' : 'Back on your plan', { undo: snap, tone: nd ? 'done' : undefined })
  }

  return (
    <>
      <header style={{ flex: 'none', padding: 'calc(var(--top) + 32px) 24px 24px', position: 'relative', overflow: 'hidden' }}>
        <motion.div aria-hidden initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 0.14 }} transition={{ ...softSpring, delay: 0.05 }}
          style={{ position: 'absolute', right: -80, top: -80, width: 260, height: 260, borderRadius: '50%', background: col, filter: 'blur(40px)', pointerEvents: 'none' }} />
        <div style={{ height: 48, display: 'flex', justifyContent: 'space-between', margin: '0 -12px', position: 'relative' }}>
          <motion.button whileTap={{ x: -4 }} className="icon-btn" style={{ color: 'var(--ink)' }} aria-label="Back" onClick={back}><ChevronL /></motion.button>
          <button className="text-btn" style={{ fontSize: 16 }} onClick={remove}>Delete</button>
        </div>
        <motion.div variants={listV} initial="hidden" animate="show" style={{ position: 'relative' }}>
          <motion.div variants={itemV} style={{ display: 'flex', alignItems: 'center', gap: 8, height: 24 }}>
            <span style={{ width: 8, height: 8, borderRadius: 4, background: col }} />
            <span className="small muted" style={{ fontWeight: 600 }}>{fmt(T.minutes) + (tl.length > 1 ? ' · ' + tl.length + ' pieces' : '')}</span>
          </motion.div>
          <motion.h1 variants={itemV} className="display" style={{ marginTop: 8, whiteSpace: 'normal' }}>{T.title}</motion.h1>
          <motion.div variants={itemV} style={{ marginTop: 4, fontWeight: 600, color: short ? 'var(--warn-text)' : 'var(--muted)' }}>
            {T.done ? 'Handed in' : 'Due ' + di.wdl + ' ' + di.num + ' ' + di.mons + (T.due > 1 ? ' · ' + T.due + ' days' : T.due === 1 ? ' · tomorrow' : '')}
          </motion.div>
          <motion.div variants={itemV} style={{ marginTop: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
            <span className="h3"><Flip value={fmt(lg)} /><span style={{ fontFamily: 'var(--body)', fontWeight: 500, fontSize: 16, color: 'var(--muted)' }}> of {fmt(T.minutes)}</span></span>
            <span className="small" style={{ fontWeight: 700, color: short ? 'var(--warn-text)' : 'var(--accent)' }}>{T.done ? 'Handed in' : short ? 'Won’t fit' : lg >= T.minutes ? 'Ready' : 'On track'}</span>
          </motion.div>
          <motion.div variants={itemV} style={{ marginTop: 8, height: 6, borderRadius: 3, background: 'var(--alt)', overflow: 'hidden' }}>
            <motion.div initial={{ width: 0 }} animate={{ width: Math.round((lg / Math.max(1, T.minutes)) * 100) + '%' }} transition={{ ...softSpring, delay: 0.2 }}
              style={{ height: 6, borderRadius: 3, background: col }} />
          </motion.div>
        </motion.div>
      </header>
      <div className="scroll" style={{ padding: '0 24px calc(var(--bottom) + 16px)', display: 'flex', flexDirection: 'column' }}>
        <motion.div variants={listV} initial="hidden" animate="show" style={{ display: 'flex', flexDirection: 'column' }}>
          {mascot && (
            <motion.div variants={itemV} className="card" style={{ flex: 'none', marginBottom: 24, background: mascot.bg }}>
              <Dodo mood={mascot.mood} size={64} />
              <div style={{ minWidth: 0 }}>
                <div className="h3" style={{ color: mascot.ink }}>{mascot.title}</div>
                <div className="small" style={{ marginTop: 4, color: mascot.ink, opacity: 0.85 }}>{mascot.body}</div>
              </div>
            </motion.div>
          )}
          <motion.h2 variants={itemV} className="kicker section-label">Plan</motion.h2>
          {tl.length === 0 && <motion.div variants={itemV} className="muted" style={{ height: 64, display: 'flex', alignItems: 'center' }}>Nothing left to plan.</motion.div>}
          {/* Timeline: a line threads each piece down to the hand-in flag. */}
          <div style={{ position: 'relative' }}>
            <motion.span aria-hidden initial={{ scaleY: 0 }} animate={{ scaleY: 1 }} transition={{ duration: 0.6, delay: 0.2, ease: 'easeOut' }}
              style={{ position: 'absolute', left: 69, top: 32, bottom: 32, width: 2, background: 'var(--line)', transformOrigin: 'top' }} />
            {tl.map((y) => {
              const d3 = dayInfo(y.d), done = m.isDoneItem(y)
              return (
                <motion.button key={y.d} variants={itemV} whileTap={{ scale: 0.98 }} onClick={() => m.openItem(y)} className="row" style={{ flex: 'none', height: 64, position: 'relative', borderBottom: 'none' }}>
                  <span style={{ flex: 'none', width: 56 }}>
                    <span style={{ display: 'block', fontSize: 12, lineHeight: '16px', fontWeight: 700, color: 'var(--muted)' }}>{y.d === 0 ? 'TODAY' : d3.wd.toUpperCase()}</span>
                    <span style={{ display: 'block', fontFamily: 'var(--display)', fontWeight: 800, fontSize: 20, lineHeight: '24px', color: y.d === 0 ? 'var(--accent)' : 'var(--ink)' }}>{d3.num}</span>
                  </span>
                  <span style={{ flex: 'none', width: 28, display: 'flex', justifyContent: 'center' }}>
                    <span style={{ width: 12, height: 12, borderRadius: 6, background: done ? col : 'var(--bg)', boxShadow: `0 0 0 2px ${col}`, position: 'relative' }} />
                  </span>
                  <span style={{ flex: 1, fontWeight: 600, color: done ? 'var(--muted)' : 'var(--ink)', textDecoration: done ? 'line-through' : 'none' }}>Piece {y.k}/{y.n}</span>
                  <span className="small muted" style={{ flex: 'none', fontWeight: 600 }}>{fmt(y.m)}</span>
                </motion.button>
              )
            })}
            <motion.div variants={itemV} style={{ flex: 'none', height: 64, display: 'flex', alignItems: 'center', color: col, position: 'relative' }}>
              <span style={{ flex: 'none', width: 56 }} />
              <span style={{ flex: 'none', width: 28, display: 'flex', justifyContent: 'center', background: 'var(--bg)' }}><Flag /></span>
              <span style={{ fontWeight: 700 }}>{'Hand in ' + di.wd + ' ' + di.num + ' ' + di.mons}</span>
            </motion.div>
          </div>
          <motion.button variants={itemV} whileTap={{ scale: 0.97 }} className={'pill-btn block ' + (T.done ? 'soft' : 'ink')} style={{ flex: 'none', marginTop: 24 }} onClick={handIn}>
            {T.done ? 'Not handed in yet' : 'Mark as handed in'}
          </motion.button>
        </motion.div>
      </div>
    </>
  )
}
