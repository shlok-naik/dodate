import { AnimatePresence, motion, type PanInfo } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'
import { Dodo } from '../components/Dodo'
import { Sliders } from '../components/Icons'
import { CheckDot, Flip, Ring } from '../components/ui'
import { itemV, listV, softSpring, spring } from '../components/motion'
import { useModel } from '../lib/model'
import { dayInfo, fmt, limitToFit, rel } from '../lib/plan'

export function DayView() {
  const m = useModel()
  const { data, ui, setUI, setData, say, plan, byId, active } = m
  const L = data.limit
  const ws = 7 * ui.weekOffset
  const sel = ui.selDay < ws || ui.selDay > ws + 6 ? ws : ui.selDay
  const [scrolled, setScrolled] = useState(false)
  const [dir, setDir] = useState(0)
  const pick = (d: number) => { setDir(Math.sign(d - sel)); setUI({ selDay: d, weekOffset: Math.floor(d / 7) }) }

  const di = dayInfo(sel)
  const items = m.itemsOn(sel)
  const total = items.reduce((a, x) => a + x.m, 0)
  const done = items.filter(m.isDoneItem)
  const doneMins = done.reduce((a, x) => a + x.m, 0)
  const blocked = !!data.blocked[sel]
  const relTitle = sel >= -1 && sel <= 1
  let sub = (relTitle ? di.wdl + ' ' : '') + di.num + ' ' + di.mon
  if (!blocked && total > 0) sub = (relTitle ? di.wd + ' ' : '') + di.num + ' ' + di.mons + ' · ' + fmt(total) + ' of homework' + (total > L ? ' · over limit' : '')
  const title = sel === 0 ? 'Today' : sel === 1 ? 'Tomorrow' : sel === -1 ? 'Yesterday' : di.wdl
  const allDone = sel === 0 && items.length > 0 && done.length === items.length

  // Fire confetti the moment today's last piece is ticked off.
  const { celebrate } = m
  const wasAllDone = useRef(allDone)
  useEffect(() => {
    if (allDone && !wasAllDone.current) celebrate()
    wasAllDone.current = allDone
  }, [allDone, celebrate])

  const toggleBlock = () => {
    const b = { ...data.blocked }
    if (b[sel]) { delete b[sel]; say('Back on — plan updated') } else { b[sel] = true; say(di.wdl + ' off — work moved to other days') }
    setData((d) => ({ ...d, blocked: b }))
  }

  const warnings = Object.keys(plan.short).map((id) => {
    const nl = limitToFit(data.tasks, data.blocked, L, data.logToday, id) ?? Math.min(480, L + 60)
    return { id, title: byId[id].title + ' won’t fit.', body: fmt(plan.short[id]) + ' over your limit.', label: 'Allow ' + fmt(nl), raise: () => { setData((d) => ({ ...d, limit: nl })); say('Daily limit is now ' + fmt(nl)) } }
  })

  // A swipe that ends over a row shouldn't also count as tapping it.
  const dragged = useRef(false)
  const swipe = (_: unknown, info: PanInfo) => {
    window.setTimeout(() => { dragged.current = false }, 50)
    if (Math.abs(info.offset.x) < 60 || Math.abs(info.offset.y) > Math.abs(info.offset.x)) return
    pick(sel + (info.offset.x < 0 ? 1 : -1))
  }

  return (
    <>
      <header className={'head' + (scrolled ? ' scrolled' : '')}>
        <div className="head-row">
          <h1 className="display" style={{ flex: 1, minWidth: 0 }}>
            <AnimatePresence mode="popLayout" initial={false} custom={dir}>
              <motion.span key={title} style={{ display: 'inline-block' }} custom={dir}
                initial={{ opacity: 0, y: 14, filter: 'blur(4px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ opacity: 0, y: -14, filter: 'blur(4px)' }} transition={spring}>
                {title}
              </motion.span>
            </AnimatePresence>
          </h1>
          <AnimatePresence>
            {!blocked && items.length > 0 && sel === 0 && (
              <motion.div initial={{ scale: 0, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0, opacity: 0 }} transition={spring}>
                <Ring size={40} value={doneMins / Math.max(1, total)} label={`${done.length} of ${items.length} done`}>
                  <span className="num" style={{ fontSize: 12, lineHeight: '16px', fontWeight: 700, display: 'flex' }}>
                    <Flip value={done.length} />/{items.length}
                  </span>
                </Ring>
              </motion.div>
            )}
          </AnimatePresence>
          <motion.button className="icon-btn" aria-label="Settings" onClick={() => setUI({ sheet: 'settings' })} style={{ marginRight: -12 }} whileTap={{ rotate: 90, scale: 0.9 }}>
            <Sliders />
          </motion.button>
        </div>
        <div className="sub ellipsis" style={{ marginTop: 4, height: 24 }}>
          <AnimatePresence mode="wait" initial={false}>
            <motion.span key={sub} style={{ display: 'block' }} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.15 }}>{sub}</motion.span>
          </AnimatePresence>
        </div>
        <DayStrip ws={ws} sel={sel} onPick={pick} />
      </header>

      <div className="scroll pad" onScroll={(e) => setScrolled(e.currentTarget.scrollTop > 0)}>
        <AnimatePresence initial={false}>
          {warnings.map((w) => (
            <motion.div key={w.id} layout initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} exit={{ opacity: 0, height: 0 }} transition={softSpring} style={{ overflow: 'hidden' }}>
              <div style={{ margin: '8px 0', background: 'var(--warn-bg)', borderRadius: 16, padding: '8px 8px 8px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
                <span className="small" style={{ flex: 1, color: 'var(--warn-ink)' }}><strong>{w.title}</strong> {w.body}</span>
                <motion.button whileTap={{ scale: 0.95 }} onClick={w.raise} style={{ flex: 'none', height: 40, padding: '0 16px', borderRadius: 20, background: 'var(--warn-btn)', color: 'var(--warn-ink)', fontWeight: 700, fontSize: 14 }}>{w.label}</motion.button>
              </div>
            </motion.div>
          ))}
        </AnimatePresence>

        {active.length === 0 ? (
          <motion.div variants={listV} initial="hidden" animate="show" style={{ paddingTop: 32 }}>
            <motion.div variants={itemV}><Dodo mood="chill" size={140} /></motion.div>
            <motion.h2 variants={itemV} className="h2" style={{ marginTop: 16 }}>Turn due dates into do dates.</motion.h2>
            <motion.p variants={itemV} className="sub" style={{ margin: '8px 0 0' }}>Tell me what’s due and when. I’ll chop it into small pieces across the days before, so nothing is a last-minute panic.</motion.p>
            <motion.button variants={itemV} whileTap={{ scale: 0.96 }} className="pill-btn primary" style={{ marginTop: 24 }} onClick={() => setUI({ sheet: 'add' })}>Add homework</motion.button>
          </motion.div>
        ) : (
          <motion.div drag="x" dragDirectionLock dragConstraints={{ left: 0, right: 0 }} dragElastic={0.18} onDragStart={() => { dragged.current = true }} onDragEnd={swipe} style={{ touchAction: 'pan-y' }}
            onClickCapture={(e) => { if (dragged.current) { e.stopPropagation(); e.preventDefault() } }}>
            <AnimatePresence mode="wait" initial={false} custom={dir}>
              <motion.div key={sel} custom={dir} variants={{
                enter: (d: number) => ({ opacity: 0, x: d * 40 }), center: { opacity: 1, x: 0 }, exit: (d: number) => ({ opacity: 0, x: d * -40 }),
              }} initial="enter" animate="center" exit="exit" transition={{ duration: 0.18 }}>
                {blocked && sel >= 0 ? (
                  <div style={{ padding: '24px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
                    <Dodo mood="sleep" size={160} />
                    <div className="h3" style={{ marginTop: 16 }}>Day off. Shhh.</div>
                    <div className="muted" style={{ marginTop: 4 }}>Even dodos need a lie-in. Your work moved to the other days.</div>
                    <button onClick={toggleBlock} style={{ marginTop: 8, height: 48, padding: '0 12px', color: 'var(--accent)', fontWeight: 700 }}>I can work after all</button>
                  </div>
                ) : items.length === 0 ? (
                  <div style={{ padding: '24px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
                    <Dodo mood="chill" size={140} />
                    <div className="h3" style={{ marginTop: 16 }}>{sel < 0 ? 'That day’s gone.' : 'Free day!'}</div>
                    <div className="muted" style={{ marginTop: 4 }}>{sel < 0 ? 'No time machine yet. Look ahead instead.' : 'Nothing’s planned. Go outside, nap, whatever you like.'}</div>
                  </div>
                ) : null}

                <motion.div variants={listV} initial="hidden" animate="show">
                  {!blocked && items.map((x) => {
                    const t = byId[x.t], isDone = m.isDoneItem(x)
                    return (
                      <motion.div key={x.t} variants={itemV} layout className="task-row row">
                        <button aria-label={(isDone ? 'Mark not done: ' : 'Mark done: ') + t.title} onClick={() => m.toggleItem(x)}
                          style={{ flex: 'none', width: 48, height: 48, marginLeft: -12, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          <CheckDot done={isDone} color={m.tint(t)} />
                        </button>
                        <motion.button whileTap={{ scale: 0.98 }} onClick={() => m.openItem(x)} style={{ flex: 1, minWidth: 0, minHeight: 72, padding: '0 0 0 4px', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 16 }}>
                          <span style={{ flex: 1, minWidth: 0 }}>
                            <span className="ellipsis" style={{ display: 'block', fontWeight: 600, color: isDone ? 'var(--muted)' : 'var(--ink)', transition: 'color 0.3s' }}>
                              <span style={{ position: 'relative' }}>
                                {t.title}
                                <motion.span aria-hidden initial={false} animate={{ scaleX: isDone ? 1 : 0 }} transition={{ duration: 0.3, ease: 'easeOut' }}
                                  style={{ position: 'absolute', left: 0, right: 0, top: '55%', height: 2, borderRadius: 1, background: 'var(--muted)', transformOrigin: 'left' }} />
                              </span>
                            </span>
                            <span className="small muted ellipsis" style={{ display: 'block' }}>{(x.n > 1 ? 'Piece ' + x.k + ' of ' + x.n + ' · ' : '') + 'due ' + rel(t.due)}</span>
                          </span>
                          <span className="small num" style={{ flex: 'none', fontWeight: 600, color: 'var(--muted)', background: 'var(--alt)', padding: '2px 10px', borderRadius: 12 }}>{fmt(x.m)}</span>
                        </motion.button>
                      </motion.div>
                    )
                  })}
                </motion.div>

                <AnimatePresence>
                  {allDone && (
                    <motion.div key="alldone" initial={{ opacity: 0, y: 20, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 10 }} transition={{ ...softSpring, delay: 0.15 }}
                      className="card" style={{ marginTop: 24, background: 'var(--accent-soft)' }}>
                      <Dodo mood="party" size={72} />
                      <div style={{ minWidth: 0 }}>
                        <div className="h3">All done today!</div>
                        <div className="small muted" style={{ marginTop: 4 }}>Future you says thanks. The rest of the evening is yours.</div>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
                {sel >= 0 && !blocked && (
                  <button className="text-btn" onClick={toggleBlock} style={{ margin: '8px 0 0 -12px' }}>{sel === 0 ? 'Can’t work today?' : 'Can’t work on ' + di.wdl + '?'}</button>
                )}
              </motion.div>
            </AnimatePresence>
          </motion.div>
        )}
      </div>
    </>
  )
}

function DayStrip({ ws, sel, onPick }: { ws: number; sel: number; onPick: (d: number) => void }) {
  const m = useModel()
  return (
    <div className="grid7" style={{ marginTop: 20 }}>
      {Array.from({ length: 7 }, (_, k) => {
        const d = ws + k, i = dayInfo(d), isSel = d === sel, isToday = d === 0
        const dots = m.data.blocked[d] ? [] : m.itemsOn(d).slice(0, 4)
        return (
          <motion.button key={d} className="strip-day" aria-label={i.wdl + ' ' + i.num} aria-pressed={isSel} onClick={() => onPick(d)} whileTap={{ scale: 0.9 }}>
            <span style={{ fontSize: 12, lineHeight: '16px', fontWeight: 600, color: 'var(--muted)' }}>{i.wd.charAt(0)}</span>
            <span className="strip-num" style={{ color: isSel ? (isToday ? 'var(--on-accent)' : 'var(--bg)') : isToday ? 'var(--accent)' : d < 0 ? 'var(--muted)' : 'var(--ink)' }}>
              {isSel && <motion.span layoutId="strip-pill" className="strip-pill" style={{ background: isToday ? 'var(--accent)' : 'var(--ink)' }} transition={spring} />}
              {i.num}
            </span>
            <span className="strip-dots">
              {m.data.blocked[d] && d >= 0 ? <i style={{ width: 10, background: 'var(--line)' }} /> : dots.map((x) => (
                <motion.i key={x.t} initial={{ scale: 0 }} animate={{ scale: 1 }} style={{ background: m.isDoneItem(x) ? 'var(--line)' : m.tint(m.byId[x.t]) }} />
              ))}
            </span>
          </motion.button>
        )
      })}
    </div>
  )
}
