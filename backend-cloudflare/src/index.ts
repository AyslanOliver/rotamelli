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

// -------- Admin UI (same-origin) --------
const adminHtml = `<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Gestão de Usuários</title>
    <link rel="stylesheet" href="/admin/styles.css">
  </head>
  <body>
    <header>
      <h1>Gestão de Usuários</h1>
      <div class="config">
        <button id="btnLogout" style="display:none">Sair</button>
      </div>
    </header>
    <main>
      <section id="login" class="form">
        <h2>Login</h2>
        <div class="grid">
          <label>E-mail <input id="loginEmail" type="email"></label>
          <label>Senha <input id="loginPin" type="password"></label>
        </div>
        <button id="btnLogin">Entrar</button>
        <p id="loginMsg" class="msg"></p>
      </section>
      <div id="adminPanel" style="display:none">
      <section class="form">
        <h2>Novo usuário</h2>
        <div class="grid">
          <label>Nome <input id="name" type="text"></label>
          <label>E-mail <input id="email" type="email"></label>
          <label>Perfil
            <select id="role">
              <option value="user">Usuário</option>
              <option value="admin">Admin</option>
            </select>
          </label>
          <label>PIN (opcional) <input id="pin" type="password"></label>
          <label>Ativo
            <select id="active">
              <option value="1">Sim</option>
              <option value="0">Não</option>
            </select>
          </label>
        </div>
        <button id="btnAdd">Adicionar</button>
        <p id="msg" class="msg"></p>
      </section>
      <section>
        <h2>Usuários</h2>
        <table id="tbl">
          <thead>
            <tr>
              <th>ID</th>
              <th>Nome</th>
              <th>E-mail</th>
              <th>Perfil</th>
              <th>Ativo</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody></tbody>
        </table>
      </section>
      </div>
    </main>
    <script src="/admin/app.js"></script>
  </body>
</html>`;

const adminCss = `:root{--primary:#4E73DF;--surface:#fff;--bg:#F8F9FC;--text:#333;--muted:#777}
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:var(--bg);color:var(--text)}
header{background:var(--surface);padding:12px 16px;border-bottom:1px solid #e3e6f0;display:flex;align-items:center;justify-content:space-between}
h1{margin:0;font-size:18px}
main{padding:16px;max-width:1000px;margin:0 auto}
.config label{font-size:12px;color:var(--muted);display:inline-flex;align-items:center;gap:6px}
input,select,button{padding:8px 10px;border:1px solid #ddd;border-radius:6px}
button{background:var(--primary);color:#fff;border:none;cursor:pointer}
button:hover{filter:brightness(1.05)}
.form{background:var(--surface);padding:12px;border-radius:8px;border:1px solid #e3e6f0;margin-bottom:16px}
.form h2{margin:0 0 8px 0;font-size:16px}
.grid{display:grid;grid-template-columns:repeat(3,minmax(180px,1fr));gap:8px}
table{width:100%;border-collapse:collapse;background:var(--surface);border:1px solid #e3e6f0;border-radius:8px;overflow:hidden}
th,td{padding:8px;border-bottom:1px solid #f0f2f7}
th{text-align:left;background:#f7f9ff}
.msg{margin-top:8px;font-size:12px;color:var(--muted)}
.actions{display:flex;gap:6px}`;

const adminJs = `(()=>{const btnAdd=document.getElementById('btnAdd');const btnLogin=document.getElementById('btnLogin');const btnLogout=document.getElementById('btnLogout');const msg=document.getElementById('msg');const loginMsg=document.getElementById('loginMsg');const tblBody=document.querySelector('#tbl tbody');const nameEl=document.getElementById('name');const emailEl=document.getElementById('email');const roleEl=document.getElementById('role');const pinEl=document.getElementById('pin');const activeEl=document.getElementById('active');const loginEmail=document.getElementById('loginEmail');const loginPin=document.getElementById('loginPin');const loginBox=document.getElementById('login');const adminPanel=document.getElementById('adminPanel');let token=localStorage.getItem('adminToken')||'';async function api(path,opt={}){const resp=await fetch(path,{method:opt.method||'GET',headers:{'Content-Type':'application/json'},body:opt.body?JSON.stringify(opt.body):undefined});if(!resp.ok){let err='Falha: '+resp.status;try{const d=await resp.json();err=d.error||err}catch{}throw new Error(err)}return resp.json()}async function apiAuth(path,opt={}){const headers={'Content-Type':'application/json'};if(token)headers['Authorization']='Bearer '+token;const resp=await fetch(path,{method:opt.method||'GET',headers,body:opt.body?JSON.stringify(opt.body):undefined});if(!resp.ok){let err='Falha: '+resp.status;try{const d=await resp.json();err=d.error||err}catch{}throw new Error(err)}return resp.json()}async function loadUsers(){try{if(!token){msg.textContent='Faça login para carregar usuários.';return}const users=await apiAuth('/api/users');tblBody.innerHTML='';users.forEach(u=>{const tr=document.createElement('tr');tr.innerHTML=\\\`<td>\\\${u.id}</td><td>\\\${u.name??''}</td><td>\\\${u.email??''}</td><td>\\\${u.role??''}</td><td>\\\${Number(u.active)?'Sim':'Não'}</td><td class=\\"actions\\"><button data-act=\\"edit\\" data-id=\\"\\\${u.id}\\\">Editar</button><button data-act=\\"del\\" data-id=\\"\\\${u.id}\\\">Excluir</button></td>\\\`;tblBody.appendChild(tr)});msg.textContent='Carregados '+users.length+' usuário(s).'}catch(e){msg.textContent=\\\`Erro: \\${e.message}\\\`}}function setLoggedIn(v){if(v){loginBox.style.display='none';btnLogout.style.display='';adminPanel.style.display=''}else{loginBox.style.display='';btnLogout.style.display='none';adminPanel.style.display='none'}}async function doLogin(){loginMsg.textContent='';try{const res=await api('/api/login',{method:'POST',body:{email:loginEmail.value.trim(),pin:loginPin.value.trim()}});if(!res?.ok||!res?.token)throw new Error(res?.error||'Falha no login');token=res.token;localStorage.setItem('adminToken',token);setLoggedIn(true);await loadUsers()}catch(e){loginMsg.textContent=\\\`Erro: \\${e.message}\\\`}}function doLogout(){token='';localStorage.removeItem('adminToken');setLoggedIn(false)}async function addUser(){const body={name:nameEl.value.trim(),email:emailEl.value.trim(),role:roleEl.value,pin:pinEl.value,active:Number(activeEl.value)};try{await apiAuth('/api/users',{method:'POST',body});nameEl.value='';emailEl.value='';pinEl.value='';roleEl.value='user';activeEl.value='1';msg.textContent='Usuário criado.';await loadUsers()}catch(e){msg.textContent=\\\`Erro ao criar: \\${e.message}\\\`}}tblBody.addEventListener('click',async ev=>{const btn=ev.target.closest('button');if(!btn)return;const id=Number(btn.dataset.id);const act=btn.dataset.act;if(act==='del'){if(!confirm('Excluir usuário?'))return;try{await apiAuth(\\\`/api/users/\\${id}\\\`,{method:'DELETE'});await loadUsers()}catch(e){msg.textContent=\\\`Erro ao excluir: \\${e.message}\\\`}}else if(act==='edit'){const name=prompt('Nome:');const email=prompt('E-mail:');const role=prompt('Perfil (user/admin):');const active=prompt('Ativo (1/0):');const pin=prompt('PIN (opcional):');const body={};if(name)body.name=name;if(email)body.email=email;if(role)body.role=role;if(active)body.active=Number(active);if(pin)body.pin=pin;try{await apiAuth(\\\`/api/users/\\${id}\\\`,{method:'PUT',body});await loadUsers()}catch(e){msg.textContent=\\\`Erro ao atualizar: \\${e.message}\\\`}}});btnAdd.addEventListener('click',addUser);btnLogin.addEventListener('click',doLogin);btnLogout.addEventListener('click',doLogout);setLoggedIn(Boolean(token));if(token)loadUsers();})();`;

app.get('/admin', (c) => new Response(adminHtml, { headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } }))
app.get('/admin/styles.css', (c) => new Response(adminCss, { headers: { 'content-type': 'text/css; charset=utf-8', 'cache-control': 'no-store' } }))
app.get('/admin/app.js', (c) => new Response(adminJs, { headers: { 'content-type': 'application/javascript; charset=utf-8', 'cache-control': 'no-store' } }))
export default app
