# Написать скрипт на языке Bash

## Задание

Написать скрипт для **CRON**, который раз в час будет формировать письмо и отправлять на заданную почту.

Необходимая информация в письме:

- Список **IP** адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта;
- Список запрашиваемых **URL** (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта;
- Ошибки веб-сервера/приложения c момента последнего запуска;
- Список всех кодов **HTTP** ответа с указанием их кол-ва с момента последнего запуска скрипта.
- Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения.

В письме должен быть прописан обрабатываемый временной диапазон.

## Реализация

Был написан скрипт [nginx-informer.sh](roles/nginx-informer/templates/nginx-informer.sh) и задание **cron** для него в [nginx-informer.cron](roles/nginx-informer/templates/nginx-informer.cron). Скрипт получает логи за час, предшествующей минуте его запуска и отправляет их на адрес электронной почты, указанный в секции **vars** [playbook.yml](playbook.yml). Для нормальной работы скрипта он должен запускаться каждый час и его минута запуска должна быть **00**. Скрипт отправляет на указанную электронную почту информацию в задании или свой лог при ошибке (реализовано с помощью **trap**'ов).

Задание сделано на **generic/centos9s** версии **v4.2.12**. **80** порты виртуальной машины проброшен на **127.0.0.1:8080** на хосте. После загрузки запускается **Ansible Playbook** [playbook.yml](playbook.yml), который последовательно запускает 3 роли:

- **nginx** - устанавливает и запускает **Nginx** с настройками по умолчанию;
- **postfix** - устанавливает и настраивает **postfix** для отправки **email**;
- **nginx-informer** - устанавливает скрипт [nginx-informer.sh](roles/nginx-informer/templates/nginx-informer.sh) и настраивает его запуск.

## Запуск

Необходимо скачать **VagrantBox** для **generic/centos9s** версии **v4.2.12** и добавить его в **Vagrant** под именем **generic/centos9s**. Сделать это можно командами:

```shell
curl -OL https://app.vagrantup.com/generic/boxes/centos9s/versions/4.3.12/providers/virtualbox/amd64/vagrant.box
vagrant box add vagrant.box --name "generic/centos9s"
rm vagrant.box
```

После этого нужно прописать адрес электронной почты на который нужно отправлять сообщения в [playbook.yml](playbook.yml) и сделать **vagrant up**.

Протестировано в **OpenSUSE Tumbleweed**:

- **Vagrant 2.3.7**
- **VirtualBox 7.0.20_SUSE r163906**
- **Ansible 2.17.3**
- **Python 3.11.9**
- **Jinja2 3.1.4**

## Проверка

1. Зайдём на [temp-mail.org](https://temp-mail.org) и получим временный адрес электронной почты, после чего пропишем его в [playbook.yml](playbook.yml) и сделаем **vagrant up**.

2. После запуска виртуальной машины генерируем лог **nginx**, для этого откроем страницу по умолчанию и несколько неверных **URL**'ов:

    - [http://localhost:8080](http://localhost:8080/)
    - [http://localhost:8080/about](http://localhost:8080/about)
    - [http://localhost:8080/variants](http://localhost:8080/variants)
    - [http://localhost:8080/about/governance](http://localhost:8080/about/governance)
    - [http://localhost:8080/code-of-conduct](http://localhost:8080/code-of-conduct)
    - [http://localhost:8080/community/calendar/](http://localhost:8080/community/calendar/)
    - [http://localhost:8080/legal](http://localhost:8080/legal)
    - [http://localhost:8080/legal/privacy](http://localhost:8080/legal/privacy)

3. Зайдём на сервер по **vagrant ssh** и отправим пару запросов с самого сервера:

    ```shell
    curl -s http://localhost > /dev/null
    curl -s http://localhost/about > /dev/null
    curl -s http://localhost/legal > /dev/null
    ```

4. Сделаем **sudo -i** и запустим одновременно две скрипт копии скрипта [nginx-informer.sh](roles/nginx-informer/templates/nginx-informer.sh), это можно сделать командой **nginx-informer.sh & nginx-informer.sh**:

    ```text
    [vagrant@bash-script ~]$ sudo -i
    [root@bash-script ~]# nginx-informer.sh & nginx-informer.sh
    [1] 8157
    [2024-08-17T14:45:29+00:00]: Блокировка на время работы скрипта: /run/nginx-informer.lock
    [2024-08-17T14:45:29+00:00]: Блокировка на время работы скрипта: /run/nginx-informer.lock
    [2024-08-17T14:45:29+00:00]: Скрипт уже запущен, файл заблокирован: /run/nginx-informer.lock
    [2024-08-17T14:45:29+00:00]: В скрипте произошла неожиданная ошибка (код 1).
    [2024-08-17T14:45:30+00:00]: Получение топ 10 IP адресов с наибольшим кол-вом запросов
    [2024-08-17T14:45:30+00:00]: Чтение и фильтрация: /var/log/nginx/access.log
    [2024-08-17T14:45:30+00:00]: Получение топ 10 запрашиваемых URL
    [2024-08-17T14:45:30+00:00]: Чтение и фильтрация: /var/log/nginx/access.log
    [2024-08-17T14:45:30+00:00]: Получение ошибок веб-сервера/приложения c момента последнего запуска
    [2024-08-17T14:45:30+00:00]: Чтение и фильтрация: /var/log/nginx/error.log
    [2024-08-17T14:45:30+00:00]: Получение списка всех кодов HTTP ответа с указанием их кол-ва
    [2024-08-17T14:45:30+00:00]: Чтение и фильтрация: /var/log/nginx/access.log
    [2024-08-17T14:45:30+00:00]: Отправка сообщения
    [1]+  Exit 1                  nginx-informer.sh
    ```

5. На почту придут два сообщения. Одно с ошибкой (что скрипт уже запущен, файл /run/nginx-informer.lock заблокирован) и одно с собираемой информацией.

    ```text
    From:	root <root@bash-script.internal>
    Subject:	Ошибка получения статистики NGINX на bash-script.internal
    Date:	Sat, 17 Aug 2024 14:45:29 +0000 (UTC) (17.08.2024 17:45:29)

    В скрипте произошла неожиданная ошибка (код 1).
    [2024-08-17T14:45:29+00:00]: Блокировка на время работы скрипта: /run/nginx-informer.lock
    [2024-08-17T14:45:29+00:00]: Скрипт уже запущен, файл заблокирован: /run/nginx-informer.lock
    [2024-08-17T14:45:29+00:00]: В скрипте произошла неожиданная ошибка (код 1).
    ```

    ```text
    From:	root <root@bash-script.internal>
    Subject:	Статистика по NGINX на bash-script.internal
    Date:	Sat, 17 Aug 2024 14:45:30 +0000 (UTC) (17.08.2024 17:45:30)

    Топ 10 IP адресов с наибольшим кол-вом запросов:
         18 10.0.2.2
          3 127.0.0.1

    Топ 10 запрашиваемых URL:
          2 /variants
          2 /legal
          2 /community/calendar/poweredby.png
          2 /community/calendar/nginx-logo.png
          2 /community/calendar/
          2 /about
          2 /
          1 /legal/privacy
          1 /legal/poweredby.png
          1 /legal/nginx-logo.png

    Ошибки веб-сервера/приложения c момента последнего запуска:
          2 "/usr/share/nginx/html/community/calendar/index.html" is not found (2: No such file or directory)
          2 open() "/usr/share/nginx/html/variants" failed (2: No such file or directory)
          2 open() "/usr/share/nginx/html/legal" failed (2: No such file or directory)
          2 open() "/usr/share/nginx/html/community/calendar/poweredby.png" failed (2: No such file or directory)
          2 open() "/usr/share/nginx/html/community/calendar/nginx-logo.png" failed (2: No such file or directory)
          2 open() "/usr/share/nginx/html/about" failed (2: No such file or directory)
          1 open() "/usr/share/nginx/html/legal/privacy" failed (2: No such file or directory)
          1 open() "/usr/share/nginx/html/legal/poweredby.png" failed (2: No such file or directory)
          1 open() "/usr/share/nginx/html/legal/nginx-logo.png" failed (2: No such file or directory)
          1 open() "/usr/share/nginx/html/code-of-conduct" failed (2: No such file or directory)
          1 open() "/usr/share/nginx/html/about/poweredby.png" failed (2: No such file or directory)
          1 open() "/usr/share/nginx/html/about/nginx-logo.png" failed (2: No such file or directory)
          1 open() "/usr/share/nginx/html/about/governance" failed (2: No such file or directory)

    Список всех кодов HTTP ответа:
          1 200
          1 304
         19 404
    ```
