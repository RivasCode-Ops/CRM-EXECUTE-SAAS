# Commands

Casos de uso de escrita (criar processo, alterar status, etc.).

Cada comando deve:

1. Validar entrada
2. Gravar em `event_store` via `appendEvent`
3. Atualizar projeções em `projections/`
