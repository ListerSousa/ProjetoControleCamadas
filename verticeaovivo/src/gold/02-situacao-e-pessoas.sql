-- 02-situacao-e-pessoas.sql — Fotografia de 2026-10-16 de cada projeto e utilização semanal por pessoa

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.projeto_situacao_atual
COMMENT 'Fotografia de 2026-10-16 dos 60 projetos com cadastro do PMO, KPIs de Valor Agregado sobre silver.tarefas e farol melancia.'
AS
WITH kpi_tarefas AS (
  SELECT
    t.projeto_id,
    SUM(
      t.horas * greatest(
        0.0,
        least(
          1.0,
          datediff(DATE'2026-10-16', t.inicio_baseline) / CAST(NULLIF(datediff(t.fim_baseline, t.inicio_baseline), 0) AS DOUBLE)
        )
      )
    ) / SUM(t.horas) AS frac_pv,
    SUM(t.horas * (t.pct_concluido / 100.0)) / SUM(t.horas) AS frac_ev,
    MAX(t.fim_real) AS max_fim_real
  FROM tarefas t
  GROUP BY t.projeto_id
),
custo_acumulado AS (
  SELECT
    projeto_id,
    SUM(valor) AS ac
  FROM custos
  WHERE data <= DATE'2026-10-16'
  GROUP BY projeto_id
),
ultimo_status AS (
  SELECT
    projeto_id,
    farol AS farol_do_gerente,
    ROW_NUMBER() OVER (PARTITION BY projeto_id ORDER BY data_status DESC) AS rn
  FROM status_semanal
  WHERE data_status <= DATE'2026-10-16'
),
calculado AS (
  SELECT
    p.projeto_id,
    concat(p.projeto_id, ' · ', p.nome_projeto) AS projeto,
    p.nome_projeto,
    p.cliente,
    p.segmento,
    p.tipo_projeto,
    p.ferramenta,
    p.gerente_projeto,
    p.valor_contrato,
    p.orcamento_custo AS orcamento,
    p.data_inicio,
    p.data_fim_baseline,
    datediff(p.data_fim_baseline, p.data_inicio) AS duracao_baseline_dias,
    p.status,
    ROUND(k.frac_ev * 100.0, 2) AS pct_concluido,
    ROUND(p.orcamento_custo * k.frac_pv, 2) AS pv,
    ROUND(p.orcamento_custo * k.frac_ev, 2) AS ev,
    ROUND(COALESCE(c.ac, 0.0), 2) AS ac,
    ROUND(try_divide(p.orcamento_custo * k.frac_ev, p.orcamento_custo * k.frac_pv), 4) AS spi,
    ROUND(try_divide(p.orcamento_custo * k.frac_ev, c.ac), 4) AS cpi,
    ROUND(try_divide(p.orcamento_custo, try_divide(p.orcamento_custo * k.frac_ev, c.ac)), 2) AS eac,
    u.farol_do_gerente,
    k.max_fim_real
  FROM projetos p
  JOIN kpi_tarefas k ON p.projeto_id = k.projeto_id
  LEFT JOIN custo_acumulado c ON p.projeto_id = c.projeto_id
  LEFT JOIN ultimo_status u ON p.projeto_id = u.projeto_id AND u.rn = 1
)
SELECT
  projeto_id,
  projeto,
  nome_projeto,
  cliente,
  segmento,
  tipo_projeto,
  ferramenta,
  gerente_projeto,
  valor_contrato,
  orcamento,
  data_inicio,
  data_fim_baseline,
  duracao_baseline_dias,
  status,
  pct_concluido,
  pv,
  ev,
  ac,
  spi,
  cpi,
  eac,
  ROUND(greatest(eac - orcamento, 0.0), 2) AS estouro_previsto,
  ROUND(valor_contrato - eac, 2) AS margem_projetada,
  CASE
    WHEN status <> 'em_andamento' THEN greatest(0, datediff(COALESCE(max_fim_real, data_fim_baseline), data_fim_baseline))
    ELSE greatest(0, CAST(ROUND(try_divide(duracao_baseline_dias, spi) - duracao_baseline_dias) AS INT))
  END AS atraso_projetado_dias,
  CASE
    WHEN status <> 'em_andamento' THEN COALESCE(max_fim_real, data_fim_baseline)
    ELSE date_add(data_inicio, CAST(ROUND(try_divide(duracao_baseline_dias, spi)) AS INT))
  END AS termino_projetado,
  CASE
    WHEN status <> 'em_andamento' THEN 'concluído'
    WHEN spi < 0.8 OR cpi < 0.8 THEN 'crítico'
    WHEN spi < 0.9 OR cpi < 0.9 THEN 'atenção'
    ELSE 'ok'
  END AS situacao,
  farol_do_gerente,
  CASE
    WHEN least(spi, cpi) >= 0.95 THEN 'verde'
    WHEN least(spi, cpi) >= 0.90 THEN 'amarelo'
    ELSE 'vermelho'
  END AS farol_calculado,
  (status = 'em_andamento' AND farol_do_gerente = 'verde' AND spi < 0.9) AS melancia
FROM calculado;

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.utilizacao_pessoa_semana
COMMENT 'Utilização e ociosidade semanal por pessoa e projeto, com custo ocioso e SPI do projeto na semana.'
AS
SELECT
  a.colaborador_id,
  c.nome,
  c.papel,
  c.senioridade,
  c.custo_hora,
  a.projeto_id,
  a.semana,
  a.horas_disponiveis,
  a.horas_apontadas,
  ROUND(a.horas_disponiveis - a.horas_apontadas, 2) AS horas_ociosas,
  ROUND(try_divide(a.horas_apontadas, a.horas_disponiveis), 4) AS utilizacao,
  ROUND((a.horas_disponiveis - a.horas_apontadas) * c.custo_hora, 2) AS custo_ocioso,
  f.spi AS spi_do_projeto
FROM apontamentos a
JOIN colaboradores c
  ON a.colaborador_id = c.colaborador_id
LEFT JOIN lakehouse_vertice.gold.fato_projeto_semana f
  ON a.projeto_id = f.projeto_id
 AND a.semana = f.semana;

