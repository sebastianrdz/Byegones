# In-app strings (EN / ES)

Voice: friendly, short, plain, a little playful. ES: neutral Latin-American Spanish, "tú". The app name is **Byegones** (chosen at Gate 1). Strings below show the name literally; if the display name is ever changed, search and replace it in this file. `%lld` = integer, `%@` = string (already formatted). Terms: EN "trash pile" / ES "pila de borrado"; EN "Recently Deleted" / ES "Eliminados recientemente" (verify against the iOS Photos album name on an ES device, which varies by region).

## Engineering notes

**Pluralization (String Catalog plural variants).** Keys marked `PLURAL` need Vary by Plural in the `.xcstrings`.
- EN needs `one` and `other`. ES needs `one`, `many` and `other` (CLDR: `many` applies to very large numbers like 1,000,000; fill it with the same text as `other`).
- Use `%lld` for the count so the variants resolve. The plural rows below list variants as `one / other`.
- 0 uses `other` in both languages ("0 left" / "Quedan 0").

**Byte sizes.** Never hard-code "MB". Format with `ByteCountFormatter` (`.file` style, `countStyle: .file`) so it localizes (KB / MB / GB, decimal separators). `%@` below is that formatted string.

**Dates / duration.** Use `Date.FormatStyle` (`.abbreviated` date) and a duration formatter (`m:ss`); not strings.

**Other.** Swipe stamps are uppercase in the UI; store them uppercase. Do not concatenate fragments across keys; each key is a full sentence. Info.plist strings go in `InfoPlist.xcstrings`.

**Open product questions (copy depends on engineering):**
1. (Resolved) Reset progress clears only the review history: swiped items come back for review; the pending trash pile and the lifetime cleared total are kept. `settings.reset.confirm.message` says so.
2. Size strings (`swipe.meta.size`, trash pill MB, summary MB) hide when the size API is unavailable; use the `.nosize` variants.
3. Celebration headline says "cleared" (not "freed") on purpose: the space is only freed after Recently Deleted is emptied. The spec said "You freed X MB"; this is a deliberate accuracy change.

## Table

| key | EN | ES | notes |
|---|---|---|---|
| **Onboarding** | | | |
| onboarding.page1.title | Swipe your way clean | Limpia deslizando | |
| onboarding.page1.body | Left to delete. Right to keep. Up to favorite ★. Oops? Undo brings it right back. | Izquierda para borrar. Derecha para guardar. Arriba para marcar como favorita ★. ¿Te equivocaste? Deshacer la recupera. | Body under animated demo card |
| onboarding.page1.demo.delete | Delete | Borrar | Demo label, swipe left |
| onboarding.page1.demo.keep | Keep | Guardar | Demo label, swipe right |
| onboarding.page1.demo.favorite | Favorite | Favorita | Demo label, swipe up |
| onboarding.page1.demo.undo | Undo | Deshacer | Demo label |
| onboarding.page1.demo.a11y | Demo: swipe left to delete, right to keep, up to favorite. | Demostración: desliza a la izquierda para borrar, a la derecha para guardar, arriba para favorita. | VoiceOver label for the animated demo |
| onboarding.page2.title | Your photos never leave your iPhone | Tus fotos nunca salen de tu iPhone | |
| onboarding.page2.body | No account. No tracking. No data collected. Everything happens right here on your device. | Sin cuenta. Sin rastreo. No recopilamos datos. Todo ocurre aquí, en tu dispositivo. | |
| onboarding.page3.title | Let's find your photos | Busquemos tus fotos | Pre-permission page |
| onboarding.page3.body | Byegones needs access to your photo library to show them to you. Nothing is deleted until you review your pile and confirm. | Byegones necesita acceso a tu fototeca para mostrártelas. No se borra nada hasta que revises tu pila y confirmes. | |
| onboarding.next | Next | Siguiente | Pages 1-2 button |
| onboarding.allow | Allow photo access | Permitir acceso a Fotos | Page 3 primary; triggers the system prompt |
| onboarding.pageindicator.a11y | Page %lld of %lld | Página %lld de %lld | |
| **System permission (InfoPlist)** | | | |
| infoplist.NSPhotoLibraryUsageDescription | Byegones shows your photos and videos one at a time so you can keep or delete them. They never leave your iPhone. | Byegones te muestra tus fotos y videos uno por uno para que decidas cuáles guardar o borrar. Nunca salen de tu iPhone. | Info.plist; must be specific. Name is literal |
| **Permission states** | | | |
| permission.denied.title | Photo access is off | El acceso a Fotos está desactivado | |
| permission.denied.body | Byegones can't show your photos without access. Turn it on in Settings, then come back. | Byegones no puede mostrar tus fotos sin acceso. Actívalo en Ajustes y vuelve. | |
| permission.denied.button | Open Settings | Abrir Ajustes | Opens app settings URL |
| permission.limited.banner | You're sharing only some photos with Byegones. | Solo compartes algunas fotos con Byegones. | Top banner |
| permission.limited.button | Change selection | Cambiar selección | Presents `presentLimitedLibraryPicker` |
| permission.restricted.title | Photo access is restricted | El acceso a Fotos está restringido | Parental controls / MDM |
| permission.restricted.body | This iPhone doesn't allow Byegones to use photos. Check Screen Time or your device settings. | Este iPhone no permite que Byegones use las fotos. Revisa Tiempo en pantalla o los ajustes del dispositivo. | |
| **Swipe screen** | | | |
| swipe.stamp.keep | KEEP | GUARDAR | Stamp, uppercase |
| swipe.stamp.delete | DELETE | BORRAR | Stamp, uppercase |
| swipe.stamp.favorite | FAVORITE | FAVORITA | Stamp, uppercase |
| swipe.counter | `PLURAL` one: 1 left / other: %lld left | `PLURAL` one: Queda 1 / many, other: Quedan %lld | Top bar; not an a11y label |
| swipe.counter.a11y | `PLURAL` one: 1 item left to review / other: %lld items left to review | `PLURAL` one: Queda 1 elemento por revisar / many, other: Quedan %lld elementos por revisar | |
| swipe.trash.pill | %lld · %@ | %lld · %@ | e.g. "12 · 340 MB"; same in both languages |
| swipe.trash.pill.nosize | `PLURAL` one: 1 item / other: %lld items | `PLURAL` one: 1 elemento / many, other: %lld elementos | When size is unavailable |
| swipe.trash.pill.a11y | `PLURAL` one: Trash pile, 1 item, %@. Opens review. / other: Trash pile, %lld items, %@. Opens review. | `PLURAL` one: Pila de borrado, 1 elemento, %@. Abre la revisión. / many, other: Pila de borrado, %lld elementos, %@. Abre la revisión. | Pass the formatted size |
| swipe.button.undo.label | Undo | Deshacer | Accessibility label |
| swipe.button.undo.hint | Brings back your last decision. | Recupera tu última decisión. | Accessibility hint |
| swipe.button.delete.label | Delete | Borrar | |
| swipe.button.delete.hint | Adds this item to your trash pile. | Añade este elemento a tu pila de borrado. | Not deleted yet |
| swipe.button.favorite.label | Favorite | Favorita | |
| swipe.button.favorite.hint | Keeps this item and adds it to Favorites in Photos. | Guarda este elemento y lo añade a Favoritos en Fotos. | |
| swipe.button.keep.label | Keep | Guardar | |
| swipe.button.keep.hint | Keeps this item and moves to the next one. | Guarda este elemento y pasa al siguiente. | |
| swipe.video.mute | Mute | Silenciar | Button label when sound is on |
| swipe.video.unmute | Unmute | Activar sonido | Button label when muted |
| swipe.video.hint | Videos play muted. Tap to change sound. | Los videos empiezan en silencio. Toca para cambiar el sonido. | |
| swipe.card.a11y.photo | Photo, %@ | Foto, %@ | Arg: date |
| swipe.card.a11y.video | Video, %@, %@ | Video, %@, %@ | Args: date, duration |
| swipe.card.a11y.actions | Use the Keep, Delete or Favorite actions. | Usa las acciones Guardar, Borrar o Favorita. | Hint for VoiceOver custom actions |
| swipe.meta.date.label | Taken %@ | Tomada el %@ | Photo only; "Tomada" feminine for "foto". For videos use `swipe.meta.date.video` |
| swipe.meta.date.video | Recorded %@ | Grabado el %@ | |
| swipe.meta.size | %@ | %@ | Value only, formatted bytes; hide if unavailable |
| swipe.meta.size.a11y | Size %@ | Tamaño: %@ | |
| swipe.meta.duration.a11y | Length %@ | Duración: %@ | Value shown as m:ss |
| swipe.meta.favorite.badge.a11y | Already a favorite | Ya es favorita | If asset is already `isFavorite` |
| swipe.loading.icloud | Getting it from iCloud... | Descargando de iCloud... | iCloud-only item loading |
| **Empty / all caught up** | | | |
| empty.done.title | All caught up! | ¡Todo al día! | Whole queue reviewed |
| empty.done.body | You've been through your whole library. New photos will show up here. | Ya revisaste toda tu biblioteca. Las fotos nuevas aparecerán aquí. | |
| empty.done.review | Review trash pile | Revisar pila de borrado | Shown only if the pile is not empty |
| empty.library.title | No photos yet | Aún no hay fotos | Library empty / limited selection empty |
| empty.library.body | Take a few photos and come back. | Toma algunas fotos y vuelve. | |
| **Trash review sheet** | | | |
| trash.title | Trash pile | Pila de borrado | Sheet title |
| trash.summary | `PLURAL` one: 1 item · %@ / other: %lld items · %@ | `PLURAL` one: 1 elemento · %@ / many, other: %lld elementos · %@ | |
| trash.summary.nosize | `PLURAL` one: 1 item / other: %lld items | `PLURAL` one: 1 elemento / many, other: %lld elementos | |
| trash.hint | Tap a photo to take it out of the pile. | Toca una foto para sacarla de la pila. | |
| trash.item.a11y | Remove from pile | Sacar de la pila | Cell action label |
| trash.item.removed | Removed from pile | Sacado de la pila | Announcement |
| trash.delete.button | `PLURAL` one: Delete 1 item / other: Delete %lld items | `PLURAL` one: Borrar 1 elemento / many, other: Borrar %lld elementos | Triggers the single iOS confirmation |
| trash.delete.hint | iOS will ask you to confirm. | iOS te pedirá confirmar. | Accessibility hint |
| trash.close | Close | Cerrar | |
| trash.empty.title | Your pile is empty | Tu pila está vacía | |
| trash.empty.body | Swipe left on photos to add them here. | Desliza fotos a la izquierda para añadirlas aquí. | |
| trash.explainer.title | Where do deleted items go? | ¿A dónde van los elementos borrados? | Expandable note |
| trash.explainer.body | They move to Recently Deleted in Photos and stay there for 30 days. To get the space back right away: Photos > Albums > Recently Deleted > Select > Delete All. | Pasan a Eliminados recientemente en Fotos y se quedan ahí 30 días. Para recuperar el espacio ya: Fotos > Álbumes > Eliminados recientemente > Seleccionar > Eliminar todo. | Core accuracy string; keep |
| trash.cancelled | Nothing was deleted. Your pile is still here. | No se borró nada. Tu pila sigue aquí. | After cancelling the iOS popup |
| **Celebration** | | | |
| celebration.title | You cleared %@! | ¡Limpiaste %@! | Arg: formatted size. Not "freed" on purpose |
| celebration.title.nosize | `PLURAL` one: 1 item cleared! / other: %lld items cleared! | `PLURAL` one: ¡1 elemento limpiado! / many, other: ¡%lld elementos limpiados! | If size unavailable |
| celebration.body | Moved to Recently Deleted. Empty that album in Photos to get the space back. | Pasó a Eliminados recientemente. Vacía ese álbum en Fotos para recuperar el espacio. | |
| celebration.lifetime | Total cleared with Byegones: %@ | Total limpiado con Byegones: %@ | Arg: lifetime formatted bytes |
| celebration.continue | Keep going | Seguir | Primary |
| celebration.openphotos | Open Photos | Abrir Fotos | Optional secondary; omit to keep one CTA |
| **Settings / About** | | | |
| settings.title | Settings | Ajustes | |
| settings.done | Done | Listo | |
| settings.lifetime.label | Total cleared | Total limpiado | Row, value is formatted bytes |
| settings.reset.button | Reset progress | Reiniciar progreso | Destructive row |
| settings.reset.confirm.title | Reset progress? | ¿Reiniciar progreso? | |
| settings.reset.confirm.message | Photos you've already reviewed will show up again for review. Your trash pile and your total cleared stay as they are. Nothing is deleted from your library. | Las fotos que ya revisaste volverán a aparecer para revisarlas. Tu pila de borrado y tu total limpiado se quedan como están. No se borra nada de tu biblioteca. | Matches engineering: reset clears review history only |
| settings.reset.confirm.action | Reset | Reiniciar | Destructive |
| settings.reset.confirm.cancel | Cancel | Cancelar | |
| settings.reset.done | Progress reset. | Progreso reiniciado. | Toast / announcement |
| settings.privacy | Privacy Policy | Política de privacidad | Opens website page |
| settings.support | Support | Soporte | Opens website page |
| settings.rate | Rate Byegones | Calificar Byegones | Opens App Store review URL |
| settings.version | Version %@ (%@) | Versión %@ (%@) | Args: marketing version, build |
| settings.about.tagline | No account. No tracking. No data collected. | Sin cuenta. Sin rastreo. No recopilamos datos. | About footer |
| settings.a11y.open | Settings | Ajustes | Gear button label |
| **Errors** | | | |
| error.generic | Something went wrong. Please try again. | Algo salió mal. Inténtalo de nuevo. | |
| error.load.photo | Couldn't load this item. | No se pudo cargar este elemento. | Card error state |
| error.load.icloud | Couldn't download this item from iCloud. Check your connection and try again. | No se pudo descargar este elemento de iCloud. Revisa tu conexión e inténtalo de nuevo. | |
| error.delete.failed | Couldn't delete those items. Your pile is still here. | No se pudieron borrar esos elementos. Tu pila sigue aquí. | Not the same as cancelled |
| error.favorite.failed | Couldn't add this to Favorites. | No se pudo añadir a Favoritos. | |
| error.library.failed | Couldn't read your photo library. | No se pudo leer tu biblioteca de fotos. | |
| error.retry | Try again | Intentar de nuevo | |
| error.ok | OK | OK | |
