import { motion } from 'framer-motion'
import { ChevronR } from '../components/Icons'
import { itemV, listV, softSpring } from '../components/motion'
import { useModel } from '../lib/model'
import { dayInfo, fmt, rel } from '../lib/plan'

export function ItemSheet() {
  const m = useModel()
  const { ui, setUI, say, plan, byId } = m
  const t = ui.item ? byId[ui.item.t] : undefined
  const x = t && (plan.items.find((y) => y.t === t.id && y.d === ui.item!.d) || plan.items.find((y) => y.t === t.id))
  if (!t || !x) return null

  const close = (msg: string, undo?: typeof m.data) => { setUI({ sheet: null }); say(msg, { undo, tone: 'done' }) }
  const already = m.isDoneItem(x), remain = Math.max(0, t.minutes - t.logged)
  const pct = Math.min(1, t.logged / Math.max(1, t.minutes))
  const log = (mins: number) => close(fmt(mins) + ' logged — rest replanned', m.upd((ts, lt) => {
    const y = ts.find((z) => z.id === t.id)!
    y.logged += mins
    lt[t.id] = (lt[t.id] || 0) + mins
  }))

  return (
    <motion.div variants={listV} initial="hidden" animate="show" style={{ padding: '0 24px calc(var(--bottom) + 8px)' }}>
      <motion.button variants={itemV} onClick={() => m.openDetail(t.id)} style={{ margin: '8px 0 0 -12px', height: 48, padding: '0 12px', display: 'flex', alignItems: 'center', gap: 8, color: 'var(--muted)' }}>
        <span style={{ width: 8, height: 8, borderRadius: 4, background: m.tint(t) }} />
        <span className="small" style={{ fontWeight: 600 }}>Due {rel(t.due)}</span>
        <ChevronR size={16} />
      </motion.button>
      <motion.h2 variants={itemV} className="h2">{t.title}</motion.h2>
      <motion.div variants={itemV} className="muted" style={{ marginTop: 4 }}>{(x.n > 1 ? 'Piece ' + x.k + ' of ' + x.n + ' · ' : '') + (x.d === 0 ? 'today' : dayInfo(x.d).wdl) + ' · ' + fmt(x.m)}</motion.div>
      <motion.div variants={itemV} style={{ marginTop: 16, height: 6, borderRadius: 3, background: 'var(--alt)', overflow: 'hidden' }}>
        <motion.div initial={{ width: 0 }} animate={{ width: Math.round(pct * 100) + '%' }} transition={{ ...softSpring, delay: 0.15 }} style={{ height: 6, borderRadius: 3, background: m.tint(t) }} />
      </motion.div>
      <motion.button variants={itemV} whileTap={{ scale: 0.97 }} className={'pill-btn block ' + (already ? 'soft' : 'primary')} style={{ marginTop: 24 }}
        onClick={() => { if (already) { m.undoDone(t.id); setUI({ sheet: null }) } else { navigator.vibrate?.(12); close(fmt(x.m) + ' done', m.markDone(x)) } }}>
        {already ? 'Done — undo' : x.d === 0 ? 'Done · ' + fmt(x.m) : 'Did it already · ' + fmt(x.m)}
      </motion.button>
      <motion.div variants={itemV} className="kicker" style={{ marginTop: 24, height: 32, display: 'flex', alignItems: 'center' }}>Worked a different amount today?</motion.div>
      <motion.div variants={itemV} style={{ marginTop: 8, display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 8 }}>
        {[15, 30, 45, 60].map((mins) => (
          <motion.button key={mins} whileTap={{ scale: 0.92 }} onClick={() => log(mins)} style={{ height: 48, borderRadius: 24, background: 'var(--alt)', fontWeight: 600 }}>{fmt(mins)}</motion.button>
        ))}
      </motion.div>
      <motion.div variants={itemV} style={{ marginTop: 24 }}>
        <button onClick={() => close('+30m added — plan updated', m.upd((ts) => { ts.find((z) => z.id === t.id)!.minutes += 30 }))}
          style={{ width: '100%', height: 56, borderTop: '1px solid var(--line)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontWeight: 600 }}>
          <span>Needs more time</span><span className="small muted">+30m</span>
        </button>
        <button onClick={() => close('Finished — ' + fmt(remain) + ' freed up', m.upd((ts) => { const y = ts.find((z) => z.id === t.id)!; y.minutes = y.logged }))}
          style={{ width: '100%', height: 56, borderTop: '1px solid var(--line)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontWeight: 600 }}>
          <span>Finished it early</span><span className="small muted">{remain > 0 ? 'frees ' + fmt(remain) : ''}</span>
        </button>
      </motion.div>
    </motion.div>
  )
}
