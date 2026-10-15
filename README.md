# Skills de orquestación con Herdr

Dos skills para Claude Code que separan del `CLAUDE.md` del proyecto la forma de trabajo de una corrida orquestada. Un orquestador Claude planifica y coordina workers Claude Code independientes en paneles de Herdr, cada uno en su propio worktree de git.

| Skill | Cuándo se usa |
|---|---|
| [`writing-herdr-plans/`](writing-herdr-plans/SKILL.md) | Para escribir el plan de implementación a partir de una spec aprobada. Usa `superpowers:writing-plans` como base y le suma las decisiones, los contratos fijos, las olas con modelo por tarea, el entorno de cada worker y los encabezados fijos. |
| [`executing-herdr-plans/`](executing-herdr-plans/SKILL.md) | Para ejecutar ese plan: confirmar el stack, preparar los worktrees, generar los paquetes, lanzar los workers, aceptar, revisar, integrar con gate, cerrar la corrida y retomarla. |

Se usan juntos: el primero escribe el plan con encabezados fijos y el segundo los usa para cortar el paquete de cada worker.

## Flujo

1. **Planificar** (`writing-herdr-plans`): del spec aprobado sale el plan con decisiones, contratos, olas y una tarea por worker, más un resumen en el idioma del usuario.
2. **Confirmar el stack** (`executing-herdr-plans`, preflight): antes de crear nada, el orquestador lee el repo y el plan y te muestra una tabla de librerías y arquitectura (ORM, base de datos, migraciones, auth, frontend, tests, CI, estructura). Marca conflictos entre repo y plan, decisiones que faltan y librerías que una tarea usa y T-000 no instala. Vos confirmás o corregís; es la única parada inicial.
3. **Ejecutar solo**: el orquestador corre el plan ola por ola. Cada tarea la implementa un worker, la revisa otro y se integra con un gate completo después de cada merge.
4. **Verificar y cerrar**: en los planes con interfaz hay un paso final de E2E, usabilidad y animaciones, una review transversal, la sincronización del vault y del tablero, y el resumen para el usuario.

## Qué incluye cada skill

```
writing-herdr-plans/
├── SKILL.md                          Reglas del plan, modelo por tarea, self-review
├── orchestration-section-template.md Secciones Orchestration y Worker environment
└── animations-guidelines.md          Guía de animaciones (sección "Animation guidelines" del plan)

executing-herdr-plans/
├── SKILL.md                          Preflight, loop de olas, aceptación, cierre, reanudación
├── scratchpad-template.md            Plantilla de SCRATCHPAD.md
├── fix-round-template.md             Plantilla de las rondas de fix
└── scripts/
    ├── make-package.sh               Paquete de un worker, cortado del plan
    └── make-review-package.sh        Paquete del reviewer (solo lectura)
```

### Confirmación de stack

Es el paso 4 del preflight de `executing-herdr-plans`. Cada fila de la tabla tiene un estado:

| Estado | Significado |
|---|---|
| `confirmed` | El repo y el plan coinciden, o solo uno lo nombra y el otro no lo contradice. |
| `conflict` | El repo y el plan, o el plan y los defaults de la empresa, no coinciden (por ejemplo el repo usa Prisma y el plan dice TypeORM). |
| `undecided` | Una tarea lo necesita y nadie lo nombró. |
| `redundant` | El repo tiene dos librerías para el mismo trabajo. |

Solo se pregunta por `conflict`, `undecided` y `redundant`, con una recomendación y un tradeoff de una línea. Lo confirmado queda como decisión `approved` en el plan y en el scratchpad. Si tu respuesta cambia el plan, se revisa antes de empezar.

### E2E, usabilidad y animaciones

En los planes con interfaz, `writing-herdr-plans` agrega una tarea después de la última feature. Solo escribe tests e informe, nunca toca el código de la app:

- E2E funcional de los flujos críticos de cada rol, en desktop y en mobile con touch;
- tareas de usabilidad por rol con criterios medibles (pasos máximos, feedback visible, estados vacío, carga y error, foco por teclado, targets táctiles de al menos 44px, sin scroll horizontal a 360px);
- auditoría de movimiento contra [`animations-guidelines.md`](writing-herdr-plans/animations-guidelines.md): duraciones, easings permitidos, hover solo en dispositivos con hover, `prefers-reduced-motion`, animaciones que nacen del disparador, solo `transform` y `opacity`;
- capturas y un informe de hallazgos. Los Critical e Important pasan a tareas de fix; las mejoras de diseño quedan como propuestas.

El plan copia la guía como sección `## Animation guidelines` y la lista en los Contracts de cada tarea de UI.

## Requisitos

- Herdr, con la integración de Claude (`herdr integration install claude`), y el orquestador corriendo dentro de un panel (`HERDR_ENV=1`);
- Claude Code;
- los skills `herdr` y `herdr-agent-orchestration`;
- el plugin Superpowers (`superpowers:writing-plans`, `verification-before-completion`, `receiving-code-review`, `systematic-debugging`);
- bash. Los scripts funcionan con el bash 3.2 de macOS;
- opcionales:
  - un MCP de Obsidian, si el proyecto tiene vault;
  - el MCP de ClickUp, si el plan espeja el avance en un tablero (un worker `clickup` crea y edita las tareas).

### Setup

1. Herdr y Claude Code instalados. Verificá con `herdr --version` y `claude --version`.
2. Integración de Herdr con Claude Code:

   ```bash
   herdr integration install claude
   herdr integration status      # debe mostrar: claude: current
   ```

3. Skills de Herdr:

   ```bash
   npx skills add herdrdev/herdr --skill herdr -g
   npx skills add aerain/herdr-agent-orchestration -g -s herdr-agent-orchestration -a claude-code
   ```

4. Superpowers, dentro de Claude Code:

   ```
   /plugin install superpowers@claude-plugins-official
   ```

## Instalación

Cloná el repo y enlazá cada skill en tu carpeta personal de skills, desde la raíz del repo:

```bash
ln -s "$PWD/writing-herdr-plans" ~/.claude/skills/writing-herdr-plans
ln -s "$PWD/executing-herdr-plans" ~/.claude/skills/executing-herdr-plans
```

Para usarlos solo en un proyecto, enlazalos en la carpeta `.claude/skills/` de ese proyecto.

Los scripts de `executing-herdr-plans/scripts/` se ejecutan con `bash <script>`, nunca por su ruta directa.

## Uso

- Pedí "armá el plan para ejecutarlo con herdr" a partir de un spec aprobado y se usa `writing-herdr-plans`.
- Pedí "ejecutá el plan", "status" o "continuá" y se usa `executing-herdr-plans`. Retoma desde `SCRATCHPAD.md`.

Las decisiones que cambian el alcance, las acciones destructivas o sensibles y los push, PR o merges a ramas compartidas siempre pasan por vos. El resto lo decide el orquestador y lo registra como decisión numerada.
