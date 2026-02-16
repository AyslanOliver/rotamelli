import express from 'express';
import cors from 'cors';
import { MongoClient } from 'mongodb';

const app = express();
app.use(cors());
app.use(express.json());
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

const uri = process.env.MONGODB_URI;
const dbName = process.env.MONGODB_DB || 'rotamelli';
const client = new MongoClient(uri);
let dbPromise;
function getDb() {
  if (!dbPromise) dbPromise = client.connect().then(c => c.db(dbName));
  return dbPromise;
}
function configOk() {
  return Boolean(uri && dbName);
}

async function ensureDbSetup() {
  if (!uri || !dbName) return;
  const db = await getDb();
  const existing = new Set((await db.listCollections().toArray()).map(c => c.name));
  if (!existing.has('rotas')) await db.createCollection('rotas');
  if (!existing.has('despesas')) await db.createCollection('despesas');
  await db.collection('rotas').createIndex({ dataRotaDate: -1 });
  await db.collection('despesas').createIndex({ dataDespesaDate: -1 });
}
ensureDbSetup().catch(() => {});

app.get('/', (req, res) => {
  res.json({
    name: 'rota-ml-render-api',
    status: 'ok',
    endpoints: [
      'GET /health',
      'POST /api/rotas',
      'GET  /api/rotas?year=YYYY&month=MM',
      'POST /api/despesas',
      'GET  /api/despesas?year=YYYY&month=MM',
      'GET  /api/metrics/avulso-mes?year=YYYY&month=MM'
    ]
  });
});

app.get('/health', (req, res) => res.status(200).json({ ok: true }));

app.get('/health/db', asyncHandler(async (req, res) => {
  if (!configOk()) {
    res.status(400).json({ ok: false, error: 'missing MONGODB_URI or MONGODB_DB' });
    return;
  }
  const db = await getDb();
  const cols = await db.listCollections().toArray();
  res.json({ ok: true, db: dbName, collections: cols.map(c => c.name) });
}));

app.post('/api/rotas', asyncHandler(async (req, res) => {
  if (!configOk()) {
    res.status(500).json({ ok: false, error: 'db not configured' });
    return;
  }
  const db = await getDb();
  const doc = req.body || {};
  if (doc.dataRota) {
    try { doc.dataRotaDate = new Date(doc.dataRota); } catch {}
  }
  await db.collection('rotas').insertOne(doc);
  res.status(201).json(doc);
}));

app.get('/api/rotas', asyncHandler(async (req, res) => {
  if (!configOk()) {
    res.status(500).json({ ok: false, error: 'db not configured' });
    return;
  }
  const db = await getDb();
  const coll = db.collection('rotas');
  const year = Number(req.query.year);
  const month = Number(req.query.month);
  if (!year || !month) {
    const list = await coll.find({}).sort({ dataRotaDate: -1 }).limit(100).toArray();
    res.json(list);
    return;
  }
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 0, 23, 59, 59, 999);
  const list = await coll.find({ dataRotaDate: { $gte: start, $lte: end } }).sort({ dataRotaDate: -1 }).toArray();
  res.json(list);
}));

app.post('/api/despesas', asyncHandler(async (req, res) => {
  if (!configOk()) {
    res.status(500).json({ ok: false, error: 'db not configured' });
    return;
  }
  const db = await getDb();
  const doc = req.body || {};
  if (doc.dataDespesa) {
    try { doc.dataDespesaDate = new Date(doc.dataDespesa); } catch {}
  }
  await db.collection('despesas').insertOne(doc);
  res.status(201).json(doc);
}));

app.get('/api/despesas', asyncHandler(async (req, res) => {
  if (!configOk()) {
    res.status(500).json({ ok: false, error: 'db not configured' });
    return;
  }
  const db = await getDb();
  const coll = db.collection('despesas');
  const year = Number(req.query.year);
  const month = Number(req.query.month);
  if (!year || !month) {
    const list = await coll.find({}).sort({ dataDespesaDate: -1 }).limit(100).toArray();
    res.json(list);
    return;
  }
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 0, 23, 59, 59, 999);
  const list = await coll.find({ dataDespesaDate: { $gte: start, $lte: end } }).sort({ dataDespesaDate: -1 }).toArray();
  res.json(list);
}));

app.get('/api/metrics/avulso-mes', asyncHandler(async (req, res) => {
  if (!configOk()) {
    res.status(500).json({ ok: false, error: 'db not configured' });
    return;
  }
  const db = await getDb();
  const coll = db.collection('rotas');
  const year = Number(req.query.year);
  const month = Number(req.query.month);
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 0, 23, 59, 59, 999);
  const agg = await coll.aggregate([
    { $match: { dataRotaDate: { $gte: start, $lte: end } } },
    { $group: { _id: null, totalPacotes: { $sum: { $ifNull: ['$pacotesVulso', 0] } } } }
  ]).toArray();
  const unit = Number(process.env.AVULSO_UNIT || 2);
  const total = (agg[0]?.totalPacotes ?? 0) * unit;
  res.json({ total });
}));

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ ok: false });
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log('Server listening on port ' + port);
});
