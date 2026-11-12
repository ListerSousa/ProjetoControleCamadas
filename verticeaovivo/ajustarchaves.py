import json, pathlib, re
arquivo = pathlib.Path("resources/ingestao.job.yml")
assert arquivo.exists(), "não achei resources/ingestao.job.yml: rode na pasta do bundle (cd ~/projetos/vertice) e depois do generate"
yml = arquivo.read_text()
chaves = {"s3_access_key_id": "AWS_ACCESS_KEY_ID", "s3_secret_access_key": "AWS_SECRET_ACCESS_KEY"}
valores = {}
for var, param in chaves.items():
    valores[var] = re.search(rf"{param}: (.+)", yml).group(1).strip().strip("\"'")
    yml = re.sub(rf"{param}: .+", f"{param}: ${{var.{var}}}", yml)
yml = "variables:\n" + "".join(f"  {v}:\n    description: chave do data lake (o valor fica fora do Git)\n" for v in chaves) + "\n" + yml
arquivo.write_text(yml)
pasta = pathlib.Path(".databricks/bundle/dev"); pasta.mkdir(parents=True, exist_ok=True)
(pasta / "variable-overrides.json").write_text(json.dumps(valores))
print("ok: as chaves saíram do YAML e foram para", pasta / "variable-overrides.json")