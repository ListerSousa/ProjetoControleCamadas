-- 04-pessoas.sql — Cadastro de colaboradores (RH) deduplicado e apontamentos de horas (timesheet)

CREATE OR REFRESH MATERIALIZED VIEW colaboradores
COMMENT 'Cadastro de colaboradores do RH sem duplicidades (mantendo o registro com papel em minúsculas).'
AS
SELECT
  colaborador_id,
  nome,
  papel,
  senioridade,
  CAST(custo_hora AS DOUBLE) AS custo_hora,
  CAST(data_admissao AS DATE) AS data_admissao,
  CAST(NULLIF(trim(data_desligamento), '') AS DATE) AS data_desligamento
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY colaborador_id
      ORDER BY CASE WHEN papel = lower(papel) THEN 0 ELSE 1 END
    ) AS rn
  FROM lakehouse_vertice.bronze.colaboradores
)
WHERE rn = 1;

CREATE OR REFRESH MATERIALIZED VIEW apontamentos
COMMENT 'Apontamentos semanais de horas por colaborador e projeto, com a sexta-feira de referência (semana).'
AS
SELECT
  colaborador_id,
  projeto_id,
  CAST(semana_inicio AS DATE) AS semana_inicio,
  date_add(CAST(semana_inicio AS DATE), 4) AS semana,
  CAST(horas_disponiveis AS DOUBLE) AS horas_disponiveis,
  CAST(horas_apontadas AS DOUBLE) AS horas_apontadas
FROM lakehouse_vertice.bronze.apontamentos;

