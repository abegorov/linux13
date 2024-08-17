#!/bin/bash
set -o errexit  # exit immediately if any untested command fails
set -o nounset  # exit immediately on expanding a variable that is not set

LOG=""  # внутренний лог (для отправки на почту при ошибке)
trap "exit_handler" EXIT  # on exit execute exit_handler

LOG_DIR="/var/log/nginx"  # директория с логами NGINX
ACCESS_LOG_PATTERN="access.log*"  # шаблон имени лога доступа NGINX
ERROR_LOG_PATTERN="error.log*"  # шаблон имени лога ошибок NGINX
LOGS_MMIN="-60"  # время модификации файлов логов в минутах (для find)
EMAIL='{{ nginx_informer_email }}' # адрес электронной почты с отчётом

# файл для предотвращения запуска второй копии скрипта:
LOCK_FILE="/run/nginx-informer.lock"

# час за которой анализируются логи, если скрипт запускается в 00:00:00, то
# будет 23:59:00 или 23 часа, однако в большинстве случаях будет текущий час
DATE_EPOCH=$(date -d "1 minute ago" "+%s")
# строки access.log начинаются с 10.0.2.2 - - [14/Aug/2024:17:14:55 +0000]:
DATE_ACCESS_LOG_GREP_PREFIX='^[^ ]\+ [^ ]\+ [^ ]\+ \['
DATE_ACCESS_LOG_FORMAT_FILTER="%d/%b/%Y:%H:"
# строки error.log начинаются с 2024/08/14 17:14:55:
DATE_ERROR_LOG_GREP_PREFIX='^'
DATE_ERROR_LOG_FORMAT_FILTER="%Y/%m/%d %H:"

# Выводит на экран сообщение с текущей датой и временем.
function log() {
  local msg="[$(date --iso-8601=seconds)]: $*"
  echo "${msg}" 1>&2
  LOG="${LOG}${msg}
"
}

# Обработчик завершения скрипта.
function exit_handler()
{
  local rc=$?
  if [[ ${rc} -ne 0 ]]; then
    log "В скрипте произошла неожиданная ошибка (код ${rc})."
    sendmail -i -- "${EMAIL}" <<EOF
Subject: Ошибка получения статистики NGINX на $(hostname)

В скрипте произошла неожиданная ошибка (код ${rc}).
${LOG}
EOF
  fi
}

# Получает логи (в том числе сжатые) за последний час, начиная от его начала.
# Arguments:
#   1. Шаблон имени файлов лога, которые необходимо просмотреть.
#   2. Регулярное выражение (для grep) приставки к дате в логе.
#   3. Формат даты в логе (для date).
function get_logs()
{
  local name_pattern="${1}"
  local date_prefix="${2}"
  local date_format="${3}"
  local grep_pattern="${date_prefix}$(date -d "@${DATE_EPOCH}" \
    "+${date_format}" | sed 's|/|\\/|g')"

  find "${LOG_DIR}" -type f -name "${name_pattern}" -mmin "${LOGS_MMIN}" \
    | while read file; do
      log "Чтение и фильтрация: ${file}"
      if [[ "${file}" =~ \.gz$ ]]; then
        zcat "${file}"
      else
        cat ${file}
      fi
    done \
    | grep "${grep_pattern}" \
    | cat
}

# Получает логи доступа за последний час, начиная от его начала.
function get_access_logs()
{
  get_logs "${ACCESS_LOG_PATTERN}" "${DATE_ACCESS_LOG_GREP_PREFIX}" \
    "${DATE_ACCESS_LOG_FORMAT_FILTER}"
}

# Получает логи ошибок за последний час, начиная от его начала.
function get_error_logs()
{
  get_logs "${ERROR_LOG_PATTERN}" "${DATE_ERROR_LOG_GREP_PREFIX}" \
    "${DATE_ERROR_LOG_FORMAT_FILTER}"
}

# Основной код скрипта.
function main()
{
  log "Блокировка на время работы скрипта: ${LOCK_FILE}"
  exec 3>"${LOCK_FILE}"
  if ! flock --exclusive --nonblock 3; then
    log "Скрипт уже запущен, файл заблокирован: ${LOCK_FILE}"
    exit 1
  fi

  # ожидание 1 секунду, чтобы можно было проверить работу блокировки:
  sleep 1

  log "Получение топ 10 IP адресов с наибольшим кол-вом запросов"
  IP_TOP=$(get_access_logs | grep --only-matching '^[^ ]\+' \
    | sort | uniq -c | sort -n -r | head -n 10)
  log "Получение топ 10 запрашиваемых URL"
  URL_TOP=$(get_access_logs | sed 's|^[^"]\+"[^ ]\+ \([^" ]\+\).*|\1|' \
    | sort | uniq -c | sort -n -r | head -n 10)
  log "Получение ошибок веб-сервера/приложения c момента последнего запуска"
  TOP_ERRORS=$(get_error_logs | sed 's|^\([^ ]\+ \)\{5\}\([^,]\+\).*|\2|' \
    | sort | uniq -c | sort -n -r)
  log "Получение списка всех кодов HTTP ответа с указанием их кол-ва"
  HTTP_CODES=$(get_access_logs | sed 's|^\([^"]\+"\)\{2\} \([0-9]\+\).*|\2|' \
    | sort | uniq -c)

  log "Отправка сообщения"
  DATE_BEGIN=$(date -d "@${DATE_EPOCH}" "+%Y-%m-%dT%H:00:00 %:z")
  DATE_END=$(date -d "@${DATE_EPOCH}" "+%Y-%m-%dT%H:%M:59 %:z")

  sendmail -i -- "${EMAIL}" <<EOF
Subject: Статистика по NGINX на $(hostname)

Статистика по NGINX на $(hostname).
С ${DATE_BEGIN} по ${DATE_END}.

Топ 10 IP адресов с наибольшим кол-вом запросов:
${IP_TOP}

Топ 10 запрашиваемых URL:
${URL_TOP}

Ошибки веб-сервера/приложения c момента последнего запуска:
${TOP_ERRORS}

Список всех кодов HTTP ответа:
${HTTP_CODES}
EOF
}

main
