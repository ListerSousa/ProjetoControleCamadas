-- 05-fornecedores.sql — Entregas de fornecedores (compras) com normalização da CodeForge e cálculo de prazos e atrasos

CREATE OR REFRESH MATERIALIZED VIEW entregas_fornecedor
COMMENT 'Entregas contratadas de fornecedores com nome da CodeForge padronizado, prazos calculados e flags de em aberto e atraso.'
AS
SELECT
  entrega_id,
  projeto_id,
  CASE
    WHEN replace(lower(fornecedor), ' ', '') LIKE '%codeforge%' THEN 'CodeForge Consultoria'
    ELSE trim(fornecedor)
  END AS fornecedor,
  fornecedor AS fornecedor_como_veio,
  item,
  CAST(valor AS DOUBLE) AS valor,
  CAST(data_pedido AS DATE) AS data_pedido,
  CAST(data_prometida AS DATE) AS data_prometida,
  CAST(NULLIF(trim(data_entrega), '') AS DATE) AS data_entrega,
  CAST(prazo_contratado_dias AS INT) AS prazo_contratado_dias,
  datediff(CAST(data_prometida AS DATE), CAST(data_pedido AS DATE)) AS prazo_prometido_dias,
  datediff(CAST(NULLIF(trim(data_entrega), '') AS DATE), CAST(data_pedido AS DATE)) AS prazo_real_dias,
  datediff(CAST(NULLIF(trim(data_entrega), '') AS DATE), CAST(data_prometida AS DATE)) AS dias_de_atraso_na_entrega,
  NULLIF(trim(data_entrega), '') IS NULL AS em_aberto,
  (NULLIF(trim(data_entrega), '') IS NULL AND CAST(data_prometida AS DATE) < DATE'2026-10-16') AS em_atraso,
  status
FROM lakehouse_vertice.bronze.entregas_fornecedor;

