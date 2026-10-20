import { motion } from 'framer-motion'
import { Chips, Flip } from '../components/ui'
import { itemV, listV, spring } from '../components/motion'
import { useModel } from '../lib/model'
import { LIMITS, fmt } from '../lib/plan'
import { seed } from '../lib/store'

export function SettingsSheet({ dark }: { dark: boolean }) {
  const { data, setData, setUI, say } = useModel()
  const theme = dark ? 'dark' : 'light'
  return (
    <motion.div variants={listV} initial="hidden" animate="show" style={{ padding: '0 24px calc(var(--bottom) + 8px)' }}>
      <motion.h2 variants={itemV} className="h2" style={{ marginTop: 16 }}>Settings</motion.h2>
      <motion.div variants={itemV} style={{ marginTop: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'center', height: 24 }}>
        <span style={{ fontWeight: 600 }}>Most homework in a day</span>
        <span style={{ fontWeight: 700, color: 'var(--accent)' }}><Flip value={fmt(data.limit)} /></span>
      </motion.div>
      <motion.div variants={itemV} className="small muted" style={{ marginTop: 4 }}>Dodate never plans more than this on one day.</motion.div>
      <motion.div variants={itemV} style={{ marginTop: 16 }}>
        <Chips ariaLabel="Daily limit" value={data.limit} onPick={(v) => setData((d) => ({ ...d, limit: v }))} options={LIMITS.map((v) => ({ v, label: fmt(v) }))} />
      </motion.div>
      <motion.div variants={itemV} style={{ marginTop: 24, height: 56, display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--line)' }}>
        <span style={{ fontWeight: 600 }}>Appearance</span>
        <div role="group" aria-label="Appearance" style={{ height: 40, display: 'flex', background: 'var(--alt)', borderRadius: 20, padding: 4, gap: 4 }}>
          {(['light', 'dark'] as const).map((p) => {
            const on = theme === p
            return (
              <button key={p} aria-pressed={on} onClick={() => setData((d) => ({ ...d, theme: p }))}
                style={{ position: 'relative', height: 32, padding: '0 16px', borderRadius: 16, fontWeight: 700, fontSize: 14, color: on ? 'var(--ink)' : 'var(--muted)', transition: 'color 0.2s' }}>
                {on && <motion.span layoutId="theme-on" transition={spring} style={{ position: 'absolute', inset: 0, borderRadius: 16, background: 'var(--bg)', boxShadow: '0 1px 2px rgba(0,0,0,0.16)' }} />}
                <span style={{ position: 'relative' }}>{p === 'light' ? 'Light' : 'Dark'}</span>
              </button>
            )
          })}
        </div>
      </motion.div>
      <motion.button variants={itemV} className="text-btn" style={{ margin: '8px 0 0 -12px' }}
        onClick={() => { const snap = data; setData((d) => seed(d.theme)); setUI({ sheet: null, screen: 'day', selDay: 0, weekOffset: 0 }); say('Demo data reset', { undo: snap }) }}>
        Reset demo data
      </motion.button>
    </motion.div>
  )
}
