# Movimiento y persona de confianza

**Objetivo:** entregar primero movimiento accesible en `prueba/dispositivo` y después una propuesta familiar en `propuestas/carlos`, con commits y push separados.

**Ejecución:** autónoma, solicitada por el usuario. Reutilizar el checkout limpio existente; SwiftUI y frameworks nativos, sin dependencias de aplicación nuevas.

## Entrega 1: movimiento

- [x] Crear un vocabulario común de resortes, entradas breves y cambios de estado. Aplicarlo a botones, selección, preguntas, Inicio, Calendario, Perfil y alta de medicinas.
- [x] Respetar Reducir movimiento incluso en las animaciones preexistentes; detener el barrido del escáner al salir o suspenderse.
- [x] Revisar diff y sintaxis, documentar QA en iPhone pendiente por falta de Xcode, commit y push a `prueba/dispositivo`.

## Entrega 2: confianza

- [x] Evaluar documentación oficial de CallMeBot, privacidad, términos y ejecución en segundo plano de iOS antes de decidir integración.
- [x] Configuración opcional por un familiar, persistencia local y borrado; contacto telefónico y resumen mínimo con envío confirmado por la persona. Sin agregar controles a Inicio.
- [x] Separar tomas confirmadas, omitidas, sin confirmar y futuras. Nunca convertir «registradas» en «tomadas» ni diagnosticar una omisión a partir del silencio.
- [x] Pruebas de reglas y persistencia; README, pitch y decisión técnica con ruta concreta para avisos remotos fiables. Núcleo ejecutado; persistencia iOS pendiente de Xcode.
- [x] Revisión independiente, verificaciones disponibles, commit y push a `propuestas/carlos`.

## Riesgos que revisar

Reducir movimiento activado durante un efecto; cancelación del escáner; letra de accesibilidad; días vacíos, futuros o con omisiones; números inválidos y esquemas URL; guardar o borrar fallido; demo que reutilice un contacto real; cancelación del envío; app suspendida.

## Alcance de validación

Windows no ofrece Xcode, SwiftUI ni simulador. La compilación iOS y la revisión visual en dispositivo deben quedar explícitamente pendientes. Intentar ejecutar las reglas puras con Swift en Linux; no presentar comprobaciones de texto como pruebas funcionales.
