# Justfile — dockerLamp
# Gestor de comandos para el stack LAMP contenerizado.
# Ejecuta `just` sin argumentos para ver todos los targets disponibles.

default := 'list'

# ── Ayuda ───────────────────────────────────────────────────────

list:
    @just --list

# ── Configuración inicial ──────────────────────────────────────

# Copia archivos .sample a archivos reales si no existen.
# Uso: just init | just init --force | just init --force .env
init *args:
    #!/usr/bin/env bash
    set -euo pipefail

    SAMPLES=(
        ".env_sample:.env"
        "docker-compose.yml.sample:docker-compose.yml"
        "traefik/traefik.yml.sample:traefik/traefik.yml"
        "traefik/dynamic_conf/dashboard-auth.yml.sample:traefik/dynamic_conf/dashboard-auth.yml"
    )

    FORCE=false
    FILES=()

    for arg in "{{args}}"; do
        if [ "$arg" = "--force" ]; then
            FORCE=true
        else
            FILES+=("$arg")
        fi
    done

    if [ "$FORCE" = true ] && [ ${#FILES[@]} -eq 0 ]; then
        for entry in "${SAMPLES[@]}"; do
            src="${entry%%:*}"
            dst="${entry##*:}"
            cp "$src" "$dst"
            echo "✓ $dst (sobrescrito)"
        done
        echo "4 de 4 archivos regenerados."
    elif [ "$FORCE" = true ]; then
        for file in "${FILES[@]}"; do
            found=false
            for entry in "${SAMPLES[@]}"; do
                src="${entry%%:*}"
                dst="${entry##*:}"
                if [ "$file" = "$dst" ] || [ "$file" = "$src" ]; then
                    cp "$src" "$dst"
                    echo "✓ $dst (sobrescrito)"
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                echo "✗ '$file' no es un archivo gestionado por init"
            fi
        done
    else
        copied=0
        existing=0
        for entry in "${SAMPLES[@]}"; do
            src="${entry%%:*}"
            dst="${entry##*:}"
            if [ -f "$dst" ]; then
                existing=$((existing + 1))
            else
                cp "$src" "$dst"
                echo "✓ $dst (creado)"
                copied=$((copied + 1))
            fi
        done
        total=$((copied + existing))
        if [ "$copied" -eq 0 ]; then
            echo "$total de $total archivos ya existen. Usa 'just init --force <archivo>' para regenerar."
        else
            echo "$copied de $total archivos creados."
        fi
    fi

# Crea un sitio nuevo o sobrescribe uno existente.
# Uso: just init-site <nombre> [<php>] [--force]
init-site name *args:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "$name" = "onion" ]; then
        echo "Usa 'just init-onion' en su lugar"
        exit 1
    fi

    FORCE=false
    PHP_VERSION=""

    for arg in "{{args}}"; do
        if [ "$arg" = "--force" ]; then
            FORCE=true
        elif echo "$arg" | grep -qE '^[0-9]+\.[0-9]+$'; then
            PHP_VERSION="$arg"
        else
            echo "Argumento inválido: $arg"
            echo "Versión de PHP válida: 7.4, 8.2, 8.4, 8.5"
            exit 1
        fi
    done

    if [ -z "$PHP_VERSION" ]; then
        PHP_VERSION="8.4"
    fi

    case "$PHP_VERSION" in
        7.4|8.2|8.4|8.5) ;;
        *)
            echo "Versión '$PHP_VERSION' no válida. Versiones disponibles: 7.4, 8.2, 8.4, 8.5"
            exit 1
            ;;
    esac

    PHP_CONTAINER="php$(echo "$PHP_VERSION" | tr -d '.')"

    if echo "$name" | grep -q '\.'; then
        DOMAIN="$name"
    else
        DOMAIN="${name}.local"
    fi

    SITE_DIR="sites/${DOMAIN}"
    VHOST_FILE="apache/vhosts/${DOMAIN}.conf"
    DYNAMIC_FILE="traefik/dynamic_conf/${DOMAIN}.yml"
    SAMPLE_DIR="sites/${name}.local.sample"
    SAMPLE_VHOST="apache/vhosts/${name}.local.conf.sample"
    SAMPLE_DYNAMIC="traefik/dynamic_conf/${name}.local.yml.sample"

    if [ -d "$SITE_DIR" ] && [ "$FORCE" != true ]; then
        echo "Sitio '$DOMAIN' ya existe. Usa '--force' para sobrescribir."
        exit 1
    fi

    mkdir -p "$SITE_DIR"
    mkdir -p apache/vhosts
    mkdir -p traefik/dynamic_conf

    if [ -d "$SAMPLE_DIR" ]; then
        if [ "$FORCE" = true ] || [ ! -d "$SITE_DIR" ]; then
            cp -r "$SAMPLE_DIR" "$SITE_DIR"
        fi
        if [ -f "$SAMPLE_VHOST" ]; then
            if [ "$FORCE" = true ] || [ ! -f "$VHOST_FILE" ]; then
                cp "$SAMPLE_VHOST" "$VHOST_FILE"
            fi
        fi
        if [ -f "$SAMPLE_DYNAMIC" ]; then
            if [ "$FORCE" = true ] || [ ! -f "$DYNAMIC_FILE" ]; then
                cp "$SAMPLE_DYNAMIC" "$DYNAMIC_FILE"
            fi
        fi

        if [ -f "$SITE_DIR/.htaccess" ]; then
            sed -i "s|fcgi://php[0-9]*:9000|fcgi://${PHP_CONTAINER}:9000|g" "$SITE_DIR/.htaccess"
            sed -i "s|/var/www/html/[a-zA-Z0-9._-]*/|/var/www/html/${DOMAIN}/|g" "$SITE_DIR/.htaccess"
        fi
        if [ -f "$VHOST_FILE" ]; then
            sed -i "s|fcgi://php[0-9]*:9000|fcgi://${PHP_CONTAINER}:9000|g" "$VHOST_FILE"
            sed -i "s|/var/www/html/[a-zA-Z0-9._-]*/|/var/www/html/${DOMAIN}/|g" "$VHOST_FILE"
            sed -i "s|ServerName [a-zA-Z0-9._-]*|ServerName ${DOMAIN}|g" "$VHOST_FILE"
        fi
        if [ -f "$DYNAMIC_FILE" ]; then
            sed -i "s|Host(\`[a-zA-Z0-9._-]*\`)|Host(\`${DOMAIN}\`)|g" "$DYNAMIC_FILE"
        fi

        echo "✓ Sitio '$DOMAIN' creado desde sample (PHP $PHP_VERSION)"
    else
        # Crear index.php
        printf '<?php phpinfo();\n' > "$SITE_DIR/index.php"

        # Crear .htaccess
        {
            echo "RewriteEngine On"
            echo ""
            echo "RewriteCond %{HTTP:X-Forwarded-Proto} !https [NC]"
            echo 'RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]'
            echo ""
            echo "RewriteRule ^(.*\.php(/.*)?)$ fcgi://${PHP_CONTAINER}:9000/var/www/html/${DOMAIN}/\$1 [L,P]"
        } > "$SITE_DIR/.htaccess"

        # Crear db_test.php
        {
            echo '<?php'
            echo 'echo "PHP " . PHP_VERSION;'
            echo '$host = '\''mariadb'\'';'
            echo '$dbname = getenv('\''MARIADB_DATABASE'\'');'
            echo '$user = getenv('\''MARIADB_USER'\'');'
            echo '$password = getenv('\''MARIADB_PASSWORD'\'');'
            echo 'try {'
            echo '    $dsn = "mysql:host=$host;dbname=$dbname;charset=utf8mb4";'
            echo '    $pdo = new PDO($dsn, $user, $password);'
            echo '    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);'
            echo '    echo "<h1>Conexion a la base de datos '\''$dbname'\'' establecida.</h1>";'
            echo '    $stmt = $pdo->query('\''SELECT NOW() AS `current_time`'\'');'
            echo '    $result = $stmt->fetch(PDO::FETCH_ASSOC);'
            echo '    echo "<p>Hora del servidor: <strong>" . $result['\''current_time'\''] . "</strong></p>";'
            echo '} catch (PDOException $e) {'
            echo '    echo "<h1>Error de Conexion</h1>";'
            echo '    echo "<p>Error: " . $e->getMessage() . "</p>";'
            echo '}'
        } > "$SITE_DIR/db_test.php"

        # Crear vhost
        {
            echo '<VirtualHost *:80>'
            echo "    ServerName ${DOMAIN}"
            echo "    DocumentRoot /var/www/html/${DOMAIN}"
            echo "    <Directory /var/www/html/${DOMAIN}>"
            echo '        AllowOverride All'
            echo '        Require all granted'
            echo '        DirectoryIndex index.php index.html'
            echo '    </Directory>'
            echo "    ProxyPassMatch ^/(.*\.php(/.*)?)$ fcgi://${PHP_CONTAINER}:9000/var/www/html/${DOMAIN}/\$1"
            echo '</VirtualHost>'
        } > "$VHOST_FILE"

        # Crear dynamic_conf
        ROUTER_NAME=$(echo "$DOMAIN" | tr '.' '-')
        {
            echo "http:"
            echo "  routers:"
            echo "    ${ROUTER_NAME}-ssl:"
            echo "      entryPoints:"
            echo "        - websecure"
            echo "      rule: \"Host(\`${DOMAIN}\`}\""
            echo '      service: "apache-service@file"'
            echo "      middlewares:"
            echo '        - "strip-root-prefix@file"'
            echo "      tls: {}"
        } > "$DYNAMIC_FILE"

        echo "✓ Sitio '$DOMAIN' creado desde cero (PHP $PHP_VERSION)"
    fi

# Configura servicios Tor (.onion).
# Uso: just init-onion | just init-onion --force
init-onion *args:
    #!/usr/bin/env bash
    set -euo pipefail

    FORCE=false
    for arg in "{{args}}"; do
        if [ "$arg" = "--force" ]; then
            FORCE=true
        fi
    done

    SAMPLES=(
        "tor/torrc.sample:tor/torrc"
        "apache/vhosts/onion.local.conf.sample:apache/vhosts/onion.local.conf"
        "traefik/dynamic_conf/onion.local.yml.sample:traefik/dynamic_conf/onion.local.yml"
    )

    if [ "$FORCE" = true ]; then
        for entry in "${SAMPLES[@]}"; do
            src="${entry%%:*}"
            dst="${entry##*:}"
            cp "$src" "$dst"
            echo "✓ $dst (sobrescrito)"
        done
        echo "Archivos Tor configurados."
    else
        copied=0
        existing=0
        for entry in "${SAMPLES[@]}"; do
            src="${entry%%:*}"
            dst="${entry##*:}"
            if [ -f "$dst" ]; then
                existing=$((existing + 1))
            else
                cp "$src" "$dst"
                echo "✓ $dst (creado)"
                copied=$((copied + 1))
            fi
        done
        total=$((copied + existing))
        if [ "$copied" -eq 0 ]; then
            echo "$total de $total archivos ya existen. Usa 'just init-onion --force' para regenerar."
        else
            echo "$copied de $total archivos Tor creados."
        fi
    fi

# ── Lifecycle ───────────────────────────────────────────────────

# Levanta todos los servicios.
up:
    #!/usr/bin/env bash
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi
    docker compose up -d

# Detiene servicios sin borrar datos.
down:
    #!/usr/bin/env bash
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi
    docker compose down

# Detiene servicios y borra volúmenes (⚠️ borra BD).
down-clean *args:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi

    FORCE=false
    for arg in "{{args}}"; do
        if [ "$arg" = "--force" ]; then
            FORCE=true
        fi
    done

    if [ "$FORCE" != true ]; then
        read -p "Esto borrará los datos de MariaDB y SFTPGo. ¿Continuar? (s/n): " confirm
        if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
            echo "Cancelado."
            exit 0
        fi
    fi
    docker compose down -v

# Reinicia todos los servicios o uno específico.
restart service='':
    #!/usr/bin/env bash
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi
    docker compose restart {{service}}

# Reconstruye imágenes Docker.
build:
    #!/usr/bin/env bash
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi
    docker compose build

# ── Logs ────────────────────────────────────────────────────────

# Muestra logs de todos los servicios en tiempo real.
logs:
    #!/usr/bin/env bash
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi
    docker compose logs -f

# Muestra logs de un servicio específico.
logs-svc service:
    #!/usr/bin/env bash
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi
    docker compose logs -f {{service}}

# ── Red ─────────────────────────────────────────────────────────

# Crea la red externa proxy.
network-create:
    #!/usr/bin/env bash
    if docker network inspect proxy >/dev/null 2>&1; then
        echo "La red 'proxy' ya existe"
    else
        docker network create proxy
        echo "Red 'proxy' creada"
    fi

# Verifica si la red proxy existe.
network-check:
    #!/usr/bin/env bash
    if docker network inspect proxy >/dev/null 2>&1; then
        echo "La red 'proxy' existe"
    else
        echo "La red 'proxy' no existe"
    fi

# ── Verificación ────────────────────────────────────────────────

# Muestra el estado de los contenedores.
status:
    #!/usr/bin/env bash
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi
    docker compose ps

# Valida el archivo docker-compose.yml.
validate:
    #!/usr/bin/env bash
    if [ ! -f docker-compose.yml ]; then
        echo "Ejecuta 'just init' primero"
        exit 1
    fi
    docker compose config

# Lista archivos .sample sin generar.
check-samples:
    #!/usr/bin/env bash
    set -euo pipefail

    TOTAL=0
    MISSING=0

    echo "=== Globales ==="
    for entry in \
        ".env_sample:.env" \
        "docker-compose.yml.sample:docker-compose.yml" \
        "traefik/traefik.yml.sample:traefik/traefik.yml" \
        "traefik/dynamic_conf/dashboard-auth.yml.sample:traefik/dynamic_conf/dashboard-auth.yml" \
        "tor/torrc.sample:tor/torrc"; do
        src="${entry%%:*}"
        dst="${entry##*:}"
        TOTAL=$((TOTAL + 1))
        if [ -f "$dst" ]; then
            echo "[✓] $dst"
        else
            echo "[✗] $dst (falta)"
            MISSING=$((MISSING + 1))
        fi
    done

    echo ""
    echo "=== Sitios ==="
    for site_dir in sites/*.local; do
        [ -d "$site_dir" ] || continue
        site=$(basename "$site_dir")

        TOTAL=$((TOTAL + 1))
        if [ -f "apache/vhosts/${site}.conf" ]; then
            echo "[✓] apache/vhosts/${site}.conf"
        else
            echo "[✗] apache/vhosts/${site}.conf (falta)"
            MISSING=$((MISSING + 1))
        fi

        TOTAL=$((TOTAL + 1))
        if [ -f "traefik/dynamic_conf/${site}.yml" ]; then
            echo "[✓] traefik/dynamic_conf/${site}.yml"
        else
            echo "[✗] traefik/dynamic_conf/${site}.yml (falta)"
            MISSING=$((MISSING + 1))
        fi
    done

    echo ""
    if [ "$MISSING" -eq 0 ]; then
        echo "Todos los archivos generados ($TOTAL/$TOTAL)."
    else
        echo "$MISSING de $TOTAL sin generar."
    fi

# ── Utilidades ──────────────────────────────────────────────────

# Genera hash para Basic Auth.
htpasswd user pass:
    #!/usr/bin/env bash
    if ! command -v htpasswd >/dev/null 2>&1; then
        echo "Instala apache2-utils: apt install apache2-utils"
        exit 1
    fi
    htpasswd -nb {{user}} {{pass}}

# Shell en contenedor apache.
shell-apache:
    #!/usr/bin/env bash
    if ! docker inspect apache >/dev/null 2>&1 || [ "$(docker inspect --format='\{\{.State.Running\}\}' apache 2>/dev/null)" != "true" ]; then
        echo "El contenedor 'apache' no está corriendo. Ejecuta 'just up' primero."
        exit 1
    fi
    docker exec -it apache /bin/sh

# Shell en contenedor PHP-FPM.
# Uso: just shell-php 7.4 | just shell-php 8.2 | just shell-php 8.4 | just shell-php 8.5
shell-php version:
    #!/usr/bin/env bash
    case "{{version}}" in
        7.4|8.2|8.4|8.5) ;;
        *)
            echo "Versión '{{version}}' no válida. Versiones disponibles: 7.4, 8.2, 8.4, 8.5"
            exit 1
            ;;
    esac

    CONTAINER="php$(echo "{{version}}" | tr -d '.')"

    if ! docker inspect "$CONTAINER" >/dev/null 2>&1 || [ "$(docker inspect --format='\{\{.State.Running\}\}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
        echo "El contenedor '$CONTAINER' no está corriendo. Ejecuta 'just up' primero."
        exit 1
    fi
    docker exec -it "$CONTAINER" /bin/bash

# Shell en contenedor MariaDB.
shell-mariadb:
    #!/usr/bin/env bash
    if ! docker inspect mariadb >/dev/null 2>&1 || [ "$(docker inspect --format='\{\{.State.Running\}\}' mariadb 2>/dev/null)" != "true" ]; then
        echo "El contenedor 'mariadb' no está corriendo. Ejecuta 'just up' primero."
        exit 1
    fi
    docker exec -it mariadb /bin/bash

# Shell en contenedor Tor.
shell-tor:
    #!/usr/bin/env bash
    if ! docker inspect tor >/dev/null 2>&1 || [ "$(docker inspect --format='\{\{.State.Running\}\}' tor 2>/dev/null)" != "true" ]; then
        echo "El contenedor 'tor' no está corriendo. Ejecuta 'just up' primero."
        exit 1
    fi
    docker exec -it tor /bin/sh

# Obtiene la dirección .onion de un servicio.
onion-get service:
    #!/usr/bin/env bash
    if ! docker inspect tor >/dev/null 2>&1 || [ "$(docker inspect --format='\{\{.State.Running\}\}' tor 2>/dev/null)" != "true" ]; then
        echo "El contenedor 'tor' no está corriendo. Ejecuta 'just up' primero."
        exit 1
    fi
    docker exec tor cat /var/lib/tor/hidden_services/{{service}}/hostname
