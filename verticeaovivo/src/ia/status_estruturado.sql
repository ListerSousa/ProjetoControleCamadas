-- src/ia/status_estruturado.sql — Classificação e extração estruturada de bloqueios do status semanal (Regra + Palavra-chave + IA v2.0)

CREATE TABLE IF NOT EXISTS lakehouse_vertice.gold.status_estruturado (
  projeto_id STRING COMMENT 'Identificador do projeto (ex.: PRJ-001).',
  data_status DATE COMMENT 'Data de referência do status semanal (sexta-feira).',
  farol STRING COMMENT 'Farol reportado pelo gerente (verde, amarelo, vermelho).',
  causa_bloqueio STRING COMMENT 'Categoria padronizada da causa do bloqueio.',
  bloqueio STRING COMMENT 'Descrição concisa do bloqueio extraída pela IA (quando metodo = ia).',
  quem_destrava STRING COMMENT 'Responsável ou área que destrava o bloqueio extraído pela IA (quando metodo = ia).',
  dias_impacto DOUBLE COMMENT 'Impacto estimado em dias no cronograma (1 semana = 7 dias).',
  metodo STRING COMMENT 'Método utilizado na classificação: regra, ia ou palavra_chave.',
  texto_status STRING COMMENT 'Texto livre original publicado pelo gerente no status semanal.',
  _classificado_em TIMESTAMP COMMENT 'Data e hora em que o registro foi classificado e inserido na tabela.'
)
COMMENT 'Status semanal estruturado com causa de bloqueio, resumo, responsável por destravar e dias de impacto (acumulativo via MERGE).';

MERGE INTO lakehouse_vertice.gold.status_estruturado AS destino
USING (
  WITH pendentes AS (
    SELECT
      s.projeto_id,
      s.data_status,
      s.farol,
      s.texto_status,
      s.status_vazio,
      lower(COALESCE(s.texto_status, '')) AS txt_lower,
      CASE
        WHEN s.status_vazio
          OR lower(COALESCE(s.texto_status, '')) RLIKE 'bloqueios: nenhum|sem bloqueios|nada relevante'
          THEN 'regra'
        WHEN s.data_status >= DATE'2026-07-18'
          THEN 'ia'
        ELSE 'palavra_chave'
      END AS metodo
    FROM lakehouse_vertice.silver.status_semanal s
    LEFT ANTI JOIN lakehouse_vertice.gold.status_estruturado d
      ON s.projeto_id = d.projeto_id
     AND s.data_status = d.data_status
  ),
  sem_ia AS (
    SELECT
      projeto_id,
      data_status,
      farol,
      CASE
        WHEN status_vazio THEN 'nao_reportado'
        WHEN metodo = 'regra' THEN 'sem_bloqueio'
        WHEN txt_lower RLIKE 'freeze|congelamento|janela de deploy' THEN 'change_freeze'
        WHEN txt_lower RLIKE 'sre|infraestrutura|ambiente de homologação' THEN 'falta_sre'
        WHEN txt_lower RLIKE 'forge|consultoria|fornecedor' THEN 'dependencia_fornecedor'
        WHEN txt_lower RLIKE 'saída de|rotatividade|onboarding' THEN 'rotatividade'
        WHEN txt_lower RLIKE 'escopo|change request|regra de negócio' THEN 'mudanca_escopo'
        WHEN txt_lower RLIKE 'bugs|regressão|refazendo' THEN 'bug_retrabalho'
        WHEN txt_lower RLIKE 'aprovação do cliente|homologação do cliente' THEN 'aprovacao_cliente'
      END AS causa_bloqueio,
      CAST(NULL AS STRING) AS bloqueio,
      CAST(NULL AS STRING) AS quem_destrava,
      CASE
        WHEN metodo = 'regra' THEN CAST(NULL AS DOUBLE)
        WHEN txt_lower RLIKE 'impacto estimado: 1 semana' THEN 7.0
        WHEN regexp_extract(txt_lower, 'impacto estimado de ([0-9]+) dias', 1) <> ''
          THEN CAST(regexp_extract(txt_lower, 'impacto estimado de ([0-9]+) dias', 1) AS DOUBLE)
        ELSE CAST(NULL AS DOUBLE)
      END AS dias_impacto,
      metodo,
      texto_status,
      current_timestamp() AS _classificado_em
    FROM pendentes
    WHERE metodo <> 'ia'
  ),
  com_ia_bruto AS (
    SELECT
      projeto_id,
      data_status,
      farol,
      metodo,
      texto_status,
      ai_classify(
        texto_status,
        '["change_freeze","falta_sre","dependencia_fornecedor","rotatividade","mudanca_escopo","bug_retrabalho","aprovacao_cliente","sem_bloqueio"]',
        map('version', '2.0')
      ) AS cls,
      ai_extract(
        texto_status,
        '{"bloqueio":{"type":"string"},"quem_destrava":{"type":"string"},"dias_impacto":{"type":"number","description":"1 semana = 7"}}',
        map('version', '2.0')
      ) AS ext
    FROM pendentes
    WHERE metodo = 'ia'
  ),
  com_ia AS (
    SELECT
      projeto_id,
      data_status,
      farol,
      CAST(cls:response[0] AS STRING) AS causa_bloqueio,
      CAST(ext:response.bloqueio AS STRING) AS bloqueio,
      CAST(ext:response.quem_destrava AS STRING) AS quem_destrava,
      CAST(ext:response.dias_impacto AS DOUBLE) AS dias_impacto,
      metodo,
      texto_status,
      current_timestamp() AS _classificado_em
    FROM com_ia_bruto
  )
  SELECT * FROM sem_ia
  UNION ALL
  SELECT * FROM com_ia
) AS origem
ON destino.projeto_id = origem.projeto_id
AND destino.data_status = origem.data_status
WHEN NOT MATCHED THEN INSERT (
  projeto_id,
  data_status,
  farol,
  causa_bloqueio,
  bloqueio,
  quem_destrava,
  dias_impacto,
  metodo,
  texto_status,
  _classificado_em
) VALUES (
  origem.projeto_id,
  origem.data_status,
  origem.farol,
  origem.causa_bloqueio,
  origem.bloqueio,
  origem.quem_destrava,
  origem.dias_impacto,
  origem.metodo,
  origem.texto_status,
  origem._classificado_em
);

SELECT
  metodo,
  causa_bloqueio,
  COUNT(*) AS quantidade
FROM lakehouse_vertice.gold.status_estruturado
GROUP BY metodo, causa_bloqueio
ORDER BY metodo, quantidade DESC;

