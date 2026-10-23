# Estudio de diseño — Tiny Empire Tycoon

## 1. Qué hace que un tycoon o simulador de colección enganche

Patrones comunes en los tycoons y simuladores de colección más jugados de Roblox (sin copiar ninguno en concreto):

| Patrón | Por qué funciona | Riesgo si se abusa |
|---|---|---|
| **Primera compra gratis e inmediata** | El jugador ve resultados en los primeros 10 segundos. | — |
| **Botones físicos en el suelo** | Moverse por la parcela es parte del juego; cada botón es un objetivo visible. | Botones mal colocados = frustración. |
| **Construcción visible** | El progreso se ve en el mundo, no solo en un número. | Si todos los edificios se parecen, se pierde el «wow». |
| **Ingreso pasivo con números que suben** | Dopamina constante; recompensa también al que está inactivo. | Números enormes sin sentido. |
| **Escalones de desbloqueo** | Cada nuevo negocio o zona es un mini‑hito con nueva estética. | Muros de espera demasiado largos. |
| **Mejoras multiplicadoras** | Decisiones cortas («¿x2 o +15 %?») que se notan al momento. | Crecimiento exponencial que rompe el balance. |
| **Retos diarios y objetivos** | Razones para volver mañana y una guía clara de «qué hago ahora». | Retos que obligan a jugar horas. |
| **Prestigio/renacimiento** | Rejugabilidad cuando todo está comprado. | Reinicios obligatorios demasiado pronto. |
| **Espacio social** | Ver a otros jugadores y sus parcelas motiva y crea comunidad. | Mecánicas competitivas que perjudican a otros. |

## 2. Decisiones aplicadas

### Satisfacción visual inmediata
- El **Puesto de Limonada es gratis** y el tutorial lleva al jugador hasta su botón con un haz de luz.
- Cada compra reproduce una **animación de obra** (las piezas suben desde el suelo con rebote, polvo y destellos), destello de color en pantalla y sonido.
- Sobre cada edificio aparecen **«+$X» flotantes** cada 3 s y el contador de dinero se anima hacia su valor.
- Cada negocio tiene **5 niveles con cambios visibles** (mesas, toldos, segundo piso, extensiones, neones, molino, carrusel, grúa…), no solo un número.
- Mejoras de imperio con **efecto físico**: furgonetas, paneles solares, helicóptero, estatua dorada.

### Progresión accesible
- Ritmo diseñado y verificado con simulación (`tests/balance.luau`, jugador eficiente):

| Hito | Tiempo |
|---|---|
| Food Truck | ~1 min |
| Cafetería | ~6 min |
| Distrito Comercial (1.ª expansión) | ~8 min |
| Almacén | ~36 min |
| Zona Corporativa (2.ª expansión) | ~1 h |
| Torre Corporativa | ~3 h |
| 24 mejoras | ~7 h |
| Primera franquicia | ~6 h |

- Los negocios se desbloquean **en orden** y cada uno indica qué falta («Primero: Panadería», «Nivel de imperio 3»).
- El **objetivo de expansión** actual siempre está visible a la derecha con barra de progreso y botón de premio.
- Las **ganancias offline** recompensan volver sin castigar al que se va.
- Los **maletines de la plaza** dan dinero proporcional a TU ingreso, así son útiles tanto al principio como al final.

### Economía
- Coste de cada negocio ≈ ×7 el anterior; ingreso ≈ ×3. El tiempo de amortización crece de forma suave (12 s → ~2 h), lo que crea etapas claras.
- Subir de nivel cuesta 1,5/3,5/7/14 veces el coste base y multiplica el ingreso por 2,2/3,8/6/9: siempre hay una mejora asequible entre negocios nuevos.
- Las mejoras globales suman (no multiplican entre sí) para evitar el crecimiento descontrolado; las específicas son x2 por negocio.
- Los premios de objetivos están escalados para equivaler a unos minutos de ingreso en ese momento.

### Monetización justa
- Todo el contenido principal (negocios, niveles, mejoras, expansiones, franquicia) es **gratis**; la simulación de 40 h lo completa sin comprar nada.
- Los pases son **cosméticos** (decoración, tema) o **atajos personales** (x2). Los paquetes de efectivo escalan con tu ingreso para que siempre tengan valor, pero no afectan a nadie más.
- No hay ventajas competitivas: los maletines de la plaza recompensan a quien los recoge sin quitar nada a nadie, y nadie puede tocar parcelas ajenas.

### Social
- Plaza central como punto de encuentro con escenario y pista de baile, bancos donde sentarse, quioscos, ranking del servidor y maletines que aparecen cada 20 s.
- Las parcelas son visibles para todos y muestran el nombre del dueño y sus ingresos en la entrada.

## 3. Arquitectura

- **Servidor autoritativo**: el cliente solo envía intenciones («comprar X»); el servidor valida tipo de argumentos, propiedad, dinero y desbloqueos. Límite de 12 acciones por segundo.
- **Animaciones en el cliente**: el servidor solo etiqueta piezas (`TE_Spin`, `TE_Bob`, `TE_Slide`, `TE_Pulse`, `TE_Car`); cada cliente las anima localmente y solo cerca de la cámara → movimiento suave y sin coste de red.
- **Datos**: DataStore con bloqueo de sesión (evita que dos servidores se pisen), reintentos, autoguardado y `BindToClose`. Los recibos de compra se guardan en el perfil para garantizar la idempotencia.
- **Todo por código**: mapa, edificios e interfaz se generan con scripts, de modo que el proyecto es reproducible y fácil de ajustar desde `Config.luau`.
