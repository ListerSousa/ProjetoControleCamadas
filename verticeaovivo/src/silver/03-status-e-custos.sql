-- 03-status-e-custos.sql — Status semanal do PMO e lançamentos financeiros de custos

CREATE OR REFRESH MATERIALIZED VIEW status_semanal (
  CONSTRAINT farol_valido EXPECT (farol IN ('verde', 'amarelo', 'vermelho')) ON VIOLATION FAIL UPDATE
)
COMMENT 'Status semanal dos projetos reportado pelos gerentes, com farol padronizado e flag de status vazio.'
AS
SELECT
  projeto_id,
  CAST(data_status AS DATE) AS data_status,
  gerente,
  lower(trim(farol)) AS farol,
  CAST(pct_concluido AS INT) AS pct_concluido,
  texto_status,
  COALESCE(trim(texto_status), '') IN ('', 'N/A', 'ver ata da reunião') AS status_vazio
FROM lakehouse_vertice.bronze.status_semanal;

CREATE OR REFRESH MATERIALIZED VIEW custos
COMMENT 'Lançamentos financeiros de custos por projeto, com valor decimal padronizado, flag de estorno e semana (sexta-feira).'
AS
SELECT
  lancamento_id,
  projeto_id,
  CAST(data AS DATE) AS data,
  date_add(date_trunc('WEEK', CAST(data AS DATE)), 4) AS semana,
  categoria,
  descricao,
  CAST(replace(valor, ',', '.') AS DOUBLE) AS valor,
  CAST(replace(valor, ',', '.') AS DOUBLE) < 0 AS estorno,
  centro_custo
FROM lakehouse_vertice.bronze.custos;

