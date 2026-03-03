import { Hono } from 'hono'
import type { D1Database } from '@cloudflare/workers-types'

type Bindings = {
  DB: D1Database
  AVULSO_UNIT?: string
}

const app = new Hono<{ Bindings: Bindings }>()

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

app.get('/api/users', async (c) => {
  await ensureUsers(c.env.DB)
  const { results } = await c.env.DB.prepare(
    `SELECT id, name, email, role, active FROM users ORDER BY name ASC`
  ).all()
  return c.json(results ?? [])
})

app.post('/api/users', async (c) => {
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
})

app.put('/api/users/:id', async (c) => {
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
})

app.delete('/api/users/:id', async (c) => {
  await ensureUsers(c.env.DB)
  const id = Number(c.req.param('id'))
  const res = await c.env.DB.prepare(`DELETE FROM users WHERE id = ?`).bind(id).run()
  return c.json({ ok: true, changes: Number(((res as any)?.meta?.changes ?? 0)) })
})

export default app
