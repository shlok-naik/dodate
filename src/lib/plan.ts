// Planning logic and date helpers. Days are integer offsets from "today" (0).

export type Task = {
  id: string
  title: string
  due: number
  minutes: number
  logged: number
  tint: number
  done: boolean
}

export type PlanItem = { t: string; d: number; m: number; k: number; n: number }
export type Plan = { items: PlanItem[]; used: Record<number, number>; short: Record<string, number> }

export const LENS = [30, 60, 120, 180]
export const LIMITS = [60, 120, 180, 240, 300]
const WD = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const WDL = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
export const MON = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
const MONS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

export function todayISO(now = new Date()) {
  const y = now.getFullYear(), m = String(now.getMonth() + 1).padStart(2, '0'), d = String(now.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

function base() {
  const n = new Date()
  return new Date(n.getFullYear(), n.getMonth(), n.getDate())
}

export function daysBetween(fromISO: string, toISO: string) {
  const [a, b] = [fromISO, toISO].map((s) => {
    const [y, m, d] = s.split('-').map(Number)
    return Date.UTC(y, m - 1, d)
  })
  return Math.round((b - a) / 86400000)
}

export function fmt(m: number) {
  m = Math.max(0, Math.round(m))
  const h = Math.floor(m / 60), r = m % 60
  return h ? h + 'h' + (r ? ' ' + r + 'm' : '') : r + 'm'
}

export function dateOf(d: number) {
  const b = base()
  return new Date(b.getFullYear(), b.getMonth(), b.getDate() + d)
}

export function dayInfo(d: number) {
  const dt = dateOf(d)
  return {
    wd: WD[dt.getDay()], wdl: WDL[dt.getDay()], num: dt.getDate(),
    mon: MON[dt.getMonth()], mons: MONS[dt.getMonth()], m: dt.getMonth(), y: dt.getFullYear(),
  }
}

export function indexOf(y: number, m: number, dnum: number) {
  return Math.round((new Date(y, m, dnum).getTime() - dateOf(0).getTime()) / 86400000)
}

export function rel(d: number) {
  if (d < 0) return 'overdue'
  if (d === 0) return 'today'
  if (d === 1) return 'tomorrow'
  const i = dayInfo(d)
  return d < 7 ? i.wdl : i.wd + ' ' + i.num + ' ' + i.mons
}

// Spread each task's remaining minutes over the days before it's due,
// earliest deadline first, never exceeding `limit` minutes a day.
export function plan(tasks: Task[], blocked: Record<number, boolean>, limit: number, logToday: Record<string, number>): Plan {
  const used: Record<number, number> = {}, items: PlanItem[] = [], short: Record<string, number> = {}
  const active = tasks.filter((t) => !t.done).slice().sort((a, b) => a.due - b.due)
  for (const t of active) {
    const R = Math.max(0, t.minutes - (t.logged - (logToday[t.id] || 0)))
    if (R <= 0) continue
    let days: number[] = []
    for (let d = 0; d <= Math.max(0, t.due - 1); d++) if (!blocked[d]) days.push(d)
    if (!days.length) days = [0]
    const alloc: Record<number, number> = {}
    let left = R
    const target = Math.max(Math.min(R, 30), Math.ceil(R / days.length / 15) * 15)
    for (const d of days) {
      const g = Math.min(Math.max(0, limit - (used[d] || 0)), target, left)
      if (g > 0) { alloc[d] = g; left -= g }
    }
    for (const d of days) {
      if (left <= 0) break
      const g = Math.min(Math.max(0, limit - (used[d] || 0) - (alloc[d] || 0)), left)
      if (g > 0) { alloc[d] = (alloc[d] || 0) + g; left -= g }
    }
    if (left > 0) {
      short[t.id] = left
      const ld = days[days.length - 1]
      alloc[ld] = (alloc[ld] || 0) + left
    }
    const mine = days.filter((d) => alloc[d] > 0)
    mine.forEach((d, k) => {
      used[d] = (used[d] || 0) + alloc[d]
      items.push({ t: t.id, d, m: alloc[d], k: k + 1, n: mine.length })
    })
  }
  return { items, used, short }
}

// Smallest daily limit (in 30m steps, up to 8h) at which `id` fits, or null.
export function limitToFit(tasks: Task[], blocked: Record<number, boolean>, limit: number, logToday: Record<string, number>, id: string) {
  for (let x = limit + 30; x <= 480; x += 30) if (!plan(tasks, blocked, x, logToday).short[id]) return x
  return null
}
