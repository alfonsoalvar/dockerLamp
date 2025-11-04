# dockerLamp

El objetivo es montar un servidor LAMP (Linux, Apache, MariaDB y PHP) con Traefik en docker para que sea sencillo de desplegar en cualquier servidor.

## Levantar servicios

Se debe crear la red de Traefik antes de ejecutar docker compose up

~~~
docker network create proxy
~~~

Levantar servicios

~~~
docker compose up -d --build --force-recreate
~~~

Destruir servicios
~~~
docker compose down -v
~~~

## Creación de usuario y contraseña para el dashboard de traefik y netdata

Con netdata utilizar la doble $

~~~
htpasswd -nb usuario contraseña
usuario:$apr1$RC7H/abr$g86hSRbf3nSCuYh/aDd0z.
~~~
