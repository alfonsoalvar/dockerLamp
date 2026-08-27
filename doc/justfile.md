# Justfile — dockerLamp

Gestor de comandos para el stack LAMP contenerizado. Unifica las operaciones más habituales bajo una interfaz coherente y descubrible.

## Requisitos previos

- [just](https://just.systems/) >= 1.0
- [Docker Compose](https://docs.docker.com/compose/) v2
- `htpasswd` (opcional, para generar hashes Basic Auth)

### Instalar just

**Debian/Ubuntu:**
```bash
apt install just
```

**macOS:**
```bash
brew install just
```

**Otros sistemas:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
```

## Inicio rápido

```bash
# 1. Configurar archivos base
just init

# 2. Editar .env con tus credenciales
nano .env

# 3. Crear red proxy
just network-create

# 4. Crear sitio de prueba
just init-site docker1

# 5. Levantar servicios
just up

# 6. Verificar que todo funciona
just status
```

## Referencia completa

Ejecuta `just` sin argumentos para ver todos los targets disponibles.

### Configuración inicial

| Target | Argumentos | Descripción |
|--------|------------|-------------|
| `init` | `[--force] [<archivo>...]` | Copia archivos .sample a archivos reales |
| `init-site` | `<nombre> [<php>] [--force]` | Crea un sitio nuevo o sobrescribe existente |
| `init-onion` | `[--force]` | Configura servicios Tor |

### Lifecycle

| Target | Argumentos | Descripción |
|--------|------------|-------------|
| `up` | — | Levanta todos los servicios |
| `down` | — | Detiene servicios (mantiene datos) |
| `down-clean` | `[--force]` | Detiene y borra volúmenes |
| `restart` | `[<servicio>]` | Reinicia todos o uno específico |
| `build` | — | Reconstruye imágenes Docker |

### Logs

| Target | Argumentos | Descripción |
|--------|------------|-------------|
| `logs` | — | Logs de todos los servicios |
| `logs-svc` | `<servicio>` | Logs de un servicio específico |

### Red

| Target | Argumentos | Descripción |
|--------|------------|-------------|
| `network-create` | — | Crea la red proxy |
| `network-check` | — | Verifica si la red proxy existe |

### Verificación

| Target | Argumentos | Descripción |
|--------|------------|-------------|
| `status` | — | Estado de contenedores |
| `validate` | — | Valida docker-compose.yml |
| `check-samples` | — | Lista archivos .sample sin generar |

### Utilidades

| Target | Argumentos | Descripción |
|--------|------------|-------------|
| `htpasswd` | `<user> <pass>` | Genera hash Basic Auth |
| `shell-apache` | — | Shell en contenedor apache |
| `shell-php` | `<versión>` | Shell en contenedor PHP |
| `shell-mariadb` | — | Shell en contenedor MariaDB |
| `shell-tor` | — | Shell en contenedor Tor |
| `onion-get` | `<servicio>` | Obtiene dirección .onion |

## Documentación detallada

### init

Copia archivos de configuración desde `.sample` a sus versiones reales.

**Archivos gestionados:**
- `.env_sample` → `.env`
- `docker-compose.yml.sample` → `docker-compose.yml`
- `traefik/traefik.yml.sample` → `traefik/traefik.yml`
- `traefik/dynamic_conf/dashboard-auth.yml.sample` → `traefik/dynamic_conf/dashboard-auth.yml`

**Sintaxis:**
```bash
just init                    # Copia archivos que no existen
just init --force            # Sobrescribe los 4 globales
just init --force .env       # Sobrescribe solo .env
just init --force .env docker-compose.yml  # Sobrescribe archivos específicos
```

**Comportamiento:**
- Si un archivo ya existe, se omite (a menos que se use `--force`)
- Si todos los archivos existen, muestra: "4 de 4 archivos ya existen. Usa `just init --force <archivo>` para regenerar."

---

### init-site

Crea un sitio nuevo o sobrescribe uno existente.

**Archivos generados:**
- `sites/<nombre>.local/index.php`
- `sites/<nombre>.local/.htaccess`
- `sites/<nombre>.local/db_test.php`
- `apache/vhosts/<nombre>.local.conf`
- `traefik/dynamic_conf/<nombre>.local.yml`

**Sintaxis:**
```bash
just init-site docker1                           # Copia desde sample existente
just init-site docker1 8.4                       # Copia desde sample, cambia PHP a 8.4
just init-site docker1 --force                   # Sobrescribe sitio existente
just init-site docker1 8.4 --force               # Sobrescribe con PHP 8.4
just init-site mipagina.com                      # Crea desde cero (PHP 8.4 por defecto)
just init-site mipagina.com 7.4                  # Crea desde cero con PHP 7.4
just init-site mipagina.com 8.4 --force          # Sobrescribe con PHP 8.4
```

**Formato del nombre:**
- `docker1` → `docker1.local` (añade `.local`)
- `docker1.local` → `docker1.local` (tal cual)
- `mipagina.com` → `mipagina.com` (tal cual)

**Versiones de PHP válidas:** 7.4, 8.2, 8.4, 8.5

**Restricción:** `init-site onion` no está permitido. Usa `just init-onion`.

---

### init-onion

Configura los servicios ocultos de Tor.

**Archivos gestionados:**
- `tor/torrc.sample` → `tor/torrc`
- `apache/vhosts/onion.local.conf.sample` → `apache/vhosts/onion.local.conf`
- `traefik/dynamic_conf/onion.local.yml.sample` → `traefik/dynamic_conf/onion.local.yml`

**Sintaxis:**
```bash
just init-onion          # Copia archivos que no existen
just init-onion --force  # Sobrescribe archivos existentes
```

---

### up

Levanta todos los servicios Docker.

**Sintaxis:**
```bash
just up
```

**Equivalente:** `docker compose up -d`

**Nota:** `up` no reconstruye imágenes. Usa `just build` primero si necesitas reconstruir.

---

### down

Detiene los servicios sin borrar volúmenes.

**Sintaxis:**
```bash
just down
```

**Equivalente:** `docker compose down`

---

### down-clean

Detiene los servicios y borra volúmenes (⚠️ borra datos de MariaDB y SFTPGo).

**Sintaxis:**
```bash
just down-clean          # Pide confirmación
just down-clean --force  # Sin confirmación
```

**Mensaje de confirmación:**
```
Esto borrará los datos de MariaDB y SFTPGo. ¿Continuar? (s/n):
```

---

### restart

Reinicia todos los servicios o uno específico.

**Sintaxis:**
```bash
just restart          # Reinicia todos
just restart apache   # Reinicia solo apache
```

---

### build

Reconstruye las imágenes Docker.

**Sintaxis:**
```bash
just build
```

**Equivalente:** `docker compose build`

**Nota:** Ejecuta `just build` antes de `just up` si has modificado Dockerfiles o `php.ini`.

---

### logs

Muestra logs de todos los servicios en tiempo real.

**Sintaxis:**
```bash
just logs
```

**Equivalente:** `docker compose logs -f`

---

### logs-svc

Muestra logs de un servicio específico en tiempo real.

**Sintaxis:**
```bash
just logs-svc apache
just logs-svc mariadb
just logs-svc traefik
```

---

### network-create

Crea la red externa `proxy` que usa Traefik.

**Sintaxis:**
```bash
just network-create
```

**Si la red ya existe:** Muestra "La red `proxy` ya existe" y continúa.

---

### network-check

Verifica si la red `proxy` existe.

**Sintaxis:**
```bash
just network-check
```

**Salida:**
```
La red `proxy` existe
```
o
```
La red `proxy` no existe
```

---

### status

Muestra el estado de los contenedores.

**Sintaxis:**
```bash
just status
```

**Equivalente:** `docker compose ps`

---

### validate

Valida el archivo `docker-compose.yml`.

**Sintaxis:**
```bash
just validate
```

**Pre-requisito:** Debe existir `docker-compose.yml`. Si no existe, muestra: "Ejecuta `just init` primero".

---

### check-samples

Lista archivos `.sample` sin generar.

**Sintaxis:**
```bash
just check-samples
```

**Salida:**
```
=== Globales ===
[✓] .env
[✗] docker-compose.yml (falta)
[✓] traefik.yml
[✗] dashboard-auth.yml (falta)
[✓] tor/torrc

=== Sitios ===
[✓] apache/vhosts/docker1.local.conf
[✗] traefik/dynamic_conf/docker1.local.yml (falta)

2 de 6 sin generar.
```

---

### htpasswd

Genera hash para Basic Auth.

**Sintaxis:**
```bash
just htpasswd <usuario> <contraseña>
```

**Ejemplo:**
```bash
just htpasswd admin mi_contraseña_segura
# Salida: admin:$apr1$RC7H/abr$g86hSRbf3nSCuYh/aDd0z.
```

**Pre-requisito:** `htpasswd` debe estar instalado. Si no está: "Instala apache2-utils: `apt install apache2-utils`"

**Nota:** El hash generado debe duplicar los `$` al usarlo en `.env` o `docker-compose.yml`.

---

### shell-apache

Abre un shell en el contenedor Apache.

**Sintaxis:**
```bash
just shell-apache
```

**Pre-requisito:** El contenedor `apache` debe estar corriendo.

---

### shell-php

Abre un shell en un contenedor PHP-FPM.

**Sintaxis:**
```bash
just shell-php 7.4
just shell-php 8.2
just shell-php 8.4
just shell-php 8.5
```

**Versiones válidas:** 7.4, 8.2, 8.4, 8.5

**Pre-requisito:** El contenedor debe estar corriendo.

---

### shell-mariadb

Abre un shell en el contenedor MariaDB.

**Sintaxis:**
```bash
just shell-mariadb
```

**Pre-requisito:** El contenedor `mariadb` debe estar corriendo.

---

### shell-tor

Abre un shell en el contenedor Tor.

**Sintaxis:**
```bash
just shell-tor
```

**Pre-requisito:** El contenedor `tor` debe estar corriendo.

---

### onion-get

Obtiene la dirección `.onion` de un servicio.

**Sintaxis:**
```bash
just onion-get docker1
```

**Pre-requisito:** El contenedor `tor` debe estar corriendo.

**Salida:**
```
abc123def456...xyz.onion
```

## Mensajes de error

| Mensaje | Causa | Solución |
|---------|-------|----------|
| `Ejecuta 'just init' primero` | No existe `docker-compose.yml` | Ejecuta `just init` |
| `El contenedor 'apache' no está corriendo. Ejecuta 'just up' primero.` | Contenedor parado | Ejecuta `just up` |
| `El contenedor 'php84' no está corriendo. Ejecuta 'just up' primero.` | Contenedor PHP parado | Ejecuta `just up` |
| `El contenedor 'mariadb' no está corriendo. Ejecuta 'just up' primero.` | Contenedor MariaDB parado | Ejecuta `just up` |
| `El contenedor 'tor' no está corriendo. Ejecuta 'just up' primero.` | Contenedor Tor parado | Ejecuta `just up` |
| `Versión '6.0' no válida. Versiones disponibles: 7.4, 8.2, 8.4, 8.5` | PHP versión incorrecta | Usa una versión válida |
| `Instala apache2-utils: apt install apache2-utils` | `htpasswd` no instalado | Instala el paquete |
| `Usa 'just init-onion' en su lugar` | `init-site onion` no permitido | Usa `init-onion` |
| `La red 'proxy' ya existe` | Red ya creada | No es error, continúa |
| `4 de 4 archivos ya existen. Usa 'just init --force <archivo>' para regenerar.` | Todos los archivos existen | Usa `--force` si necesitas regenerar |
| `Sitio '<nombre>' ya existe. Usa '--force' para sobrescribir.` | Sitio ya existe | Usa `--force` |

## Ejemplos completos

### Primera instalación

```bash
# 1. Configurar archivos base
just init

# 2. Editar .env con tus credenciales
nano .env

# 3. Crear red proxy
just network-create

# 4. Crear sitio de prueba
just init-site docker1

# 5. Levantar servicios
just up

# 6. Verificar que todo funciona
just status
just validate
```

### Crear sitio nuevo

```bash
# Crear sitio con PHP 8.4 (por defecto)
just init-site mipagina.com

# O con PHP específico
just init-site mipagina.com 7.4

# Levantar servicios
just up

# Verificar
just status
```

### Cambiar versión PHP de un sitio

```bash
# Cambiar a PHP 7.4
just init-site mipagina.com 7.4 --force

# Levantar servicios
just up
```

### Configurar Tor

```bash
# 1. Configurar archivos Tor
just init-onion

# 2. Editar tor/torrc con tus servicios ocultos
nano tor/torrc

# 3. Levantar servicios
just up

# 4. Obtener dirección .onion
just onion-get docker1
```

### Ver logs y debug

```bash
# Logs de todos los servicios
just logs

# Logs de un servicio específico
just logs-svc apache
just logs-svc mariadb

# Shell en un contenedor
just shell-php 8.4
just shell-apache

# Verificar estado
just status
```

### Limpiar y empezar de cero

```bash
# Detener servicios (mantiene datos)
just down

# Detener y borrar todo (⚠️ borra BD)
just down-clean

# O sin confirmación
just down-clean --force

# Regenerar archivos de configuración
just init --force

# Crear sitio y levantar
just init-site docker1
just up
```

### Generar hash Basic Auth

```bash
# Generar hash
just htpasswd admin mi_contraseña_segura

# Copiar el output y pegarlo en .env, duplicando los $
# Ejemplo: admin:$$apr1$$RC7H/abr$$g86hSRbf3nSCuYh/aDd0z.
```

## FAQ

### ¿Qué es `just`?
`just` es un gestor de comandos similar a `make`, diseñado para ser más simple y fácil de usar.

### ¿Por qué no usar `make`?
`just` tiene una sintaxis más limpia, mejor soporte para argumentos, y no requiere `#` para comentarios.

### ¿Puedo usar el justfile sin `just`?
No. El justfile requiere `just` instalado. Alternativamente, puedes ejecutar los comandos Docker directamente.

### ¿Qué pasa si pierdo mis datos con `down-clean`?
Los datos de MariaDB y SFTPGo se borran permanentemente. Asegúrate de tener backups antes de ejecutar `down-clean`.

### ¿Cómo actualizo las imágenes Docker?
```bash
just build
just up
```

### ¿Puedo cambiar la versión de PHP de un sitio?
```bash
just init-site mipagina.com 7.4 --force
just up
```
