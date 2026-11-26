# App Store listing (ES)

Nombre de la app: **Byegones** (elegido el 2026-11-25; reemplaza a "Rollaway", ver `names.md`). Localización Español (México), reutilizable en Español (España). Tono: tú, español neutro latinoamericano.

## Name
`Byegones` (8 chars; see `names.md`)

## Subtitle options (<= 30)
- A. `Limpia tu galería deslizando` (28)
- B. `Desliza fotos, libera espacio` (29)
- C. `Borra o guarda con un gesto` (27)

**Recommended: A.**

## Promotional text (<= 170)
Limpia tu carrete en minutos. Desliza a la izquierda para borrar, a la derecha para guardar, arriba para favoritas. Gratis, privado y nada se borra sin tu confirmación.

(168 chars)

## Description (<= 4000)
```text
Tu carrete, un deslizamiento a la vez.

Byegones convierte la limpieza de fotos en un juego rápido: desliza a la izquierda para borrar, a la derecha para guardar y hacia arriba para marcar como favorita. Gratis, sin cuenta y tus fotos nunca salen de tu iPhone.

DESLIZA. DECIDE. LISTO.
- Primero lo más reciente, un elemento a la vez y a pantalla completa
- Izquierda para borrar, derecha para guardar, arriba (o toca la estrella) para guardar y añadir a Favoritos en Fotos
- Los videos se reproducen en silencio y en bucle; toca para activar el sonido
- Mira la fecha, el tamaño y la duración de cada elemento

NADA SE BORRA HASTA QUE TÚ LO DECIDES
- Lo que deslizas a la izquierda va a una pila de borrado, no al vacío
- Abre la pila cuando quieras y toca una foto para sacarla
- Mira cuántos elementos hay en la pila y cuánto espacio ocupan
- Borra todo de una vez con una sola confirmación de iOS

PENSADA PARA LOS DEDAZOS
- Deshacer revierte tu última decisión: guardar, borrar o favorita
- Tu progreso se guarda, así que las fotos que ya revisaste no vuelven a aparecer
- ¿Quieres empezar de cero? Reinicia el progreso en Ajustes

PRIVADA POR DISEÑO
- Sin cuenta, sin registro, sin anuncios
- Sin rastreo, sin analíticas, sin recopilar datos
- Tus fotos y videos se quedan en tu iPhone. Byegones no tiene servidores a los que enviarlos.
- También funciona con acceso limitado: comparte solo algunas fotos y Byegones limpia justo esas.

CÓMO FUNCIONA
1. Permite el acceso a tus fotos.
2. Desliza por tu biblioteca y ordénala a tu manera.
3. Abre la pila de borrado, revísala y toca Borrar.
4. Listo. Tus elementos pasan al álbum Eliminados recientemente de Fotos.

BUENO SABER: CÓMO RECUPERAR EL ESPACIO
Cuando borras fotos en el iPhone, iOS las guarda 30 días en Eliminados recientemente. El almacenamiento se libera por completo cuando vacías ese álbum. Para recuperar el espacio ya, abre Fotos > Álbumes > Eliminados recientemente > Seleccionar > Eliminar todo. Byegones te lo recuerda después de cada limpieza.

GRATIS DE VERDAD
Sin compras dentro de la app, sin suscripciones, sin pruebas.
```

## Keywords (<= 100, comma-separated, no spaces)
```text
almacenamiento,carrete,videos,capturas,basura,eliminar,ordenar,favoritos,memoria,privado,limpiador
```
(98 chars)

Estrategia: no se repiten palabras del nombre ni de los subtítulos (comprobado abajo). Sin competidores ni marcas. "Carrete" y "galería" (galería está en el subtítulo A) cubren cómo busca la gente en México y España.

**Overlap check** (keywords vs name `Byegones` and all three subtitle options):
```text
keywords: almacenamiento, carrete, videos, capturas, basura, eliminar, ordenar, favoritos, memoria, privado, limpiador
name+subtitle words: borra, con, desliza, deslizando, espacio, fotos, galería, gesto, guarda, libera, limpia, o, byegones, tu, un
intersection: (none)
duplicates within keywords: (none)
spaces inside keyword string: none
```
Name is final (Byegones); re-check only if it changes.

## What's New (1.0)
¡Bienvenido a Byegones! Desliza por tus fotos y videos, arma una pila de borrado y bórrala toda de una vez. Deshacer siempre está a un toque. Gratis, privada y sin cuenta.

(171 chars)

## Screenshot captions (<= 30 chars; in shot order)

| # | Caption | chars | Screen to capture |
|---|---|---|---|
| 1 | Desliza, guarda, borra | 22 | Pantalla de deslizar: tarjeta con sello BORRAR, fila de botones visible |
| 2 | Mira cuánto vas a limpiar | 25 | Pastilla de basura ("12 · 340 MB") y la hoja de revisión |
| 3 | ¿Te arrepientes? Deshaz | 23 | Pantalla de deslizar justo tras Deshacer |
| 4 | Arriba para favoritas ★ | 23 | Tarjeta deslizada hacia arriba con el sello azul FAVORITA |
| 5 | Privado, en tu iPhone | 21 | Onboarding página 2 ("Tus fotos nunca salen de tu iPhone") |
| 6 | ¡Buen trabajo! Pila lista | 25 | Pantalla de celebración ("Limpiaste X MB" + total acumulado) |

## Character-count verification (python `len()`)

| Field | Count | Limit | Result |
|---|---|---|---|
| Subtitle option A | 28 | 30 | OK |
| Subtitle option B | 29 | 30 | OK |
| Subtitle option C | 27 | 30 | OK |
| Promotional text | 168 | 170 | OK |
| Description (with Byegones) | 2099 | 4000 | OK |
| Description (name replaced by 30 chars, worst case) | 2187 | 4000 | OK |
| Keywords | 98 | 100 | OK |
| What's New 1.0 | 171 | 4000 | OK |
| Caption 1 | 22 | 30 | OK |
| Caption 2 | 25 | 30 | OK |
| Caption 3 | 23 | 30 | OK |
| Caption 4 | 23 | 30 | OK |
| Caption 5 | 21 | 30 | OK |
| Caption 6 | 25 | 30 | OK |

## Notas de precisión
- Lo borrado va a Eliminados recientemente 30 días; el texto lo dice y explica cómo vaciarlo. No se promete espacio instantáneo.
- El tamaño por elemento depende de una API protegida; si no está disponible, quitar las menciones de tamaño (viñeta fecha/tamaño/duración, leyenda 2).
- Sin calificaciones, descargas, rankings ni comparaciones con competidores.
- Verificar en un iPhone en español los nombres de iOS: Fotos > Álbumes > Eliminados recientemente > Seleccionar > Eliminar todo.
