import { useMemo } from 'react'
import { dayInfo, fmt, plan as makePlan, type PlanItem, type Task } from './plan'
import { useStore, type Data } from './store'

export function useModel() {
  const store = useStore()
  const { data, ui, setData, setUI, say } = store

  const byId = useMemo(() => Object.fromEntries(data.tasks.map((t) => [t.id, t])) as Record<string, Task>, [data.tasks])
  const plan = useMemo(() => makePlan(data.tasks, data.blocked, data.limit, data.logToday), [data.tasks, data.blocked, data.limit, data.logToday])
  const active = useMemo(() => data.tasks.filter((t) => !t.done), [data.tasks])

  const isDoneItem = (x: PlanItem) => x.d === 0 && (data.logToday[x.t] || 0) >= x.m
  const itemsOn = (d: number) => plan.items.filter((x) => x.d === d)

  // Apply a change to tasks/logToday; returns the snapshot taken before it, for undo.
  const upd = (fn: (ts: Task[], lt: Record<string, number>) => void): Data => {
    const before = data
    setData((d) => {
      const ts = d.tasks.map((t) => ({ ...t }))
      const lt = { ...d.logToday }
      fn(ts, lt)
      return { ...d, tasks: ts, logToday: lt }
    })
    return before
  }

  const markDone = (x: PlanItem) => upd((ts, lt) => {
    const t = ts.find((y) => y.id === x.t)
    if (!t) return
    const add = Math.max(0, x.m - (x.d === 0 ? lt[x.t] || 0 : 0))
    t.logged += add
    lt[x.t] = (lt[x.t] || 0) + add
  })

  const undoDone = (id: string) => upd((ts, lt) => {
    const t = ts.find((y) => y.id === id)
    if (!t) return
    t.logged = Math.max(0, t.logged - (lt[id] || 0))
    lt[id] = 0
  })

  const toggleItem = (x: PlanItem) => {
    if (isDoneItem(x)) { undoDone(x.t); return }
    const snap = markDone(x)
    navigator.vibrate?.(12)
    say(x.d === 0 ? fmt(x.m) + ' done' : 'Done early — ' + dayInfo(x.d).wdl + ' is lighter now', { undo: snap, tone: 'done' })
  }

  const setHandedIn = (id: string, done: boolean) => {
    const snap = data
    setData((d) => ({ ...d, tasks: d.tasks.map((y) => (y.id === id ? { ...y, done, due: done ? y.due : Math.max(1, y.due) } : y)) }))
    return snap
  }

  const openDetail = (id: string) => setUI((u) => ({ screen: 'detail', detailId: id, back: u.screen === 'detail' ? u.back : u.screen, sheet: null, dialog: null }))
  const openItem = (x: PlanItem) => setUI({ sheet: 'item', item: { t: x.t, d: x.d } })
  const tint = (t: Task) => `var(--tint-${t.tint % 6})`

  return { ...store, data, ui, byId, plan, active, isDoneItem, itemsOn, upd, markDone, undoDone, toggleItem, setHandedIn, openDetail, openItem, tint }
}

export type Model = ReturnType<typeof useModel>
