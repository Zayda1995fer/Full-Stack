#!/usr/bin/env bash
# Ejercicio 19a: rotación, reutilización de tokens, logout y logout-all.
# Requisitos: backend corriendo (npm run dev), PostgreSQL arriba, curl y jq.
# Solo imprime códigos de estado HTTP, NUNCA tokens (pensado para capturas de evidencia).
set -u

BASE=${BASE:-http://localhost:3000/api/v1}
EMAIL="student-$RANDOM$RANDOM@example.test"
PASSWORD='a-long-local-test-password-for-this-exercise'
JSON='Content-Type: application/json'

status() { curl -sS -o /dev/null -w "%{http_code}" "$@"; }
check() { # check <descripción> <esperado> <obtenido>
  local mark="FALLA"; [ "$2" = "$3" ] && mark="OK"
  printf '%-52s esperado=%s obtenido=%s  [%s]\n' "$1" "$2" "$3" "$mark"
}

echo "== Setup =="
REGISTER=$(curl -sS -X POST "$BASE/auth/register" -H "$JSON" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
ACCESS=$(printf '%s' "$REGISTER" | jq -r .accessToken)
REFRESH=$(printf '%s' "$REGISTER" | jq -r .refreshToken)
unset REGISTER
if [ -z "$REFRESH" ] || [ "$REFRESH" = "null" ]; then
  echo "No se pudo registrar la cuenta. ¿Está corriendo el backend? ¿Error 429? Reinicia con npm run dev."
  exit 1
fi
echo "Cuenta de prueba creada (tokens guardados en variables, no se muestran)."

echo; echo "== Tarea 1: Rotación =="
OLD_REFRESH=$REFRESH
# NOTA: el documento original incluye aquí una línea ROTATION_STATUS que vuelve a
# enviar el token viejo; eso dispara la detección de reutilización antes de tiempo.
# Aquí se mide el código del primer refresh directamente.
ROTATED=$(curl -sS -w '\n%{http_code}' -X POST "$BASE/auth/refresh" -H "$JSON" \
  -d "{\"refreshToken\":\"$OLD_REFRESH\"}")
ROTATION_STATUS=$(printf '%s' "$ROTATED" | tail -n1)
NEW_REFRESH=$(printf '%s' "$ROTATED" | head -n1 | jq -r .refreshToken)
check "Refresh con token válido" 200 "$ROTATION_STATUS"
if [ "$NEW_REFRESH" != "$OLD_REFRESH" ]; then SAME=different; else SAME=same; fi
check "¿El nuevo refresh token es diferente?" different "$SAME"
REFRESH=$NEW_REFRESH
unset ROTATED NEW_REFRESH

echo; echo "== Tarea 2: Detección de reutilización =="
check "Refresh con token viejo (reutilizado)" 401 \
  "$(status -X POST "$BASE/auth/refresh" -H "$JSON" -d "{\"refreshToken\":\"$OLD_REFRESH\"}")"
check "Refresh con token más nuevo tras reutilización" 401 \
  "$(status -X POST "$BASE/auth/refresh" -H "$JSON" -d "{\"refreshToken\":\"$REFRESH\"}")"

echo; echo "== Tarea 3: Logout =="
LOGIN=$(curl -sS -X POST "$BASE/auth/login" -H "$JSON" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
LOGOUT_REFRESH=$(printf '%s' "$LOGIN" | jq -r .refreshToken)
unset LOGIN
check "Logout" 204 \
  "$(status -X POST "$BASE/auth/logout" -H "$JSON" -d "{\"refreshToken\":\"$LOGOUT_REFRESH\"}")"
check "Refresh después de logout" 401 \
  "$(status -X POST "$BASE/auth/refresh" -H "$JSON" -d "{\"refreshToken\":\"$LOGOUT_REFRESH\"}")"

echo; echo "== Tarea 4: Logout-all =="
SESSION_ONE=$(curl -sS -X POST "$BASE/auth/login" -H "$JSON" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
ACCESS_ONE=$(printf '%s' "$SESSION_ONE" | jq -r .accessToken)
REFRESH_ONE=$(printf '%s' "$SESSION_ONE" | jq -r .refreshToken)
SESSION_TWO=$(curl -sS -X POST "$BASE/auth/login" -H "$JSON" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
REFRESH_TWO=$(printf '%s' "$SESSION_TWO" | jq -r .refreshToken)
unset SESSION_ONE SESSION_TWO
check "Logout-all" 204 \
  "$(status -X POST "$BASE/auth/logout-all" -H "Authorization: Bearer $ACCESS_ONE")"
check "Refresh sesión 1 después de logout-all" 401 \
  "$(status -X POST "$BASE/auth/refresh" -H "$JSON" -d "{\"refreshToken\":\"$REFRESH_ONE\"}")"
check "Refresh sesión 2 después de logout-all" 401 \
  "$(status -X POST "$BASE/auth/refresh" -H "$JSON" -d "{\"refreshToken\":\"$REFRESH_TWO\"}")"

echo; echo "== Extra: tareas protegidas =="
LOGIN=$(curl -sS -X POST "$BASE/auth/login" -H "$JSON" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
ACCESS=$(printf '%s' "$LOGIN" | jq -r .accessToken)
unset LOGIN
check "GET /tasks sin token" 401 "$(status "$BASE/tasks")"
check "POST /tasks con token" 201 "$(status -X POST "$BASE/tasks" -H "Authorization: Bearer $ACCESS" -H "$JSON" \
  -d '{"title":"Review API security","description":"Check ownership and validation"}')"
check "GET /tasks con token" 200 "$(status "$BASE/tasks?page=1&limit=20" -H "Authorization: Bearer $ACCESS")"

unset ACCESS REFRESH OLD_REFRESH LOGOUT_REFRESH ACCESS_ONE REFRESH_ONE REFRESH_TWO
