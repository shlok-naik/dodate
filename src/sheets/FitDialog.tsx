import { AnimatePresence, motion } from 'framer-motion'
import { Dodo } from '../components/Dodo'
import { softSpring } from '../components/motion'
import { useModel } from '../lib/model'
import { fmt, limitToFit, rel } from '../lib/plan'

// Shown when new homework can't fit under the daily limit before it's due.
export function FitDialog() {
  const { data, ui, setUI, setData, say, plan, byId } = useModel()
  const ft = ui.dialog ? byId[ui.dialog.id] : undefined
  const need = ft ? plan.short[ft.id] || 0 : 0
  const open = !!(ft && need)

  let body = null
  if (ft && need) {
    const L = data.limit
    const tot = Math.max(0, ft.minutes - ft.logged), fits = Math.max(0, tot - need)
    const target = limitToFit(data.tasks, data.blocked, L, data.logToday, ft.id)
    const shrinkTo = Math.floor((ft.logged + fits) / 15) * 15
    const close = () => setUI({ dialog: null })
    body = (
      <motion.div key="fit" role="alertdialog" aria-modal aria-label={'This won’t fit before ' + rel(ft.due)}
        initial={{ y: 60, opacity: 0, scale: 0.96 }} animate={{ y: 0, opacity: 1, scale: 1 }} exit={{ y: 40, opacity: 0 }} transition={softSpring}
        style={{ width: '100%', background: 'var(--bg)', borderRadius: 32, padding: '24px 16px 16px' }}>
        <div style={{ padding: '0 8px' }}>
          <div style={{ marginTop: -64, marginBottom: 8 }}><Dodo mood="sweat" size={96} /></div>
          <h2 className="h2">This won’t fit before {rel(ft.due)}.</h2>
          <p className="muted" style={{ margin: '8px 0 0' }}>{ft.title} needs {fmt(tot)}. With your other homework, only {fmt(fits)} is free at {fmt(L)} a day.</p>
          <div style={{ marginTop: 16, display: 'flex', height: 8, gap: 4 }}>
            <motion.div initial={{ width: 0 }} animate={{ width: Math.round((fits / Math.max(1, tot)) * 100) + '%' }} transition={{ ...softSpring, delay: 0.2 }} style={{ background: 'var(--accent)', borderRadius: 4 }} />
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: [0.6, 1, 0.6] }} transition={{ duration: 1.6, repeat: Infinity }} style={{ flex: 1, background: 'var(--warn-bar)', borderRadius: 4 }} />
          </div>
          <div style={{ marginTop: 8, display: 'flex', justifyContent: 'space-between', fontSize: 12, lineHeight: '16px', fontWeight: 700, color: 'var(--muted)' }}>
            <span>{fmt(fits)} fits</span><span style={{ color: 'var(--warn-text)' }}>{fmt(need)} doesn’t</span>
          </div>
        </div>
        <div style={{ marginTop: 24, display: 'flex', flexDirection: 'column', gap: 8 }}>
          {target && (
            <motion.button whileTap={{ scale: 0.97 }} className="pill-btn primary" onClick={() => { setData((d) => ({ ...d, limit: target })); close(); say('Daily limit is now ' + fmt(target)) }}>
              Allow {fmt(target)} a day
            </motion.button>
          )}
          {shrinkTo >= 15 && (
            <motion.button whileTap={{ scale: 0.97 }} className="pill-btn soft"
              onClick={() => { setData((d) => ({ ...d, tasks: d.tasks.map((z) => (z.id === ft.id ? { ...z, minutes: shrinkTo } : z)) })); close(); say('Now ' + fmt(shrinkTo) + ' — it fits') }}>
              Make it {fmt(shrinkTo)}
            </motion.button>
          )}
          <button style={{ height: 48, color: 'var(--muted)', fontWeight: 600 }} onClick={close}>Keep it anyway</button>
        </div>
      </motion.div>
    )
  }

  return (
    <AnimatePresence>
      {open && (
        <motion.div key="fit-scrim" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
          style={{ position: 'absolute', zIndex: 30, inset: 0, background: 'var(--scrim)', display: 'flex', alignItems: 'flex-end', padding: 8 }}>
          {body}
        </motion.div>
      )}
    </AnimatePresence>
  )
}
