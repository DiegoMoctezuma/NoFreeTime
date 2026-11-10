# Movimiento MiMi

El vocabulario vive en `Compartido/Movimiento.swift`: respuesta táctil (0.28 s), cambios (0.44 s), entradas (0.58 s), escalonado máximo de 225 ms. Sin paquetes ni archivos de animación externos. Las entradas no ocultan texto ni bloquean controles. Las pantallas existentes usan la navegación y hojas nativas del sistema.

Cobertura: presentación inicial, preguntas y alta, opciones/radios, botones principales/secundarios, Inicio y progreso de tomas, Calendario, medicinas y Perfil. El escáner se actualiza a 30 fps mientras está visible y activo, y queda estático con Reducir movimiento. La raíz desactiva también animaciones explícitas preexistentes cuando ese ajuste está activo.

## Comprobar en Xcode / iPhone

- Recorrer presentación, agregar manualmente y por foto, volver atrás y cancelar lectura.
- Registrar una toma, deshacer, pasar una toma y cambiar de día: no perder ni duplicar registros.
- Observar entradas, pulsaciones, progreso y cambio de tarjeta en Inicio; cambiar pestañas rápidamente.
- Activar Reducir movimiento antes de abrir y durante el escáner; suspender y reabrir la app.
- Probar VoiceOver y letra Muy grande: contenido legible desde el primer cuadro y controles alcanzables.
- Perfil con muchas medicinas y Calendario con muchas tomas: desplazamiento fluido sin entradas repetidas en cada actualización del reloj.

La revisión visual, el rendimiento en dispositivo y la compilación iOS requieren macOS/Xcode. No están verificados en el entorno Windows de esta entrega. Las comprobaciones de sintaxis en Linux no sustituyen esa validación.
