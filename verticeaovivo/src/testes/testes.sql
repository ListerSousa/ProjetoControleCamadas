-- src/testes/testes.sql — 10 testes de qualidade da camada Silver e Gold (falha com raise_error se qualquer um divergir)

WITH resultados AS (
  -- 1. os 60 projetos têm cronograma na silver.tarefas
  SELECT
    1 AS ordem,
    '1. 60 projetos na silver.tarefas' AS teste,
    COUNT(DISTINCT projeto_id) = 60 AS passou,
    concat('esperado=60, obtido=', CAST(COUNT(DISTINCT projeto_id) AS STRING)) AS detalhe
  FROM lakehouse_vertice.silver.tarefas

  UNION ALL

  -- 2. cada projeto veio de UMA ferramenta, a do cadastro do PMO
  SELECT
    2 AS ordem,
    '2. Cada projeto veio da ferramenta do cadastro do PMO' AS teste,
    COUNT(*) = 0 AS passou,
    concat('divergencias=', CAST(COUNT(*) AS STRING)) AS detalhe
  FROM (
    SELECT t.projeto_id
    FROM lakehouse_vertice.silver.tarefas t
    JOIN lakehouse_vertice.silver.projetos p ON t.projeto_id = p.projeto_id
    GROUP BY t.projeto_id, p.ferramenta
    HAVING COUNT(DISTINCT t.ferramenta) <> 1 OR MAX(t.ferramenta) <> p.ferramenta
  )

  UNION ALL

  -- 3. as horas do Excel na silver = a soma das linhas de TOTAL das planilhas
  SELECT
    3 AS ordem,
    '3. Horas do Excel na silver = soma das linhas TOTAL da bronze' AS teste,
    ROUND(s.horas_silver, 2) = ROUND(b.horas_total_bronze, 2) AS passou,
    concat('silver=', CAST(ROUND(s.horas_silver, 2) AS STRING), ', bronze_total=', CAST(ROUND(b.horas_total_bronze, 2) AS STRING)) AS detalhe
  FROM (
    SELECT SUM(horas) AS horas_silver
    FROM lakehouse_vertice.silver.tarefas
    WHERE ferramenta = 'excel'
  ) s
  CROSS JOIN (
    SELECT SUM(CAST(regexp_replace(trim(horas_previstas), 'h$', '') AS DOUBLE)) AS horas_total_bronze
    FROM lakehouse_vertice.bronze.excel_tarefas
    WHERE upper(trim(tarefa)) = 'TOTAL'
  ) b

  UNION ALL

  -- 4. uma linha por pessoa na silver
  SELECT
    4 AS ordem,
    '4. Uma linha por pessoa na silver.colaboradores' AS teste,
    COUNT(*) = COUNT(DISTINCT colaborador_id) AND COUNT(*) = 520 AS passou,
    concat('linhas=', CAST(COUNT(*) AS STRING), ', distintos=', CAST(COUNT(DISTINCT colaborador_id) AS STRING)) AS detalhe
  FROM lakehouse_vertice.silver.colaboradores

  UNION ALL

  -- 5. a CodeForge virou um fornecedor só
  SELECT
    5 AS ordem,
    '5. CodeForge unificada em um único fornecedor' AS teste,
    COUNT(DISTINCT fornecedor) = 1 AS passou,
    concat('distintos_codeforge=', CAST(COUNT(DISTINCT fornecedor) AS STRING)) AS detalhe
  FROM lakehouse_vertice.silver.entregas_fornecedor
  WHERE replace(lower(fornecedor), ' ', '') LIKE '%codeforge%'

  UNION ALL

  -- 6. a limpeza não mudou o custo total (bronze com replace = silver)
  SELECT
    6 AS ordem,
    '6. Custo total silver = custo total bronze com replace' AS teste,
    ROUND(s.total_silver, 2) = ROUND(b.total_bronze, 2) AS passou,
    concat('silver=', CAST(ROUND(s.total_silver, 2) AS STRING), ', bronze=', CAST(ROUND(b.total_bronze, 2) AS STRING)) AS detalhe
  FROM (
    SELECT SUM(valor) AS total_silver FROM lakehouse_vertice.silver.custos
  ) s
  CROSS JOIN (
    SELECT SUM(CAST(replace(valor, ',', '.') AS DOUBLE)) AS total_bronze FROM lakehouse_vertice.bronze.custos
  ) b

  UNION ALL

  -- 7. os 60 projetos têm fotografia de hoje
  SELECT
    7 AS ordem,
    '7. Os 60 projetos têm fotografia em gold.projeto_situacao_atual' AS teste,
    COUNT(*) = 60 AND COUNT(DISTINCT projeto_id) = 60 AS passou,
    concat('linhas=', CAST(COUNT(*) AS STRING), ', distintos=', CAST(COUNT(DISTINCT projeto_id) AS STRING)) AS detalhe
  FROM lakehouse_vertice.gold.projeto_situacao_atual

  UNION ALL

  -- 8. todo projeto em andamento tem SPI e CPI
  SELECT
    8 AS ordem,
    '8. Todo projeto em andamento tem SPI e CPI não nulos' AS teste,
    COUNT_IF(status = 'em_andamento' AND (spi IS NULL OR cpi IS NULL)) = 0 AS passou,
    concat('sem_spi_ou_cpi=', CAST(COUNT_IF(status = 'em_andamento' AND (spi IS NULL OR cpi IS NULL)) AS STRING)) AS detalhe
  FROM lakehouse_vertice.gold.projeto_situacao_atual

  UNION ALL

  -- 9. o EV de hoje do status semanal bate com o das ferramentas (diferença < 1%)
  SELECT
    9 AS ordem,
    '9. EV de hoje do status semanal bate com o das ferramentas (< 1%)' AS teste,
    abs(SUM(f.ev) - SUM(psa.ev)) / SUM(psa.ev) < 0.01 AS passou,
    concat('diff_relativa=', CAST(ROUND(abs(SUM(f.ev) - SUM(psa.ev)) / SUM(psa.ev) * 100.0, 4) AS STRING), '%') AS detalhe
  FROM lakehouse_vertice.gold.fato_projeto_semana f
  JOIN lakehouse_vertice.gold.projeto_situacao_atual psa ON f.projeto_id = psa.projeto_id
  WHERE f.semana = DATE'2026-10-16'

  UNION ALL

  -- 10. AC de hoje no fato = soma dos lançamentos até hoje
  SELECT
    10 AS ordem,
    '10. AC de hoje em fato_projeto_semana = soma de silver.custos até hoje' AS teste,
    ROUND(f.ac_hoje, 2) = ROUND(c.custos_ate_hoje, 2) AS passou,
    concat('fato_ac=', CAST(ROUND(f.ac_hoje, 2) AS STRING), ', custos=', CAST(ROUND(c.custos_ate_hoje, 2) AS STRING)) AS detalhe
  FROM (
    SELECT SUM(ac) AS ac_hoje
    FROM lakehouse_vertice.gold.fato_projeto_semana
    WHERE semana = DATE'2026-10-16'
  ) f
  CROSS JOIN (
    SELECT SUM(valor) AS custos_ate_hoje
    FROM lakehouse_vertice.silver.custos
    WHERE data <= DATE'2026-10-16'
  ) c
)
SELECT
  ordem,
  teste,
  detalhe,
  CASE
    WHEN NOT passou THEN raise_error(concat('FALHA NO TESTE [', teste, ']: ', detalhe))
    ELSE 'OK'
  END AS resultado
FROM resultados
ORDER BY ordem;

