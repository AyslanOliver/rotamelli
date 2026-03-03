import { Hono } from 'hono'
import { cors } from 'hono/cors'
import type { D1Database } from '@cloudflare/workers-types'

type Bindings = {
  DB: D1Database
  AVULSO_UNIT?: string
  AUTH_SECRET?: string
}

const app = new Hono<{ Bindings: Bindings }>()

// CORS para chamadas do admin (localhost, etc.)
app.use('/*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  maxAge: 600
}))

// Preflight explícito para qualquer rota
app.options('/*', (c) => {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '600'
    }
  })
})

// ------- Auth helpers -------
function b64url(data: ArrayBuffer) {
  const str = String.fromCharCode.apply(null, Array.from(new Uint8Array(data)) as any)
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
function b64urlStr(s: string) {
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
async function signJWT(secret: string, payload: any) {
  const enc = new TextEncoder()
  const header = { alg: 'HS256', typ: 'JWT' }
  const headerB64 = b64urlStr(JSON.stringify(header))
  const payloadB64 = b64urlStr(JSON.stringify(payload))
  const toSign = `${headerB64}.${payloadB64}`
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(toSign))
  const sigB64 = b64url(sig)
  return `${toSign}.${sigB64}`
}
async function verifyJWT(secret: string, token: string) {
  const enc = new TextEncoder()
  const parts = token.split('.')
  if (parts.length !== 3) return null
  const [h, p, s] = parts
  const toSign = `${h}.${p}`
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'])
  const sigBin = Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0))
  const ok = await crypto.subtle.verify('HMAC', key, sigBin, enc.encode(toSign))
  if (!ok) return null
  const payload = JSON.parse(atob(p.replace(/-/g, '+').replace(/_/g, '/')))
  if (payload?.exp && Date.now() / 1000 > payload.exp) return null
  return payload
}
function requireAdmin(handler: (c: any) => Promise<Response> | Response) {
  return async (c: any) => {
    const secret = c.env.AUTH_SECRET || 'dev-secret'
    const auth = c.req.header('Authorization') || ''
    const m = auth.match(/^Bearer\s+(.+)$/)
    if (!m) return c.json({ ok: false, error: 'unauthorized' }, 401)
    const payload = await verifyJWT(secret, m[1])
    if (!payload || payload.role !== 'admin') return c.json({ ok: false, error: 'forbidden' }, 403)
    return handler(c)
  }
}

const endpoints = [
  'GET /health',
  'POST /api/rotas',
  'GET  /api/rotas?year=YYYY&month=MM',
  'POST /api/despesas',
  'GET  /api/despesas?year=YYYY&month=MM',
  'GET  /api/metrics/avulso-mes?year=YYYY&month=MM',
  'GET  /api/users',
  'POST /api/users',
  'PUT  /api/users/:id',
  'DELETE /api/users/:id'
]

app.get('/', (c) => c.json({ name: 'rota-ml-cloudflare-api', status: 'ok', endpoints }))

app.get('/health', (c) => c.json({ ok: true }))

// Login
app.post('/api/login', async (c) => {
  await ensureUsers(c.env.DB)
  const body = await c.req.json()
  const email = String(body?.email ?? '').toLowerCase().trim()
  const pin = String(body?.pin ?? '').trim()
  if (!email || !pin) return c.json({ ok: false, error: 'email/pin obrigatórios' }, 400)
  const { results } = await c.env.DB.prepare(`SELECT id, name, email, role, active, pinHash FROM users WHERE email = ?`).bind(email).all()
  const u = (results ?? [])[0] as any
  if (!u || Number(u.active) === 0) return c.json({ ok: false, error: 'usuário inválido' }, 401)
  const pinHash = await hashPin(pin)
  if ((u.pinHash ?? '') !== pinHash) return c.json({ ok: false, error: 'pin inválido' }, 401)
  const exp = Math.floor(Date.now() / 1000) + 12 * 60 * 60 // 12h
  const token = await signJWT(c.env.AUTH_SECRET || 'dev-secret', { sub: u.id, email: u.email, role: u.role ?? 'user', exp })
  return c.json({ ok: true, token, user: { id: u.id, name: u.name, email: u.email, role: u.role, active: u.active } })
})

app.post('/api/rotas', async (c) => {
  const doc = await c.req.json()
  const dt = doc?.dataRota ? new Date(doc.dataRota) : new Date()
  const res = await c.env.DB.prepare(
    `INSERT INTO rotas (nomeRota, dataRotaMillis, placaCarro, quantidadePacotes, pacotesVulso, tipoVeiculo, valorCalculado)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      doc?.nomeRota ?? null,
      dt.getTime(),
      doc?.placaCarro ?? null,
      Number(doc?.quantidadePacotes ?? 0),
      Number(doc?.pacotesVulso ?? 0),
      doc?.tipoVeiculo ?? null,
      doc?.valorCalculado != null ? Number(doc.valorCalculado) : null
    )
    .run()
  return c.json({ ok: true, id: (res as any)?.meta?.last_row_id ?? null }, 201)
})

app.get('/api/rotas', async (c) => {
  const year = Number(c.req.query('year'))
  const month = Number(c.req.query('month'))
  const start = new Date(year, month - 1, 1).getTime()
  const end = new Date(year, month, 0, 23, 59, 59, 999).getTime()
  const { results } = await c.env.DB.prepare(
    `SELECT id, nomeRota, dataRotaMillis, placaCarro, quantidadePacotes, pacotesVulso, tipoVeiculo, valorCalculado
     FROM rotas
     WHERE dataRotaMillis BETWEEN ? AND ?
     ORDER BY dataRotaMillis DESC`
  )
    .bind(start, end)
    .all()
  return c.json(results ?? [])
})

app.post('/api/despesas', async (c) => {
  const doc = await c.req.json()
  const dt = doc?.dataDespesa ? new Date(doc.dataDespesa) : new Date()
  const res = await c.env.DB.prepare(
    `INSERT INTO despesas (descricao, dataDespesaMillis, valor, categoria)
     VALUES (?, ?, ?, ?)`
  )
    .bind(doc?.descricao ?? null, dt.getTime(), Number(doc?.valor ?? 0), doc?.categoria ?? null)
    .run()
  return c.json({ ok: true, id: (res as any)?.meta?.last_row_id ?? null }, 201)
})

app.put('/api/rotas/:id', async (c) => {
  const id = Number(c.req.param('id'))
  const doc = await c.req.json()
  const dt = doc?.dataRota ? new Date(doc.dataRota) : new Date()
  const res = await c.env.DB.prepare(
    `UPDATE rotas
     SET nomeRota = ?, dataRotaMillis = ?, placaCarro = ?, quantidadePacotes = ?, pacotesVulso = ?, tipoVeiculo = ?, valorCalculado = ?
     WHERE id = ?`
  )
    .bind(
      doc?.nomeRota ?? null,
      dt.getTime(),
      doc?.placaCarro ?? null,
      Number(doc?.quantidadePacotes ?? 0),
      Number(doc?.pacotesVulso ?? 0),
      doc?.tipoVeiculo ?? null,
      doc?.valorCalculado != null ? Number(doc.valorCalculado) : null,
      id
    )
    .run()
  return c.json({ ok: true, changes: Number(((res as any)?.meta?.changes ?? 0)) })
})

app.delete('/api/rotas/:id', async (c) => {
  const id = Number(c.req.param('id'))
  const res = await c.env.DB.prepare(`DELETE FROM rotas WHERE id = ?`).bind(id).run()
  return c.json({ ok: true, changes: Number(((res as any)?.meta?.changes ?? 0)) })
})

app.put('/api/despesas/:id', async (c) => {
  const id = Number(c.req.param('id'))
  const doc = await c.req.json()
  const dt = doc?.dataDespesa ? new Date(doc.dataDespesa) : new Date()
  const res = await c.env.DB.prepare(
    `UPDATE despesas
     SET descricao = ?, dataDespesaMillis = ?, valor = ?, categoria = ?
     WHERE id = ?`
  )
    .bind(doc?.descricao ?? null, dt.getTime(), Number(doc?.valor ?? 0), doc?.categoria ?? null, id)
    .run()
  return c.json({ ok: true, changes: Number(((res as any)?.meta?.changes ?? 0)) })
})

app.delete('/api/despesas/:id', async (c) => {
  const id = Number(c.req.param('id'))
  const res = await c.env.DB.prepare(`DELETE FROM despesas WHERE id = ?`).bind(id).run()
  return c.json({ ok: true, changes: Number(((res as any)?.meta?.changes ?? 0)) })
})

app.get('/api/despesas', async (c) => {
  const year = Number(c.req.query('year'))
  const month = Number(c.req.query('month'))
  const start = new Date(year, month - 1, 1).getTime()
  const end = new Date(year, month, 0, 23, 59, 59, 999).getTime()
  const { results } = await c.env.DB.prepare(
    `SELECT id, descricao, dataDespesaMillis, valor, categoria
     FROM despesas
     WHERE dataDespesaMillis BETWEEN ? AND ?
     ORDER BY dataDespesaMillis DESC`
  )
    .bind(start, end)
    .all()
  return c.json(results ?? [])
})

app.get('/api/metrics/avulso-mes', async (c) => {
  const year = Number(c.req.query('year'))
  const month = Number(c.req.query('month'))
  const start = new Date(year, month - 1, 1).getTime()
  const end = new Date(year, month, 0, 23, 59, 59, 999).getTime()
  const { results } = await c.env.DB.prepare(
    `SELECT SUM(COALESCE(pacotesVulso, 0)) AS totalPacotes
     FROM rotas
     WHERE dataRotaMillis BETWEEN ? AND ?`
  )
    .bind(start, end)
    .all()
  const totalPacotes = Number((results?.[0] as any)?.totalPacotes ?? 0)
  const unit = Number(c.env.AVULSO_UNIT ?? 2)
  const total = totalPacotes * unit
  return c.json({ total })
})

app.post('/api/import', async (c) => {
  try {
    const payload = await c.req.json()
    if (!payload || typeof payload !== 'object') {
      return c.json({ ok: false, error: 'Payload inválido' }, 400)
    }
    const rotas: any[] = Array.isArray(payload?.rotas) ? payload.rotas : []
    const despesas: any[] = Array.isArray(payload?.despesas) ? payload.despesas : []
    const parseDate = (s: any) => {
      if (typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s)) return new Date(s + 'T00:00:00Z')
      const d = new Date(s)
      return Number.isNaN(d.getTime()) ? new Date() : d
    }
    const rotaStmts = rotas.map((r) =>
      c.env.DB
        .prepare(
          `INSERT INTO rotas (nomeRota, dataRotaMillis, placaCarro, quantidadePacotes, pacotesVulso, tipoVeiculo, valorCalculado)
           VALUES (?, ?, ?, ?, ?, ?, ?)`
        )
        .bind(
          r?.nomeRota ?? null,
          parseDate(r?.dataRota).getTime(),
          r?.placaCarro ?? null,
          Number(r?.quantidadePacotes ?? 0),
          Number(r?.pacotesVulso ?? 0),
          r?.tipoVeiculo ?? null,
          r?.valorCalculado != null ? Number(r.valorCalculado) : null
        )
    )
    const despesaStmts = despesas.map((d) =>
      c.env.DB
        .prepare(
          `INSERT INTO despesas (descricao, dataDespesaMillis, valor, categoria)
           VALUES (?, ?, ?, ?)`
        )
        .bind(d?.descricao ?? null, parseDate(d?.dataDespesa).getTime(), Number(d?.valor ?? 0), d?.categoria ?? null)
    )
    const chunks = (arr: any[], size: number) => {
      const out: any[] = []
      for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size))
      return out
    }
    const runBatch = async (stmts: any[]) => {
      for (const cks of chunks(stmts, 10)) {
        await c.env.DB.batch(cks as any)
      }
    }
    if (rotaStmts.length) await runBatch(rotaStmts)
    if (despesaStmts.length) await runBatch(despesaStmts)
    return c.json({ ok: true, imported: { rotas: rotas.length, despesas: despesas.length } })
  } catch (err: any) {
    const msg = err?.message ?? String(err)
    return c.json({ ok: false, error: msg }, 500)
  }
})

async function ensureUsers(db: D1Database) {
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      email TEXT UNIQUE,
      role TEXT,
      active INTEGER DEFAULT 1,
      pinHash TEXT
    )`
  ).run()
}

function hashPin(pin: string) {
  const data = new TextEncoder().encode(pin)
  return crypto.subtle.digest('SHA-256', data).then((buf) => {
    const arr = Array.from(new Uint8Array(buf))
    return arr.map((b) => b.toString(16).padStart(2, '0')).join('')
  })
}

app.get('/api/users', requireAdmin(async (c) => {
  await ensureUsers(c.env.DB)
  const { results } = await c.env.DB.prepare(
    `SELECT id, name, email, role, active FROM users ORDER BY name ASC`
  ).all()
  return c.json(results ?? [])
}))

app.post('/api/users', requireAdmin(async (c) => {
  await ensureUsers(c.env.DB)
  const doc = await c.req.json()
  const name = String(doc?.name ?? '').trim()
  const email = String(doc?.email ?? '').trim().toLowerCase()
  const role = String(doc?.role ?? 'user').trim()
  const active = Number(doc?.active ?? 1) === 0 ? 0 : 1
  const pin = String(doc?.pin ?? '').trim()
  if (!name || !email) return c.json({ ok: false, error: 'Nome e e-mail obrigatórios' }, 400)
  const pinHash = pin ? await hashPin(pin) : null
  const res = await c.env.DB.prepare(
    `INSERT INTO users (name, email, role, active, pinHash) VALUES (?, ?, ?, ?, ?)`
  ).bind(name, email, role, active, pinHash).run()
  return c.json({ ok: true, id: (res as any)?.meta?.last_row_id ?? null }, 201)
}))

app.put('/api/users/:id', requireAdmin(async (c) => {
  await ensureUsers(c.env.DB)
  const id = Number(c.req.param('id'))
  const doc = await c.req.json()
  const name = doc?.name != null ? String(doc.name).trim() : null
  const email = doc?.email != null ? String(doc.email).trim().toLowerCase() : null
  const role = doc?.role != null ? String(doc.role).trim() : null
  const active = doc?.active != null ? (Number(doc.active) === 0 ? 0 : 1) : null
  const pin = doc?.pin != null ? String(doc.pin).trim() : null
  const pinHash = pin ? await hashPin(pin) : null
  const res = await c.env.DB.prepare(
    `UPDATE users
     SET name = COALESCE(?, name),
         email = COALESCE(?, email),
         role = COALESCE(?, role),
         active = COALESCE(?, active),
         pinHash = COALESCE(?, pinHash)
     WHERE id = ?`
  ).bind(name, email, role, active, pinHash, id).run()
  return c.json({ ok: true, changes: Number(((res as any)?.meta?.changes ?? 0)) })
}))

app.delete('/api/users/:id', requireAdmin(async (c) => {
  await ensureUsers(c.env.DB)
  const id = Number(c.req.param('id'))
  const res = await c.env.DB.prepare(`DELETE FROM users WHERE id = ?`).bind(id).run()
  return c.json({ ok: true, changes: Number(((res as any)?.meta?.changes ?? 0)) })
}))

// Bootstrap inicial: criar admin sem auth quando não há usuários
app.post('/api/bootstrap_admin', async (c) => {
  await ensureUsers(c.env.DB)
  const { results } = await c.env.DB.prepare(`SELECT COUNT(*) as cnt FROM users`).all()
  const cnt = Number(((results ?? [])[0] as any)?.cnt ?? 0)
  if (cnt > 0) return c.json({ ok: false, error: 'already_initialized' }, 403)
  const body = await c.req.json()
  const name = String(body?.name ?? '').trim() || 'Admin'
  const email = String(body?.email ?? '').trim().toLowerCase()
  const pin = String(body?.pin ?? '').trim()
  if (!email || !pin) return c.json({ ok: false, error: 'email/pin obrigatórios' }, 400)
  const pinHash = await hashPin(pin)
  const res = await c.env.DB.prepare(
    `INSERT INTO users (name, email, role, active, pinHash) VALUES (?, ?, 'admin', 1, ?)`
  ).bind(name, email, pinHash).run()
  return c.json({ ok: true, id: (res as any)?.meta?.last_row_id ?? null }, 201)
})
export default app
