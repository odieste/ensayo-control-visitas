#!/usr/bin/env python3
"""Punto de entrada de CDK. Lee los parámetros del contexto (cdk.json y -c clave=valor) y crea la pila."""

import os
import re
import sys

import aws_cdk as cdk

from control_visitas.stack import ControlVisitasStack

app = cdk.App()


def contexto(clave: str) -> str:
    valor = app.node.try_get_context(clave)
    return "" if valor is None else str(valor).strip()


def error(mensaje: str) -> None:
    print(f"Error: {mensaje}", file=sys.stderr)
    sys.exit(1)


exam_id = contexto("exam_id")
mi_ip = contexto("mi_ip")
repo_url = contexto("repo_url")
commit = contexto("commit")
db_host = contexto("db_host")
db_name = contexto("db_name")
secret_name = contexto("secret_name")

# Comprobaciones para que un error de configuración se vea aquí, y no diez minutos después en la instancia
if not re.fullmatch(r"[A-Za-z0-9-]{3,30}", exam_id):
    error("falta exam_id en cdk/cdk.json. Ejecuta antes: bash params.sh <EXAM_ID>")
if not re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?(\.git)?", repo_url):
    error(f"repo_url en cdk/cdk.json no es la URL HTTPS de un repositorio de GitHub: '{repo_url}'")
if not re.fullmatch(r"[0-9a-f]{40}", commit):
    error("falta el commit. Despliega con: bash aws-scripts/desplegar.sh")
if not re.fullmatch(r"[A-Za-z0-9.-]+\.rds\.amazonaws\.com", db_host):
    error(f"db_host en cdk/cdk.json no es un endpoint de RDS: '{db_host}'")

env = cdk.Environment(
    account=os.environ.get("CDK_DEFAULT_ACCOUNT"),
    region=os.environ.get("CDK_DEFAULT_REGION", "us-east-1"),
)

# Sin bootstrap: la pila no tiene assets, y el bootstrap crea roles IAM, que el laboratorio no permite
ControlVisitasStack(
    app, "ControlVisitasStack", env=env, synthesizer=cdk.LegacyStackSynthesizer(),
    exam_id=exam_id, mi_ip=mi_ip, repo_url=repo_url, commit=commit,
    db_host=db_host, db_name=db_name, secret_name=secret_name,
)

app.synth()
