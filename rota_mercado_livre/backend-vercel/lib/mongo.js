import { MongoClient } from 'mongodb';

let dbPromise;

export function getDb() {
  if (!dbPromise) {
    const uri = process.env.MONGODB_URI;
    const name = process.env.MONGODB_DB;
    const client = new MongoClient(uri);
    dbPromise = client.connect().then(c => c.db(name));
  }
  return dbPromise;
}
