# Imagen de la aplicación del control (Spring Boot).
# La construye la propia instancia EC2 al arrancar (ver cdk/control_visitas/stack.py).

# --- Etapa 1: compilación ------------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src

# Primero el pom.xml y las dependencias, y después el código: si solo cambia src/, Docker reutiliza
# la capa de las dependencias y no las vuelve a descargar
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests

# --- Etapa 2: ejecución ---------------------------------------------------------------------
# TODO (Tarea 1): imagen base. La imagen oficial de Eclipse Temurin con Java 21, en su variante que solo
# incluye el entorno de ejecución (JRE), no el JDK.

WORKDIR /app
COPY --from=build /src/target/app.jar app.jar

# El commit desplegado llega como argumento de construcción y queda en la imagen como variable de entorno
ARG GIT_COMMIT=desconocido
ENV GIT_COMMIT=$GIT_COMMIT

# La aplicación no necesita privilegios
USER nobody

# TODO (Tarea 1): documenta el puerto en el que escucha la aplicación (mira server.port en application.properties).


# TODO (Tarea 1): orden que arranca la aplicación (java -jar ...), en forma exec (lista JSON).

