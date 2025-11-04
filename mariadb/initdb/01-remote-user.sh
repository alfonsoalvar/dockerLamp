#!/bin/bash

echo "Creando usuario remoto: ${MARIADB_REMOTE_USER}"

# Usamos 'mysql' para ejecutar comandos.
# El usuario root ya está autenticado a nivel de la inicialización.
mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOSQL
    -- Creamos el usuario remoto usando una variable de entorno para la contraseña remota
    CREATE USER '${MARIADB_REMOTE_USER}'@'%' IDENTIFIED BY '${MARIADB_REMOTE_PASSWORD}';
    GRANT ALL PRIVILEGES ON *.* TO 'usuario_remoto'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;

    -- Opcional: Permitir al root conectarse desde fuera también
    -- GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}' WITH GRANT OPTION;
    -- FLUSH PRIVILEGES;
EOSQL

echo "Usuario remoto '${MARIADB_REMOTE_USER}' creado con éxito usando la contraseña remota."
