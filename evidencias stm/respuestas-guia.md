# Guía de respuestas (para revisar las tuyas, no para copiarlas)

**1. ¿Por qué rotar los refresh tokens?**
Cada token sirve una sola vez. Si alguien roba uno, solo le dura hasta que el
usuario legítimo haga su siguiente refresh, y además ese uso doble se detecta.
Sin rotación, un token robado serviría los 7 días completos sin que nadie lo note.

**2. ¿Qué pasa si el servidor guarda los refresh tokens sin hashear?**
Una fuga de la base de datos (backup, inyección SQL, empleado con acceso)
entregaría sesiones válidas de todos los usuarios. Con SHA-256, la base solo
tiene hashes: sirven para comparar, pero no para iniciar sesión.

**3. ¿Por qué la reutilización revoca toda la familia?**
Si un token ya rotado vuelve a aparecer, hay dos copias: la del usuario y la
de un atacante, y el servidor no puede saber cuál es cuál. Revocar la familia
completa saca a los dos; el usuario legítimo solo tiene que volver a iniciar
sesión, mientras que el atacante pierde el acceso.

**4. ¿Costo de reintentar un refresh tras un timeout?**
Si el servidor sí rotó el token pero la respuesta se perdió, el cliente aún
tiene el token viejo; al reintentarlo, el servidor lo ve como reutilización y
cierra la sesión. Se cambia comodidad (logouts inesperados en redes malas) por
seguridad. Mitigaciones: un periodo de gracia corto, o no reintentar el
refresh automáticamente (como hace este cliente).
