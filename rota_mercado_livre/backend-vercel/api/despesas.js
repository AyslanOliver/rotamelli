import { getDb } from '../lib/mongo.js';

export default async function handler(req, res) {
  const db = await getDb();
  const coll = db.collection('despesas');
  if (req.method === 'POST') {
    const doc = req.body;
    if (doc?.dataDespesa) {
      try {
        doc.dataDespesaDate = new Date(doc.dataDespesa);
      } catch (_) {}
    }
    await coll.insertOne(doc);
    res.status(200).json(doc);
    return;
  }
  if (req.method === 'GET') {
    const year = Number(req.query.year);
    const month = Number(req.query.month);
    if (!year || !month) {
      const list = await coll.find({}).sort({ dataDespesaDate: -1 }).limit(100).toArray();
      res.status(200).json(list);
      return;
    }
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0, 23, 59, 59, 999);
    const list = await coll.find({ dataDespesaDate: { $gte: start, $lte: end } }).sort({ dataDespesaDate: -1 }).toArray();
    res.status(200).json(list);
    return;
  }
  res.status(405).end();
}
