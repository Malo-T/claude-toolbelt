import type { EngineInterface, Register } from 'claude-code'

const MINUTE = 60_000
const REFRESH_MS = 30_000
// Below this share of the window the context counts as fresh: green.
const GREEN_PERCENT = 15
// A cache this small is not worth a countdown.
const COLD_MIN_TOKENS = 50_000
// The warning shows this long before the cache expires, at most halfway through its life.
const LEAD_MS = 10 * MINUTE

// Module state: a reload drops it and the next turn rebuilds it.
let ttlMs = 60 * MINUTE
let warnSetting = 0
let critSetting = 0
let lastTurnEndedAt: number | undefined
let ticking = false

function tokens(n: number): string {
  return n >= 1_000_000 && n % 1_000_000 === 0 ? `${n / 1_000_000}M` : `${Math.round(n / 1000)}k`
}

// 42min, 1h05.
function age(ms: number): string {
  const minutes = Math.max(0, Math.floor(ms / MINUTE))
  return minutes < 60 ? `${minutes}min` : `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}`
}

function cacheSegment(used: number, now: number): string {
  if (ttlMs <= 0 || lastTurnEndedAt === undefined || used < COLD_MIN_TOKENS) return ''
  const left = ttlMs - (now - lastTurnEndedAt)
  if (left <= 0) return ' · 🧊 cache froid'
  const icon = left <= Math.min(LEAD_MS, ttlMs / 2) ? '⏳' : '🌞'
  return ` · ${icon} cache ${String(Math.ceil(left / MINUTE)).padStart(2)}min`
}

async function refresh($: EngineInterface): Promise<void> {
  const [{ startedAt, context }, now] = await Promise.all([$.session.usage(), $.clock.now()])
  const used = context.tokens
  const window = context.window
  const warn = warnSetting > 0 ? warnSetting : Math.min(150_000, window * 0.6)
  const crit = critSetting > 0 ? critSetting : Math.min(400_000, window * 0.8)

  const percent = used === undefined ? undefined : Math.round((used / window) * 100)
  let icon = ''
  if (used !== undefined) {
    if (used >= crit) icon = '🛑 '
    else if (used >= warn) icon = '⚠️ '
    else if (percent !== undefined && percent < GREEN_PERCENT) icon = '🟢 '
  }

  const size = used === undefined ? `ctx –/${tokens(window)}` : `ctx ${tokens(used)}/${tokens(window)} (${percent}%)`
  $.ui.status(`${icon}${size}${cacheSegment(used ?? 0, now)} · session ${age(now - startedAt)}`)
}

async function safeRefresh($: EngineInterface): Promise<void> {
  await refresh($).catch(() => undefined)
}

// The countdown moves with the clock, not with events: refresh twice a minute.
function ensureTicking($: EngineInterface): void {
  if (ticking) return
  ticking = true
  $.clock.every(REFRESH_MS, () => safeRefresh($))
}

export const register: Register = (on, options) => {
  ttlMs = Number(options.cacheTtlMinutes ?? 60) * MINUTE
  warnSetting = Number(options.warnTokens ?? 0)
  critSetting = Number(options.critTokens ?? 0)
  ticking = false

  on('session.start', async ($, e, next) => {
    const started = await next(e)
    ensureTicking($)
    await safeRefresh($)
    return started
  })

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    if (e.agentId === undefined) lastTurnEndedAt = await $.clock.now()
    ensureTicking($)
    await safeRefresh($)
    return done
  })

  // /clear starts a new context: the old cache no longer counts.
  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear') lastTurnEndedAt = undefined
    return next(e)
  })
}
