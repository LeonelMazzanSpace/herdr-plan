# Diseño: planes Herdr agnósticos al tipo de trabajo

Fecha: 2026-10-26 · Repos: `herdr-plan` y `herdr-plan-hermes` · Skills: `writing-herdr-plans(-hermes)`, `executing-herdr-plans(-hermes)`

## Intención

Hoy `herdr-plan` asume que cada task termina en código: worktree propio, TDD, merge y gate de tests. Leonel lo quiere usar también para trabajo que no es código, con el mismo modelo de orquestación: un orquestador parte el trabajo, cada parte la hace un worker independiente en su panel de Herdr con su paquete, otro worker la revisa y el orquestador consolida un resultado. La skill pasa a estar más cerca de `superpowers:writing-plans` (un plan para cualquier trabajo), sin perder nada de lo que hoy sabe hacer con código.

Escenarios confirmados por Leonel (todos aplican):

1. Auditoría de seguridad o calidad de un repo: un worker por módulo o servicio, informe de hallazgos con severidad y evidencia, sin cambiar código.
2. Auditoría de infraestructura o cumplimiento (AWS, accesos, evidencias tipo SOC 2): un worker por área, sin tocar el entorno, hallazgos contra una lista de controles.
3. Documentación de un sistema heredado: un worker por parte del sistema, documentos de arquitectura, flujos y riesgos, con revisión cruzada de coherencia.
4. Investigación comparativa: un worker por opción, informes con el mismo formato, resumen final con recomendación.
5. Propuesta técnica y estimación para un cliente: un worker por sección, consolidación y consistencia entre secciones.
6. Plan de migración o rollout: un worker por frente (datos, infra, cutover), pasos y riesgos, sin ejecutar nada.

Un mismo plan puede mezclar tipos: por ejemplo, una auditoría en la ola 1 y los arreglos en código en la ola 2.

## Objetivos

- Un plan Herdr sirve para código, auditorías, investigación, documentación, propuestas y planes de migración.
- Lo común a todos los escenarios se escribe una sola vez: orquestador y workers, paquetes cortados del plan por encabezados fijos, olas con dependencias, modelo por task, revisor independiente, scratchpad, D-numbers, relevo al 70%, vault, ClickUp, revisión cruzada final, resumen para el usuario.
- Lo que cambia por tipo de trabajo vive en un solo lugar por tipo.
- Resultado final de un plan sin código: un `.md` o un `.html`, elegido en cada plan (decisión de Leonel).
- El cambio se aplica igual en `herdr-plan` y en `herdr-plan-hermes` (decisión de Leonel).

## No objetivos

- No se renombran las skills ni los repos (rompería los symlinks de `~/.claude/skills` y los hábitos).
- No se toca `herdr-qa-plan` (ya es la versión especializada para QA) ni `herdr-execution`.
- No se cambia el canal de Telegram de la variante Hermes, solo se le aplica el mismo cambio.
- No hay detección automática del tipo de trabajo: el plan lo declara por task.

## Anti-objetivos (sería un fracaso aunque funcione)

- **Perder know-how de código.** La confirmación de stack, T-000 con dependencias, worktrees y bases de datos por worker, TDD, scope check por diff, merge con gate completo, la task de E2E, usabilidad y animaciones, las `animations-guidelines.md`, las reglas de paralelismo (archivos disjuntos por ola, contratos antes de paralelizar) y los Red Flags de código siguen existiendo con el mismo texto. Se pueden mover de lugar, nunca resumir ni reescribir.
- **Un plan de código que se comporte distinto que hoy.** Un plan donde todas las tasks son `code` debe producir exactamente la misma corrida que hoy.
- **Llenar las skills de "si es código… si no…"** en cada párrafo, haciéndolas más difíciles de seguir para el orquestador.
- **Bajar la vara de evidencia en lo que no es código.** Un hallazgo sin evidencia verificable, o una sección de documento sin fuentes, no se acepta, igual que hoy no se acepta código sin Verify verde.

## Diseño

### 1. Tipo de task (`Kind`)

Cada task declara su tipo en la línea de encabezado, como primer campo:

```markdown
**Kind:** findings · **Model:** sonnet · **Depends on:** T-000 · **Parallel with:** T-002 · **Contracts:** Findings format, Severity scale · **Vault:** none
```

Tres tipos, definidos por lo que entrega el worker:

| Kind | Qué entrega | Escenarios |
|---|---|---|
| `code` | Cambios en un repo, en su rama y worktree | Implementación, arreglos que salen de una auditoría |
| `findings` | Afirmaciones sobre algo que ya existe, cada una con evidencia verificable (archivo:línea, comando y salida, URL, captura) | 1, 2 |
| `document` | Contenido escrito (una sección, un informe comparativo, un plan de pasos), con sus fuentes citadas | 3, 4, 5, 6 |

Si una task no tiene `Kind`, es `code`. Así los planes existentes siguen funcionando sin cambios.

Por qué tres y no más: la diferencia que importa para orquestar es cómo se verifica el resultado. Código se verifica corriendo cosas; hallazgos se verifican re-reproduciendo cada uno; documentos se verifican contra sus fuentes y contra las otras partes. Investigación comparativa y plan de migración son documentos con fuentes; no necesitan un tipo propio.

### 2. Qué define cada tipo

| Aspecto | `code` | `findings` | `document` |
|---|---|---|---|
| Espacio de trabajo | Worktree y rama propios (hoy) | Ninguno de escritura: lee las fuentes que el paquete lista | Ninguno de escritura en el repo |
| Dónde escribe | Su worktree + su informe | Solo su informe en el report dir | Su parte en `<report-dir>/parts/T-0NN.md` + su informe |
| Modo de permisos sugerido | Modo de escritura aprobado (hoy) | `dontAsk` con allowlist de lectura y escritura solo bajo el report dir | Igual que `findings` |
| Pasos de la task | TDD (hoy) | Relevar, verificar cada hallazgo, escribir en el formato del contrato, autochequeo | Leer fuentes, escribir según el esquema, citar, autochequeo |
| Verify del worker | Comandos de test, lint, build | Comandos concretos de autochequeo del formato (por ejemplo, que todo hallazgo tenga los campos de evidencia) | Comandos concretos de autochequeo (secciones del esquema presentes, cada afirmación con fuente) |
| Scope check del orquestador | Diff contra la merge-base (hoy) | Las fuentes quedaron intactas (`git status --porcelain` vacío si son un repo) y el worker escribió solo en el report dir | Igual que `findings`, más que la parte respeta el esquema |
| Revisor | Revisión de código (hoy) | Re-verifica cada hallazgo Critical/Important y una muestra de los Minor; veredicto por hallazgo: confirmado, no reproducido, inexacto | Contrasta la parte con sus fuentes y con las partes ya integradas; marca afirmaciones sin fuente y contradicciones |
| Integración | Merge `--no-ff` + gate completo (hoy) | El orquestador incorpora los hallazgos confirmados al entregable y corre el gate del plan | El orquestador incorpora la parte al entregable y corre el gate del plan |
| Gate | Lint, test, e2e, build (hoy) | Los comandos de chequeo que el plan escribe (IDs únicos, campos completos, enlaces de evidencia existentes) | Los comandos de chequeo del plan (esquema completo, enlaces internos, sin partes faltantes) |

Los hallazgos no reproducidos no se borran: pasan a una sección de falsos positivos corregidos, como en `herdr-qa-plan`.

**Veredicto del revisor y ronda de arreglo** (se mantienen `APPROVED` / `CHANGES_REQUIRED`, `fix-round-template.md` y la escalada de un modelo arriba):

- `findings`: cada hallazgo recibe confirmado, no reproducido o inexacto. Un no reproducido lo mueve el orquestador a falsos positivos, sin ronda de arreglo. `CHANGES_REQUIRED` cuando hay hallazgos sin los campos de evidencia, áreas del alcance de la task sin cubrir, o hallazgos Critical/Important inexactos (severidad o descripción equivocada).
- `document`: `CHANGES_REQUIRED` cuando hay afirmaciones Critical/Important sin fuente, contradicciones con partes ya integradas o secciones del esquema faltantes. Lo Minor queda como notas.
- Muestra de Minor: todos los Critical e Important, y de los Minor el 20% o al menos 3, lo que sea mayor (todos si hay menos de 3).

**Fuentes intactas.** En T-000 el orquestador guarda una línea base (`git status --porcelain` y el commit de cada repo fuente). El scope check compara contra esa línea base, no contra "vacío", porque el propio orquestador escribe el plan y el scratchpad en el mismo repo.

### 3. Entregable

- Todo plan con tasks `findings` o `document` declara su entregable en una decisión `to confirm`: ruta, formato (`md` o `html`) y si se commitea. La opción propuesta es `<COORDINATION_ROOT>/deliverables/<run-id>/`, con su evidencia en `evidence/` dentro de esa carpeta (para que se comparta entera y los enlaces no se rompan), commiteada por el orquestador en la rama de coordinación. Cuando la evidencia es sensible (salidas de cuentas reales, datos de clientes), la alternativa es la misma estructura fuera del repo, sin commitear. El usuario lo decide en la parada inicial.
- **Integración parte por parte.** Al aceptar una task `findings` o `document`, el orquestador copia su parte (y su evidencia) a `deliverables/<run-id>/parts/` y corre el gate del plan sobre el conjunto de partes. Eso es `integrated`. La task de consolidación arma el documento final a partir de esas partes.
- **IDs de hallazgos** con el prefijo de su task (`T-003-F01`), así ningún worker necesita coordinar numeración con otro.
- El `.md` es siempre la fuente. Si el formato es `html`, se genera a partir del `.md` como un único archivo autocontenido (CSS en línea, sin scripts, sin red), y nunca se edita a mano: se corrige el `.md` y se vuelve a generar.
- Lo arma una task de **consolidación** en la última ola (tipo `document`): junta las partes y los hallazgos confirmados, escribe el resumen ejecutivo y, si corresponde, la recomendación. Pasa por revisor como cualquier task.
- Un plan solo de código no tiene entregable de este tipo; su resultado sigue siendo la rama integrada.

### 4. Estructura del plan (writing-herdr-plans)

Se mantienen los encabezados fijos y su orden, porque son el contrato con `make-package.sh`. Cambia lo siguiente:

- **Encabezado (writing-plans).** El campo `Tech Stack` es para planes con código. Un plan sin código usa `Sources and tools`: qué se lee (repos, cuentas, documentos, URLs), con qué acceso y con qué herramientas. Un plan mixto tiene los dos.
- **T-000** sigue siendo del orquestador, pero su contenido depende de los tipos que haya en el plan:
  - con código: lo de hoy (dependencias, scripts, aislamiento de tests, gate verde);
  - con `findings` o `document`: crear el report dir y `parts/`, verificar que cada fuente es accesible en modo lectura (por ejemplo, un `aws sts get-caller-identity` con el perfil de solo lectura, o un `git status` limpio del repo a auditar), y verificar las herramientas que las tasks nombran.
- **Contratos.** El mecanismo no cambia (secciones `##` que cada task lista). Se suman contratos tipo, que el plan escribe cuando los necesita: `Findings format`, `Severity scale`, `Control list` (auditorías de cumplimiento), `Document outline`, `Style guide`, `Sources`, `Comparison criteria` (investigación).
- **Worker environment.** Sigue siendo obligatorio. Para tipos sin código dice qué fuentes puede leer, con qué credenciales (solo nombres de variables o perfiles), dónde escribe, si tiene acceso a la red y qué no puede tocar.
- **Pasos de cada task.** Las tasks `code` siguen el template de writing-plans con TDD. Las tasks `findings` y `document` siguen un template propio con pasos concretos y un paso final de **Verify** con comandos reales de autochequeo. La regla de "sin placeholders" de writing-plans aplica igual.
- **Planes mixtos.** Las tasks de código que dependen de hallazgos que todavía no existen se reservan como lugares (`### Tasks T-0NN … T-0MM: Reserved for fixes from <task>`). Después de la ola de `findings`, el orquestador escribe cada task completa en el plan con el mecanismo actual de "New task IDs" (con su Files, criterios y Verify, y un D-number), y recién entonces se empaqueta. La confirmación de stack de esas tasks ocurre cuando se escriben, si nombran algo que la confirmación inicial no cubrió.
- **Tasks especiales.** La task de E2E, usabilidad y animaciones aplica solo a planes con UI (hoy ya es así). La revisión cruzada final aplica a todos los planes: en código revisa la rama integrada; en `findings` y `document` revisa el entregable consolidado (coherencia, contradicciones, afirmaciones sin fuente).
- **Decisiones que cambian el alcance**, además de las de hoy: acceso a producción o a cuentas reales, uso de credenciales, acceso a la red de los workers y la audiencia del entregable. Esas van `to confirm` hasta que el usuario las responda.
- **Self-review.** Se suman chequeos por tipo: cada task tiene `Kind` válido o es `code`; toda task `findings` lista `Findings format` y `Severity scale`; toda task `document` lista `Document outline`; hay una task de consolidación si hay tasks sin código; el entregable tiene formato decidido.

### 5. Ejecución (executing-herdr-plans)

- **Preflight, paso 4 (la única parada inicial).** Para planes con código: la confirmación de stack de hoy, sin cambios. Para tasks sin código: una confirmación de **alcance y acceso**, en el mismo mensaje y con la misma forma de tabla: fuentes, acceso de solo lectura y credenciales por nombre, acceso a red, contratos de formato, entregable y formato, qué queda afuera. Un plan mixto muestra las dos tablas en un solo mensaje.
- **Preparar cada task.** `code`: worktree, `.env`, bases, install (hoy). `findings` y `document`: nada que crear salvo la carpeta del report dir; el panel arranca con `--cwd` en la raíz de las fuentes (lectura) o en el report dir.
- **Lanzamiento.** Igual que hoy, con el modo de permisos según el tipo (tabla de la sección 2). El modo de escritura para `code` sigue siendo una decisión aprobada por el usuario.
- **Aceptación.** El paso 1 (estado asentado e informe PASS en archivo) es común. Los pasos de scope, re-ejecución de Verify, revisor e integración salen de la tabla de la sección 2.
- **Estados.** Se mantienen los mismos nombres (`dispatched`, `in review`, `integrated`, `verified`, `blocked`). Para tipos sin código, `integrated` significa incorporado al entregable y `verified` significa gate del plan verde. Así ClickUp y el scratchpad no cambian.
- **Cierre.** Revisión cruzada, consolidación y generación del entregable (`md` o `html`), sync del vault y de ClickUp, y entrega al usuario de la ruta absoluta del entregable. La verificación final de E2E, usabilidad y animaciones queda para planes con UI, como hoy.
- **Relevo al 70%.** Sin cambios. La entrada de hand-off suma, para tipos sin código, el estado del entregable (partes integradas y faltantes).
- **Scripts.**
  - `make-package.sh` recibe `--kind code|findings|document` (por defecto lo lee del encabezado de la task; si no hay, `code`). Para `findings` y `document`, `--worktree`, `--branch`, `--base` y `--coord-branch` dejan de ser obligatorios y el paquete cambia sus líneas de rol, objetivo, git, archivos permitidos y salida. Para `code`, el paquete generado es idéntico al de hoy.
  - `make-review-package.sh` recibe `--kind`. Para `code` produce el mismo paquete que hoy. Para `findings` y `document` produce la checklist de revisión de la sección 2, sin diff de git.

### 6. Dónde vive cada cosa

Para no llenar los `SKILL.md` de condicionales y para cuidar el contexto del orquestador (relevante para el relevo al 70%):

- Cada `SKILL.md` queda con el núcleo común y una tabla corta "qué cambia por tipo" que apunta a un archivo por tipo.
- Archivos nuevos por tipo, que se leen solo si el plan tiene ese tipo:
  - `writing-herdr-plans/kinds/code.md`: el texto de hoy sobre T-000, worktrees, DB, archivos disjuntos, contratos de código, E2E/usabilidad/animaciones y sus chequeos de self-review, movido sin reescribir.
  - `writing-herdr-plans/kinds/findings.md` y `kinds/document.md`: template de task, contratos tipo con ejemplos y chequeos de self-review.
  - `executing-herdr-plans/kinds/code.md`: confirmación de stack, preparación de worktrees, aceptación, merge, gate y sus filas de fallas, movido sin reescribir.
  - `executing-herdr-plans/kinds/findings.md` y `kinds/document.md`: preparación, aceptación, revisión, integración y gate.
- `animations-guidelines.md` y las plantillas actuales no cambian de lugar.
- La variante Hermes recibe la misma estructura; lo de Telegram no se toca. El evento `done` de Telegram incluye la ruta del entregable.
- Los README de ambos repos explican los tres tipos y el entregable.

## Decisiones que tomé yo (a revisar)

- **Tres tipos** (`code`, `findings`, `document`) en vez de uno por escenario, y la regla de que una task sin `Kind` es `code`.
- **Los nombres de las skills no cambian**; sí sus descripciones, para que se carguen también ante pedidos de auditoría, documentación o investigación.
- **Reverificación de hallazgos:** todos los Critical e Important, y una muestra de los Minor, como en `herdr-qa-plan`.
- **El `.md` es la fuente** y el `.html` se genera a partir de él.
- **Archivos por tipo** en `kinds/`, moviendo el texto de código sin reescribirlo, en vez de agregar condicionales en los `SKILL.md`.
- **Los workers sin código no escriben en el repo** y corren en `dontAsk` con allowlist, como el modo research de `herdr-execution`.
- **Dónde vive el entregable** es una decisión `to confirm` por plan: carpeta del proyecto commiteada (propuesta) o fuera del repo sin commitear cuando la evidencia es sensible.
- **Integración parte por parte** con gate en cada aceptación, y la consolidación al final arma el documento.
- **IDs de hallazgos con prefijo de task.**
- **Planes mixtos** con lugares reservados que el orquestador completa después de la auditoría.
- **Veredictos, muestra de Minor y línea base de fuentes** como dice la sección 2.
- En tasks sin código, `--worktree`, `--branch`, `--base` y `--coord-branch` no se usan, y las partes comunes que hoy nombran worktrees (cierre, hand-off) los mencionan solo para tasks `code`.

Diseño aprobado por Leonel el 2026-10-26.

## Lo que queda para quien lo implemente

- La redacción exacta de los templates de task `findings` y `document` y de los contratos tipo.
- Cómo se genera el `.html` desde el `.md` (un script en `scripts/` o instrucciones a la task de consolidación), respetando: autocontenido, sin red, sin edición a mano.
- La allowlist exacta de herramientas de los workers sin código, verificada contra `claude --help`.
- Las pruebas: generar un paquete `code` con el script nuevo y compararlo byte a byte con el de hoy; generar paquetes `findings` y `document` a partir de un plan de ejemplo.
