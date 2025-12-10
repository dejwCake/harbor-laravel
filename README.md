# Harbor #

This harbor provides docker configuration for your project. It is based on vessel by Fideloper LLC - https://vessel.shippingdocker.com/. It consists of:
 
* nginx container, 
* php container, 
* php qa container, 
* db container, 
* testing db container,
* node container,
* redis container

This script handles the current instance. To create new, install or update harbor, use harbor installer.

## Upgrade guide ##

### From 3 to 4 ###

As Harbor 4 uses the same structure and files as v3, so the upgrade is simple. The main difference is in used versions and that by default it uses mariad/mysql instead of postgres. If you want to use postgres, you have to modify the `docker-compose.override.yml` file and `.env.harbor` file. Also, PHP QA image has been added, so now on you can check your code with PHP QA tools.

### From 2 to 3 ###

Harbor 3 has been completely rewritten from Harbor 2. It is using prebuild docker images. Therefore, the upgrade have to be done manually.

1. backup all data from `pgsql` container, you can use `./harbor pg_dump` command. In version 3 container has a different name and volume, so you have to move data if needed. In case of no important data, just skip this step. 
2. stop harbor if running `./harbor stop`
3. backup `docker` folder and `docker-compose.yml` file. 
4. remove `docker` folder, `docker-compose.yml`, `harbor`, `harbor-README.md` files.
5. run `harbor install craftable` command in project folder
6. change values in `.env.harbor` according #docker-config section in `.env` file, map ENV values as follows:
    ```
    DOCKER_APP_PORT -> HARBOR_WEB_PORT
    DOCKER_PGSQL_PORT -> HARBOR_DB_PORT
    DOCKER_PGSQL_TEST_PORT -> HARBOR_DB_TESTING_PORT
    DOCKER_PGSQL_TEST_DIR -> is not used anymore
    DOCKER_PHP_VERSION -> HARBOR_PHP_VERSION
    DOCKER_POSTGRES_VERSION -> HARBOR_POSTGRES_VERSION
    DOCKER_NODE_VERSION -> HARBOR_NODE_VERSION
    DOCKER_PHP_XDEBUG -> XDEBUG_SWITCH
    ``` 
    also, change this values in `.env.harbor` according your `.env` file
    ```
    DB_DATABASE
    DB_USERNAME
    DB_PASSWORD
    ``` 
   Beware `.env.harbor` file is committed, so if you use some secret password for db in development, leave the password empty in `.env.harbor`
7. change `DB_HOST` env value in `.env` and `.env.example` file to `HARBOR_DB_HOST` env value in `.env.harbor`, probably the value is `db`.
8. check other env values in `.env.harbor`
9. remove #docker-config section in `.env` and `.env.example` files
10. if you use standard `docker-compose.yml` and `Dockerfiles` for images in version 2, you can sgo to step 11.
11. modify `docker-compose.override.yml` according the backed up `docker-compose.yml` changes you have made. If you need some special changes in Dockerfiles, you can extend provided images and prepare your Dockerfiles used in `docker-compose.override.yml` file.
12. move folders `docker-entrypoint-initdb.d`, `export` and `import` from your backup docker folder `docker/pgsql` to `.harbor/db`
13. move folder `docker-entrypoint-initdb.d` from your backup docker folder `docker/testing` to `.harbor/db-testing`
14. move ssh keys from your backup docker folder `docker/php/ssh` to `.harbor/ssh` probably 3 files (`id_rsa`, `id_rsa.pub`, `known_hosts`)
15. import backup database data or just run `./harbor art migrate`
16. now you should have a working harbor, just run `./harbor start`

### From 1 to 2 ###

As the containers has been changed, you have to rebuild all the containers and create global volume.

`docker volume create composercache` to create global volume for composer cache

then run 

`harbor rebuild -i -v` which will remove all used images and volumes. All data will be lost, so if you need the volumes, please run the command without -v. It will also recreate new images.

## Customization ##

If you need to customize some harbor/docker settings, it is recommended to modify `docker-compose.override.yml` file for a docker compose overrides and `.env.harbor` for harbor settings. You can define which version of php, mariadb or postgres and node will harbor be using.

Currently supported versions are:

```
PHP 8.2
PHP 8.3
PHP 8.4
PHP 8.5

MariaDB 10.6
MariaDB 10.11
MariaDB 11.4
MariaDB 11.8
MariaDB 12.0
MariaDB 12.1

Postgress 14
Postgress 15
Postgress 16
Postgress 17
Postgress 18

Node 20
Node 22
Node 24
```

## Databases ##

Currently, we support only MariaDB and Postgres. By default, MariaDB is prepared. To change to Postgres you have to modify `docker-compose.override.yml` file, the snippet is already there. Just uncomment required parts.

In file `.env.harbor` you have to change the config for DB. Comment out Mysql/Mariadb part and uncomment Postgres part. Example:

```
# Mysql/Mariadb
#HARBOR_DB_CONNECTION=mysql
#HARBOR_DB_PORT=3306
#HARBOR_DB_TESTING_PORT=3307
#HARBOR_DB_DATA_PATH=/usr/local/lib/mysql
#HARBOR_DB_USER=mysql
# Postgres
HARBOR_DB_CONNECTION=pgsql
HARBOR_DB_PORT=5432
HARBOR_DB_TESTING_PORT=5433
HARBOR_DB_DATA_PATH=/var/lib/postgresql/data
HARBOR_DB_USER=postgres
```

## Let's init laravel / craftable ##

If you have an existing laravel / craftable project, and you have not initialized this project, run 

`harbor init laravel` or `harbor init craftable` 

which will setup some .env variables, install required packages and will run npm

## Starting a harbor (docker) ##

To start the docker environment use:

`harbor start`

This will start all the docker containers and set up network and volumes correctly. So now we can play around with empty db or php. Now you can point your browser to the http://localhost, and you should be able to see a default `/` route mapped to public/index.php.

## Rebuild a harbor (docker) ##

In case you change some env values for docker, or changes some docker file or other configuration, you should run

`harbor rebuild`

NOTE: To rebuild images use `-i|--images`, to destroy volumes use `-v|--volumes` 

## Daily usage ##

In this section you can find all commands supported by harbor:

#### Docker commands ####

`harbor start` will start all containers based on `docker-compose.yml` and `docker-compose.override.yml` files.

`harbor up` will start all containers based on `docker-compose.yml` and `docker-compose.override.yml` files, but not as a daemon.

`harbor stop` will stop and destroy all containers.

`harbor restart`will stop and destroy and then starts again all containers.

`harbor rebuild` will stop and destroy all containers then starts again all containers, build them if changes has been made. Can be used with -i to remove images, -v to remove volumes, or -d to remove test database if in folder and not in volume

#### PHP container commands ####

`harbor artisan` OR `harbor art` will pass all additional arguments to php container to php artisan command, e.g. `harbor art make:migration` goes to php docker container and call `php artisan make:migration`.

`harbor composer` OR `harbor comp` will pass all additional arguments to php container to composer command, e.g. `harbor comp require brackets/craftable` goes to php docker container and call `composer require brackets/craftable`.

`harbor test` will run phpunit tests on new php container. All additional arguments are passed to phpunit.

`harbor css` will run php code style check on new php container. All additional arguments are passed to command.

`harbor csf` will run php code style fix on new php container. All additional arguments are passed to command.

`harbor pst` will run php stan on new php container. All additional arguments are passed to command.

`harbor pmd` will run php mass detector on new php container with argument with list of dirs. All additional arguments are passed to command.

`harbor cmp` will run php code compatibility check on new php container. All additional arguments are passed to command.

`harbor cn` will run php composer normalisation on new php container. All additional arguments are passed to command.

#### NPM container commands ####

`harbor npm` will run npm command on node container and pass all additional arguments to npm.

#### DB container commands ####

`harbor db` will run `mysql`/`psql` command on db container with user and host form .env file and pass all additional arguments to `mysql`/`psql` command.

`harbor dump` will run `mysqldump`/`pg_dump` command on db container with user and host form .env file and pass all additional arguments to `mysqldump`/`pg_dump` command.

#### Global commands ####

`harbor ssh {container}` will connect to container and run bash in it, cannot be used with node. You can provide a second parameter `root` to open as root. 

`harbor exec` is an alias for docker-compose exec 

`harbor run` is an alias for docker-compose run 

## Install command (use with care) ##

`harbor new laravel` will install laravel application to current folder. See harbor installer, it is the recommended way.

`harbor new craftable` will install craftable application to current folder. See harbor installer, it is the recommended way.

## SSH keys ##

To use ssh keys in php container, copy your keys to `./harbor/ssh`. You have to restart container after adding keys. SSH keys may be required for some git repositories.