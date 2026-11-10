# Persona de confianza: decisión técnica

Evaluación: 10 de noviembre de 2026. Decisión del implementador siguiendo la autorización de trabajo autónomo: no integrar CallMeBot en esta entrega. Implementar primero contacto local, llamada y resumen con envío revisado; conservar Inicio sin controles nuevos.

## Alternativas evaluadas

| Alternativa | Ventaja | Coste / límite | Decisión |
| --- | --- | --- | --- |
| CallMeBot desde el iPhone | Activación personal y petición HTTP sencilla | Credencial, teléfono y texto en query; dependencia de tercero; iOS no garantiza ejecutar al vencer el margen | No integrar |
| Servidor con programador y proveedor de mensajería | Puede evaluar vencimientos aunque la app esté cerrada | Requiere infraestructura, emparejamiento, consentimiento, autenticación, sincronización, tratamiento de datos desactualizados y operación del proveedor | Próxima etapa explícita |
| Contacto local + composición nativa | Funciona sin cuenta nueva ni claves; fácil de demostrar y revisar | El envío requiere a la persona; no alerta al familiar por sí solo | Implementado |

## Qué se verificó de CallMeBot

La [documentación del servicio](https://www.callmebot.com/blog/free-api-whatsapp-messages/) limita la API gratuita al uso personal. La activación se hace desde el WhatsApp receptor y entrega una clave. Si no llega en dos minutos, indica reintentar después de 24 horas. La petición documentada pone teléfono, texto y apikey en la URL. No se ejecutaron peticiones ni se activó un contacto real durante este trabajo.

El feedback decía que no había términos: la página actual enlaza [términos de servicio](https://www.callmebot.com/terms-of-service/) y [política de privacidad](https://www.callmebot.com/privacy-policy/). Eso corrige aquella observación. No encontré en las páginas consultadas una garantía de entrega o de tiempo de respuesta adecuada para tratar una omisión de medicación como una alerta fiable. Es una conclusión de diseño sobre lo consultado, no una auditoría del servicio.

Ni una respuesta HTTP exitosa ni abrir WhatsApp demuestran que el familiar recibió el mensaje. No se ofrecen indicadores de entrega inventados.

## Por qué un temporizador de iOS no basta

Apple explica que el sistema decide cuándo ejecutar [BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app). Un temporizador, una notificación local o el delegado que la recibe no son un programador de red remoto con ejecución garantizada al minuto elegido. La app tampoco debe asumir que descartar una notificación confirma una toma.

El compositor de [MessageUI](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller) requiere confirmación y no garantiza entrega. El enlace [Click to Chat de WhatsApp](https://faq.whatsapp.com/5913398998672934) prepara el destinatario y el texto; la persona envía desde WhatsApp. Ambos comportamientos están reflejados en la interfaz.

## Implementación entregada

- Paso opcional en la presentación y sección en Perfil; no hay que repetirlo a diario.
- Nombre, teléfono internacional y canal; el contacto acepta ser contactado. La aceptación declarada se renueva al editar.
- Validación estricta del teléfono, sin extensiones, esquemas arbitrarios o caracteres de control. No se adivina el país.
- Guardado conjunto de los tres campos en Perfil, con restauración si falla; quitar contacto y borrado total. Los perfiles anteriores comienzan sin contacto.
- Resumen de las actividades de hoy usando la misma Agenda de Inicio, con confirmadas, omitidas, sin confirmar tras 30 minutos y pendientes. El margen es informativo, no una indicación médica.
- Mensaje positivo solo si hay actividades y todas están confirmadas. Nunca afirmar «tomó todo» a partir de simples registros o silencios.
- Vista previa estática antes del envío. No expone nombres de medicamentos ni dosis. No hay tráfico de la función de confianza hasta una acción explícita de la persona.

## Ruta concreta para avisos remotos automáticos

Esta ruta está diseñada y documentada, **no implementada ni desplegada**:

1. Emparejar al familiar con una invitación de un solo uso y vencimiento corto; obtener su aceptación y verificar el canal. Guardar credenciales del proveedor en el servidor y credencial de sesión de la app en Keychain. Permitir revocar y borrar la relación.
2. Sincronizar un horizonte limitado de actividades con identificadores estables y fecha UTC. Enviar solo lo necesario para evaluar pendientes, sin recetas ni dosis. Autenticar cada operación y comprobar que pertenece a esa relación.
3. Procesar confirmaciones, omisiones, deshacer, cambios de rutina y fin de tratamiento. Cada edición debe reemplazar/cancelar la programación anterior. La operación de confirmación y el trabajador deben resolver carreras mediante transacción.
4. Un trabajador duradero comprueba el margen después de las repeticiones. Deduplicar por persona, actividad y tipo de aviso; agrupar omisiones cercanas y limitar frecuencia. Reintentos con espera creciente, caducidad y cola de errores. No enviar alertas tardías de días anteriores.
5. Separar «sin confirmar», «omitida» y «sin conexión». Una última sincronización vieja exige un mensaje de falta de información, nunca asegurar que la persona olvidó la toma.
6. Configurar el resumen positivo nocturno como opt-in. Solo enviarlo si el día completo está sincronizado, tiene actividades y todas están confirmadas. Respetar zona horaria y hora preferida; no anunciar cumplimiento al mediodía porque faltan actividades futuras por sincronizar.
7. Elegir un proveedor oficial con condiciones, privacidad, costes y confirmaciones de entrega evaluados; probar con números de demostración autorizados. Añadir métricas sin contenido privado y una vista de estado que distinga programado, aceptado por proveedor, entregado y fallido.

No se desplegó un servidor improvisado ni se solicitó una clave del familiar porque el usuario pidió evaluar CallMeBot antes de integrarlo y no dejó infraestructura ni credenciales para un servicio remoto. La versión local queda utilizable mientras se define esa siguiente etapa.
