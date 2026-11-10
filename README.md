# MiMi

MiMi acompaña a personas mayores a organizar sus medicinas y cuidados con palabras claras, botones grandes y una rutina que les resulte familiar. Sin crear una cuenta.

## Qué puedes hacer

- Fotografiar una receta o una caja, revisar lo leído y confirmar cada indicación antes de guardarla.
- Recibir alarmas o recordatorios y registrar una toma desde la app, Siri o una notificación.
- Consultar Inicio, Calendario y Perfil; adaptar el tamaño de letra y usar dictado o lectura en voz alta.
- Elegir una persona de confianza durante la configuración inicial o desde Perfil. Llamarle y revisar un resumen de hoy antes de abrir Mensajes o WhatsApp para enviarlo.

El resumen familiar contiene nombre y conteos de actividades; no incluye medicinas, dosis, fotos ni diagnósticos. Una actividad sin confirmar no equivale a una actividad omitida. La persona decide qué compartir y confirma el envío en el canal elegido. **No hay avisos automáticos a familiares**, seguimiento remoto ni detección de emergencias en esta versión.

## Ramas de esta entrega

- `prueba/dispositivo`: movimiento nativo, entradas suaves, respuesta táctil y soporte de Reducir movimiento.
- `propuestas/carlos`: lo anterior más persona de confianza, resumen familiar, documentación y pruebas de las nuevas reglas.

## Abrir y probar

1. Abre `IOSLAB-9Nov.xcodeproj` en macOS con Xcode y un SDK compatible con el proyecto. El deployment target heredado es **iOS 27.0**; verifica ese ajuste y el SDK instalado antes de ejecutar. Esta entrega no cambia la versión mínima.
2. Selecciona el target `IOSLAB-9Nov`, tu equipo de firma y un dispositivo o simulador compatible. AlarmKit, cámara, voz y envío de mensajes requieren sus capacidades/permisos correspondientes; algunos comportamientos necesitan un iPhone real.
3. Ejecuta las pruebas del esquema `IOSLAB-9Nov` con Product → Test. Se incluyen las pruebas existentes y las nuevas de confianza/persistencia.
4. Para datos ficticios: usa Perfil → Cargar datos de ejemplo. En Debug también se admite el argumento `-demo`; `-enMemoria` usa almacenamiento volátil. Cargar demo o borrar todo elimina también el contacto anterior: no configures un número real para una demostración pública.

La lectura por nube ya existente necesita el consentimiento correspondiente y una configuración local basada en `Secretos.ejemplo.plist`. Nunca subas `IOSLAB-9Nov/Secretos.plist`. Las funciones de confianza no usan claves ni CallMeBot.

### Reglas que pueden probarse sin Xcode

Con Swift 6.2 o posterior, desde la raíz:

```sh
swift test
```

Swift Package Manager compila los mismos archivos de `IOSLAB-9Nov/Confianza/Core` que usa la app. Estas pruebas cubren validación de contactos, construcción de enlaces, conteos y mensajes. **No compilan la app iOS ni ejecutan SwiftData, SwiftUI, MessageUI o las pruebas existentes de esos componentes.**

## Organización

| Carpeta | Responsabilidad |
| --- | --- |
| `Modelos` | Perfil, medicamentos, planificación y registros SwiftData |
| `Pantallas` | Inicio, Calendario, Perfil y flujos de alta |
| `Compartido` | Estilo, componentes, voz y movimiento accesible |
| `IA` | OCR, lectura y revisión de propuestas |
| `Avisos` / `Intents` | AlarmKit, notificaciones y confirmaciones |
| `Confianza/Core` | Validación y resumen sin dependencias de iOS |
| `Confianza` | Guardado local, editor y composición de mensajes |

## Privacidad y alcance

El contacto se guarda como tres campos opcionales de Perfil para conservar compatibilidad con perfiles anteriores. Guardar y quitar muestran un error si falla la persistencia. No se solicita acceso a la agenda; se escribe solo el contacto elegido. Los datos permanecen sujetos a la protección y copias de seguridad del dispositivo, como el almacén SwiftData existente.

Mensajes usa el compositor del sistema. WhatsApp usa su enlace oficial de composición, solo después de revisar el texto; el destinatario y resumen pasan a WhatsApp al abrirlo y pueden quedar en el historial si se usa un navegador. MiMi no puede verificar que un mensaje haya sido entregado, ni que la persona realmente haya realizado una actividad más allá de lo que registra.

Consulta el [pitch](docs/PITCH.md), la [evaluación de CallMeBot y automatización](docs/decision-confianza.md), la [QA de movimiento](docs/QA-movimiento.md) y la [validación de confianza](docs/QA-confianza.md).
