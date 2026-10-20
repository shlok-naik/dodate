import { AnimatePresence, MotionConfig, motion } from 'framer-motion'
import { useEffect, useState } from 'react'
import { Plus } from './components/Icons'
import { Confetti, Sheet, Toast } from './components/ui'
import { spring } from './components/motion'
import { useModel } from './lib/model'
import { StoreProvider, type Screen } from './lib/store'
import { DayView } from './screens/DayView'
import { DeadlinesView } from './screens/DeadlinesView'
import { DetailView } from './screens/DetailView'
import { WeekView } from './screens/WeekView'
import { AddSheet } from './sheets/AddSheet'
import { FitDialog } from './sheets/FitDialog'
import { ItemSheet } from './sheets/ItemSheet'
import { SettingsSheet } from './sheets/SettingsSheet'

const TABS: { id: Screen; label: string }[] = [
  { id: 'day', label: 'Day' },
  { id: 'week', label: 'Week' },
  { id: 'deadlines', label: 'Deadlines' },
]
const order = (s: Screen) => (s === 'detail' ? 3 : TABS.findIndex((t) => t.id === s))

function useSystemDark() {
  const q = '(prefers-color-scheme: dark)'
  const [dark, setDark] = useState(() => window.matchMedia?.(q).matches ?? false)
  useEffect(() => {
    const mq = window.matchMedia?.(q)
    const on = (e: MediaQueryListEvent) => setDark(e.matches)
    mq?.addEventListener('change', on)
    return () => mq?.removeEventListener('change', on)
  }, [])
  return dark
}

function Shell() {
  const m = useModel()
  const { data, ui, setUI, toast, undo, plan, byId, party } = m
  const systemDark = useSystemDark()
  const dark = data.theme ? data.theme === 'dark' : systemDark

  useEffect(() => {
    document.documentElement.dataset.theme = dark ? 'dark' : 'light'
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', dark ? '#0F1211' : '#FFFFFF')
  }, [dark])

  // Escape closes the topmost layer.
  useEffect(() => {
    const on = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return
      if (ui.dialog) setUI({ dialog: null })
      else if (ui.sheet) setUI({ sheet: null })
      else if (ui.screen === 'detail') setUI((u) => ({ screen: u.back }))
    }
    window.addEventListener('keydown', on)
    return () => window.removeEventListener('keydown', on)
  }, [ui.dialog, ui.sheet, ui.screen, setUI])

  // A new sheet takes focus; don't leave an old toast floating over it.
  const { dismissToast } = m
  useEffect(() => { if (ui.sheet) dismissToast() }, [ui.sheet, dismissToast])

  const screen: Screen = ui.screen === 'detail' && !(ui.detailId && byId[ui.detailId]) ? 'day' : ui.screen
  // Direction of travel: tabs slide gently sideways, the detail page pushes over them.
  const [nav, setNav] = useState({ screen, dir: 1, push: false })
  if (nav.screen !== screen) setNav({ screen, dir: order(screen) >= order(nav.screen) ? 1 : -1, push: screen === 'detail' || nav.screen === 'detail' })
  const custom = { dir: nav.dir, push: nav.push }

  const isDetail = screen === 'detail'
  const alert = Object.keys(plan.short).length > 0
  const closeSheet = () => setUI({ sheet: null })
  const itemOk = !!(ui.item && byId[ui.item.t] && plan.items.some((y) => y.t === ui.item!.t))

  return (
    <div className="app">
      <AnimatePresence initial={false} custom={custom}>
        <motion.div key={screen} className="screen" custom={custom}
          variants={{
            enter: (c: typeof custom) => (c.push ? (c.dir > 0 ? { x: '100%', opacity: 1, zIndex: 3 } : { x: '-30%', opacity: 0.6 }) : { x: c.dir * 48, opacity: 0 }),
            center: { x: 0, opacity: 1 },
            exit: (c: typeof custom) => (c.push ? (c.dir > 0 ? { x: '-30%', opacity: 0.6 } : { x: '100%', opacity: 1, zIndex: 3 }) : { x: c.dir * -48, opacity: 0 }),
          }}
          initial="enter" animate="center" exit="exit" transition={{ type: 'spring', stiffness: 380, damping: 40 }}>
          {screen === 'day' && <DayView />}
          {screen === 'week' && <WeekView />}
          {screen === 'deadlines' && <DeadlinesView />}
          {screen === 'detail' && <DetailView />}
        </motion.div>
      </AnimatePresence>

      <AnimatePresence>
        {!isDetail && (
          <motion.div key="nav" initial={{ y: 120 }} animate={{ y: 0 }} exit={{ y: 120 }} transition={spring}>
            <div className="nav-fade" />
            <div className="nav-wrap">
              <nav className="nav" aria-label="Views">
                {TABS.map((t) => {
                  const on = screen === t.id
                  return (
                    <motion.button key={t.id} whileTap={{ scale: 0.94 }} aria-current={on ? 'page' : undefined} style={{ zIndex: 0 }}
                      onClick={() => setUI(t.id === 'day' ? { screen: 'day' } : { screen: t.id })}>
                      {on && <motion.span layoutId="nav-on" className="nav-on" transition={spring} />}
                      <span>{t.label}</span>
                      {t.id === 'deadlines' && alert && (
                        <motion.span aria-label="something won't fit" initial={{ scale: 0 }} animate={{ scale: [1, 1.4, 1] }} transition={{ duration: 1.2, repeat: Infinity, repeatDelay: 1.5 }}
                          style={{ flex: 'none', width: 8, height: 8, borderRadius: 4, background: 'var(--warn-bar)' }} />
                      )}
                    </motion.button>
                  )
                })}
              </nav>
              <motion.button className="fab" aria-label="Add homework" onClick={() => setUI({ sheet: 'add' })}
                whileTap={{ scale: 0.88, rotate: 90 }} whileHover={{ scale: 1.05 }} transition={spring}>
                <Plus />
              </motion.button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <Sheet open={ui.sheet === 'add'} onClose={closeSheet} tall label="Add homework"><AddSheet onClose={closeSheet} /></Sheet>
      <Sheet open={ui.sheet === 'item' && itemOk} onClose={closeSheet} label="Homework piece"><ItemSheet /></Sheet>
      <Sheet open={ui.sheet === 'settings'} onClose={closeSheet} label="Settings"><SettingsSheet dark={dark} /></Sheet>
      <FitDialog />
      <Toast toast={toast} onUndo={undo} />
      {party > 0 && <Confetti key={party} count={80} />}
    </div>
  )
}

export default function App() {
  return (
    <MotionConfig reducedMotion="user">
      <StoreProvider><Shell /></StoreProvider>
    </MotionConfig>
  )
}
