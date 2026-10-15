# Skills de orquestación con Herdr

Dos skills que separan del `CLAUDE.md` del proyecto la forma de trabajo de esta corrida. Un orquestador Claude planifica y coordina workers Claude Code independientes en paneles de Herdr, cada uno en su propio worktree.

| Skill | Cuándo se usa |
|---|---|
| `writing-herdr-plans/` | Para escribir el plan de implementación a partir de una spec aprobada. Usa `superpowers:writing-plans` como base y le suma las decisiones, los contratos fijos, las olas con modelo por tarea, el entorno de cada worker y los encabezados fijos. |
| `executing-herdr-plans/` | Para ejecutar ese plan: preparar los worktrees, generar los paquetes, lanzar los workers, aceptar, revisar, integrar con gate, cerrar la corrida y retomarla. |

## Requisitos

Necesitan tener instalados:

- Herdr, con la integración de Claude (`herdr integration install claude`);
- los skills `herdr` y `herdr-agent-orchestration`;
- el plugin Superpowers;
- un MCP de Obsidian, si el proyecto tiene vault.

## Instalación

Para usarlos en todos los proyectos, enlazalos en tu carpeta personal de skills:

```bash
ln -s "$PWD/skills/writing-herdr-plans" ~/.claude/skills/writing-herdr-plans
ln -s "$PWD/skills/executing-herdr-plans" ~/.claude/skills/executing-herdr-plans
```

Para usarlos solo en este proyecto, enlazalos en `.claude/skills/`.

Los scripts de `executing-herdr-plans/scripts/` se ejecutan con `bash <script>`. Funcionan con el bash 3.2 de macOS.
