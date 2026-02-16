import { MongoClient } from 'mongodb';

async function run() {
  const uri = process.argv[2] || process.env.MONGODB_URI;
  const dbName = process.argv[3] || process.env.MONGODB_DB || 'rotamelli';
  if (!uri) {
    console.error('Missing MONGODB_URI');
    process.exit(1);
  }
  const client = new MongoClient(uri);
  await client.connect();
  const db = client.db(dbName);
  const existing = new Set((await db.listCollections().toArray()).map(c => c.name));
  if (!existing.has('rotas')) await db.createCollection('rotas');
  if (!existing.has('despesas')) await db.createCollection('despesas');
  await db.collection('rotas').createIndex({ dataRotaDate: -1 });
  await db.collection('despesas').createIndex({ dataDespesaDate: -1 });
  console.log('ok:' + dbName);
  await client.close();
}

run().catch(e => {
  console.error('error:' + (e?.message || e));
  process.exit(1);
});
