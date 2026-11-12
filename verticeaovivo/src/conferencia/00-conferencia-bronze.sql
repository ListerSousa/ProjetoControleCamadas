-- Conferência das 9 tabelas da camada bronze contra a contagem esperada (seed 42).
-- A tabela bronze.feriados fica de fora pois cresce a cada execução.
-- Se alguma contagem divergir, falha imediatamente com raise_error() indicando a tabela e onde olhar.

WITH esperado AS (
  SELECT * FROM VALUES
    ('projetos',            60L),
    ('status_semanal',      3911L),
    ('excel_tarefas',       1663L),
    ('clickup_tarefas',     2119L),
    ('msproject_tarefas',   1260L),
    ('colaboradores',       523L),
    ('apontamentos',        30883L),
    ('custos',              23640L),
    ('entregas_fornecedor', 640L)
  AS t(tabela, esperado)
),
obtido AS (
  SELECT 'projetos' AS tabela, COUNT(*) AS obtido FROM lakehouse_vertice.bronze.projetos
  UNION ALL SELECT 'status_semanal', COUNT(*) FROM lakehouse_vertice.bronze.status_semanal
  UNION ALL SELECT 'excel_tarefas', COUNT(*) FROM lakehouse_vertice.bronze.excel_tarefas
  UNION ALL SELECT 'clickup_tarefas', COUNT(*) FROM lakehouse_vertice.bronze.clickup_tarefas
  UNION ALL SELECT 'msproject_tarefas', COUNT(*) FROM lakehouse_vertice.bronze.msproject_tarefas
  UNION ALL SELECT 'colaboradores', COUNT(*) FROM lakehouse_vertice.bronze.colaboradores
  UNION ALL SELECT 'apontamentos', COUNT(*) FROM lakehouse_vertice.bronze.apontamentos
  UNION ALL SELECT 'custos', COUNT(*) FROM lakehouse_vertice.bronze.custos
  UNION ALL SELECT 'entregas_fornecedor', COUNT(*) FROM lakehouse_vertice.bronze.entregas_fornecedor
)
SELECT
  e.tabela,
  e.esperado,
  o.obtido,
  CASE
    WHEN o.obtido <> e.esperado THEN raise_error(
      concat(
        'Divergência na tabela bronze.', e.tabela,
        ': esperado=', CAST(e.esperado AS STRING),
        ', obtido=', CAST(o.obtido AS STRING),
        '. Verifique a saída da tarefa ingestao_data_lake.'
      )
    )
    ELSE 'OK'
  END AS status_conferencia
FROM esperado e
JOIN obtido o ON e.tabela = o.tabela
ORDER BY e.esperado DESC;

