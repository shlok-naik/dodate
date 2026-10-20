import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { daysBetween, todayISO, type Task } from './plan'

export type Screen = 'day' | 'week' | 'deadlines' | 'detail'
export type Sheet = null | 'add' | 'item' | 'settings'
export type Theme = 'light' | 'dark' | null

// Everything that survives a reload. Day numbers are offsets from `anchor`.
export type Data = {
  anchor: string
  limit: number
  blocked: Record<number, boolean>
  theme: Theme
  nextTint: number
  logToday: Record<string, number>
  tasks: Task[]
}

export type UI = {
  screen: Screen
  back: Screen
  sheet: Sheet
  dialog: null | { id: string }
  detailId: string | null
  item: null | { t: string; d: number }
  weekOffset: number
  selDay: number
}

export type Toast = { id: number; msg: string; undo?: Data; tone?: 'done' | 'info' | 'warn' }

const KEY = 'dodate:v1'

export function seed(theme: Theme = null): Data {
  return {
    anchor: todayISO(), limit: 180, blocked: { 5: true }, theme, nextTint: 4, logToday: { mat: 45 },
    tasks: [
      { id: 'mat', title: 'Maths vectors', due: 2, minutes: 90, logged: 45, tint: 2, done: false },
      { id: 'his', title: 'History essay', due: 3, minutes: 180, logged: 0, tint: 0, done: false },
      { id: 'phy', title: 'Physics write-up', due: 4, minutes: 360, logged: 0, tint: 1, done: false },
      { id: 'fre', title: 'French writing', due: 7, minutes: 180, logged: 0, tint: 3, done: false },
      { id: 'bio', title: 'Biology notes', due: -2, minutes: 90, logged: 90, tint: 5, done: true },
    ],
  }
}

// Re-anchor saved data to today: shift day offsets and start a fresh day log.
function rollForward(d: Data): Data {
  const today = todayISO()
  const delta = daysBetween(d.anchor, today)
  if (delta === 0) return d
  const blocked: Record<number, boolean> = {}
  for (const k of Object.keys(d.blocked)) if (+k - delta >= 0) blocked[+k - delta] = true
  return { ...d, anchor: today, blocked, logToday: {}, tasks: d.tasks.map((t) => ({ ...t, due: t.due - delta })) }
}

function load(): Data {
  try {
    const raw = localStorage.getItem(KEY)
    if (raw) return rollForward(JSON.parse(raw))
  } catch { /* storage unavailable or corrupt */ }
  return seed()
}

type Store = {
  data: Data
  ui: UI
  toast: Toast | null
  setData: (fn: (d: Data) => Data) => void
  setUI: (p: Partial<UI> | ((u: UI) => Partial<UI>)) => void
  say: (msg: string, opts?: { undo?: Data; tone?: Toast['tone'] }) => void
  dismissToast: () => void
  undo: () => void
  party: number
  celebrate: () => void
}

const Ctx = createContext<Store | null>(null)

export function StoreProvider({ children }: { children: ReactNode }) {
  const [data, setDataRaw] = useState<Data>(load)
  const [ui, setUIRaw] = useState<UI>({ screen: 'day', back: 'day', sheet: null, dialog: null, detailId: null, item: null, weekOffset: 0, selDay: 0 })
  const [toast, setToast] = useState<Toast | null>(null)
  const [party, setParty] = useState(0)
  const celebrate = useCallback(() => setParty((p) => p + 1), [])
  const timer = useRef<number | undefined>(undefined)

  useEffect(() => {
    try { localStorage.setItem(KEY, JSON.stringify(data)) } catch { /* ignore */ }
  }, [data])

  // Keep "today" correct if the app stays open past midnight.
  useEffect(() => {
    const id = window.setInterval(() => setDataRaw((d) => rollForward(d)), 60_000)
    return () => window.clearInterval(id)
  }, [])

  const setData = useCallback((fn: (d: Data) => Data) => setDataRaw(fn), [])
  const setUI = useCallback((p: Partial<UI> | ((u: UI) => Partial<UI>)) => setUIRaw((u) => ({ ...u, ...(typeof p === 'function' ? p(u) : p) })), [])
  const dismissToast = useCallback(() => { window.clearTimeout(timer.current); setToast(null) }, [])
  const say = useCallback((msg: string, opts?: { undo?: Data; tone?: Toast['tone'] }) => {
    window.clearTimeout(timer.current)
    setToast({ id: Date.now(), msg, ...opts })
    timer.current = window.setTimeout(() => setToast(null), opts?.undo ? 4000 : 2400)
  }, [])
  const toastRef = useRef(toast)
  useEffect(() => { toastRef.current = toast }, [toast])
  const undo = useCallback(() => {
    const snap = toastRef.current?.undo
    if (snap) setDataRaw(snap)
    window.clearTimeout(timer.current)
    setToast(null)
  }, [])

  const value = useMemo(() => ({ data, ui, toast, setData, setUI, say, dismissToast, undo, party, celebrate }), [data, ui, toast, setData, setUI, say, dismissToast, undo, party, celebrate])
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useStore() {
  const s = useContext(Ctx)
  if (!s) throw new Error('useStore outside StoreProvider')
  return s
}
