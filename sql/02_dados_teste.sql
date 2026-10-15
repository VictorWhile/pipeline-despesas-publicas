-- =====================================================================
-- 02_dados_teste.sql
-- Dados SIMULADOS (fictícios) para testar as queries com resultado conhecido.
-- Órgão 26000 = "Ministério da Saúde" (fictício)
-- Órgão 26001 = "Ministério da Educação" (fictício)
--
-- Nunca informe o id de uma coluna SERIAL no INSERT: a sequence não
-- "sabe" do valor manual e o próximo INSERT automático colide (ver fim do arquivo).
-- =====================================================================

-- CENÁRIO 1: caminho feliz -> empenhado, liquidado e pago integralmente
INSERT INTO empenho (numero_empenho, id_orgao, favorecido, cnpj_cpf_favorecido, elemento_despesa, valor_empenhado, data_empenho)
VALUES ('2024NE000101', 26000, 'Fornecedora de Materiais Hospitalares LTDA', '12.345.678/0001-90', 'Material de Consumo', 50000.00, '2024-02-10');   -- id_empenho = 1

INSERT INTO liquidacao (numero_liquidacao, valor_liquidado, data_liquidacao)
VALUES ('2024NL000201', 50000.00, '2024-03-05');                                                                                                  -- id_liquidacao = 1

INSERT INTO liquidacao_empenho_impactado (id_liquidacao, id_empenho) VALUES (1, 1);

INSERT INTO pagamento (numero_pagamento, id_liquidacao, valor_pago, data_pagamento)
VALUES ('2024NP000301', 1, 50000.00, '2024-03-20');


-- CENÁRIO 2: empenho PENDENTE -> nunca foi liquidado (contrato não executado)
-- Propositalmente não há linha em liquidacao_empenho_impactado para este empenho.
INSERT INTO empenho (numero_empenho, id_orgao, favorecido, cnpj_cpf_favorecido, elemento_despesa, valor_empenhado, data_empenho)
VALUES ('2024NE000102', 26000, 'Construtora Alfa S.A.', '98.765.432/0001-10', 'Obras e Instalações', 120000.00, '2024-01-15');                  -- id_empenho = 2


-- CENÁRIO 3: UMA liquidação cobrindo DOIS empenhos (motivo da tabela associativa)
INSERT INTO empenho (numero_empenho, id_orgao, favorecido, cnpj_cpf_favorecido, elemento_despesa, valor_empenhado, data_empenho)
VALUES ('2024NE000103', 26001, 'Editora Beta Livros Didáticos', '11.222.333/0001-44', 'Material Didático', 30000.00, '2024-02-01');              -- id_empenho = 3

INSERT INTO empenho (numero_empenho, id_orgao, favorecido, cnpj_cpf_favorecido, elemento_despesa, valor_empenhado, data_empenho)
VALUES ('2024NE000104', 26001, 'Editora Beta Livros Didáticos', '11.222.333/0001-44', 'Material Didático', 20000.00, '2024-02-03');              -- id_empenho = 4

INSERT INTO liquidacao (numero_liquidacao, valor_liquidado, data_liquidacao)
VALUES ('2024NL000202', 50000.00, '2024-03-10');                                                                                                  -- id_liquidacao = 2 (30.000 + 20.000)

INSERT INTO liquidacao_empenho_impactado (id_liquidacao, id_empenho) VALUES (2, 3), (2, 4);


-- CENÁRIO 4: liquidado, mas o pagamento ainda não saiu (estágio intermediário)
INSERT INTO empenho (numero_empenho, id_orgao, favorecido, cnpj_cpf_favorecido, elemento_despesa, valor_empenhado, data_empenho)
VALUES ('2024NE000105', 26000, 'Serviços de Limpeza Gama EIRELI', '55.666.777/0001-88', 'Serviços de Terceiros - PJ', 15000.00, '2024-03-01'); -- id_empenho = 5

INSERT INTO liquidacao (numero_liquidacao, valor_liquidado, data_liquidacao)
VALUES ('2024NL000203', 15000.00, '2024-03-25');                                                                                                  -- id_liquidacao = 3

INSERT INTO liquidacao_empenho_impactado (id_liquidacao, id_empenho) VALUES (3, 5);
-- Sem linha em pagamento para a liquidação 3.


-- CENÁRIO 5: segundo empenho PENDENTE no mesmo órgão (26000)
-- Necessário para o PARTITION BY fazer diferença (dois pendentes no mesmo órgão).
INSERT INTO empenho (numero_empenho, id_orgao, favorecido, cnpj_cpf_favorecido, elemento_despesa, valor_empenhado, data_empenho)
VALUES ('2024NE000106', 26000, 'Supermercado Souza LTDA', '98.456.654/0001-77', 'Material de Consumo', 100000.00, '2024-04-03');                -- id_empenho = 6


-- =====================================================================
-- MANUTENÇÃO: se algum dia inserir um id manualmente numa coluna SERIAL,
-- realinhe a sequence com o maior id existente.
-- pg_get_serial_sequence evita adivinhar o nome da sequence.
-- =====================================================================
-- SELECT setval(
--     pg_get_serial_sequence('empenho', 'id_empenho'),
--     (SELECT MAX(id_empenho) FROM empenho)
-- );
