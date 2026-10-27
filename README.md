# Secure Task Manager: Flutter + Node.js

Proyecto completo del tutorial *"Full-Stack Tutorial: Secure Task Manager with Flutter and Node.js"*:
una API REST (Express, PostgreSQL y Prisma) con registro, login, rotación de refresh tokens,
detección de reutilización y logout, más un cliente Flutter con login y CRUD de tareas.

> Proyecto de aprendizaje, no es una auditoría de seguridad de producción.

```
secure_task_manager/
├── backend/                 API Node.js
│   ├── compose.yaml         PostgreSQL 16 en Docker
│   ├── prisma/schema.prisma
│   ├── src/                 routes → controllers → services → repositories
│   ├── tests/               Jest + Supertest (22 pruebas)
│   ├── scripts/ejercicio-19a.sh   Ejercicio 19a automatizado (solo imprime códigos HTTP)
│   └── openapi.yaml         Contrato de la API
├── mobile/                  Cliente Flutter (lib/, test/, pubspec.yaml)
└── evidencias/              Plantilla de evidencias y guía de respuestas
```

---

## Requisitos

- Node.js LTS (20 o 22), Docker Desktop, Flutter SDK (3.24 o superior) y un emulador Android
- `curl` y `jq` para el ejercicio 19a. En Windows, usa **Git Bash** o **WSL** para el script.

---

## 1. Backend

```bash
cd backend

# 1) Base de datos
docker compose up -d
docker compose ps            # espera a que diga "healthy"

# 2) Dependencias
npm install

# 3) Configuración local
cp .env.example .env
npm run secret               # copia el valor en JWT_ACCESS_SECRET
npm run secret               # copia OTRO valor en JWT_REFRESH_SECRET

# 4) Tablas
npx prisma migrate dev --name init

# 5) Servidor
npm run dev
```

Prueba: `curl http://localhost:3000/health` debe responder `{"status":"ok"}`.

### Pruebas del backend

Con la base de datos encendida:

```bash
npm test
```

Se esperan **22 pruebas aprobadas**: health; registro y login; rotación, reutilización,
logout y logout-all; y CRUD con propiedad de las tareas (el usuario A no puede ver, editar
ni borrar tareas del usuario B).

### Ejercicio 19a (rotación, reutilización y logout)

Con el servidor corriendo, en otra terminal:

```bash
cd backend
./scripts/ejercicio-19a.sh
```

Cada línea muestra el código esperado, el obtenido y `[OK]` o `[FALLA]`. Nunca imprime tokens,
así que puedes tomar la captura para la evidencia directamente.

Si aparece un **429** (demasiadas peticiones), reinicia el servidor: el límite se guarda en memoria.

---

## 2. App Flutter

Esta carpeta trae solo el código (`lib/`, `test/`, `pubspec.yaml`) y el manifest de debug de
Android. Las carpetas de plataforma se generan con `flutter create`, que **no sobrescribe** los
archivos que ya existen:

```bash
cd mobile
flutter create . --project-name mobile --platforms=android,ios,web
flutter pub get
flutter test
```

Ejecutar en el emulador Android (con el backend corriendo):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

- **Teléfono físico:** usa la IP de tu PC en la red local, por ejemplo
  `--dart-define=API_BASE_URL=http://192.168.1.50:3000/api/v1`, y permite el puerto 3000 en el firewall.
- **Flutter web:** ejecuta `flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:3000/api/v1`
  y agrega `http://localhost:5000` a `CORS_ORIGINS` en `backend/.env`.
- **Android exige `minSdk` 18 o más** para `flutter_secure_storage`. Si la compilación falla
  por eso, en `android/app/build.gradle(.kts)` cambia `minSdk` a `23`.

Qué puedes hacer en la app: registrarte, iniciar sesión, crear, marcar, editar (tocando la tarea)
y eliminar tareas (con confirmación), cerrar sesión y cerrar sesión en todos los dispositivos
(menú ⋮).

---

## 3. Cambios respecto al documento

Estos son los puntos en los que el código del documento falla o queda incompleto con las
versiones actuales, y lo que se hizo:

| # | Problema en el documento | Solución en este proyecto |
|---|---|---|
| 1 | Prisma 7 ya no acepta `url = env(...)` en `schema.prisma` | Se fija Prisma **6.19** en `package.json` |
| 2 | En Express 5, `req.query` es de solo lectura, así que `req[key] = parsed.data` hace fallar `GET /tasks` | `Object.defineProperty` en `validate.middleware.js` |
| 3 | El cliente Flutter metía `?page=1&limit=20` dentro del *path*; se codificaba como `%3F` y daba 404 | `ApiClient.send(..., query: {...})` |
| 4 | En la tarea 1 del ejercicio 19a, la línea `ROTATION_STATUS` reenviaba el token viejo y disparaba la detección de reutilización antes de tiempo | Eliminada en `scripts/ejercicio-19a.sh` |
| 5 | Jest no cargaba `.env`, así que `config.js` fallaba | `"jest": { "setupFiles": ["dotenv/config"] }` |
| 6 | Faltaban `main.dart`, los providers de Riverpod, el controlador y la página de tareas, el login y el `FakeTokenStore` | Agregados |
| 7 | Android bloquea HTTP sin cifrar hacia `10.0.2.2` | `android/app/src/debug/AndroidManifest.xml`, que solo aplica en debug |
| 8 | `controllers/` y `user.repository.js` estaban en la estructura pero nunca se usaban | Implementados (routes → controllers → services → repositories) |
| 9 | No se validaba el `taskId` de la ruta (el documento lo pedía como pendiente) | `taskIdParamsSchema`: un id malformado devuelve 400 seguro |
| 10 | Dos refresh simultáneos podían rotar el mismo token | La revocación verifica `count`; si otro proceso ganó, se trata como reutilización |
| 11 | Un JSON malformado devolvía el mensaje crudo del parser | El manejador de errores devuelve un mensaje genérico |
| 12 | El rate limit hacía fallar las pruebas automáticas | Se desactiva **solo** con `NODE_ENV=test`, que Jest pone automáticamente |

También se agregó `GET /tasks/:taskId`, el campo `replacedById` se llena al rotar y la UI está en español.

---

## 4. Reiniciar el estado local

| Situación | Qué hacer |
|---|---|
| Repetir el ejercicio | Vuelve a correr el script: cada ejecución crea una cuenta nueva |
| Error 429 | Reinicia `npm run dev` |
| Borrar todo lo local | `npx prisma migrate reset` (solo contra tu base **local**) |
| La app se queda con sesión iniciada o cerrada | Cierra sesión en la app, o en Android ve a Información de la app → Almacenamiento → Borrar |

## 5. Solución de problemas

- **`P1001 Can't reach database`:** ejecuta `docker compose ps`. Si el puerto 5432 está ocupado
  por otro Postgres, detenlo o cambia el puerto en `compose.yaml` y en `DATABASE_URL`.
- **`JWT_ACCESS_SECRET` too small:** los secretos deben tener al menos 32 caracteres (usa `npm run secret`).
- **La app dice "No se pudo conectar con el servidor":** revisa que el backend esté corriendo y que
  la URL use `10.0.2.2` en el emulador.
- **`npm audit` muestra vulnerabilidades en `prisma`:** vienen de la herramienta de línea de
  comandos de Prisma 6 (dependencia de desarrollo) y no se incluyen en el servidor.


  ## 6. Evidencias 
  <img width="1917" height="957" alt="1" src="https://github.com/user-attachments/assets/f54e06cf-51af-428a-a305-aafa05f3d1ab" />
<img width="1552" height="646" alt="2" src="https://github.com/user-attachments/assets/a2effd76-b39c-4d94-965c-f0382973d0f3" />
<img width="1531" height="545" alt="4" src="https://github.com/user-attachments/assets/41b7a84b-b811-4dc9-aaed-07573a7aa673" />

<img width="1656" height="955" alt="3" src="https://github.com/user-attachments/assets/b052f48f-dc66-46de-a27f-1472d0669d90" />

<img width="1805" height="990" alt="5" src="https://github.com/user-attachments/assets/6a248b1d-1a23-438f-8102-53baf8586c12" />
<img width="1457" height="846" alt="6" src="https://github.com/user-attachments/assets/a9de42e8-3021-427f-9f3d-5543d51acea4" />

  <img width="1307" height="577" alt="7" src="https://github.com/user-attachments/assets/d4cb1bc1-b602-4f24-a4ed-b70ffbdc8128" />
<img width="1281" height="91" alt="8" src="https://github.com/user-attachments/assets/78a1171f-7b07-4891-8ccf-f21a6d99ced5" />
<img width="1916" height="1020" alt="9" src="https://github.com/user-attachments/assets/051be8d5-c912-4fd7-9731-ead08a13c171" />

<img width="1895" height="1007" alt="10" src="https://github.com/user-attachments/assets/eb438f05-e5f8-4b50-a505-2905a97cda2a" />

<img width="1917" height="962" alt="11" src="https://github.com/user-attachments/assets/4c71b666-6360-4c2e-a45b-d23e19fa0186" />
