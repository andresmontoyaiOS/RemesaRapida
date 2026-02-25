# .claude/ — Agentes e instrucciones usados para construir este proyecto

Este directorio contiene todos los prompts y skills usados con Claude Code para generar RemesaRapida.

## Estructura

```
.claude/
├── PLAN.md                    # Plan completo de implementación
├── agents/
│   ├── ios-project-creator.md # Prompt del agente que creó todos los archivos Swift
│   ├── ios-unit-tester.md     # Prompt del agente que escribió los tests
│   ├── ios-documenter.md      # Prompt del agente que generó la documentación
│   └── github-sync.md         # Prompt del agente que creó el repo en GitHub
└── skills/
    └── ios-project.md         # Skill /ios-project usado para orquestar los 3 agentes
```

## Cómo reproducir desde cero

1. Instala Claude Code: `npm install -g @anthropic-ai/claude-code`
2. Copia el skill a `~/.claude/skills/ios-project/SKILL.md`
3. En un directorio vacío, ejecuta:
   ```
   /ios-project RemesaRapida - <descripción>
   ```
4. Claude lanza 3 agentes en paralelo en tmux y construye el proyecto completo.
