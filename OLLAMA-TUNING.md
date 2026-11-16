# Ollama Tuning — Guía de velocidad, gateway y errores comunes

> Copia este archivo a la raíz de cualquier proyecto que use Ollama local.
> Vale para AI-SW-Factory, chimpa-watch, local-ai-platform y cualquier repo con `model_gateway` + `04-corrida-local.ps1`.
> Última actualización: 2026-11-12. Probado en Windows PowerShell + Ollama local en `http://127.0.0.1:11434`.

---

## 1. TL;DR — Reglas de oro

1. **Para planning con JSON forzado, usa el modelo más chico que sepa JSON, no el más grande.** `qwen2.5-coder:1.5b` (986 MB) le gana a `ministral-3:3b` (3 GB) y a `gemma4:e4b` (6.6 GB) en este caso.
2. **Siempre verifica `$env:OLLAMA_HOST` antes de lanzar.** Windows puede tener un valor a nivel User/Machine que pisa tu `.env`.
3. **Nunca uses `0.0.0.0:11434` sin `http://`.** Siempre `http://127.0.0.1:11434`.
4. **El prompt casi nunca es el problema.** 21 docs = 37 KB = ~2,700 tokens. El problema suele ser `format: "json"` + `temperature: 0.0` + modelo que no sabe cerrar JSON.
5. **Si el warm-up tarda >30s y el planning hace timeout 2 veces, no es que el modelo sea lento, es que está atorado generando JSON.**

---

## 2. Configuración recomendada (`.env`)

Pega esto en tu `.env`. Borra duplicados de `OLLAMA_HOST` — que solo quede uno.

```env
# Modelo de Lenguaje (Local / Pasarela)
MODEL_PROVIDER=ollama
MODEL_ENABLED=true
OLLAMA_ENABLED=true
OLLAMA_HOST=http://127.0.0.1:11434
OLLAMA_BASE_URL=http://127.0.0.1:11434
FACTORY_MODEL_GATEWAY=http://127.0.0.1:11434
OLLAMA_MODEL=qwen2.5-coder:1.5b
OLLAMA_TIMEOUT_SECONDS=900
OLLAMA_NUM_CTX=16384
OLLAMA_NUM_PREDICT=2000
```

### Por qué estos valores

| Variable | Valor | Por qué |
|---|---|---|
| `OLLAMA_HOST` / `OLLAMA_BASE_URL` / `FACTORY_MODEL_GATEWAY` | `http://127.0.0.1:11434` | Con `http://` explícito. `0.0.0.0:11434` sin esquema rompe el warm-up. |
| `OLLAMA_MODEL` | `qwen2.5-coder:1.5b` | Default del gateway. Entrenado para JSON / código. 986 MB, calienta en ~10s. |
| `OLLAMA_TIMEOUT_SECONDS` | `900` | 15 min. 300s es muy corto para spec completa. |
| `OLLAMA_NUM_CTX` | `16384` | Ventana de contexto. Default viejo era 4096, muy corto. |
| `OLLAMA_NUM_PREDICT` | `2000` | Límite de tokens de salida. Default era 1200, a veces corta la spec. |

---

## 3. El bug de `OLLAMA_HOST` del sistema (Windows)

### Síntoma

```
$env:OLLAMA_HOST
0.0.0.0:11434

Error de corrida local: Ollama no responde en el endpoint configurado; no se inicio la TaskRun.
```

Aunque tu `.env` tenga `http://127.0.0.1:11434`, el script no lo usa.

### Causa

`Set-FactoryConfiguration` en `04-corrida-local.ps1` respeta lo que ya existe en Process:

```powershell
if ([Environment]::GetEnvironmentVariable($name, "Process")) { continue }
```

Si Windows ya tiene `OLLAMA_HOST=0.0.0.0:11434` a nivel User/Machine, esa variable gana y el `.env` se ignora.

### Diagnóstico

```powershell
[Environment]::GetEnvironmentVariable("OLLAMA_HOST", "User")
[Environment]::GetEnvironmentVariable("OLLAMA_HOST", "Machine")
$env:OLLAMA_HOST
```

### Fix permanente (una sola vez)

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "http://127.0.0.1:11434", "User")
# Si está en Machine, necesitas PowerShell como Admin:
# [Environment]::SetEnvironmentVariable("OLLAMA_HOST", "http://127.0.0.1:11434", "Machine")
```

Cierra y abre una terminal nueva. `$env:OLLAMA_HOST` ya debe salir `http://127.0.0.1:11434` solo.

### Fix por sesión (si no quieres tocar el sistema)

```powershell
$env:OLLAMA_HOST = "http://127.0.0.1:11434"
$env:OLLAMA_BASE_URL = "http://127.0.0.1:11434"
$env:FACTORY_MODEL_GATEWAY = "http://127.0.0.1:11434"
$env:OLLAMA_MODEL = "qwen2.5-coder:1.5b"
$env:OLLAMA_TIMEOUT_SECONDS = "900"
$env:OLLAMA_NUM_CTX = "16384"
$env:OLLAMA_NUM_PREDICT = "2000"
```

---

## 4. Velocidad real medida (noviembre 2026)

Misma tarea: análisis READ_ONLY de chimpa-watch (21 .md, prompt ~10,790 chars).

| Modelo | Tamaño | Warm-up carga | Warm-up generación | Warm-up total | Planning spec |
|---|---|---|---|---|---|
| `gemma4:e4b` | 6.6 GB | 34.0s | 0.96s (5 tokens) | 38.6s | Timeout a 300s, nunca terminó |
| `ministral-3:3b` | 3.0 GB | 15.5s / 7.5s | 3.8s (14 tokens) | 104-107s | Timeout a 901s (15 min), 2 intentos, nunca terminó |
| `qwen2.5-coder:1.5b` | 986 MB | 6.3s | 0.44s (5 tokens) | **10.09s** | En curso, es el único que avanza |

**Conclusión:** más grande ≠ más rápido para planning con JSON. El modelo chico entrenado para JSON gana por 10x en warm-up y no se atora.

### Otros modelos que tienes (para qué sirven)

| Modelo | Uso recomendado | No usar para |
|---|---|---|
| `qwen2.5-coder:1.5b` / `qwen2.5-coder:7b` | Planning con JSON, código, specs | Análisis narrativo largo |
| `ministral-3:3b` | Análisis de docs sin JSON forzado, resúmenes | Planning con `format: "json"` |
| `phi4-mini:latest` | Razonamiento, Q&A | JSON estricto |
| `gemma4:e4b` | Análisis profundo, inconsistencias complejas | Planning rápido, si hay timeout corto |
| `deepseek-r1:7b` | Razonamiento profundo | Cualquier cosa con timeout <10 min, genera `think` muy largo |
| `llama3.2:3b`, `qwen2.5:1.5b` | Pruebas rápidas, fallback | Planning con JSON |
| `mxbai-embed-large`, `nomic-embed-text` | Embeddings, búsqueda | **Nunca** para generar texto |

---

## 5. El verdadero cuello de botella: `format: "json"` + `temperature: 0.0`

En `src/ai_software_factory/planning/model_gateway.py`:

```python
DEFAULT_NUM_CTX = 16384
DEFAULT_NUM_PREDICT = 1200
DEFAULT_TEMPERATURE = 0.0

"format": format_schema or "json",
"stream": False,
"options": {
  "temperature": 0.0,
  "num_predict": 1200,
  "num_ctx": 16384,
}
```

- `format: "json"` obliga al modelo a devolver JSON válido.
- `temperature: 0.0` quita sampling, el modelo no puede salir de un bucle.
- `stream: False` obliga a esperar a que termine TODO antes de responder.
- Un modelo 3B que no está entrenado para JSON se queda generando JSON inválido hasta que el gateway corta por timeout.

### Cómo confirmarlo en 30 segundos

```powershell
# 1. Sin JSON -> debe responder en segundos
$body1 = @{ model="qwen2.5-coder:1.5b"; prompt="Dime en una frase que es chimpa-watch"; stream=$false } | ConvertTo-Json
Measure-Command { Invoke-RestMethod -Uri http://127.0.0.1:11434/api/generate -Method POST -Body $body1 -ContentType "application/json" -TimeoutSec 60 }

# 2. Con JSON forzado como hace el gateway -> es el que se atora con ministral/gemma
$body2 = @{ model="ministral-3:3b"; prompt="Devuelve un JSON valido con claves resumen, hallazgos, severidad"; stream=$false; format="json"; options=@{ temperature=0; num_predict=1200; num_ctx=16384 } } | ConvertTo-Json -Depth 5
Measure-Command { Invoke-RestMethod -Uri http://127.0.0.1:11434/api/generate -Method POST -Body $body2 -ContentType "application/json" -TimeoutSec 120 }
```

Si el 1 tarda 5s y el 2 tarda 120s o da timeout, el problema es el JSON, no la velocidad.

### Fixes

**Opción A (recomendada): usa `qwen2.5-coder:1.5b`** — sabe cerrar JSON.

**Opción B: relajar el gateway** — quitar el `format: "json"` duro o subir `temperature` a 0.2 para que no se atasque. Solo si necesitas usar `ministral`/`gemma` sí o sí.

---

## 6. `04-corrida-local.ps1` — lo que debe tener

### `-NoObservability`

Sin stack de observabilidad, OTEL hace retries a `4317/4318` y mete `WinError 10061` en los logs.

```powershell
.\04-corrida-local.ps1 -RepoPath C:\workspaceAgentsAI\git\chimpa-watch -AuthorizeReadOnly -NoObservability
```

### `AllowedEnvironment` debe incluir `NUM_CTX` y `NUM_PREDICT`

Si no, el `.env` los ignora y tienes que poner `$env:` a mano cada vez:

```powershell
$AllowedEnvironment = @(
    "FACTORY_MODEL_GATEWAY",
    "OLLAMA_HOST",
    "OLLAMA_BASE_URL",
    "OLLAMA_MODEL",
    "OLLAMA_TIMEOUT_SECONDS",
    "OLLAMA_NUM_CTX",
    "OLLAMA_NUM_PREDICT",
    "PYTHONUTF8",
    "PYTHONIOENCODING"
)
```

### `model_gateway.py` debe tener `OLLAMA_NUM_CTX` configurable

```python
DEFAULT_NUM_CTX = 16384

def _ollama_num_ctx() -> int:
    raw = os.environ.get("OLLAMA_NUM_CTX")
    if not raw:
        return DEFAULT_NUM_CTX
    try:
        v = int(raw)
    except ValueError:
        return DEFAULT_NUM_CTX
    return v if v > 0 else DEFAULT_NUM_CTX
```

Y en `get_model_gateway()`:
```python
return LocalModelGateway(
    base_url=_ollama_base_url(),
    model=os.environ.get("OLLAMA_MODEL") or DEFAULT_OLLAMA_MODEL,
    timeout_seconds=_ollama_timeout_seconds(),
    num_predict=_ollama_num_predict(),
    temperature=_ollama_temperature(),
    num_ctx=_ollama_num_ctx(),
)
```

---

## 7. Cómo correr una corrida limpia (checklist)

```powershell
# 1. Terminal fresca (cierra la vieja para limpiar $env: heredados)
# 2. Verificar que no hay nada heredado
$env:OLLAMA_MODEL
$env:OLLAMA_HOST
# Si sale 0.0.0.0:11434, corrige con el fix de la sección 3

# 3. Lanzar (ya lee del .env)
.\04-corrida-local.ps1 -RepoPath C:\workspaceAgentsAI\git\chimpa-watch -AuthorizeReadOnly -NoObservability

# 4. Pegar el input + END + READ ONLY
# 5. En Terminal 2 fresca, monitorear SOLO el TaskRun nuevo:
$ultimo = Get-ChildItem artifacts\local-runs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "Monitoreando: $($ultimo.Name)"
Get-Content "artifacts\local-runs\$($ultimo.Name)\local.log" -Wait -Tail 20
```

### Qué esperar

```
Warm-up: OK en ~10s (qwen) / ~100s (ministral)
TASK_RUN_STARTED | model: qwen2.5-coder:1.5b
SCOPE_CONTRACT_CREATED | allowed_operations: ["READ", "LIST"] | VALID
MODEL_REQUEST_STARTED | attempt: 1
MODEL_REQUEST_COMPLETED  <- si sale en <5 min, va bien
PLANNING_COMPLETED
Estado: EXECUTION o VERIFICATION
```

### Cuándo matar la corrida

- Si llega a 15 min en `MODEL_REQUEST_STARTED | 1` sin `COMPLETED` → va a hacer retry solo, déjalo.
- Si hace 2 intentos y ambos dan `MODEL_REQUEST_TIMEOUT` → mátalo con `Ctrl+C`, cambia a `qwen2.5-coder:1.5b`, y re-corre.
- Si sale `Ollama no responde` antes de crear TaskRun → es el bug de `OLLAMA_HOST` de la sección 3, no el modelo.

---

## 8. Terminal 2 y el error `ambiguous_active`

Si la Terminal 2 dice:

```
Estado general: ambiguous_active
TaskRun: no hay seleccion univoca desde SQLite
```

Es porque hay varios TaskRuns atorados en `active` en la DB (los que mataste con `Ctrl+C` nunca se marcaron como `BLOCKED`).

**No uses `05-monitor-local.ps1` sin elegir.** Cuando te salga `0 1 2 3`, escribe el número de la corrida nueva.

O mejor, usa el log directo y olvídate del monitor:

```powershell
$ultimo = Get-ChildItem artifacts\local-runs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content "artifacts\local-runs\$($ultimo.Name)\local.log" -Tail 40
```

---

## 9. Checklist para copiar a otro proyecto

- [ ] Copiar este MD a la raíz del nuevo proyecto como `OLLAMA-TUNING.md`.
- [ ] En `.env`, poner la sección de la sección 2, sin duplicar `OLLAMA_HOST`.
- [ ] En Windows, verificar `[Environment]::GetEnvironmentVariable("OLLAMA_HOST", "User")` no sea `0.0.0.0:11434`.
- [ ] En `04-corrida-local.ps1` o equivalente, incluir `OLLAMA_NUM_CTX` y `OLLAMA_NUM_PREDICT` en `AllowedEnvironment`.
- [ ] En `model_gateway.py` o equivalente, tener `DEFAULT_NUM_CTX = 16384` y `_ollama_num_ctx()` configurable.
- [ ] Probar warm-up con `qwen2.5-coder:1.5b` antes de la corrida completa (debe ser ~10s).
- [ ] Probar la prueba de JSON de la sección 5 antes de asumir que el modelo es lento.
