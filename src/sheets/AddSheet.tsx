import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'
import { Dodo } from '../components/Dodo'
import { ChevronD, ChevronL, ChevronR, Minus, Plus } from '../components/Icons'
import { Chips, Flip } from '../components/ui'
import { softSpring, spring } from '../components/motion'
import { useModel } from '../lib/model'
import { LENS, MON, dayInfo, fmt, indexOf, plan as makePlan } from '../lib/plan'

type Draft = { title: string; due: number; minutes: number; calOpen: boolean; lenOpen: boolean; calMonth: null | { y: number; m: number } }
const newDraft = (): Draft => ({ title: '', due: 3, minutes: 60, calOpen: false, lenOpen: false, calMonth: null })

const collapse = { initial: { height: 0, opacity: 0 }, animate: { height: 'auto', opacity: 1 }, exit: { height: 0, opacity: 0 }, transition: softSpring }

export function AddSheet({ onClose }: { onClose: () => void }) {
  const m = useModel()
  const { data, setData, setUI, say, plan, byId } = m
  const [D, setDraft] = useState<Draft>(newDraft)
  const setD = (p: Partial<Draft>) => setDraft((d) => ({ ...d, ...p }))
  const input = useRef<HTMLInputElement>(null)
  const [shake, setShake] = useState(0)
  useEffect(() => { const t = window.setTimeout(() => input.current?.focus(), 350); return () => window.clearTimeout(t) }, [])

  const L = data.limit
  const dI = dayInfo(D.due)
  const farDate = D.due > 7
  const customLen = !LENS.includes(D.minutes)

  // Preview how the new task would be split, without committing it.
  const draftTask = { id: '__d', title: D.title, due: D.due, minutes: D.minutes, logged: 0, tint: data.nextTint, done: false }
  const pp = makePlan(data.tasks.concat([draftTask]), data.blocked, L, data.logToday)
  const per: Record<number, number> = {}
  pp.items.forEach((x) => { if (x.t === '__d') per[x.d] = x.m })
  const nP = Object.keys(per).length, shortBy = pp.short['__d'] || 0
  const bumped = Object.keys(pp.short).filter((id) => id !== '__d' && !plan.short[id] && byId[id])
  const bumpedName = bumped.length ? byId[bumped[0]].title + (bumped.length > 1 ? ' and ' + (bumped.length - 1) + ' more' : '') : ''
  const mx = Math.max(30, ...Object.values(per))
  const nb = Math.max(1, Math.min(D.due, 14))
  const trouble = !!(shortBy || bumped.length)
  const has = !!D.title.trim()

  const save = () => {
    if (!has) { input.current?.focus(); setShake((s) => s + 1); return }
    const id = 't' + Date.now()
    const nt = { id, title: D.title.trim(), due: D.due, minutes: D.minutes, logged: 0, tint: data.nextTint, done: false }
    const all = data.tasks.concat([nt])
    const ck = makePlan(all, data.blocked, L, data.logToday)
    const hit = ck.short[id] ? id : Object.keys(ck.short).find((k) => !plan.short[k])
    const snap = data
    setData((d) => ({ ...d, tasks: all, nextTint: (d.nextTint + 1) % 6 }))
    setUI({ sheet: null, dialog: hit ? { id: hit } : null })
    if (!hit) say('Added — ' + (nP === 1 ? 'one piece' : nP + ' pieces'), { undo: snap, tone: 'done' })
  }

  // Month calendar
  const cm = D.calMonth || { y: dI.y, m: dI.m }
  const lead = (new Date(cm.y, cm.m, 1).getDay() + 6) % 7
  const dim = new Date(cm.y, cm.m + 1, 0).getDate()
  const base = dayInfo(0)
  const atFirst = cm.y === base.y && cm.m === base.m
  const shiftMonth = (k: number) => { const nm = new Date(cm.y, cm.m + k, 1); setD({ calMonth: { y: nm.getFullYear(), m: nm.getMonth() } }) }

  const rowStyle = (on: boolean) => ({
    marginTop: 8, width: '100%', height: 56, borderRadius: 16, padding: '0 12px 0 16px', display: 'flex', alignItems: 'center', gap: 8,
    background: on ? 'var(--chip-on)' : 'var(--alt)', color: on ? 'var(--chip-on-ink)' : 'var(--ink)', transition: 'background 0.2s, color 0.2s',
  })

  return (
    <>
      <div style={{ flex: 'none', height: 48, padding: '0 16px 0 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button className="text-btn" style={{ marginLeft: -12, fontSize: 16 }} onClick={onClose}>Cancel</button>
        <motion.button whileTap={{ scale: 0.94 }} onClick={save}
          style={{ height: 40, padding: '0 24px', borderRadius: 20, fontWeight: 700, background: has ? 'var(--accent)' : 'var(--alt)', color: has ? 'var(--on-accent)' : 'var(--muted)', transition: 'background 0.2s, color 0.2s' }}>Add</motion.button>
      </div>
      <div className="scroll" style={{ padding: '16px 24px 48px', touchAction: 'pan-y' }}>
        <label htmlFor="dd-title" style={{ position: 'absolute', width: 1, height: 1, overflow: 'hidden', clip: 'rect(0 0 0 0)' }}>Homework</label>
        <motion.input key={shake} animate={shake ? { x: [0, -8, 8, -6, 6, 0] } : {}} transition={{ duration: 0.35 }}
          id="dd-title" ref={input} value={D.title} onChange={(e) => setD({ title: e.target.value })} onKeyDown={(e) => { if (e.key === 'Enter') save() }}
          placeholder="What's the homework?" autoComplete="off" enterKeyHint="done"
          style={{ display: 'block', border: 'none', background: 'transparent', padding: 0, width: '100%', height: 36, fontFamily: 'var(--display)', fontWeight: 800, fontSize: 28, lineHeight: '32px', letterSpacing: -0.8, color: 'var(--ink)', outline: 'none', caretColor: 'var(--accent)' }} />

        <div style={{ marginTop: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span className="kicker">Due</span>
          <span className="small" style={{ fontWeight: 600 }}><Flip value={dI.wdl + ' ' + dI.num + ' ' + dI.mons} /></span>
        </div>
        <div style={{ marginTop: 8 }}>
          <Chips ariaLabel="Due date" height={64} value={farDate ? null : D.due} onPick={(d) => setD({ due: d, calOpen: false })}
            options={Array.from({ length: 7 }, (_, q) => { const d = q + 1, i = dayInfo(d); return { v: d, label: '', aria: i.wdl + ' ' + i.num + ' ' + i.mon } })}
            render={(o) => {
              const i = dayInfo(o.v as number)
              return <><span style={{ fontSize: 12, lineHeight: '16px', fontWeight: 600, opacity: 0.8 }}>{o.v === 1 ? 'Tmrw' : i.wd}</span><span style={{ fontWeight: 700 }}>{i.num}</span></>
            }} />
        </div>
        <button onClick={() => setD({ calOpen: !D.calOpen, lenOpen: false, calMonth: null })} aria-expanded={D.calOpen} style={rowStyle(farDate && !D.calOpen)}>
          <span style={{ flex: 1, textAlign: 'left', fontWeight: 600 }}>Another date</span>
          <span className="small" style={{ fontWeight: 600, opacity: 0.8 }}>{farDate ? dI.wd + ' ' + dI.num + ' ' + dI.mons : ''}</span>
          <motion.span animate={{ rotate: D.calOpen ? 180 : 0 }} style={{ display: 'flex' }}><ChevronD /></motion.span>
        </button>
        <AnimatePresence initial={false}>
          {D.calOpen && (
            <motion.div key="cal" {...collapse} style={{ overflow: 'hidden' }}>
              <div style={{ marginTop: 8, background: 'var(--alt)', borderRadius: 24, padding: 8 }}>
                <div style={{ height: 48, display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingLeft: 12 }}>
                  <span style={{ fontWeight: 700 }}><Flip value={MON[cm.m] + ' ' + cm.y} /></span>
                  <span style={{ display: 'flex' }}>
                    <button className="icon-btn" disabled={atFirst} aria-label="Previous month" onClick={() => !atFirst && shiftMonth(-1)} style={{ color: atFirst ? 'var(--disabled)' : 'var(--ink)' }}><ChevronL /></button>
                    <button className="icon-btn" aria-label="Next month" onClick={() => shiftMonth(1)} style={{ color: 'var(--ink)' }}><ChevronR /></button>
                  </span>
                </div>
                <div className="grid7" style={{ height: 32, alignItems: 'center', textAlign: 'center', fontSize: 12, lineHeight: '16px', fontWeight: 700, color: 'var(--muted)' }}>
                  {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((x, i) => <span key={i}>{x}</span>)}
                </div>
                <div className="grid7" style={{ rowGap: 4 }}>
                  {Array.from({ length: lead }, (_, e) => <span key={'e' + e} />)}
                  {Array.from({ length: dim }, (_, n) => {
                    const dn = n + 1, idx = indexOf(cm.y, cm.m, dn), on = idx === D.due, dis = idx < 1, isToday = idx === 0
                    return (
                      <span key={dn} style={{ height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <motion.button whileTap={dis ? undefined : { scale: 0.85 }} disabled={dis} aria-label={dn + ' ' + MON[cm.m]} aria-pressed={on} onClick={() => setD({ due: idx })}
                          style={{ width: 40, height: 40, borderRadius: 20, position: 'relative', fontWeight: on ? 700 : 500, color: on ? 'var(--chip-on-ink)' : dis ? 'var(--disabled)' : isToday ? 'var(--accent)' : 'var(--ink)', boxShadow: isToday && !on ? 'inset 0 0 0 2px var(--accent)' : 'none' }}>
                          {on && <motion.span layoutId="cal-on" transition={spring} style={{ position: 'absolute', inset: 0, borderRadius: 20, background: 'var(--chip-on)' }} />}
                          <span style={{ position: 'relative' }}>{dn}</span>
                        </motion.button>
                      </span>
                    )
                  })}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        <div style={{ marginTop: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span className="kicker">How long it will take</span>
          <span className="small num" style={{ fontWeight: 600 }}><Flip value={fmt(D.minutes)} /></span>
        </div>
        <div style={{ marginTop: 8 }}>
          <Chips ariaLabel="Length" value={customLen ? null : D.minutes} onPick={(v) => setD({ minutes: v, lenOpen: false })} options={LENS.map((v) => ({ v, label: fmt(v) }))} />
        </div>
        <button onClick={() => setD({ lenOpen: !D.lenOpen, calOpen: false })} aria-expanded={D.lenOpen} style={rowStyle(customLen && !D.lenOpen)}>
          <span style={{ flex: 1, textAlign: 'left', fontWeight: 600 }}>Another length</span>
          <span className="small" style={{ fontWeight: 600, opacity: 0.8 }}>{customLen ? fmt(D.minutes) : ''}</span>
          <motion.span animate={{ rotate: D.lenOpen ? 180 : 0 }} style={{ display: 'flex' }}><ChevronD /></motion.span>
        </button>
        <AnimatePresence initial={false}>
          {D.lenOpen && (
            <motion.div key="len" {...collapse} style={{ overflow: 'hidden' }}>
              <div style={{ marginTop: 8, background: 'var(--alt)', borderRadius: 24, padding: 8, display: 'flex', flexDirection: 'column', gap: 8 }}>
                {[
                  { label: 'Hours', value: String(Math.floor(D.minutes / 60)), dec: 60, decLabel: 'One hour less', incLabel: 'One hour more' },
                  { label: 'Minutes', value: String(D.minutes % 60).padStart(2, '0'), dec: 15, decLabel: '15 minutes less', incLabel: '15 minutes more' },
                ].map((sp) => (
                  <div key={sp.label} style={{ height: 64, background: 'var(--bg)', borderRadius: 16, padding: '0 8px 0 16px', display: 'flex', alignItems: 'center' }}>
                    <span style={{ flex: 1, fontWeight: 600 }}>{sp.label}</span>
                    <motion.button whileTap={{ scale: 0.88 }} aria-label={sp.decLabel} onClick={() => setD({ minutes: Math.max(15, D.minutes - sp.dec) })}
                      style={{ width: 48, height: 48, borderRadius: 24, background: 'var(--alt)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Minus /></motion.button>
                    <span aria-live="polite" className="num" style={{ width: 64, display: 'flex', justifyContent: 'center', fontFamily: 'var(--display)', fontWeight: 800, fontSize: 20, lineHeight: '24px' }}><Flip value={sp.value} /></span>
                    <motion.button whileTap={{ scale: 0.88 }} aria-label={sp.incLabel} onClick={() => setD({ minutes: Math.min(1200, D.minutes + sp.dec) })}
                      style={{ width: 48, height: 48, borderRadius: 24, background: 'var(--alt)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Plus /></motion.button>
                  </div>
                ))}
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Live preview of how the work gets split across the days. */}
        <div style={{ marginTop: 32, paddingTop: 24, borderTop: '1px solid var(--line)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <Dodo mood={trouble ? 'sweat' : 'write'} size={56} />
            <div style={{ minWidth: 0 }}>
              <AnimatePresence mode="wait" initial={false}>
                <motion.div key={(trouble ? 't' : 'o') + nP + shortBy} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.15 }}
                  style={{ fontWeight: 700, color: trouble ? 'var(--warn-text)' : 'var(--ink)' }}>
                  {shortBy ? 'Won’t fit — ' + fmt(shortBy) + ' over your limit' : bumped.length ? 'Fits, but ' + bumpedName + ' won’t' : nP === 1 ? 'Done in one go' : 'Split into ' + nP + ' pieces'}
                </motion.div>
              </AnimatePresence>
              <div className="small muted">{trouble ? 'Pick a later date or a shorter length.' : nP > 1 ? 'About ' + fmt(Math.round(D.minutes / nP / 15) * 15) + ' a day, around your other homework.' : 'Fits around your other homework.'}</div>
            </div>
          </div>
          <div style={{ marginTop: 16, display: 'flex', gap: 4, alignItems: 'flex-end' }}>
            {Array.from({ length: nb }, (_, b) => {
              const bi = dayInfo(b)
              const h = per[b] ? Math.max(8, Math.round((per[b] / mx) * 48)) : 4
              const c = per[b] ? (shortBy && b === nb - 1 ? 'var(--warn-bar)' : `var(--tint-${data.nextTint % 6})`) : 'var(--line)'
              return (
                <div key={b} style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                  <div style={{ width: '100%', height: 48, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
                    <motion.div initial={{ height: 0 }} animate={{ height: h }} transition={{ ...spring, delay: b * 0.02 }} style={{ width: '100%', borderRadius: 4, background: c, transition: 'background 0.25s' }} />
                  </div>
                  <span style={{ fontSize: 12, lineHeight: '16px', fontWeight: 600, color: 'var(--muted)' }}>{nb > 10 ? bi.wd.charAt(0) : b === 0 ? 'Tod' : bi.wd.charAt(0) + bi.num}</span>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </>
  )
}
