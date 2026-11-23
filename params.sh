#!/bin/bash

# Prepara el control a partir de tu EXAM_ID: escribe exam_id y tu IP pública (para la regla del SSH)
# en el contexto de cdk/cdk.json. La IP de la instancia la escribe después aws-scripts/desplegar.sh en
# entrega.txt.
#
# Uso:
#   bash params.sh <EXAM_ID>
set -e

DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

if [ -z "${1:-}" ] || [ -n "${2:-}" ]; then
    echo "Uso: $0 <EXAM_ID>"
    exit 1
fi
if ! [[ "$1" =~ ^[A-Za-z0-9-]{3,30}$ ]]; then
    echo "Error: EXAM_ID solo admite letras, números y guiones (3 a 30 caracteres)."
    exit 1
fi
EXAM_ID="$1"

PYTHON="$(command -v python3 || command -v python || true)"
[ -n "$PYTHON" ] || { echo "Error: no encuentro python3 (lo necesita CDK)."; exit 1; }

# IP pública de esta máquina. Si no se averigua, la pila no abre el SSH (no es imprescindible).
MI_IP="$(curl -s --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')"
if ! [[ "$MI_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    MI_IP=""
    echo "Aviso: no se pudo averiguar tu IP pública. La instancia no tendrá SSH abierto." >&2
fi

"$PYTHON" - "$DIR/cdk/cdk.json" "$EXAM_ID" "$MI_IP" <<'PY'
import json, sys
ruta, exam_id, mi_ip = sys.argv[1:]
with open(ruta, encoding="utf-8") as f:
    datos = json.load(f)
datos["context"]["exam_id"] = exam_id
datos["context"]["mi_ip"] = mi_ip
with open(ruta, "w", encoding="utf-8") as f:
    json.dump(datos, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

echo "EXAM_ID $EXAM_ID escrito en cdk/cdk.json."
if [ -n "$MI_IP" ]; then echo "Tu IP pública ($MI_IP) queda en cdk/cdk.json para la regla del SSH."; fi
