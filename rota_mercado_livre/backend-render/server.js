import express from 'express';
import cors from 'cors';
import { MongoClient } from 'mongodb';

const app = express();
app.use(cors());
app.use(express.json());

const uri = process.env.MONGODB_URI;
const dbName = process.env.MONGODB_DB;
const client = new MongoClient(uri);
let dbPromise;
function getDb() {
  if (!dbPromise) dbPromise = client.connect().then(c => c.db(dbName));
  return dbPromise;
}

app.get('/health', (req, res) => res.status(200).json({ ok: true }));

app.post('/api/rotas', async (req, res) => {
  const db = await getDb();
  const doc = req.body || {};
  if (doc.dataRota) {
    try { doc.dataRotaDate = new Date(doc.dataRota); } catch {}
  }
  await db.collection('rotas').insertOne(doc);
  res.status(201).json(doc);
});

app.get('/api/rotas', async (req, res) => {
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
});

app.post('/api/despesas', async (req, res) => {
  const db = await getDb();
  const doc = req.body || {};
  if (doc.dataDespesa) {
    try { doc.dataDespesaDate = new Date(doc.dataDespesa); } catch {}
  }
  await db.collection('despesas').insertOne(doc);
  res.status(201).json(doc);
});

app.get('/api/despesas', async (req, res) => {
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
});

app.get('/api/metrics/avulso-mes', async (req, res) => {
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
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log('Server listening on port ' + port);
});
