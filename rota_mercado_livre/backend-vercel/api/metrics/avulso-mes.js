import { getDb } from '../../lib/mongo.js';

export default async function handler(req, res) {
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
  res.status(200).json({ total });
}
