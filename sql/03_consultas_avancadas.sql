-- =====================================================================
-- 03_consultas_avancadas.sql
-- Consultas do Bloco 1 (SQL avançado), na ordem em que foram aprendidas.
-- Cada uma traz: a pergunta de negócio, o conceito e o resultado esperado
-- com os dados de 02_dados_teste.sql.
--
-- As linhas '-- title:' dão nome à aba de resultado no DBeaver.
--
-- Regra geral: sem ORDER BY o banco NÃO garante a ordem das linhas.
-- O ORDER BY de dentro do OVER() só define a ordem da janela, não a da saída.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 01. Quais empenhos ainda não foram liquidados?
-- Conceito: anti-join (LEFT JOIN + IS NULL na chave do lado direito).
-- Esperado: 2024NE000106 e 2024NE000102 (ordem DESC).
-- ---------------------------------------------------------------------
-- title: 01 - Empenhos pendentes (sem liquidação)
SELECT e.numero_empenho
FROM empenho e
LEFT JOIN liquidacao_empenho_impactado lei ON lei.id_empenho = e.id_empenho
WHERE lei.id_liquidacao IS NULL
ORDER BY e.numero_empenho DESC;


-- ---------------------------------------------------------------------
-- 02. Quanto dinheiro está parado (empenhado e não liquidado) por órgão?
-- Conceito: GROUP BY + SUM. O GROUP BY COLAPSA as linhas (muda a granularidade).
-- Depois do GROUP BY, só podem aparecer no SELECT/ORDER BY colunas do
-- GROUP BY ou resultados de agregação.
-- Esperado: órgão 26000 -> 220.000,00
-- ---------------------------------------------------------------------
-- title: 02 - Valor pendente por órgão
SELECT
    e.id_orgao                         AS orgao,
    ROUND(SUM(e.valor_empenhado), 2)   AS valor_pendente
FROM empenho e
LEFT JOIN liquidacao_empenho_impactado lei ON lei.id_empenho = e.id_empenho
WHERE lei.id_liquidacao IS NULL
GROUP BY e.id_orgao
ORDER BY valor_pendente DESC;


-- ---------------------------------------------------------------------
-- 03. Cada empenho pendente, com o total pendente do órgão ao lado.
-- Conceito: window function (SUM OVER PARTITION BY). Agrega SEM perder a
-- linha individual (mantém a granularidade de empenho).
-- Esperado: 2 linhas, ambas com valor_total = 220.000,00.
-- ---------------------------------------------------------------------
-- title: 03 - Pendentes com total do órgão (window function)
SELECT
    e.numero_empenho                                      AS numero,
    e.id_orgao                                            AS orgao,
    e.valor_empenhado                                     AS valor,
    SUM(e.valor_empenhado) OVER (PARTITION BY e.id_orgao) AS valor_total
FROM empenho e
LEFT JOIN liquidacao_empenho_impactado lei ON lei.id_empenho = e.id_empenho
WHERE lei.id_liquidacao IS NULL
ORDER BY e.id_orgao, e.numero_empenho;


-- ---------------------------------------------------------------------
-- 04. Qual a fatia de cada empenho pendente dentro do total pendente do órgão?
-- Conceito: CTE. Um alias definido no SELECT não pode ser usado por outra
-- coluna do MESMO SELECT; a CTE calcula num nível e reaproveita no seguinte.
-- O filtro de pendentes mora DENTRO da CTE: o WHERE roda ANTES das window
-- functions. Fora dela, o total seria sobre todos os empenhos (285.000).
-- Esperado: 54,54% (102) e 45,45% (106).
-- NUMERIC / NUMERIC preserva casas decimais (com INTEGER a divisão truncaria).
-- ---------------------------------------------------------------------
-- title: 04 - Percentual do empenho no total pendente do órgão
WITH pendentes AS (
    SELECT
        e.numero_empenho                                      AS numero,
        e.id_orgao                                            AS orgao,
        e.valor_empenhado                                     AS valor,
        SUM(e.valor_empenhado) OVER (PARTITION BY e.id_orgao) AS valor_total
    FROM empenho e
    LEFT JOIN liquidacao_empenho_impactado lei ON lei.id_empenho = e.id_empenho
    WHERE lei.id_liquidacao IS NULL
)
SELECT
    numero,
    orgao,
    valor,
    valor_total,
    valor / valor_total * 100 AS percentual
FROM pendentes
ORDER BY orgao, numero;


-- ---------------------------------------------------------------------
-- 05. GRANULARIDADE: o JOIN que multiplica linhas (erro silencioso).
-- Pergunta: qual o total liquidado?
-- A liquidação 2 (50.000) cobre 2 empenhos; no JOIN com a tabela associativa
-- ela aparece 2 vezes e a soma sai inflada. Nenhum erro é lançado.
-- Regra: antes de agregar após um JOIN, pergunte "o que uma linha
-- representa agora?". Correção típica: agregar ANTES do JOIN (CTE).
-- ---------------------------------------------------------------------
-- title: 05 - Granularidade: total liquidado CORRETO
-- Correto: 115.000,00
SELECT SUM(l.valor_liquidado) AS total_correto
FROM liquidacao l;

-- title: 05 - Granularidade: total liquidado INFLADO (erro)
-- ERRADO: 165.000,00 (a liquidação de 50.000 foi contada duas vezes)
SELECT SUM(l.valor_liquidado) AS total_inflado
FROM liquidacao l
JOIN liquidacao_empenho_impactado lei ON lei.id_liquidacao = l.id_liquidacao;


-- ---------------------------------------------------------------------
-- 06. CTE RECURSIVA: gerar uma série de meses do zero.
-- Estrutura: caso base + UNION ALL + caso recursivo com condição de parada.
-- O WHERE filtra a linha que ENTRA na próxima rodada (por isso o último
-- mês, 2024-06-01, ainda é gerado).
-- Armadilha: date + INTERVAL devolve timestamp; o caso base e o recursivo
-- precisam ter o MESMO tipo, então o resultado é convertido de volta com ::DATE.
-- Sem condição de parada, a query roda para sempre: teste com limite pequeno.
-- Esperado: 6 linhas (2024-01-01 ... 2024-06-01).
-- ---------------------------------------------------------------------
-- title: 06 - CTE recursiva: série de meses
WITH RECURSIVE serie_meses AS (
    SELECT DATE '2024-01-01' AS mes

    UNION ALL

    SELECT (mes + INTERVAL '1 month')::DATE
    FROM serie_meses
    WHERE mes < DATE '2024-06-01'
)
SELECT mes
FROM serie_meses;


-- ---------------------------------------------------------------------
-- 07. A forma idiomática de gerar a mesma série: generate_series().
-- Não existe versão para DATE, então o Postgres promove para timestamp:
-- o ::DATE devolve o tipo certo.
-- Em CTE recursiva, o uso real é DADO HIERÁRQUICO (organograma, categorias,
-- estrutura orçamentária), onde não existe função pronta.
-- ---------------------------------------------------------------------
-- title: 07 - generate_series: série de meses
SELECT generate_series(
           DATE '2024-01-01',
           DATE '2024-06-01',
           INTERVAL '1 month'
       )::DATE AS mes;


-- ---------------------------------------------------------------------
-- 08. Quais meses não tiveram nenhum pagamento?
-- Conceito: o mesmo anti-join do item 01, mas com o lado esquerdo GERADO
-- (generate_series). DATE_TRUNC('month', ...) leva a data de pagamento ao
-- dia 1 do mês, para poder comparar com a série.
-- Checa-se a PK (p.id_pagamento) e não uma coluna de negócio: a PK é a única
-- garantidamente não nula quando existe linha.
-- Esperado: todos os meses exceto 2024-03.
-- ---------------------------------------------------------------------
-- title: 08 - Meses sem nenhum pagamento
SELECT m.mes::DATE AS mes
FROM generate_series(
         DATE '2024-01-01',
         DATE '2024-06-01',
         INTERVAL '1 month'
     ) AS m(mes)
LEFT JOIN pagamento p
       ON DATE_TRUNC('month', p.data_pagamento) = m.mes
WHERE p.id_pagamento IS NULL
ORDER BY m.mes;


-- ---------------------------------------------------------------------
-- 09. Qual a data do empenho anterior do mesmo órgão?
-- Conceito: LAG() olha a linha ANTERIOR dentro da partição, na ordem do OVER.
-- LEAD() é o espelho (linha seguinte). O primeiro de cada órgão vem NULL.
-- ---------------------------------------------------------------------
-- title: 09 - LAG: data do empenho anterior
SELECT
    e.numero_empenho,
    e.data_empenho,
    LAG(e.data_empenho) OVER (
        PARTITION BY e.id_orgao
        ORDER BY e.data_empenho
    ) AS data_empenho_anterior
FROM empenho e
ORDER BY e.id_orgao, e.data_empenho;


-- ---------------------------------------------------------------------
-- 10. Quantos dias entre um empenho e o anterior do mesmo órgão?
-- Conceito: WINDOW nomeada (define a janela uma vez, reutiliza com OVER w).
-- Subtrair duas colunas DATE devolve inteiro de dias, respeitando o calendário.
-- O NULL é mantido de propósito: "sem anterior" não é o mesmo que "0 dias".
-- Esperado: 26, 20, 33 (órgão 26000) e 2 (órgão 26001).
-- ---------------------------------------------------------------------
-- title: 10 - Dias desde o empenho anterior (WINDOW nomeada)
SELECT
    e.numero_empenho,
    e.data_empenho,
    LAG(e.data_empenho) OVER w                       AS data_empenho_anterior,
    e.data_empenho - LAG(e.data_empenho) OVER w      AS dias_desde_anterior
FROM empenho e
WINDOW w AS (PARTITION BY e.id_orgao ORDER BY e.data_empenho)
ORDER BY e.id_orgao, e.data_empenho;


-- ---------------------------------------------------------------------
-- 11. Quais empenhos estão acima da média do PRÓPRIO órgão?
-- Conceito: subquery correlacionada. Ela referencia a query de fora
-- (e.id_orgao), então é reavaliada para cada linha. Note o alias e2 para a
-- mesma tabela. O plano mostra um SubPlan dentro do Filter.
-- Médias: 26000 = 71.250 | 26001 = 25.000
-- Esperado: 2024NE000102, 2024NE000103 e 2024NE000106.
-- ---------------------------------------------------------------------
-- title: 11 - Acima da média do órgão (subquery correlacionada)
SELECT
    e.numero_empenho,
    e.id_orgao,
    e.valor_empenhado
FROM empenho e
WHERE e.valor_empenhado > (
    SELECT AVG(e2.valor_empenhado)
    FROM empenho e2
    WHERE e2.id_orgao = e.id_orgao
)
ORDER BY e.id_orgao, e.numero_empenho;


-- ---------------------------------------------------------------------
-- 12. A mesma pergunta do item 11, com window function.
-- Conceito: o WHERE roda ANTES das window functions, então a janela precisa
-- ficar num nível anterior (CTE) para o filtro enxergá-la.
-- O plano mostra Sort -> WindowAgg -> Filter, sem reexecução por linha.
-- Esperado: o mesmo resultado do item 11.
-- ---------------------------------------------------------------------
-- title: 12 - Acima da média do órgão (window function)
WITH empenho_com_media AS (
    SELECT
        e.numero_empenho,
        e.id_orgao,
        e.valor_empenhado,
        AVG(e.valor_empenhado) OVER (PARTITION BY e.id_orgao) AS valor_medio_empenhado
    FROM empenho e
)
SELECT
    numero_empenho,
    id_orgao,
    valor_empenhado
FROM empenho_com_media
WHERE valor_empenhado > valor_medio_empenhado
ORDER BY id_orgao, numero_empenho;


-- ---------------------------------------------------------------------
-- 13. Como ver COMO o Postgres executa uma query?
-- EXPLAIN mostra o plano estimado; EXPLAIN ANALYZE executa de verdade e mostra
-- números reais (loops, tempo). Os custos são estimativas: com poucas linhas
-- e sem estatísticas (rode ANALYZE empenho;) os números absolutos enganam, o
-- que vale é o formato do plano.
-- Execute o EXPLAIN em cada versão (11 e 12) e compare.
-- ---------------------------------------------------------------------
-- EXPLAIN
-- <cole aqui a query do item 11 ou 12>
