# Player One — Análisis y predicción de partidas de Age of Empires IV

**Universidad del Bío-Bío** · Integrantes: Constanza Zapata Anríquez y Antonia Muñoz Sierra.

## Descripción

Player One es un proyecto de análisis de partidas competitivas de Age of Empires IV. Integra consultas a la API de AoE4 World, obtención y depuración de datos, análisis exploratorio y comparación de métodos de predicción de victorias desde una interfaz de comandos construida en Nushell.

El módulo se ha cargado en Nushell 0.116.1. Se han probado los comandos `aoe perfil`, `aoe top`, `aoe cruce` y `aoe duelo` (con y sin civilizaciones); sus salidas se documentan en `resultados/evidencias/`. La ejecución completa del pipeline y la clasificación de algunas civilizaciones continúan sujetas a validación.

## Estructura

- `aoe.nu`: consultas a API, scouting, limpieza, preparación, exploración, modelo, métricas, cruce y duelo.
- `modelos/motor_logistico_70.py`: únicamente ajuste y predicción mediante scikit-learn.
- `data/raw`: respuestas JSON originales de AoE4 World.
- `data/processed`: CSV limpios, 846 partidas y conjuntos 592/254; `partidas_depuradas_entrega.csv` conserva campos descriptivos adicionales; la clasificación de algunas civilizaciones es **provisional**.
- `resultados`: métricas originales, auditorías y tablas de exploración.
- `informe`: código fuente LaTeX, logo y PDF.
- `verificaciones/`: script de contrastes con `curl` y `jq` y procesamiento de archivos locales con GNU Parallel; las salidas ejecutadas están en `resultados/`.
- `respaldo`: versiones originales preservadas para comparación.

## Instalación previa en Ubuntu

Se requieren **Nushell**, el plugin **nu_plugin_polars**, **curl**, **jq**, **parallel** y Python con **scikit-learn**. El programa Python ya está en `modelos/`; el ajuste utiliza `sklearn.linear_model.LogisticRegression`.

La API requiere `User-Agent` identificable con correo de contacto. Se debe definir como variable de entorno en la terminal, sin incluir el correo personal ni el valor de esa variable en el repositorio:

```nu
$env.AOE_USER_AGENT__xx = "PlayerOne/1.0 (contacto: correo@ejemplo.cl)"
```

**Reemplazar el correo de ejemplo por uno de contacto legítimo al ejecutar. No incluir credenciales ni información privada en el código.**

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

Requiere `curl`, `jq`, `parallel`. Las llamadas a API se hacen en serie; GNU Parallel solo se utiliza para archivos JSON locales. Las salidas de consulta y sus resúmenes se guardan en `resultados/verificacion_*.json`; se revisaron el ranking de tres jugadores y el cruce French–English frente a las salidas de Nushell. También existe `resultados/verificacion_parallel_ids.txt` con diez identificadores. La validación completa de reproducibilidad sigue requiriendo ejecutar el proyecto desde una copia limpia. No almacenar credenciales en archivos del proyecto.

## Datos y modelo

846 partidas con IDs únicos; 592 entrenamiento / 254 prueba, división cronológica. Referencias guardadas: exactitud 54,72% (constante), 60,24% (Elo), 63,78% (regresión logística). Datos experimentales recopilados para una selección de 10 jugadores del ranking de Chile.

**Limitación de los datos:** la tabla depurada usa el campo `rating` registrado como `rating_previo`; la auditoría de continuidad dio 864 coincidencias y 12 discrepancias de 876 comparaciones. No está probado universalmente. `scots` y `vikings` no aparecen en la lista de 23 IDs del JSON de estadísticas guardado: se etiquetaron explícitamente `fuera_catalogo_api`, y el resto de clasificaciones están marcadas como provisionales. Resolverlo antes de afirmar validación completa.
