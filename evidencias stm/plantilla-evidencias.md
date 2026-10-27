# Evidencias – Secure Task Manager

**Nombre:** ______________________  **Fecha:** ____________

> Regla del documento: **nunca** muestres tokens en capturas ni notas. El script
> `backend/scripts/ejercicio-19a.sh` solo imprime códigos HTTP, así que puedes capturarlo tal cual.

## 1. Predicciones (escríbelas ANTES de ejecutar cada tarea)

| Tarea | Mi predicción |
|---|---|
| 1. Rotación: ¿qué devuelve `/refresh`? ¿El token nuevo es igual al viejo? | |
| 2. Reutilización: ¿qué pasa al enviar el token viejo? ¿Y con el más nuevo de esa familia? | |
| 3. Logout: ¿qué código devuelve? ¿El token sirve después? | |
| 4. Logout-all: ¿qué pasa con los refresh tokens de ambas sesiones? | |

## 2. Tabla de resultados

| Prueba | Esperado | Mi resultado | ¿Pasa? |
|---|---|---|---|
| Refresh con token válido | 200 | | |
| Refresh con token viejo | 401 | | |
| Refresh con token más nuevo tras reutilización | 401 | | |
| Refresh después de logout | 401 | | |
| Refresh después de logout-all | 401 | | |

Captura: salida de `./scripts/ejercicio-19a.sh` → `captura-01-ejercicio.png`

## 3. Verificación de la base de datos (opcional)

Captura de Prisma Studio (`npx prisma studio`) o de esta consulta (no incluye `tokenHash`):

```sql
SELECT id, "familyId", "revokedAt", "expiresAt" FROM "RefreshToken" ORDER BY "createdAt" DESC;
```

- [ ] Se crea una fila nueva por cada refresh exitoso
- [ ] El token viejo tiene `revokedAt` después de rotar
- [ ] Los tokens rotados comparten `familyId`
- [ ] Tras la reutilización, toda la familia queda revocada

## 4. Verificación en Flutter

- [ ] Inicio sesión, dejo la app en segundo plano > 10 min, vuelvo y la lista carga (refresh automático)
- [ ] Al cerrar sesión regreso al login y el almacenamiento seguro se limpia
- [ ] Tras `logout-all` desde curl, la siguiente petición de la app me lleva al login

Capturas: `captura-02-login.png`, `captura-03-lista.png`, `captura-04-sesion-expirada.png`

## 5. Pruebas automatizadas

- [ ] `cd backend && npm test` → captura de "Tests: N passed" → `captura-05-npm-test.png`
- [ ] `cd mobile && flutter test` → captura → `captura-06-flutter-test.png`

## 6. Reflexión (con tus propias palabras)

1. ¿Por qué rotar los refresh tokens?

2. ¿Qué podría pasar si el servidor guardara los refresh tokens sin hashear?

3. ¿Por qué la reutilización revoca toda la familia?

4. ¿Cuál es el costo si un cliente legítimo reintenta un refresh después de un timeout de red?

## 7. Checklist de seguridad

| Práctica | ¿Dónde está en el código? | ✔ |
|---|---|---|
| Autorización a nivel de objeto en cada operación | `task.repository.js` (filtra por `ownerId`) | |
| Access tokens cortos + rotación de refresh | `utils/tokens.js`, `auth.service.js` | |
| Hash de contraseñas fuerte | `auth.service.js` (bcrypt, costo 12) | |
| Validación de entrada y límite de tamaño | `schemas/*.js`, `express.json({ limit: '20kb' })` | |
| Rate limit en login/registro | `routes/auth.routes.js` | |
| Errores seguros | `middleware/error.middleware.js` | |
| CORS con lista permitida | `app.js` + `CORS_ORIGINS` | |
| Secretos fuera del repositorio y logs con redacción | `.gitignore`, `pino-http redact` | |
| Paginación con límite máximo | `listTasksSchema` (máx. 100) | |
| Pruebas de acceso entre usuarios | `tests/tasks.test.js` | |
| Logout y revocación | `/auth/logout`, `/auth/logout-all`, `TokenStore.clear()` | |
