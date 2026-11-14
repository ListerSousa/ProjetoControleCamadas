import json
from pathlib import Path


def text_widget(name: str, lines: list[str], x: int, y: int, width: int = 12, height: int = 2) -> dict:
    return {
        "widget": {
            "name": name,
            "multilineTextboxSpec": {
                "lines": lines,
            },
        },
        "position": {"x": x, "y": y, "width": width, "height": height},
    }


def counter_widget(
    name: str,
    dataset: str,
    field: str,
    title: str,
    x: int,
    y: int,
    width: int,
    height: int = 3,
    fmt: dict | None = None,
    description: str | None = None,
) -> dict:
    value_enc: dict = {
        "fieldName": field,
        "displayName": title,
    }
    if fmt is not None:
        value_enc["format"] = fmt

    frame: dict = {"showTitle": True, "title": title}
    if description:
        frame["showDescription"] = True
        frame["description"] = description

    return {
        "widget": {
            "name": name,
            "queries": [
                {
                    "name": "main_query",
                    "query": {
                        "datasetName": dataset,
                        "fields": [{"name": field, "expression": f"`{field}`"}],
                        "disaggregated": True,
                    },
                }
            ],
            "spec": {
                "version": 2,
                "widgetType": "counter",
                "encodings": {"value": value_enc},
                "frame": frame,
            },
        },
        "position": {"x": x, "y": y, "width": width, "height": height},
    }


def table_widget(
    name: str,
    dataset: str,
    columns: list[tuple[str, str]],
    title: str,
    x: int,
    y: int,
    width: int = 12,
    height: int = 6,
) -> dict:
    return {
        "widget": {
            "name": name,
            "queries": [
                {
                    "name": "main_query",
                    "query": {
                        "datasetName": dataset,
                        "fields": [{"name": col, "expression": f"`{col}`"} for col, _ in columns],
                        "disaggregated": True,
                    },
                }
            ],
            "spec": {
                "version": 2,
                "widgetType": "table",
                "encodings": {
                    "columns": [
                        {"fieldName": col, "displayName": label} for col, label in columns
                    ]
                },
                "frame": {"showTitle": True, "title": title},
            },
        },
        "position": {"x": x, "y": y, "width": width, "height": height},
    }


def build_dashboard() -> dict:
    brl_compact = {
        "type": "number-currency",
        "currencyCode": "BRL",
        "abbreviation": "compact",
        "decimalPlaces": {"type": "max", "places": 2},
    }
    decimal_4 = {
        "type": "number-plain",
        "decimalPlaces": {"type": "exact", "places": 4},
    }

    datasets = [
        {
            "name": "ds_kpis_portfolio",
            "displayName": "KPIs da Carteira em Andamento",
            "queryLines": [
                "SELECT\n",
                "  ROUND(SUM(valor_contrato), 2) AS carteira,\n",
                "  ROUND(SUM(ev) / SUM(pv), 4) AS spi,\n",
                "  ROUND(SUM(ev) / SUM(ac), 4) AS cpi,\n",
                "  ROUND(SUM(estouro_previsto), 2) AS estouro_previsto,\n",
                "  COUNT_IF(situacao IN ('atenção', 'crítico')) AS projetos_em_risco,\n",
                "  COUNT_IF(situacao = 'crítico') AS criticos,\n",
                "  COUNT_IF(melancia) AS melancias\n",
                "FROM projeto_situacao_atual\n",
                "WHERE status = 'em_andamento'\n",
            ],
        },
        {
            "name": "ds_projetos_andamento",
            "displayName": "Projetos em Andamento",
            "queryLines": [
                "SELECT\n",
                "  projeto_id,\n",
                "  projeto,\n",
                "  nome_projeto,\n",
                "  cliente,\n",
                "  segmento,\n",
                "  ferramenta,\n",
                "  gerente_projeto,\n",
                "  valor_contrato,\n",
                "  orcamento,\n",
                "  pct_concluido,\n",
                "  pv,\n",
                "  ev,\n",
                "  ac,\n",
                "  spi,\n",
                "  cpi,\n",
                "  eac,\n",
                "  estouro_previsto,\n",
                "  margem_projetada,\n",
                "  atraso_projetado_dias,\n",
                "  termino_projetado,\n",
                "  situacao,\n",
                "  farol_do_gerente,\n",
                "  farol_calculado,\n",
                "  CASE WHEN melancia THEN 'Melancia' ELSE 'Normal' END AS status_melancia,\n",
                "  melancia\n",
                "FROM projeto_situacao_atual\n",
                "WHERE status = 'em_andamento'\n",
                "ORDER BY estouro_previsto DESC, spi ASC\n",
            ],
        },
        {
            "name": "ds_curva_spi_cpi",
            "displayName": "SPI e CPI Semanais da Carteira",
            "queryLines": [
                "SELECT\n",
                "  semana,\n",
                "  ROUND(SUM(ev) / SUM(pv), 4) AS spi,\n",
                "  ROUND(SUM(ev) / SUM(ac), 4) AS cpi\n",
                "FROM fato_projeto_semana\n",
                "WHERE semana >= DATE'2025-03-07'\n",
                "GROUP BY semana\n",
                "ORDER BY semana\n",
            ],
        },
        {
            "name": "ds_top15_pessoas_ociosas",
            "displayName": "Top 15 Pessoas por Custo da Hora Parada (12 semanas)",
            "queryLines": [
                "SELECT\n",
                "  colaborador_id,\n",
                "  concat(colaborador_id, ' · ', nome) AS pessoa,\n",
                "  nome,\n",
                "  papel,\n",
                "  senioridade,\n",
                "  ROUND(SUM(horas_disponiveis), 1) AS horas_disponiveis,\n",
                "  ROUND(SUM(horas_apontadas), 1) AS horas_apontadas,\n",
                "  ROUND(SUM(horas_ociosas), 1) AS horas_ociosas,\n",
                "  ROUND(SUM(horas_apontadas) / SUM(horas_disponiveis), 4) AS utilizacao,\n",
                "  ROUND(SUM(custo_ocioso), 2) AS custo_ocioso\n",
                "FROM utilizacao_pessoa_semana\n",
                "WHERE semana > DATE'2026-07-24'\n",
                "GROUP BY colaborador_id, nome, papel, senioridade\n",
                "ORDER BY custo_ocioso DESC\n",
                "LIMIT 15\n",
            ],
        },
        {
            "name": "ds_utilizacao_pessoa_projeto",
            "displayName": "Utilização por Pessoa e Projeto",
            "queryLines": [
                "SELECT\n",
                "  colaborador_id,\n",
                "  nome,\n",
                "  papel,\n",
                "  senioridade,\n",
                "  projeto_id,\n",
                "  ROUND(SUM(horas_disponiveis), 1) AS horas_disponiveis,\n",
                "  ROUND(SUM(horas_apontadas), 1) AS horas_apontadas,\n",
                "  ROUND(SUM(horas_ociosas), 1) AS horas_ociosas,\n",
                "  ROUND(SUM(horas_apontadas) * 100.0 / SUM(horas_disponiveis), 1) AS utilizacao_pct,\n",
                "  ROUND(SUM(custo_ocioso), 2) AS custo_ocioso,\n",
                "  ROUND(AVG(spi_do_projeto), 4) AS spi_do_projeto\n",
                "FROM utilizacao_pessoa_semana\n",
                "WHERE semana > DATE'2026-07-24'\n",
                "GROUP BY colaborador_id, nome, papel, senioridade, projeto_id\n",
                "ORDER BY utilizacao_pct ASC, custo_ocioso DESC\n",
            ],
        },
        {
            "name": "ds_causas_bloqueio_projeto",
            "displayName": "Causas de Bloqueio por Projeto (Últimos 90 dias)",
            "queryLines": [
                "SELECT\n",
                "  projeto_id,\n",
                "  causa_bloqueio,\n",
                "  COUNT(*) AS ocorrencias,\n",
                "  ROUND(SUM(COALESCE(dias_impacto, 0)), 1) AS dias_impacto\n",
                "FROM status_estruturado\n",
                "WHERE data_status >= DATE'2026-07-18'\n",
                "  AND causa_bloqueio NOT IN ('sem_bloqueio', 'nao_reportado')\n",
                "GROUP BY projeto_id, causa_bloqueio\n",
                "ORDER BY ocorrencias DESC\n",
            ],
        },
        {
            "name": "ds_fornecedores_resumo",
            "displayName": "Resumo por Fornecedor",
            "queryLines": [
                "SELECT\n",
                "  fornecedor,\n",
                "  COUNT(DISTINCT fornecedor_como_veio) AS grafias_no_cadastro,\n",
                "  COUNT(*) AS entregas,\n",
                "  ROUND(SUM(prazo_real_dias) / CAST(SUM(CASE WHEN NOT em_aberto THEN prazo_prometido_dias END) AS DOUBLE), 2) AS prazo_real_div_prometido,\n",
                "  ROUND(COUNT_IF(NOT em_aberto AND dias_de_atraso_na_entrega <= 0) * 100.0 / NULLIF(COUNT_IF(NOT em_aberto), 0), 1) AS pct_no_prazo,\n",
                "  COUNT_IF(em_atraso) AS em_atraso_hoje,\n",
                "  ROUND(SUM(valor), 2) AS valor_contratado\n",
                "FROM lakehouse_vertice.silver.entregas_fornecedor\n",
                "GROUP BY fornecedor\n",
                "ORDER BY em_atraso_hoje DESC, pct_no_prazo ASC\n",
            ],
        },
        {
            "name": "ds_entregas_em_atraso",
            "displayName": "Entregas em Atraso Hoje",
            "queryLines": [
                "SELECT\n",
                "  entrega_id,\n",
                "  projeto_id,\n",
                "  fornecedor,\n",
                "  fornecedor_como_veio,\n",
                "  item,\n",
                "  ROUND(valor, 2) AS valor,\n",
                "  data_pedido,\n",
                "  data_prometida,\n",
                "  prazo_prometido_dias,\n",
                "  datediff(DATE'2026-10-16', data_prometida) AS dias_em_atraso_hoje,\n",
                "  status\n",
                "FROM lakehouse_vertice.silver.entregas_fornecedor\n",
                "WHERE em_atraso = true\n",
                "ORDER BY dias_em_atraso_hoje DESC, valor DESC\n",
            ],
        },
    ]

    # --- PÁGINA 1: PORTFÓLIO ---
    page_portfolio = {
        "name": "portfolio",
        "displayName": "Portfólio",
        "pageType": "PAGE_TYPE_CANVAS",
        "layoutVersion": "GRID_V1",
        "layout": [
            text_widget(
                "titulo-portfolio",
                [
                    "## Portfólio · Quais projetos estão atrasando, quanto vão estourar no orçamento e onde estão os projetos melancia?\n",
                    "\n",
                    "Visão executiva da carteira em andamento em **2026-10-16** integrando Excel, ClickUp e MS Project com custos reais e farol reportado.",
                ],
                x=0,
                y=0,
                width=12,
                height=2,
            ),
            counter_widget(
                "kpi-carteira",
                "ds_kpis_portfolio",
                "carteira",
                "Carteira em Andamento",
                x=0,
                y=2,
                width=3,
                height=3,
                fmt=brl_compact,
            ),
            counter_widget(
                "kpi-spi",
                "ds_kpis_portfolio",
                "spi",
                "SPI da Carteira (SUM/SUM)",
                x=3,
                y=2,
                width=3,
                height=3,
                fmt=decimal_4,
            ),
            counter_widget(
                "kpi-cpi",
                "ds_kpis_portfolio",
                "cpi",
                "CPI da Carteira (SUM/SUM)",
                x=6,
                y=2,
                width=3,
                height=3,
                fmt=decimal_4,
            ),
            counter_widget(
                "kpi-estouro",
                "ds_kpis_portfolio",
                "estouro_previsto",
                "Estouro Previsto Total",
                x=9,
                y=2,
                width=3,
                height=3,
                fmt=brl_compact,
            ),
            counter_widget(
                "kpi-em-risco",
                "ds_kpis_portfolio",
                "projetos_em_risco",
                "Projetos em Risco (Atenção + Crítico)",
                x=0,
                y=5,
                width=4,
                height=3,
            ),
            counter_widget(
                "kpi-criticos",
                "ds_kpis_portfolio",
                "criticos",
                "Projetos Críticos (SPI ou CPI < 0,8)",
                x=4,
                y=5,
                width=4,
                height=3,
            ),
            counter_widget(
                "kpi-melancias",
                "ds_kpis_portfolio",
                "melancias",
                "Projetos Melancia (Farol Verde e SPI < 0,9)",
                x=8,
                y=5,
                width=4,
                height=3,
            ),
            {
                "widget": {
                    "name": "bar-estouro-por-projeto",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_projetos_andamento",
                                "fields": [
                                    {"name": "projeto_id", "expression": "`projeto_id`"},
                                    {"name": "estouro_previsto", "expression": "`estouro_previsto`"},
                                    {"name": "situacao", "expression": "`situacao`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "bar",
                        "encodings": {
                            "x": {
                                "fieldName": "projeto_id",
                                "displayName": "Projeto",
                                "scale": {"type": "categorical"},
                            },
                            "y": {
                                "fieldName": "estouro_previsto",
                                "displayName": "Estouro Previsto (R$)",
                                "scale": {"type": "quantitative"},
                            },
                            "color": {
                                "fieldName": "situacao",
                                "displayName": "Situação",
                                "scale": {
                                    "type": "categorical",
                                    "mappings": [
                                        {"value": "crítico", "color": "#FF5F46"},
                                        {"value": "atenção", "color": "#F6C344"},
                                        {"value": "ok", "color": "#22C2F4"},
                                    ],
                                },
                            },
                        },
                        "frame": {
                            "showTitle": True,
                            "title": "Estouro Previsto por Projeto ( colorido por Situação )",
                        },
                    },
                },
                "position": {"x": 0, "y": 8, "width": 6, "height": 6},
            },
            {
                "widget": {
                    "name": "scatter-spi-cpi",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_projetos_andamento",
                                "fields": [
                                    {"name": "spi", "expression": "`spi`"},
                                    {"name": "cpi", "expression": "`cpi`"},
                                    {"name": "situacao", "expression": "`situacao`"},
                                    {"name": "orcamento", "expression": "`orcamento`"},
                                    {"name": "projeto_id", "expression": "`projeto_id`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "scatter",
                        "encodings": {
                            "x": {
                                "fieldName": "spi",
                                "displayName": "SPI (Prazo)",
                                "scale": {"type": "quantitative"},
                            },
                            "y": {
                                "fieldName": "cpi",
                                "displayName": "CPI (Custo)",
                                "scale": {"type": "quantitative"},
                            },
                            "color": {
                                "fieldName": "situacao",
                                "displayName": "Situação",
                                "scale": {
                                    "type": "categorical",
                                    "mappings": [
                                        {"value": "crítico", "color": "#FF5F46"},
                                        {"value": "atenção", "color": "#F6C344"},
                                        {"value": "ok", "color": "#22C2F4"},
                                    ],
                                },
                            },
                            "size": {
                                "fieldName": "orcamento",
                                "displayName": "Orçamento (R$)",
                                "scale": {"type": "quantitative"},
                            },
                        },
                        "frame": {
                            "showTitle": True,
                            "title": "Dispersão SPI × CPI por Projeto em Andamento",
                        },
                    },
                },
                "position": {"x": 6, "y": 8, "width": 6, "height": 6},
            },
            {
                "widget": {
                    "name": "line-spi-cpi-semanal",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_curva_spi_cpi",
                                "fields": [
                                    {"name": "semana", "expression": "`semana`"},
                                    {"name": "spi", "expression": "`spi`"},
                                    {"name": "cpi", "expression": "`cpi`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "line",
                        "encodings": {
                            "x": {
                                "fieldName": "semana",
                                "displayName": "Semana (Sexta-feira)",
                                "scale": {"type": "temporal"},
                            },
                            "y": {
                                "scale": {"type": "quantitative"},
                                "fields": [
                                    {"fieldName": "spi", "displayName": "SPI da Carteira"},
                                    {"fieldName": "cpi", "displayName": "CPI da Carteira"},
                                ],
                            },
                        },
                        "frame": {
                            "showTitle": True,
                            "title": "Evolução Semanal de SPI e CPI da Carteira (a partir de 2025-03-07)",
                        },
                    },
                },
                "position": {"x": 0, "y": 14, "width": 12, "height": 5},
            },
            table_widget(
                "tabela-projetos-andamento",
                "ds_projetos_andamento",
                [
                    ("projeto", "Projeto"),
                    ("cliente", "Cliente"),
                    ("ferramenta", "Ferramenta"),
                    ("gerente_projeto", "Gerente"),
                    ("pct_concluido", "% Concluído"),
                    ("spi", "SPI"),
                    ("cpi", "CPI"),
                    ("farol_do_gerente", "Farol do Gerente"),
                    ("farol_calculado", "Farol pelo Número"),
                    ("melancia", "Melancia"),
                    ("situacao", "Situação"),
                    ("estouro_previsto", "Estouro Previsto (R$)"),
                    ("atraso_projetado_dias", "Atraso Projetado (dias)"),
                ],
                "Projetos em Andamento — Farol do Gerente vs. Farol pelo Número e Melancia",
                x=0,
                y=19,
                width=12,
                height=7,
            ),
        ],
    }

    # --- PÁGINA 2: PESSOAS ---
    page_pessoas = {
        "name": "pessoas",
        "displayName": "Pessoas",
        "pageType": "PAGE_TYPE_CANVAS",
        "layoutVersion": "GRID_V1",
        "layout": [
            text_widget(
                "titulo-pessoas",
                [
                    "## Pessoas · Quem está com horas paradas nas últimas 12 semanas e quais bloqueios travam os times?\n",
                    "\n",
                    "Análise de ociosidade (`semana > 2026-07-24`) e causas de bloqueio estruturadas nos últimos 90 dias (`data_status >= 2026-07-18`).",
                ],
                x=0,
                y=0,
                width=12,
                height=2,
            ),
            {
                "widget": {
                    "name": "bar-top15-pessoas-custo-ocioso",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_top15_pessoas_ociosas",
                                "fields": [
                                    {"name": "pessoa", "expression": "`pessoa`"},
                                    {"name": "custo_ocioso", "expression": "`custo_ocioso`"},
                                    {"name": "papel", "expression": "`papel`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "bar",
                        "encodings": {
                            "x": {
                                "fieldName": "custo_ocioso",
                                "displayName": "Custo da Hora Parada (R$)",
                                "scale": {"type": "quantitative"},
                            },
                            "y": {
                                "fieldName": "pessoa",
                                "displayName": "Colaborador",
                                "scale": {"type": "categorical"},
                            },
                            "color": {
                                "fieldName": "papel",
                                "displayName": "Papel",
                                "scale": {"type": "categorical"},
                            },
                        },
                        "frame": {
                            "showTitle": True,
                            "title": "Top 15 Pessoas por Custo da Hora Parada (Últimas 12 Semanas)",
                        },
                    },
                },
                "position": {"x": 0, "y": 2, "width": 6, "height": 6},
            },
            {
                "widget": {
                    "name": "bar-causas-bloqueio-projeto",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_causas_bloqueio_projeto",
                                "fields": [
                                    {"name": "projeto_id", "expression": "`projeto_id`"},
                                    {"name": "ocorrencias", "expression": "`ocorrencias`"},
                                    {"name": "causa_bloqueio", "expression": "`causa_bloqueio`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "bar",
                        "encodings": {
                            "x": {
                                "fieldName": "projeto_id",
                                "displayName": "Projeto",
                                "scale": {"type": "categorical"},
                            },
                            "y": {
                                "fieldName": "ocorrencias",
                                "displayName": "Semanas com Bloqueio",
                                "scale": {"type": "quantitative"},
                            },
                            "color": {
                                "fieldName": "causa_bloqueio",
                                "displayName": "Causa do Bloqueio",
                                "scale": {"type": "categorical"},
                            },
                        },
                        "frame": {
                            "showTitle": True,
                            "title": "Causas de Bloqueio por Projeto (Últimos 90 Dias)",
                        },
                    },
                },
                "position": {"x": 6, "y": 2, "width": 6, "height": 6},
            },
            table_widget(
                "tabela-utilizacao-pessoa-projeto",
                "ds_utilizacao_pessoa_projeto",
                [
                    ("colaborador_id", "ID"),
                    ("nome", "Nome"),
                    ("papel", "Papel"),
                    ("senioridade", "Senioridade"),
                    ("projeto_id", "Projeto"),
                    ("horas_disponiveis", "Horas Disponíveis"),
                    ("horas_apontadas", "Horas Apontadas"),
                    ("horas_ociosas", "Horas Ociosas"),
                    ("utilizacao_pct", "Utilização (%)"),
                    ("custo_ocioso", "Custo Ocioso (R$)"),
                    ("spi_do_projeto", "SPI Médio do Projeto"),
                ],
                "Utilização por Pessoa e Projeto (da mais parada à mais ocupada — últimas 12 semanas)",
                x=0,
                y=8,
                width=12,
                height=8,
            ),
        ],
    }

    # --- PÁGINA 3: FORNECEDORES ---
    page_fornecedores = {
        "name": "fornecedores",
        "displayName": "Fornecedores",
        "pageType": "PAGE_TYPE_CANVAS",
        "layoutVersion": "GRID_V1",
        "layout": [
            text_widget(
                "titulo-fornecedores",
                [
                    "## Fornecedores · Qual consultoria atrasa nossas entregas e quais pacotes estão vencidos hoje?\n",
                    "\n",
                    "Auditoria direta sobre `lakehouse_vertice.silver.entregas_fornecedor` após unificação das 4 grafias da CodeForge Consultoria.",
                ],
                x=0,
                y=0,
                width=12,
                height=2,
            ),
            table_widget(
                "tabela-resumo-fornecedores",
                "ds_fornecedores_resumo",
                [
                    ("fornecedor", "Fornecedor"),
                    ("grafias_no_cadastro", "Grafias no Cadastro"),
                    ("entregas", "Entregas"),
                    ("prazo_real_div_prometido", "Prazo Real ÷ Prometido"),
                    ("pct_no_prazo", "% no Prazo"),
                    ("em_atraso_hoje", "Em Atraso Hoje"),
                    ("valor_contratado", "Valor Total (R$)"),
                ],
                "Desempenho por Fornecedor (Grafias, Entregas, Prazo Real ÷ Prometido, % no Prazo e Em Atraso Hoje)",
                x=0,
                y=2,
                width=12,
                height=5,
            ),
            table_widget(
                "tabela-entregas-em-atraso",
                "ds_entregas_em_atraso",
                [
                    ("entrega_id", "Entrega ID"),
                    ("projeto_id", "Projeto"),
                    ("fornecedor", "Fornecedor Normalizado"),
                    ("fornecedor_como_veio", "Fornecedor como Veio"),
                    ("item", "Item / Entregável"),
                    ("valor", "Valor (R$)"),
                    ("data_pedido", "Data do Pedido"),
                    ("data_prometida", "Data Prometida"),
                    ("prazo_prometido_dias", "Prazo Prometido (dias)"),
                    ("dias_em_atraso_hoje", "Dias em Atraso Hoje (2026-10-16)"),
                ],
                "Entregas em Atraso Hoje (Em Aberto com Data Prometida anterior a 2026-10-16)",
                x=0,
                y=7,
                width=12,
                height=6,
            ),
        ],
    }

    return {
        "datasets": datasets,
        "pages": [page_portfolio, page_pessoas, page_fornecedores],
        "uiSettings": {
            "theme": {
                "canvasBackgroundColor": {"light": "#F7F9FC", "dark": "#14141A"},
                "widgetBackgroundColor": {"light": "#FFFFFF", "dark": "#1C1C24"},
                "fontColor": {"light": "#14141A", "dark": "#F0F4F8"},
                "selectionColor": {"light": "#0059DB", "dark": "#22C2F4"},
                "visualizationColors": [
                    "#0059DB",
                    "#22C2F4",
                    "#F6C344",
                    "#FF5F46",
                    "#8B5CF6",
                    "#10B981",
                ],
                "widgetHeaderAlignment": "LEFT",
            }
        },
    }


def main() -> None:
    destino = Path("resources/dashboard-portfolio.lvdash.json")
    destino.parent.mkdir(parents=True, exist_ok=True)
    dashboard = build_dashboard()
    destino.write_text(json.dumps(dashboard, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Dashboard gerado com sucesso em {destino} ({len(dashboard['datasets'])} datasets, {len(dashboard['pages'])} páginas)")


if __name__ == "__main__":
    main()

