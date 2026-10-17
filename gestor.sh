#!/bin/bash
# =============================================================================
# gestor.sh - Menú interactivo para gestionar el ciclo de vida de la aplicación
#             Spring Boot "hola-docker": compilar, construir imagen Docker,
#             ejecutar el contenedor y consultar el estado.
# Uso: ./gestor.sh
# =============================================================================

# Nos situamos en el directorio donde está el script (raíz del proyecto, donde
# están pom.xml, mvnw y el Dockerfile), para que las rutas relativas funcionen.
cd "$(dirname "$0")" || exit 1

# ---------------------------- VARIABLES --------------------------------------
PROYECTO="hola-docker"                        # Nombre del proyecto
IMAGEN="hola-docker"                          # Nombre de la imagen Docker
CONTENEDOR="hola-docker-app"                  # Nombre del contenedor
JAR="target/hola-docker-0.0.1-SNAPSHOT.jar"   # Ruta del JAR generado por Maven
PUERTO=8080                                   # Puerto que se publica en el host

# ---------------------------- FUNCIONES --------------------------------------

# Opción 1: comprueba que los comandos necesarios están instalados.
verificar_prerequisitos() {
    echo "== Verificando prerrequisitos =="
    # Bucle for sobre la lista de comandos a comprobar (fácil de ampliar).
    for cmd in java mvn docker; do
        if command -v "$cmd" > /dev/null 2>&1; then
            echo "[OK]   $cmd está disponible"
        elif [ "$cmd" = "mvn" ] && [ -x "./mvnw" ]; then
            # Maven no está instalado globalmente, pero sirve el wrapper.
            echo "[OK]   mvn no está instalado, pero se usará el wrapper ./mvnw"
        else
            echo "[FALTA] $cmd NO está disponible"
        fi
    done
}

# Opción 2: compila y empaqueta la aplicación generando el JAR.
compilar() {
    echo "== Compilando y empaquetando $PROYECTO =="
    ./mvnw clean package -DskipTests

    # Comprobamos que el JAR se ha generado correctamente en target/.
    if [ -f "$JAR" ]; then
        echo "[OK] JAR generado correctamente: $JAR"
    else
        echo "[ERROR] No se ha generado el JAR en $JAR. Revisa los mensajes de Maven."
    fi
}

# Opción 3: construye la imagen Docker (solo si el JAR existe).
construir_imagen() {
    if [ ! -f "$JAR" ]; then
        echo "[AVISO] No existe $JAR. Primero debes compilar la aplicación (opción 2)."
    else
        echo "== Construyendo la imagen Docker '$IMAGEN' =="
        if docker build -t "$IMAGEN" .; then
            echo "[OK] Imagen '$IMAGEN' construida correctamente"
        else
            echo "[ERROR] Falló la construcción de la imagen"
        fi
    fi
}

# Opción 4: ejecuta el contenedor (solo si la imagen existe).
ejecutar_contenedor() {
    # Comprobamos que la imagen existe antes de intentar arrancar nada.
    if ! docker image inspect "$IMAGEN" > /dev/null 2>&1; then
        echo "[AVISO] No existe la imagen '$IMAGEN'. Primero constrúyela (opción 3)."
        return
    fi

    # Buscamos si ya hay un contenedor con ese nombre (en marcha o parado).
    existente=$(docker ps -a --filter "name=^${CONTENEDOR}$" --format '{{.Names}}')
    if [ -n "$existente" ]; then
        echo "Ya existe un contenedor llamado '$CONTENEDOR'."
        read -r -p "¿Quieres detenerlo y eliminarlo antes de crear uno nuevo? (s/n): " resp
        if [ "$resp" = "s" ] || [ "$resp" = "S" ]; then
            docker rm -f "$CONTENEDOR" > /dev/null
            echo "[OK] Contenedor anterior eliminado"
        else
            echo "Operación cancelada. No se ha creado ningún contenedor nuevo."
            return
        fi
    fi

    echo "== Arrancando el contenedor '$CONTENEDOR' =="
    if docker run -d --name "$CONTENEDOR" -p "$PUERTO:8080" "$IMAGEN" > /dev/null; then
        echo "[OK] Contenedor en marcha. Prueba: http://localhost:$PUERTO/hello"
    else
        echo "[ERROR] No se pudo arrancar el contenedor"
    fi
}

# Opción 5: muestra el estado actual (JAR, imagen y contenedor).
mostrar_estado() {
    echo "== Estado actual de $PROYECTO =="

    # Estado del JAR y su tamaño.
    if [ -f "$JAR" ]; then
        echo "JAR:        existe ($(du -h "$JAR" | cut -f1)) -> $JAR"
    else
        echo "JAR:        no existe"
    fi

    # Estado de la imagen y fecha de creación.
    if docker image inspect "$IMAGEN" > /dev/null 2>&1; then
        creada=$(docker image inspect -f '{{.Created}}' "$IMAGEN")
        echo "Imagen:     existe, creada el $creada"
    else
        echo "Imagen:     no existe"
    fi

    # Estado del contenedor (solo si está en ejecución).
    en_marcha=$(docker ps --filter "name=^${CONTENEDOR}$" --format '{{.Names}} ({{.Status}})')
    if [ -n "$en_marcha" ]; then
        echo "Contenedor: en ejecución -> $en_marcha"
    else
        echo "Contenedor: no hay ninguno en ejecución"
    fi
}

# ---------------------------- MENÚ PRINCIPAL ---------------------------------
# Bucle while infinito: se repite hasta que el usuario elige la opción 6 (exit).
while true; do
    echo
    echo "=========================================="
    echo "   GESTOR DE $PROYECTO"
    echo "=========================================="
    echo "1) Verificar prerrequisitos"
    echo "2) Compilar y empaquetar la aplicación"
    echo "3) Construir la imagen Docker"
    echo "4) Ejecutar el contenedor Docker"
    echo "5) Mostrar el estado actual"
    echo "6) Salir"
    echo "------------------------------------------"
    read -r -p "Elige una opción [1-6]: " opcion
    echo

    # Validación de la opción elegida con if-elif-else.
    if [ -z "$opcion" ]; then
        echo "[AVISO] No has escrito nada. Elige un número del 1 al 6."
    elif [ "$opcion" = "1" ]; then
        verificar_prerequisitos
    elif [ "$opcion" = "2" ]; then
        compilar
    elif [ "$opcion" = "3" ]; then
        construir_imagen
    elif [ "$opcion" = "4" ]; then
        ejecutar_contenedor
    elif [ "$opcion" = "5" ]; then
        mostrar_estado
    elif [ "$opcion" = "6" ]; then
        echo "¡Hasta luego!"
        exit 0
    else
        echo "[ERROR] Opción '$opcion' no válida. Elige un número del 1 al 6."
    fi
done
