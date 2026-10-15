-- =====================================================================
-- 01_schema.sql
-- Schema do projeto: despesa pública (empenho -> liquidação -> pagamento)
--
-- Ordem de execução: 1º este arquivo, 2º 02_dados_teste.sql
-- Banco: PostgreSQL 17 (container Docker: pg-despesas)
-- =====================================================================

-- Empenho: o governo reserva o dinheiro (compromisso já assumido).
-- id_orgao NÃO é SERIAL: o código do órgão vem da fonte de dados,
-- a tabela não deve inventar esse número.
CREATE TABLE empenho (
    id_empenho          SERIAL PRIMARY KEY,
    numero_empenho      VARCHAR(30),
    id_orgao            INTEGER,
    favorecido          TEXT,
    cnpj_cpf_favorecido VARCHAR(18),
    elemento_despesa    TEXT,
    valor_empenhado     NUMERIC(15,2),   -- dinheiro: NUMERIC, nunca FLOAT
    data_empenho        DATE
);

-- Liquidação: confirma que o serviço/produto foi entregue.
CREATE TABLE liquidacao (
    id_liquidacao      SERIAL PRIMARY KEY,
    numero_liquidacao  VARCHAR(30),
    valor_liquidado    NUMERIC(15,2),
    data_liquidacao    DATE
);

-- Tabela associativa (muitos-para-muitos):
-- uma liquidação pode cobrir vários empenhos de uma vez.
-- A PK composta garante que o par (liquidação, empenho) não se repita.
CREATE TABLE liquidacao_empenho_impactado (
    id_liquidacao  INTEGER REFERENCES liquidacao(id_liquidacao),
    id_empenho     INTEGER REFERENCES empenho(id_empenho),
    PRIMARY KEY (id_liquidacao, id_empenho)
);

-- Pagamento: o dinheiro sai de fato.
CREATE TABLE pagamento (
    id_pagamento      SERIAL PRIMARY KEY,
    numero_pagamento  VARCHAR(30),
    id_liquidacao     INTEGER REFERENCES liquidacao(id_liquidacao),
    valor_pago        NUMERIC(15,2),
    data_pagamento    DATE
);
