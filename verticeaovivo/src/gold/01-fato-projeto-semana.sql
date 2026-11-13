-- 01-fato-projeto-semana.sql — Evolução semanal de Valor Agregado (PV, EV, AC, SPI, CPI, EAC) e horas por projeto

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.fato_projeto_semana (
  CONSTRAINT pv_nao_negativo EXPECT (pv >= 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT ev_ate_orcamento EXPECT (ev <= orcamento) ON VIOLATION FAIL UPDATE
)
COMMENT 'Fato semanal por projeto (toda sexta-feira até 2026-10-16) com curvas S (PV, EV, AC), SPI, CPI, EAC, farol do gerente e horas.'
AS
WITH semanas_projeto AS (
  SELECT
    p.projeto_id,
    p.nome_projeto,
    p.orcamento_custo AS orcamento,
    p.data_inicio,
    p.data_fim_baseline,
    p.status,
    explode(
      sequence(
        next_day(date_sub(p.data_inicio, 1), 'FRI'),
        DATE'2026-10-16',
        INTERVAL 1 WEEK
      )
    ) AS semana
  FROM projetos p
),
pv_semanal AS (
  SELECT
    sp.projeto_id,
    sp.semana,
    sp.orcamento * SUM(
      t.horas * greatest(
        0.0,
        least(
          1.0,
          datediff(sp.semana, t.inicio_baseline) / CAST(NULLIF(datediff(t.fim_baseline, t.inicio_baseline), 0) AS DOUBLE)
        )
      )
    ) / SUM(t.horas) AS pv
  FROM semanas_projeto sp
  JOIN tarefas t ON sp.projeto_id = t.projeto_id
  GROUP BY sp.projeto_id, sp.semana, sp.orcamento
),
custos_semana AS (
  SELECT
    projeto_id,
    semana,
    SUM(valor) AS custo_semana
  FROM custos
  GROUP BY projeto_id, semana
),
apontamentos_semana AS (
  SELECT
    projeto_id,
    semana,
    SUM(horas_disponiveis) AS horas_disponiveis,
    SUM(horas_apontadas) AS horas_apontadas,
    SUM(horas_disponiveis - horas_apontadas) AS horas_ociosas
  FROM apontamentos
  GROUP BY projeto_id, semana
),
base_acumulada AS (
  SELECT
    sp.projeto_id,
    sp.semana,
    sp.orcamento,
    ROUND(pv.pv, 2) AS pv,
    COALESCE(
      last_value(s.pct_concluido, true) OVER (
        PARTITION BY sp.projeto_id
        ORDER BY sp.semana
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ),
      0
    ) AS pct_concluido,
    ROUND(
      sp.orcamento * COALESCE(
        last_value(s.pct_concluido, true) OVER (
          PARTITION BY sp.projeto_id
          ORDER BY sp.semana
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        0
      ) / 100.0,
      2
    ) AS ev,
    ROUND(
      COALESCE(
        SUM(COALESCE(c.custo_semana, 0.0)) OVER (
          PARTITION BY sp.projeto_id
          ORDER BY sp.semana
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        0.0
      ),
      2
    ) AS ac,
    last_value(s.farol, true) OVER (
      PARTITION BY sp.projeto_id
      ORDER BY sp.semana
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS farol_do_gerente,
    COALESCE(a.horas_disponiveis, 0.0) AS horas_disponiveis,
    COALESCE(a.horas_apontadas, 0.0) AS horas_apontadas,
    COALESCE(a.horas_ociosas, 0.0) AS horas_ociosas
  FROM semanas_projeto sp
  JOIN pv_semanal pv
    ON sp.projeto_id = pv.projeto_id AND sp.semana = pv.semana
  LEFT JOIN status_semanal s
    ON sp.projeto_id = s.projeto_id AND sp.semana = s.data_status
  LEFT JOIN custos_semana c
    ON sp.projeto_id = c.projeto_id AND sp.semana = c.semana
  LEFT JOIN apontamentos_semana a
    ON sp.projeto_id = a.projeto_id AND sp.semana = a.semana
)
SELECT
  projeto_id,
  semana,
  orcamento,
  pct_concluido,
  pv,
  ev,
  ac,
  ROUND(try_divide(ev, pv), 4) AS spi,
  ROUND(try_divide(ev, ac), 4) AS cpi,
  ROUND(try_divide(orcamento, try_divide(ev, ac)), 2) AS eac,
  farol_do_gerente,
  ROUND(horas_disponiveis, 2) AS horas_disponiveis,
  ROUND(horas_apontadas, 2) AS horas_apontadas,
  ROUND(horas_ociosas, 2) AS horas_ociosas
FROM base_acumulada;

