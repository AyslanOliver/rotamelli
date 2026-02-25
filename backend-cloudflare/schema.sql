CREATE TABLE IF NOT EXISTS rotas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nomeRota TEXT,
  dataRotaMillis INTEGER NOT NULL,
  placaCarro TEXT,
  quantidadePacotes INTEGER,
  pacotesVulso INTEGER,
  tipoVeiculo TEXT,
  valorCalculado REAL
);

CREATE INDEX IF NOT EXISTS idx_rotas_data ON rotas (dataRotaMillis DESC);

CREATE TABLE IF NOT EXISTS despesas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  descricao TEXT,
  dataDespesaMillis INTEGER NOT NULL,
  valor REAL NOT NULL,
  categoria TEXT
);

CREATE INDEX IF NOT EXISTS idx_despesas_data ON despesas (dataDespesaMillis DESC);
