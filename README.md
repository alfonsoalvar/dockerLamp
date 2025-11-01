# dockerLamp

El objetivo es montar un servidor LAMP (Linux, Apache, MariaDB y PHP) con Traefik en docker para que sea sencillo de desplegar en cualquier servidor.

## Levantar servicios

Se debe crear la red de Traefik antes de ejecutar docker compose up

~~~
docker network create proxy
~~~

Levantar servicios

~~~
docker compose up -d --build --force-recreat
~~~

Destruir servicios
~~~
docker compose down -v
~~~
