#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${AOE_USER_AGENT__xx:?Define AOE_USER_AGENT__xx como PlayerOne/1.0 (correo de contacto)}"
mkdir -p resultados
# Las tres consultas siguientes son SECUENCIALES (no paralelas).
# Guardar respuesta original y resumen con jq, para compararla a mano con aoe.nu.
curl --fail --silent --show-error --retry 2 -H "User-Agent: $AOE_USER_AGENT__xx" \
    'https://aoe4world.com/api/v0/players/4703134' \
    -o resultados/verificacion_perfil_api.json
jq '{profile_id,name,country,rm_solo:.modes.rm_solo}' resultados/verificacion_perfil_api.json \
    > resultados/verificacion_perfil_jq.json

curl --fail --silent --show-error --retry 2 -H "User-Agent: $AOE_USER_AGENT__xx" \
    'https://aoe4world.com/api/v0/leaderboards/rm_solo?country=cl&page=1' \
    -o resultados/verificacion_top_api.json
jq '{total_count,page,primeros:(.players[0:3]|map({profile_id,name,rating}))}' \
    resultados/verificacion_top_api.json > resultados/verificacion_top_jq.json

curl --fail --silent --show-error --retry 2 -H "User-Agent: $AOE_USER_AGENT__xx" \
    'https://aoe4world.com/api/v0/stats/rm_solo/matchups' \
    -o resultados/verificacion_cruces_api.json
jq '{patch,rank_level,french_english:(.data|map(select(.civilization=="french" and .other_civilization=="english"))|first)}' \
    resultados/verificacion_cruces_api.json > resultados/verificacion_cruces_jq.json

# GNU Parallel procesa exclusivamente JSON descargados y guardados en el disco.
find data/raw -maxdepth 1 -type f -name 'scout_*.json' ! -name '*_p*.json' -print0 \
  | parallel -0 --jobs 2 'jq -r .profile_id "{}"' \
  > resultados/verificacion_parallel_ids.txt

echo 'Listo: inspecciona resultados/verificacion_*.json y compáralos con aoe perfil/top/cruce.'
