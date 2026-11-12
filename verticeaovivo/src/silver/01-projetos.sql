-- 01-projetos.sql — Cadastro do PMO (de-para da integração entre as três ferramentas)

CREATE OR REFRESH MATERIALIZED VIEW projetos (
  CONSTRAINT data_inicio_valida EXPECT (data_inicio IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT ferramenta_valida EXPECT (ferramenta IN ('excel', 'clickup', 'msproject')) ON VIOLATION FAIL UPDATE
)
COMMENT 'Cadastro de projetos do PMO limpo e tipado, usado como de-para das ferramentas de cronograma.'
AS
SELECT
  projeto_id,
  nome_projeto,
  cliente,
  segmento,
  tipo_projeto,
  CASE
    WHEN lower(trim(ferramenta)) IN ('excel', 'planilha') THEN 'excel'
    WHEN lower(trim(ferramenta)) = 'clickup' THEN 'clickup'
    WHEN lower(trim(ferramenta)) IN ('ms project', 'msproject', 'project') THEN 'msproject'
    ELSE lower(trim(ferramenta))
  END AS ferramenta,
  ferramenta AS ferramenta_como_veio,
  NULLIF(trim(codigo_ferramenta), '') AS codigo_ferramenta,
  CAST(valor_contrato AS DOUBLE) AS valor_contrato,
  CAST(orcamento_custo AS DOUBLE) AS orcamento_custo,
  COALESCE(
    try_to_date(data_inicio, 'yyyy-MM-dd'),
    try_to_date(data_inicio, 'dd/MM/yyyy')
  ) AS data_inicio,
  COALESCE(
    try_to_date(data_fim_baseline, 'yyyy-MM-dd'),
    try_to_date(data_fim_baseline, 'dd/MM/yyyy')
  ) AS data_fim_baseline,
  status,
  gerente_projeto
FROM lakehouse_vertice.bronze.projetos;

