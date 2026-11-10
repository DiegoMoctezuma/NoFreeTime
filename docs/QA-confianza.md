# Validación de confianza

## Ejecutado en este entorno

- Swift 6.2.1 para Ubuntu en WSL: `swift test`, compilando el núcleo real de la app. Las pruebas se escribieron primero y fallaron contra la implementación vacía; después pasaron 9 pruebas, incluidas las variantes de teléfonos y nombres.
- El mismo núcleo y sus 9 pruebas también pasaron con modo de lenguaje Swift 5 y aislamiento predeterminado MainActor, como el target de la app.
- Análisis sintáctico de todos los archivos Swift de aplicación y pruebas con `swift-frontend -parse`.
- `git diff --check` y revisión independiente del diff.

Esto no es una compilación iOS. Windows/WSL no tienen SwiftUI, SwiftData, MessageUI ni Xcode. Las pruebas iOS existentes y las nuevas de persistencia no se ejecutaron aquí.

## Casos del núcleo

Teléfono internacional con espacios y guiones; número local ambiguo; signos de inyección y extensiones; caracteres Unicode que parecen números; nombre vacío, largo o con salto de línea; codificación de `&`, `?` y `#` en el mensaje; umbral exacto de 30 minutos; actividad futura; día vacío; día completo; omisiones y falta de registro; identificadores duplicados. Se comprueba que abrir un enlace no cambia el destinatario.

## Pendiente en macOS / iPhone

- Ejecutar todo el target de pruebas: las cuatro suites existentes, `ConfianzaTests` y `ConfianzaPersistenciaTests`.
- Migración de una instalación real anterior, conservando nombre, medicinas, rutina y registros; sin contacto hasta elegirlo. Las pruebas en memoria no validan esta migración en disco.
- Guardar contacto, cerrar y abrir app; editar y cancelar; quitar y reiniciar; datos corruptos o canal desconocido no deben habilitar acciones.
- Cargar demo y borrar todo sin conservar un contacto real. Ensayar también un fallo de almacenamiento: la hoja permanece abierta y no muestra éxito.
- Saltar la configuración opcional del familiar, volver atrás y terminar la presentación. No deben aparecer acciones nuevas en Inicio.
- Resumen con cuidados, aplicaciones y tomas: usa «actividades», nunca asume que «registradas» equivale a «tomadas».
- No enviar ni abrir servicios al revisar, cancelar o quitar contacto. Mensajes con capacidad disponible/no disponible y resultados enviado, cancelado y fallido. La aceptación por el compositor no se muestra como entrega.
- WhatsApp instalado/no instalado y sin sesión, navegador e internet no disponible; el resumen está en la URL de composición y su vista previa lo explica. Nunca decir que se entregó.
- Llamadas en iPhone y dispositivo sin telefonía: comprobar aviso si el sistema rechaza abrir la llamada.
- Letra Muy grande, VoiceOver y Reducir movimiento en el editor y las dos hojas. Revisar que se puedan alcanzar Guardar, Cancelar y Cerrar con teclado abierto.
- Al cambiar nombre, teléfono o canal de un contacto existente, la declaración de aceptación debe volver a quedar desmarcada; Guardar no se habilita hasta aceptarla otra vez.

## Revisión independiente

La revisión señaló que al editar un contacto se reutilizaba la aceptación anterior. Se corrigió para desmarcarla ante cualquier cambio. También se movió la presentación del resultado de Mensajes al cierre de su hoja para evitar competir con la animación de salida, y se amplió la prueba del adaptador para incluir un cuidado además de una toma. La interacción y persistencia siguen pendientes de ejecución iOS.

## Security check:

- Data touched: nombre y teléfono del contacto; nombre del perfil y conteos de actividades al compartir.
- Auth required: no hay cuenta ni servicio remoto nuevo; acceso local al dispositivo. La aceptación del familiar es declarada, no una verificación remota.
- Authorization enforced at: acciones explícitas de guardar, llamar, revisar y continuar al canal; el envío se confirma en Mensajes/WhatsApp.
- Secrets: ninguna clave ni token nuevo. CallMeBot no está integrado.
- Input validation: `ContactoConfianza` valida longitud y caracteres de nombre/teléfono, normaliza separadores y rechaza esquemas o extensiones; canales desconocidos deshabilitan contacto.
- Output rendering: texto nativo SwiftUI y MessageUI, sin HTML; `URLComponents` codifica el enlace al host fijo `wa.me`.
- Logs/errors: sin logs de contactos ni resúmenes; errores de almacenamiento genéricos en la interfaz.
- DB/storage rules: tres campos opcionales en Perfil; mismo contenedor SwiftData local; borrado al quitar contacto y al reemplazar perfil por demo/borrar todo. La migración en disco requiere verificación en iPhone.
- Dependencies: sin paquetes de aplicación nuevos; Foundation, SwiftUI, SwiftData y MessageUI. SwiftPM permite probar el núcleo sin descargar paquetes externos.
- Rate limiting / abuse controls: N/A; no hay endpoints ni envíos de red automáticos.
- Web risks: destino HTTPS fijo de composición, sin tokens; el teléfono y resumen pueden persistir en historial del navegador. Se informa antes de abrir y se ofrece Mensajes como alternativa.
- Prototype/security debt: avisos remotos automáticos, emparejamiento verificado y entrega no implementados; interfaz y pitch los declaran pendientes. No se simula cobertura de emergencias.
