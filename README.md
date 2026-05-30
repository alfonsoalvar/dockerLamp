# dockerLamp

Un stack LAMP (Linux, Apache, MariaDB, PHP) moderno y contenerizado con Docker, diseñado para ser fácil de desplegar en cualquier servidor. Utiliza **Traefik** como proxy inverso para gestionar el enrutamiento y la generación automática de certificados SSL (Let's Encrypt). Además, incluye diversas herramientas integradas para gestión y monitorización.

## Características

- **Servidor Web:** Apache.
- **PHP-FPM:** Soporte para múltiples versiones de PHP (PHP 7.4, PHP 8.4 y PHP 8.5).
- **Base de Datos:** MariaDB.
- **Proxy Inverso:** Traefik v3 (gestión de rutas y HTTPS automático).
- **Gestores de Base de Datos:** Adminer y phpMyAdmin.
- **Servidor SFTP y Gestión de Archivos:** SFTPGo (con interfaz web).
- **Monitorización del Sistema:** Glances en tiempo real.

## 📋 Requisitos Previos

- [Docker](https://docs.docker.com/get-docker/) instalado.
- [Docker Compose](https://docs.docker.com/compose/install/) instalado.

## 🛠️ Configuración y Despliegue paso a paso

### 1. Archivos de configuración y variables de entorno

El proyecto utiliza archivos de plantilla o muestra (`.sample`) para evitar subir credenciales al repositorio de GitHub. Debes preparar tus propios archivos de configuración:

- **Variables de entorno (`.env`):**
  Copia el archivo `.env_sample` y renómbralo a `.env`:
  ```bash
  cp .env_sample .env
  ```
  Abre el archivo `.env` y **configura tus contraseñas seguras**, nombres de base de datos y los dominios que utilizarás para cada servicio (por ejemplo, `ADMINER_HOST`, `SFTPGO_HOST`, etc.).

- **Configuración de servicios (`docker-compose.yml`):**
  Copia el archivo `docker-compose.yml.sample` a `docker-compose.yml`:
  ```bash
  cp docker-compose.yml.sample docker-compose.yml
  ```
  Revisa el archivo por si deseas habilitar o deshabilitar ciertos servicios (como Adminer o phpMyAdmin) comentando las secciones respectivas.

### 2. Crear la red externa

El stack de Docker Compose asume que existe una red externa llamada `proxy` que Traefik utiliza para comunicarse con el resto de servicios de manera segura. Debes crearla ejecutando el siguiente comando:

```bash
docker network create proxy
```

### 3. Levantar los servicios

Una vez configurado todo, puedes iniciar el entorno y construir las imágenes ejecutando:

```bash
docker compose up -d --build --force-recreate
```

### 4. Destrucción de contenedores y limpieza

Para detener y destruir los servicios, junto con sus volúmenes asociados (⚠️ **Cuidado**, la opción `-v` borrará la base de datos y otros datos temporales/persistentes si están configurados en el compose down), puedes usar:

```bash
docker compose down -v
```

*(Si deseas mantener tus datos persistentes de base de datos, ejecuta únicamente `docker compose down`).*

## 🔐 Generación de contraseñas para Basic Auth

Para los servicios protegidos (como el dashboard de Traefik o Glances), es posible que necesites generar un hash de contraseña para el usuario administrador. Puedes hacerlo usando la utilidad `htpasswd`:

```bash
htpasswd -nb usuario contraseña
```

Esto generará un output como el siguiente:
`usuario:$apr1$RC7H/abr$g86hSRbf3nSCuYh/aDd0z.`

**¡Atención!** Al colocar este hash en tu archivo `.env` o en el archivo `docker-compose.yml`, debes **duplicar los signos de dólar (`$`)** para que Docker Compose no los interprete como variables:

`usuario:$$apr1$$RC7H/abr$$g86hSRbf3nSCuYh/aDd0z.`

## Licencia

Este proyecto es de código abierto y está disponible bajo la licencia [GNU GPLv3](LICENSE).
Esta licencia es "copyleft", lo que asegura que cualquier modificación o distribución de este proyecto también deba ser obligatoriamente de código abierto.