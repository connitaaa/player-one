# Validación técnica pendiente de ejecución en Ubuntu

El archivo `validar_api_y_parallel.sh` contiene **tres consultas seriales** (perfil, ranking y cruces) mediante `curl`, con extracción independiente mediante `jq`. Luego usa GNU Parallel exclusivamente sobre JSON locales.

**Este script no ha sido ejecutado en tu equipo ni se ha contrastado su salida con los comandos `aoe`**. Es obligatorio ejecutarlo, inspeccionar los resultados y conservar las salidas finales antes de afirmar el cumplimiento de la pauta.

Comandos de comparación en Nushell: `aoe perfil 4703134`, `aoe top rm_solo --pais cl --n 3` y `aoe cruce french english`. El ranking y las estadísticas pueden cambiar con el tiempo; registra fechas, parches y rangos.

`scots` y `vikings` aparecen en las partidas guardadas, pero no en el catálogo histórico de 23 civilizaciones de `data/raw/matchups_rm_solo.json`. Deben revisarse por parche y catálogo; `aoe validar civs` da un error explícito hasta resolverlo.
