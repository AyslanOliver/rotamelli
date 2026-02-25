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
  'GET  /api/metrics/avulso-mes?year=YYYY&month=MM'
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

export default app
