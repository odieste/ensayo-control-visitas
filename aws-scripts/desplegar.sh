#!/bin/bash

# Despliega con CDK el último commit de la rama main de tu fork en GitHub y espera a que la aplicación
# responda.
#
#   1. Comprueba que estás en main, que no hay cambios sin commit y que tu main es exactamente la de
#      GitHub.
#   2. Ejecuta cdk deploy con ese commit (-c commit=...).
#   3. Escribe la IP de la instancia en entrega.txt.
#   4. Espera a que http://<IP>/health responda con ese commit.
#
# Uso:
#   bash aws-scripts/desplegar.sh          despliega
#   bash aws-scripts/desplegar.sh --diff   hace las mismas comprobaciones y muestra qué cambiaría en AWS
#                                          (cdk diff), sin desplegar nada
set -e

MODO=deploy
case "${1:-}" in
    "")     ;;
    --diff) MODO=diff ;;
    *)      echo "Uso: $0 [--diff]" >&2; exit 1 ;;
esac

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
CDK_DIR="$ROOT/cdk"
cd "$ROOT"

fallo() { echo "Error: $*" >&2; exit 1; }

# La orden cdk es un programa de Node.js. Si no está instalada, se usa con npx, que la descarga al vuelo
if command -v cdk >/dev/null 2>&1; then
    CDK=(cdk)
elif command -v npx >/dev/null 2>&1; then
    echo "No encuentro la orden cdk: uso npx -y aws-cdk@2 (necesita Node.js)."
    CDK=(npx -y aws-cdk@2)
else
    fallo "no encuentro ni cdk ni npx. Instala Node.js (https://nodejs.org) y, si quieres, la orden cdk: npm install -g aws-cdk"
fi
PYTHON="$(command -v python3 || command -v python || true)"
[ -n "$PYTHON" ] || fallo "no encuentro python3."
leer_ctx() { "$PYTHON" -c 'import json,sys; print(json.load(open(sys.argv[1]))["context"].get(sys.argv[2], ""))' "$CDK_DIR/cdk.json" "$1"; }

# --- 1. Git ---------------------------------------------------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fallo "esta carpeta no es un repositorio de git."
# entrega.txt no cuenta: lo reescribe este mismo script, y no influye en lo que se despliega
if [ -n "$(git status --porcelain --untracked-files=no -- . ':!entrega.txt')" ]; then
    git status --short --untracked-files=no -- . ':!entrega.txt'
    fallo "hay cambios sin commit. Haz commit y push antes de desplegar."
fi
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || fallo "no estás en la rama main. Cambia a ella con: git switch main"

echo "Comprobando que tu main es la misma que la de GitHub..."
git fetch --quiet origin main || fallo "no puedo hacer fetch de la rama main de origin."
COMMIT="$(git rev-parse HEAD)"
REMOTO="$(git rev-parse origin/main)"
if [ "$COMMIT" != "$REMOTO" ]; then
    if git merge-base --is-ancestor "$REMOTO" "$COMMIT"; then
        fallo "tienes commits sin subir a GitHub. Haz git push."
    elif git merge-base --is-ancestor "$COMMIT" "$REMOTO"; then
        fallo "GitHub tiene commits que no están en tu equipo. Haz git pull."
    else
        fallo "tu main y la de GitHub han divergido. Haz git pull, resuelve los conflictos y haz git push."
    fi
fi

# repo_url (lo que clona la instancia) debe ser el mismo repositorio que origin (donde haces push)
normalizar() { echo "$1" | sed -E 's#^git@github\.com:#https://github.com/#; s#\.git$##; s#/$##' | tr '[:upper:]' '[:lower:]'; }
REPO_URL="$(leer_ctx repo_url)"
ORIGIN_URL="$(git remote get-url origin)"
if [ "$(normalizar "$REPO_URL")" != "$(normalizar "$ORIGIN_URL")" ]; then
    fallo "repo_url de cdk/cdk.json ('$REPO_URL') no es tu repositorio origin ('$ORIGIN_URL')."
fi

# --- 2. CDK ---------------------------------------------------------------------------------
# Entorno virtual de Python con las librerías de CDK. Se crea la primera vez.
if [ ! -d "$CDK_DIR/.venv" ]; then
    echo "Creando el entorno virtual de Python de CDK (solo la primera vez)..."
    "$PYTHON" -m venv "$CDK_DIR/.venv"
fi
if [ -f "$CDK_DIR/.venv/bin/activate" ]; then
    source "$CDK_DIR/.venv/bin/activate"
else
    source "$CDK_DIR/.venv/Scripts/activate"   # Git Bash en Windows
fi
pip install -q -r "$CDK_DIR/requirements.txt"

if [ "$MODO" = diff ]; then
    echo "Cambios que haría el despliegue del commit ${COMMIT:0:7} (no se despliega nada):"
    (cd "$CDK_DIR" && "${CDK[@]}" diff -c "commit=$COMMIT")
    exit 0
fi

INICIO=$SECONDS
(cd "$CDK_DIR" && "${CDK[@]}" deploy --require-approval never -c "commit=$COMMIT" --outputs-file cdk-outputs.json)

# --- 3. entrega.txt -------------------------------------------------------------------------
IP="$("$PYTHON" -c 'import json,sys; print(json.load(open(sys.argv[1]))["ControlVisitasStack"]["PublicIp"])' "$CDK_DIR/cdk-outputs.json")"
cat > "$ROOT/entrega.txt" <<TXT
# Lo escribe aws-scripts/desplegar.sh: la IP pública (elástica) de tu instancia.
INSTANCE_IP=$IP
TXT
echo "IP de la instancia: $IP (escrita en entrega.txt)"

# --- 4. Esperar a la aplicación -------------------------------------------------------------
# CloudFormation da la instancia por creada en cuanto arranca, pero aún tiene que instalar Docker,
# clonar el repositorio y construir la imagen.
echo "Esperando a que http://$IP/health responda con el commit ${COMMIT:0:7} (unos minutos)..."
for _ in $(seq 1 60); do
    if curl -s --max-time 5 "http://$IP/health" | grep -qE "\"commit\" *: *\"$COMMIT\""; then
        echo "Desplegado en $(( (SECONDS - INICIO) / 60 )) min $(( (SECONDS - INICIO) % 60 )) s: http://$IP/"
        exit 0
    fi
    sleep 10
done
echo "La aplicación no responde tras 10 minutos. Mira el registro de la instancia:" >&2
echo "  ssh -i ssh-key/labsuser.pem ubuntu@$IP 'sudo tail -n 50 /var/log/cloud-init-output.log'" >&2
exit 1
