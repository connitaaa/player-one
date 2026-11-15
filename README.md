# Player One — entrega de Ciencia de Datos en la Terminal Linux

**Universidad del Bío-Bío** · Integrantes: Constanza Zapata Anríquez y Antonia Muñoz Sierra.

## Estado de la entrega

Este paquete reúne el informe, bases, resultados y el script `aoe.nu` unificado. **Es una versión de revisión; todavía se necesita probar su funcionamiento en el Nushell 0.116.1 de las integrantes.** No afirmar que se cumple toda la pauta sin completar `verificaciones/` y `PENDIENTES_ANTES_DE_ENTREGAR.md`.

## Estructura

- `aoe.nu`: consultas a API, scouting, limpieza, preparación, exploración, modelo, métricas, cruce y duelo.
- `modelos/motor_logistico_70.py`: únicamente ajuste y predicción mediante scikit-learn.
- `data/raw`: respuestas JSON originales de AoE4 World.
- `data/processed`: CSV limpios, 846 partidas y conjuntos 592/254; `partidas_depuradas_entrega.csv` incluye campos exigidos pero la clasificación de civilizaciones es **provisional**.
- `resultados`: métricas originales, auditorías y tablas de exploración.
- `informe`: código fuente LaTeX, logo y PDF.
- `verificaciones/`: scripts `curl`, `jq`, GNU Parallel de ejecución pendiente.
- `respaldo`: versiones originales preservadas para comparación.

## Instalación previa en Ubuntu

Se requieren **Nushell**, el plugin **nu_plugin_polars**, **curl**, **jq**, **parallel** y Python con **scikit-learn**. El programa Python ya está en `modelos/`; el ajuste utiliza `sklearn.linear_model.LogisticRegression`.

La API requiere `User-Agent` identificable con correo de contacto. Se debe definir como variable de entorno en la terminal, sin incluir el correo personal ni el valor de esa variable en el repositorio:

```nu
$env.AOE_USER_AGENT__xx = "PlayerOne/1.0 (contacto: correo@ejemplo.cl)"
```

**Reemplazar el correo de ejemplo por uno de contacto legítimo al ejecutar; NO subirlo a GitHub.**

## Cargar el archivo único

Desde la raíz de esta carpeta, iniciar Nushell y ejecutar:

```nu
overlay use ./aoe.nu
help "aoe buscar"
```

**Ejemplos de la interfaz de consultas** (necesitan Internet, y algunos cargan caché):

```nu
aoe buscar "Starflark" --limite 3
aoe perfil 4703134
aoe top rm_solo --pais cl --n 3
aoe civs
aoe partidas 4703134 --n 5
aoe reportar 4703134
```

**Pipeline con datos guardados** (sin volver a descargar):

```nu
aoe clean
aoe preparar
aoe validar civs   # En estos datos se espera advertencia por scots y vikings
aoe explorar
aoe model
aoe evaluar
```

`aoe ejecutar` intenta las etapas anteriores exceptuando la validación de civs (que requiere resolver las categorías fuera de catálogo). **No lo uses como demostración hasta probarlo comando por comando**.

**Comandos avanzados** (API y perfiles actuales):

```nu
aoe cruce french english
aoe cruce french english --rango platinum
aoe duelo 4703134 6640305
aoe duelo 4703134 6640305 --civ1 french --civ2 english
```

En `aoe duelo`, si no se dan ambas civilizaciones se informa explícitamente que se utiliza una ventaja neutral, sin inventar una elección. Cuando hay civilizaciones, `aoe cruce` obtiene la tasa de la API y la compara con la tabla local; informa el parche proporcionado por la API.

## Validaciones independientes

Desde Bash en Ubuntu, establecer la misma variable de entorno `AOE_USER_AGENT__xx` y ejecutar:

```bash
bash verificaciones/validar_api_y_parallel.sh
```

Requiere `curl`, `jq`, `parallel`. Las llamadas a API se hacen en serie; GNU Parallel solo se utiliza para archivos JSON locales. Las salidas deberán contrastarse con `aoe perfil`, `aoe top` y `aoe cruce` y adjuntar evidencia de fechas/parches. No subir credenciales.

## Datos y modelo

846 partidas con IDs únicos; 592 entrenamiento / 254 prueba, división cronológica. Referencias guardadas: exactitud 54,72% (constante), 60,24% (Elo), 63,78% (regresión logística). Datos experimentales recopilados para una selección de 10 jugadores del ranking de Chile.

**Advertencia:** la tabla de entrega usa el campo `rating` registrado como `rating_previo`; la auditoría de continuidad dio 864 coincidencias y 12 discrepancias de 876 comparaciones. No está probado universalmente. `scots` y `vikings` no aparecen en la lista de 23 IDs del JSON de estadísticas guardado: se etiquetaron explícitamente `fuera_catalogo_api`, y el resto de clasificaciones están marcadas como provisionales. Resolverlo antes de afirmar validación completa.

## Entrega

Subir carpetas y archivos del proyecto al repositorio GitHub (no solo un ZIP), con ramas y commits de ambas integrantes. Deben estar tanto `informe/informe_player_one.tex` como `informe/informe_player_one.pdf`. Enviar URL al profesor el 26-11-2026 y preparar defensa del 01-12-2026.
