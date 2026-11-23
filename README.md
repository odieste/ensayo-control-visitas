# Control práctico: contenedores y Aurora

**Duración:** 1 hora y 30 minutos · **Modalidad:** individual, con todo el material, internet y asistentes de IA permitidos · **Entrega:** un *pull request* de tu *fork* del repositorio.

## Entrega

La entrega es un *pull request* desde la rama `main` de tu *fork* contra la rama `main` del repositorio original (rellena la plantilla). El último commit del *pull request* debe ser el que **quede desplegado** en tu laboratorio.

**Se entregan** (haz *commit* de ellos):

- `entrega.txt`, con la IP de tu instancia (`INSTANCE_IP`), que escribe `desplegar.sh`.
- `app/Dockerfile`, `cdk/cdk.json` y `cdk/control_visitas/stack.py`, con tus cambios.

**No subas**:

- La contraseña de la base de datos. No debe aparecer en **ningún** fichero del repositorio.
- La clave SSH del laboratorio (`ssh-key/labsuser.pem` y cualquier `.pem`, que están en `.gitignore`).
- Ficheros de trabajo, en concreto:
   - Lo que genera CDK (`cdk/.venv/`, `cdk/cdk.out/`, `cdk/cdk-outputs.json`, `cdk/cdk.context.json`, también en `.gitignore`).
   - Lo que genera la compilación local de la aplicación, si la pruebas con `mvn package` (`app/target/`), y la caché de Python (`__pycache__/`). También están en `.gitignore`.
   - Ficheros ajenos al control, como los `*:Zone.Identifier` que crea Windows al copiar ficheros, `.DS_Store` (macOS) o `.vscode/`. También están en `.gitignore`.

Las respuestas a las preguntas **no van en el repositorio**, sino en el cuestionario de Moodle.

## La aplicación

Una API mínima en **Spring Boot** (`app/`), sin interfaz web, que registra visitas en una base de datos **Aurora PostgreSQL**. Lee el usuario y la contraseña de la base de datos de un secreto de Secrets Manager. Ese secreto **no** es el que crea Aurora (`rds!cluster-…`), que está en la cuenta del profesor: es uno que creas tú en tu cuenta en la Tarea 3. No hace falta modificar la aplicación para completar el examen.

| Ruta | Qué hace |
|---|---|
| `GET /health` | Muestra cómo está configurada la aplicación (ver el ejemplo de abajo). No se conecta a Aurora, así que responde aunque la base de datos o el secreto fallen. |
| `POST /registro` | Inserta una fila en la tabla `registro` y la devuelve. La base de datos añade la IP de tu instancia, la instancia de Aurora que escribió la fila y la hora. |
| `GET /registro` | Lista tus filas. |

Ejemplo de respuesta de `GET /health`:

```json
{
  "exam_id": "123456",
  "commit": "3f2a9c1e...",
  "db_host": "control-visitas-writer.cdciac06i0ta.us-east-1.rds.amazonaws.com",
  "credenciales": true
}
```

| Campo | Significado |
|---|---|
| `exam_id` | Tu EXAM_ID. |
| `commit` | El commit de Git que está desplegado. |
| `db_host` | El endpoint de Aurora al que se conecta la aplicación. |
| `credenciales` | `true` si la aplicación leyó el usuario y la contraseña del secreto al arrancar, y `false` si no pudo. |

### Datos de la base de datos

La base de datos **no es tuya ni la despliegas tú**. Es del profesor y ya está en funcionamiento. Se trata de un clúster con dos instancias: una de escritura (*writer*) y una réplica de lectura (*reader*). Tu aplicación se conecta a ella por Internet, con TLS y con un usuario que solo puede insertar y leer, pero no borrar.

| Dato | Valor |
|---|---|
| Endpoint del clúster | `control-visitas.cluster-cdciac06i0ta.us-east-1.rds.amazonaws.com` |
| Endpoint de lectura del clúster | `control-visitas.cluster-ro-cdciac06i0ta.us-east-1.rds.amazonaws.com` |
| Endpoint de la instancia `control-visitas-writer` | `control-visitas-writer.cdciac06i0ta.us-east-1.rds.amazonaws.com` |
| Endpoint de la instancia `control-visitas-reader` | `control-visitas-reader.cdciac06i0ta.us-east-1.rds.amazonaws.com` |
| Puerto | `5432` |
| Base de datos | `db_control_visitas` |
| Usuario | `alumno` |
| Contraseña | En el cuestionario de Moodle |

### El repositorio

Tú despliegas, en **tu laboratorio** y con **CDK**, una instancia EC2. Desde tu equipo no se sube nada a la instancia: `cdk deploy` solo envía a CloudFormation la plantilla, que incluye el *user data*. Ese script clona **tu fork desde GitHub**, construye la imagen Docker de `app/` y ejecuta el contenedor.

| Carpeta o fichero | Qué contiene |
|---|---|
| `app/` | La aplicación (proyecto Maven) y un `Dockerfile`. |
| `cdk/` | La aplicación CDK en Python. `cdk/cdk.json` tiene los parámetros (contexto) y `cdk/control_visitas/stack.py`, la pila. |
| `params.sh` | Escribe tu `EXAM_ID` y la IP de tu equipo en `cdk/cdk.json`. |
| `aws-scripts/desplegar.sh` | Despliega el último commit de la rama `main` de tu *fork* en GitHub. Antes comprueba que tu `main` es exactamente la de GitHub. Después ejecuta `cdk deploy`, escribe la IP en `entrega.txt` y espera a que la aplicación responda. Con `--diff`, hace las mismas comprobaciones y solo muestra lo que cambiaría (`cdk diff`). |

Esta pila no necesita `cdk bootstrap`, porque no tiene *assets* (el laboratorio no permite crear los roles del bootstrap). Por eso la imagen no la construye CDK en tu equipo, sino la propia instancia, que compila la aplicación con Maven dentro de `docker build`. **No necesitas Docker en tu equipo**, ni compilar la aplicación (aunque puedes probarla con `mvn package`).

## Antes de empezar

Necesitas el laboratorio iniciado, sus credenciales en `~/.aws/credentials`, `git`, Python 3 y Node.js. CDK tiene dos partes: la librería de Python (`aws-cdk-lib`), que `desplegar.sh` instala sola en `cdk/.venv`, y la orden `cdk`, que es un programa de Node.js. Si no tienes la orden instalada (`npm install -g aws-cdk`), `desplegar.sh` la usa a través de `npx`, que la descarga automáticamente. Los scripts son de *bash*: en Windows, usa WSL o Git Bash.

1. Haz un *fork* de este repositorio en tu cuenta de GitHub
2. Escoge tu **EXAM_ID**, un número de 6 dígitos que eliges libremente, y ejecuta:

   ```bash
   bash params.sh <EXAM_ID>
   ```

   El script escribe por ti, en `cdk/cdk.json`, dos valores que necesita la pila: `exam_id` (tu EXAM_ID) y `mi_ip` (la IP pública de tu equipo, para la regla del SSH). La IP de la instancia la escribirá después `desplegar.sh` en `entrega.txt`.

3. Haz *commit* y *push* de `cdk/cdk.json`.

**Checkpoint.** `cdk/cdk.json` tiene tu `exam_id` y tu `mi_ip`, y `aws sts get-caller-identity` responde con tu cuenta del laboratorio.

## Tareas (4 puntos)

Cada despliegue tarda unos 3 o 4 minutos.

### Tarea 1. La imagen · 1 punto

Completa los tres `TODO (Tarea 1)` de `app/Dockerfile`. Haz *commit* y *push*. No despliegues todavía: la aplicación no será accesible hasta completar la Tarea 2.

**Pregunta 1 (0,5 puntos).** El `Dockerfile` construye la imagen en dos etapas. La primera (`FROM maven:... AS build`) compila la aplicación. La segunda, cuya imagen base escribes tú en el primer `TODO (Tarea 1)`, solo copia el `app.jar` de la primera (`COPY --from=build`) y lo ejecuta. ¿Por qué es recomendable construir la imagen en dos etapas?

### Tarea 2. Desplegar desde tu fork · 1 punto

En esta tarea cambias dos ficheros: `cdk/cdk.json` y `cdk/control_visitas/stack.py`.

1. **`cdk/cdk.json`.** La instancia clona el repositorio que indica `repo_url`, que ahora vale `TODO (Tarea 2)`. Escribe ahí la URL HTTPS de **tu** *fork*.
2. **`cdk/control_visitas/stack.py`.** Tal como está, la pila crea la instancia, pero la aplicación no es accesible desde Internet. Completa los dos `TODO (Tarea 2)`:
   - El grupo de seguridad solo deja entrar SSH desde la IP de tu equipo. Añade la regla que permite HTTP (puerto 80) desde cualquier dirección.
   - El contenedor escucha en su puerto, pero nada lo conecta con la instancia. En el `docker run` del *user data*, publica el puerto 80 de la instancia en el puerto del contenedor.
3. Haz *commit* y *push*, y despliega:

   ```bash
   bash aws-scripts/desplegar.sh
   ```

**Checkpoint.** `http://<INSTANCE_IP>/health` responde con tu `EXAM_ID`. `POST /registro` todavía da error: se resuelve en la Tarea 3.

Si `/health` no responde, entra en la instancia y mira qué pasó en el arranque:

```bash
ssh -i ssh-key/labsuser.pem ubuntu@<INSTANCE_IP>
sudo tail -n 50 /var/log/cloud-init-output.log   # instalación, git clone y docker build
sudo docker ps                                   # el contenedor y sus puertos publicados
sudo docker logs contenedor-control-visitas      # salida de Spring Boot
curl -s localhost/health                         # desde la propia instancia, sin pasar por el grupo de seguridad
```

**Pregunta 2 (0,5 puntos).** El `Dockerfile` ya declara `EXPOSE 8080`. ¿Por qué ha hecho falta, además, publicar el puerto en el `docker run`?

### Tarea 3. El secreto · 1 punto

La aplicación lee el usuario y la contraseña de Aurora de un secreto de Secrets Manager **de tu cuenta**.

1. Crea el secreto en Secrets Manager, desde la consola web o con la CLI, como prefieras:
   - **Nombre:** el de `secret_name` en `cdk/cdk.json`.
   - **Contenido:** el usuario (`alumno`) y la contraseña de la base de datos (que está en el cuestionario de Moodle). Spring Cloud AWS convierte cada clave del secreto en una propiedad de Spring. Mira en `app/src/main/resources/application.properties` qué nombres de propiedad espera la aplicación para el usuario y la contraseña.
   - No escribas la contraseña en ningún fichero del repositorio.
2. La aplicación necesita saber qué secreto leer (mira `SECRET_NAME` en `app/src/main/resources/application.properties`). Completa el `TODO (Tarea 3)` de `cdk/control_visitas/stack.py`.

**Pregunta 3 (0,5 puntos).** Antes de volver a desplegar, consulta `/health`: aunque el secreto ya existe y has completado `stack.py`, sigue mostrando `"credenciales": false`. ¿Por qué?

Haz *commit* y *push*. Antes de desplegar, mira qué va a cambiar en AWS. `--diff` hace las mismas comprobaciones que el despliegue, pero solo muestra los cambios (`cdk diff`), sin aplicarlos:

```bash
bash aws-scripts/desplegar.sh --diff
```

**Pregunta 4 (0,5 puntos).** El `diff` muestra que la instancia no se modifica: se borra (`[-]`) y se crea otra nueva (`[+]`). ¿Por qué se sustituye, en lugar de actualizar la que ya existe?

**Pregunta 5 (0,5 puntos).** Aunque la instancia se sustituye, su IP pública (`INSTANCE_IP` en `entrega.txt`) no cambia. ¿Por qué?

Despliega:

```bash
bash aws-scripts/desplegar.sh
```

**Checkpoint.** `/health` muestra `"credenciales": true`, y `curl -X POST http://<INSTANCE_IP>/registro` responde `201` con: la fila de la tabla (`id`), el `EXAM_ID`, el commit desplegado, la IP de tu instancia en `cliente` y, en `instancia`, la instancia de Aurora que la escribió.

**Pregunta 6 (0,5 puntos).** Un compañero propone ahorrarse el secreto y pasar el usuario y la contraseña directamente como variables de entorno en el `docker run` de `stack.py`: `-e SPRING_DATASOURCE_USERNAME=alumno -e SPRING_DATASOURCE_PASSWORD=...` (Spring Boot las asocia a las propiedades `spring.datasource.username` y `spring.datasource.password`). ¿En qué sitios quedaría visible esa contraseña? Indica al menos dos.

**Pregunta 7 (0,5 puntos).** En el tutorial de Aurora, el back leía el secreto que crea Aurora al crear el clúster (`rds!cluster-…`). ¿Por qué en este control no se usa ese secreto?

### Tarea 4. Failover · 1 punto

A la hora que anunciará el profesor, se provocará un **failover** en Aurora: la réplica pasará a ser la instancia de escritura, y la antigua instancia de escritura pasará a ser réplica.

Cuando ocurra, comprueba si tu aplicación sigue funcionando (`GET` y `POST /registro`).

**Pregunta 8 (0,75 puntos).** Después del failover, `GET /registro` sigue funcionando, pero `POST /registro` falla. ¿Por qué?

Corrige el problema. La corrección consiste en cambiar **solo** `cdk/cdk.json`, y esta vez tienes que hacerla **en la web de GitHub**, no en tu equipo:

1. En tu *fork*, abre `cdk/cdk.json`, edítalo con el lápiz (*Edit this file*) y haz el *commit* directamente en `main`.
2. Despliega desde tu equipo con `bash aws-scripts/desplegar.sh`. Lee lo que responde y haz lo que te pide hasta que el despliegue termine.

**Checkpoint.** `POST /registro` responde `201`.

**Pregunta 9 (0,5 puntos).** El cambio de `db_host` ya estaba en GitHub, pero `desplegar.sh` se negó a desplegar hasta que hiciste `git pull`. ¿Por qué no basta con que el cambio esté en GitHub?

**Pregunta 10 (0,75 puntos).** La tabla [«Datos de la base de datos»](#datos-de-la-base-de-datos) tiene cuatro endpoints. ¿A qué instancia te lleva cada uno, antes y después del failover?

**Pregunta 11 (0,5 puntos).** Incluso con el endpoint correcto, durante el failover la aplicación falla unos segundos. ¿Por qué no es instantáneo?


## Recuerda

- Haz *commit* y *push* antes de cada despliegue: la instancia despliega lo que hay en GitHub, no lo que hay en tu equipo.
- No borres la pila (`cdk destroy`) ni el secreto hasta que se haya corregido el control.
- Si cambias de red, la IP pública de tu equipo cambia y el SSH dejará de conectar. Vuelve a ejecutar `params.sh`, haz *commit* y despliega, o añade la regla en la consola web.
