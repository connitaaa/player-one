
# ==========================================
# PLAYER ONE - AGE OF EMPIRES IV
# Nushell 0.116.1
# Consultas, scouting, limpieza, exploracion y modelacion
# ==========================================

# CONSULTAS A LA API CON CACHE

def consultar_api__xx [
    url__xx: string
    ruta_cache__xx: string
    vigencia__xx: duration
] {
    if ($ruta_cache__xx | path exists) {
        let modificado__xx = (
            ls $ruta_cache__xx | get 0.modified
        )

        let edad__xx = (
            (date now) - $modificado__xx
        )

        if $edad__xx < $vigencia__xx {
            return (open $ruta_cache__xx)
        }
    }

    let agente__xx = (
        $env
        | get -o AOE_USER_AGENT__xx
        | default ""
    )

    if ($agente__xx | is-empty) {
        error make {
            msg: "Debes configurar AOE_USER_AGENT__xx antes de consultar la API."
        }
    }

    mut reintentos__xx = 0

    loop {
        let respuesta__xx = (
            http get --full --allow-errors --max-time 20sec
                --headers {'User-Agent': $agente__xx}
                $url__xx
        )

        if $respuesta__xx.status == 200 {
            $respuesta__xx.body
            | save -f $ruta_cache__xx

            return $respuesta__xx.body
        }

        if ($respuesta__xx.status == 429) and ($reintentos__xx < 3) {
            $reintentos__xx = $reintentos__xx + 1

            print $"API ocupada (HTTP 429). Reintento ($reintentos__xx) de 3."

            sleep (2sec * $reintentos__xx)
        } else {
            error make {
                msg: $"La API devolvio HTTP ($respuesta__xx.status) al consultar ($url__xx)."
            }
        }
    }
}


# ==========================================
# COMANDO 1: BUSCAR JUGADORES
# ==========================================

export def "aoe buscar" [
    texto__xx: string
    --limite (-n): int
] {
    let texto_limpio__xx = (
        $texto__xx | str trim
    )

    let limite_real__xx = (
        $limite | default 10
    )

    if ($texto_limpio__xx | is-empty) {
        error make {
            msg: "El texto de busqueda no puede estar vacio."
        }
    }

    if ($limite_real__xx < 1) or ($limite_real__xx > 200) {
        error make {
            msg: "El limite debe estar entre 1 y 200."
        }
    }

    let clave__xx = (
        $texto_limpio__xx | url encode
    )

    mut pagina__xx = 1
    mut jugadores__xx = []

    loop {
        let url__xx = $"https://aoe4world.com/api/v0/players/search?query=($clave__xx)&page=($pagina__xx)"

        let ruta__xx = if $pagina__xx == 1 {
            $"data/cache/busqueda_($clave__xx).json"
        } else {
            $"data/cache/busqueda_($clave__xx)_pagina_($pagina__xx).json"
        }

        let datos__xx = (
            consultar_api__xx $url__xx $ruta__xx 1hr
        )

        let encontrados__xx = (
            $datos__xx
            | get -o players
            | default []
        )

        $jugadores__xx = (
            $jugadores__xx ++ $encontrados__xx
        )

        let siguiente__xx = (
            $datos__xx | get -o next_page
        )

        if (($jugadores__xx | length) >= $limite_real__xx) or ($siguiente__xx == null) {
            break
        }

        $pagina__xx = $siguiente__xx
    }

    if ($jugadores__xx | is-empty) {
        print "No se encontraron jugadores."
        return []
    }

    $jugadores__xx
    | first $limite_real__xx
    | select profile_id name country
}


# ==========================================
# COMANDO 2: PERFIL DE JUGADOR
# ==========================================

export def "aoe perfil" [
    profile_id__xx: int
] {
    if $profile_id__xx <= 0 {
        error make {
            msg: "El profile_id debe ser positivo."
        }
    }

    let url__xx = $"https://aoe4world.com/api/v0/players/($profile_id__xx)"

    let ruta__xx = $"data/cache/perfil_($profile_id__xx).json"

    let perfil__xx = (
        consultar_api__xx $url__xx $ruta__xx 1hr
    )

    let modos__xx = (
        $perfil__xx | get -o modes
    )

    if $modos__xx == null {
        error make {
            msg: "El perfil no contiene modalidades."
        }
    }

    let tabla__xx = (
        $modos__xx
        | columns
        | each {|modo__xx|
            let datos__xx = (
                $modos__xx | get -o $modo__xx
            )

            if $datos__xx == null {
                null
            } else {
                let texto_fecha__xx = (
                    $datos__xx | get -o last_game_at
                )

                let fecha__xx = if ($texto_fecha__xx == null) or ($texto_fecha__xx == "") {
                    null
                } else {
                    $texto_fecha__xx | into datetime
                }

                let dias__xx = if $fecha__xx == null {
                    null
                } else {
                    ((date now) - $fecha__xx) // 1day
                }

                {
                    modalidad: $modo__xx
                    rating: ($datos__xx | get -o rating)
                    max_rating: ($datos__xx | get -o max_rating)
                    liga: ($datos__xx | get -o rank_level)
                    racha: ($datos__xx | get -o streak)
                    ganadas: ($datos__xx | get -o wins_count)
                    perdidas: ($datos__xx | get -o losses_count)
                    porcentaje_victorias: ($datos__xx | get -o win_rate)
                    ultimo_juego: $fecha__xx
                    dias_inactivo: $dias__xx
                }
            }
        }
        | compact
    )

    print $"Jugador: ($perfil__xx.name)"
    print $"Profile ID: ($perfil__xx.profile_id)"
    print $"Pais: ($perfil__xx.country)"

    $tabla__xx
}


# ==========================================
# COMANDO 3: RANKING
# ==========================================

export def "aoe top" [
    modalidad__xx: string
    --pais (-p): string
    --n: int
] {
    let cantidad__xx = (
        $n | default 10
    )

    if ($cantidad__xx < 1) or ($cantidad__xx > 50) {
        error make {
            msg: "La cantidad debe estar entre 1 y 50."
        }
    }

    let modalidad_limpia__xx = (
        $modalidad__xx
        | str trim
        | str lowercase
    )

    let modalidad_api__xx = if $modalidad_limpia__xx == "rm_1v1" {
        print "Aviso: el ranking rm_1v1 redirige a rm_solo. Se usara rm_solo."
        "rm_solo"
    } else {
        $modalidad_limpia__xx
    }

    if ($modalidad_api__xx | is-empty) {
        error make {
            msg: "Debes indicar una modalidad."
        }
    }

    let pais_real__xx = (
        $pais
        | default ""
        | str trim
        | str lowercase
    )

    if ($pais_real__xx != "") and ($pais_real__xx !~ '^[a-z]{2}$') {
        error make {
            msg: "El pais debe ser un codigo ISO de dos letras, como cl."
        }
    }

    let base__xx = $"https://aoe4world.com/api/v0/leaderboards/($modalidad_api__xx)"

    let url__xx = if $pais_real__xx == "" {
        $base__xx
    } else {
        $"($base__xx)?country=($pais_real__xx)"
    }

    let ruta__xx = if $pais_real__xx == "" {
        $"data/cache/top_($modalidad_api__xx)_global.json"
    } else {
        $"data/cache/top_($modalidad_api__xx)_($pais_real__xx).json"
    }

    let datos__xx = (
        consultar_api__xx $url__xx $ruta__xx 1hr
    )

    let jugadores__xx = (
        $datos__xx
        | get -o players
        | default []
    )

    if ($jugadores__xx | is-empty) {
        print "No se encontraron jugadores en ese ranking."
        return []
    }

    $jugadores__xx
    | first $cantidad__xx
    | each {|jugador__xx|
        {
            posicion: ($jugador__xx | get -o rank)
            profile_id: ($jugador__xx | get -o profile_id)
            nombre: ($jugador__xx | get -o name)
            rating: ($jugador__xx | get -o rating)
            liga: ($jugador__xx | get -o rank_level)
            tasa_victorias: ($jugador__xx | get -o win_rate)
        }
    }
}

# ==========================================
# COMANDO 4: ESTADISTICAS DE CIVILIZACIONES
# ==========================================

export def "aoe civs" [
    --rango (-r): string
] {

    # Normalizar el rango de liga
    let rango_real__xx = (
        $rango
        | default ""
        | str trim
        | str lowercase
    )

    # Validar el rango ingresado
    if ($rango_real__xx != "") and ($rango_real__xx !~ '^[a-z0-9_]+$') {
        error make {
            msg: "El rango contiene caracteres no permitidos."
        }
    }

    # Construir la URL de la API
    let base__xx = "https://aoe4world.com/api/v0/stats/rm_solo/civilizations"

    let url__xx = if $rango_real__xx == "" {
        $base__xx
    } else {
        $"($base__xx)?rank_level=($rango_real__xx)"
    }

    # Definir el archivo de cache
    let ruta__xx = if $rango_real__xx == "" {
        "data/cache/civs_rm_solo.json"
    } else {
        $"data/cache/civs_($rango_real__xx).json"
    }

    # Consultar la API con cache de 12 horas
    let datos__xx = (
        consultar_api__xx $url__xx $ruta__xx 12hr
    )

    # Obtener las civilizaciones
    let civilizaciones__xx = (
        $datos__xx
        | get -o data
        | default []
    )

    if ($civilizaciones__xx | is-empty) {
        print "No se encontraron estadisticas para este rango."
        return []
    }

    # Fecha de obtencion o almacenamiento
    let fecha_archivo__xx = (
        ls $ruta__xx | get 0.modified
    )

    let fecha_texto__xx = (
        $fecha_archivo__xx
        | format date "%Y-%m-%d %H:%M:%S %z"
    )

    # Construir la tabla de resultados
    let tabla__xx = (
        $civilizaciones__xx
        | each {|civilizacion__xx|

            let mediana_seg__xx = (
                $civilizacion__xx
                | get -o duration_median
            )

            # Convertir segundos a minutos
            let mediana_min__xx = if $mediana_seg__xx == null {
                null
            } else {
                (
                    ($mediana_seg__xx / 60)
                    | math round --precision 2
                )
            }

            {
                civilizacion: ($civilizacion__xx | get -o civilization)
                tasa_victorias: ($civilizacion__xx | get -o win_rate)
                porcentaje_eleccion: ($civilizacion__xx | get -o pick_rate)
                duracion_mediana_min: $mediana_min__xx
            }
        }
        | sort-by tasa_victorias --reverse
    )

    # Mostrar informacion de la consulta
    print "========================================"
    print "PLAYER ONE - CIVILIZACIONES"
    print "========================================"

    print $"Modalidad: ($datos__xx.leaderboard)"
    print $"Rango: ($datos__xx.rank_level)"
    print $"Rating: ($datos__xx.rating)"
    print $"Patch: ($datos__xx.patch)"
    print $"Fecha del archivo: ($fecha_texto__xx)"
    print $"Civilizaciones encontradas: ($tabla__xx | length)"

    print "========================================"

    # Devolver la tabla
    $tabla__xx
}

# ==========================================
# COMANDO 5: HISTORIAL DE PARTIDAS
# ==========================================

export def "aoe partidas" [
    profile_id__xx: int
    --modo (-m): string
    --civ (-c): string
    --n: int
] {
    # Validar los parametros
    if $profile_id__xx <= 0 {
        error make {
            msg: "El profile_id debe ser positivo."
        }
    }

    let cantidad__xx = ($n | default 10)
    let modo_real__xx = (
        $modo | default "rm_solo" | str trim | str lowercase
    )
    let civ_real__xx = (
        $civ | default "" | str trim | str lowercase
    )

    if ($cantidad__xx < 1) or ($cantidad__xx > 100) {
        error make {
            msg: "La cantidad debe estar entre 1 y 100."
        }
    }

    if $modo_real__xx not-in ["rm_solo" "rm_1v1"] {
        error make {
            msg: "Este comando admite rm_solo o rm_1v1."
        }
    }

    mut pagina__xx = 1
    mut filas__xx = []

    # Consultas seriales, con un maximo de 5 paginas
    loop {
        if $pagina__xx > 5 {
            break
        }

        let url__xx = $"https://aoe4world.com/api/v0/players/($profile_id__xx)/games?leaderboard=($modo_real__xx)&limit=50&page=($pagina__xx)"

        let ruta__xx = $"data/cache/partidas_($profile_id__xx)_($modo_real__xx)_p($pagina__xx).json"

        let datos__xx = (
            consultar_api__xx $url__xx $ruta__xx 1hr
        )

        let partidas__xx = (
            $datos__xx | get -o games | default []
        )

        for partida__xx in $partidas__xx {

            # Excluir partidas en curso
            if ($partida__xx | get -o ongoing) != false {
                continue
            }

            # Conservar solamente enfrentamientos 1v1
            if ($partida__xx | get -o kind) != "rm_1v1" {
                continue
            }

            # Obtener los jugadores de ambos equipos
            let equipos__xx = (
                $partida__xx | get -o teams | default []
            )

            let jugadores__xx = (
                $equipos__xx
                | flatten
                | each {|entrada__xx|
                    $entrada__xx | get -o player
                }
                | compact
            )

            if ($jugadores__xx | length) != 2 {
                continue
            }

            # Identificar al jugador mediante profile_id
            let propios__xx = (
                $jugadores__xx
                | where {|jugador__xx|
                    ($jugador__xx | get -o profile_id) == $profile_id__xx
                }
            )

            let rivales__xx = (
                $jugadores__xx
                | where {|jugador__xx|
                    ($jugador__xx | get -o profile_id) != $profile_id__xx
                }
            )

            if ($propios__xx | is-empty) or ($rivales__xx | is-empty) {
                continue
            }

            let propio__xx = ($propios__xx | first)
            let rival__xx = ($rivales__xx | first)

            # Filtrar por civilizacion propia
            let civilizacion__xx = (
                $propio__xx | get -o civilization | default ""
            )

            if ($civ_real__xx != "") and (($civilizacion__xx | str lowercase) != $civ_real__xx) {
                continue
            }

            # Convertir duracion de segundos a minutos
            let segundos__xx = (
                $partida__xx | get -o duration
            )

            let minutos__xx = if $segundos__xx == null {
                null
            } else {
                ($segundos__xx / 60) | math round --precision 2
            }

            # Convertir fecha de inicio a datetime
            let texto_fecha__xx = (
                $partida__xx | get -o started_at
            )

            let fecha__xx = if $texto_fecha__xx == null {
                null
            } else {
                $texto_fecha__xx | into datetime
            }

            # Construir un registro por partida
            let fila__xx = {
                game_id: ($partida__xx | get -o game_id)
                fecha_inicio: $fecha__xx
                duracion_min: $minutos__xx
                mapa: ($partida__xx | get -o map)
                civ_propia: ($propio__xx | get -o civilization)
                civ_rival: ($rival__xx | get -o civilization)
                resultado: ($propio__xx | get -o result)
                rating_propio: ($propio__xx | get -o rating)
                rating_rival: ($rival__xx | get -o rating)
                rating_diff: ($propio__xx | get -o rating_diff)
            }

            $filas__xx = ($filas__xx | append $fila__xx)

            if ($filas__xx | length) >= $cantidad__xx {
                break
            }
        }

        if ($filas__xx | length) >= $cantidad__xx {
            break
        }

        # Continuar solamente si existe otra pagina
        let siguiente__xx = (
            $datos__xx | get -o next_page
        )

        if $siguiente__xx == null {
            break
        }

        $pagina__xx = $siguiente__xx
    }

    if ($filas__xx | is-empty) {
        print "No se encontraron partidas que cumplan los filtros."
        return []
    }

    $filas__xx | first $cantidad__xx
}

# ==========================================
# COMANDO 6: REPORTAR UN JUGADOR
# ==========================================

export def "aoe reportar" [
    profile_id__xx: int
] {

    # Validar el identificador
    if $profile_id__xx <= 0 {
        error make {
            msg: "El profile_id debe ser positivo."
        }
    }

    # Consultar el perfil mediante el cache
    let url__xx = $"https://aoe4world.com/api/v0/players/($profile_id__xx)"

    let ruta__xx = $"data/cache/perfil_($profile_id__xx).json"

    let perfil__xx = (
        consultar_api__xx $url__xx $ruta__xx 1hr
    )

    # Obtener estadisticas de rm_solo
    let datos__xx = (
        $perfil__xx | get -o modes.rm_solo
    )

    if $datos__xx == null {
        error make {
            msg: "El jugador no tiene estadisticas en rm_solo."
        }
    }

    # Recuperar rating y porcentaje de victorias
    let rating__xx = (
        $datos__xx | get -o rating
    )

    let porcentaje__xx = (
        $datos__xx | get -o win_rate
    )

    # Preparar los textos, incluyendo valores faltantes
    let rating_texto__xx = if $rating__xx == null {
        "sin datos"
    } else {
        $rating__xx | into string
    }

    let porcentaje_texto__xx = if $porcentaje__xx == null {
        "sin datos"
    } else {
        $porcentaje__xx | into string
    }

    # Construir el cuerpo JSON
    let cuerpo__xx = {
        title: $perfil__xx.name
        body: $"Rating rm_solo: ($rating_texto__xx); porcentaje de victorias: ($porcentaje_texto__xx)%."
        userId: $profile_id__xx
    }

    # URL del servicio de pruebas
    let url_post__xx = "https://jsonplaceholder.typicode.com/posts"

    # Enviar la solicitud POST
    let respuesta__xx = (
        try {
            http post --full --allow-errors --max-time 20sec --content-type application/json $url_post__xx $cuerpo__xx
        } catch {|error__xx|
            error make {
                msg: $"No fue posible enviar el reporte: ($error__xx.msg)"
            }
        }
    )

    # Mostrar el codigo HTTP
    print $"Codigo HTTP: ($respuesta__xx.status)"

    # Detectar respuestas HTTP de error
    if ($respuesta__xx.status < 200) or ($respuesta__xx.status >= 300) {
        print $respuesta__xx.body

        error make {
            msg: $"El servicio devolvio HTTP ($respuesta__xx.status)."
        }
    }

    # Mostrar la respuesta del servicio
    print "Respuesta del servicio:"

    $respuesta__xx.body
}

# ==========================================
# PIPELINE - ETAPA 1: OBTENCION DE DATOS
# ==========================================

export def "aoe scout" [
    --pais: string
    --n: int
    --modo: string
    --dias-activo: int
    --max-paginas: int
    --max-consultas: int
    --meses: int
    --min-partidas: int
    --max-partidas: int
] {

    # 1. Parametros
    let pais_real__xx = (
        $pais | default "" | str trim | str lowercase
    )
    let n_real__xx = ($n | default 10)
    let modo_real__xx = ($modo | default "rm_solo")
    let dias_real__xx = ($dias_activo | default 90)
    let paginas_real__xx = ($max_paginas | default 5)
    let consultas_real__xx = ($max_consultas | default 250)
    let meses_real__xx = ($meses | default 3)
    let minimo_real__xx = ($min_partidas | default 20)
    let maximo_real__xx = ($max_partidas | default 200)

    if $pais_real__xx !~ '^[a-z]{2}$' {
        error make {
            msg: "Indica un pais ISO, por ejemplo --pais cl."
        }
    }

    if $modo_real__xx not-in ["rm_solo" "rm_1v1"] {
        error make {
            msg: "La modalidad debe ser rm_solo o rm_1v1."
        }
    }

    if (
        $n_real__xx < 1 or
        $dias_real__xx < 1 or
        $paginas_real__xx < 1 or
        $consultas_real__xx < 2 or
        $meses_real__xx < 1 or
        $minimo_real__xx < 1 or
        $maximo_real__xx < $minimo_real__xx
    ) {
        error make {
            msg: "Revisa los limites numericos del comando."
        }
    }

    # Tres meses se aproximan a 90 dias.
    
let ahora__xx = (date now)
let corte_activo__xx = ($ahora__xx - (1day * $dias_real__xx))
let corte_juegos__xx = ($ahora__xx - (30day * $meses_real__xx))


    if $corte_juegos__xx > $corte_activo__xx {
        error make {
            msg: "El periodo de partidas debe cubrir los dias de actividad."
        }
    }

    let desde__xx = (
        $corte_juegos__xx
        | format date "%+"
        | url encode
    )

    # 2. Contadores
    mut consultas_usadas__xx = 0
    mut revisados__xx = 0
    mut activos__xx = 0
    mut inactivos__xx = 0
    mut insuficientes__xx = 0
    mut descargadas__xx = 0
    mut seleccionados__xx = []
    mut detener__xx = false

    # 3. Estadisticas de cruces: una consulta
    let url_cruces__xx = "https://aoe4world.com/api/v0/stats/rm_solo/matchups"
    let ruta_cruces__xx = "data/cache/matchups_rm_solo.json"

    let cruces__xx = (
        consultar_api__xx $url_cruces__xx $ruta_cruces__xx 12hr
    )

    $consultas_usadas__xx = $consultas_usadas__xx + 1

    $cruces__xx | save -f data/raw/matchups_rm_solo.json

    let registro_cruces__xx = {
        patch: ($cruces__xx | get -o patch)
        fecha_cache: (ls $ruta_cruces__xx | get 0.modified)
    }

    $registro_cruces__xx
    | save -f resultados/scout_matchups_info.json

    # 4. Recorrer el ranking de forma serial
    for pagina__xx in 1..$paginas_real__xx {

        if $consultas_usadas__xx >= $consultas_real__xx {
            break
        }

        if ($seleccionados__xx | length) >= $n_real__xx {
            break
        }

        let url_rank__xx = $"https://aoe4world.com/api/v0/leaderboards/rm_solo?country=($pais_real__xx)&page=($pagina__xx)"

        let ruta_rank__xx = if $pagina__xx == 1 {
            $"data/cache/top_rm_solo_($pais_real__xx).json"
        } else {
            $"data/cache/scout_ranking_($pais_real__xx)_p($pagina__xx).json"
        }

        let ranking__xx = (
            consultar_api__xx $url_rank__xx $ruta_rank__xx 1hr
        )

        $consultas_usadas__xx = $consultas_usadas__xx + 1

        let jugadores__xx = (
            $ranking__xx | get -o players | default []
        )

        for jugador__xx in $jugadores__xx {

            if ($seleccionados__xx | length) >= $n_real__xx {
                break
            }

            if $consultas_usadas__xx >= $consultas_real__xx {
                $detener__xx = true
                break
            }

            $revisados__xx = $revisados__xx + 1

            let ultima__xx = (
                $jugador__xx | get -o last_game_at
            )

            if $ultima__xx == null {
                $inactivos__xx = $inactivos__xx + 1
                continue
            }

            let fecha_ultima__xx = (
                $ultima__xx | into datetime
            )

            if $fecha_ultima__xx < $corte_activo__xx {
                $inactivos__xx = $inactivos__xx + 1
                continue
            }

            $activos__xx = $activos__xx + 1

            let id__xx = ($jugador__xx.profile_id)

            mut pagina_juegos__xx = 1
            mut juegos_todos__xx = []
            mut juegos_validos__xx = []

            # 5. Descargar historial del jugador
            loop {

                if $consultas_usadas__xx >= $consultas_real__xx {
                    $detener__xx = true
                    break
                }

                let url_juegos__xx = $"https://aoe4world.com/api/v0/players/($id__xx)/games?leaderboard=($modo_real__xx)&limit=50&page=($pagina_juegos__xx)&since=($desde__xx)"

                let ruta_juegos__xx = $"data/cache/scout_($id__xx)_($modo_real__xx)_p($pagina_juegos__xx).json"

                let respuesta__xx = (
                    consultar_api__xx $url_juegos__xx $ruta_juegos__xx 1hr
                )

                $consultas_usadas__xx = $consultas_usadas__xx + 1

                let lote__xx = (
                    $respuesta__xx | get -o games | default []
                )

                $descargadas__xx = $descargadas__xx + ($lote__xx | length)

                $juegos_todos__xx = (
                    $juegos_todos__xx ++ $lote__xx
                )

                # Verificar fecha, estado y tipo de partida
                let validos_lote__xx = (
                    $lote__xx
                    | where ongoing == false
                    | where kind == "rm_1v1"
                    | where {|partida__xx|
                        let inicio__xx = (
                            $partida__xx | get -o started_at
                        )

                        if $inicio__xx == null {
                            false
                        } else {
                            ($inicio__xx | into datetime) >= $corte_juegos__xx
                        }
                    }
                )

                $juegos_validos__xx = (
                    $juegos_validos__xx ++ $validos_lote__xx
                )

                if ($juegos_validos__xx | length) >= $maximo_real__xx {
                    break
                }

                let siguiente__xx = (
                    $respuesta__xx | get -o next_page
                )

                if $siguiente__xx == null {
                    break
                }

                $pagina_juegos__xx = $siguiente__xx
            }

            # 6. Verificar minimo de partidas
            let cantidad_validas__xx = (
                $juegos_validos__xx | length
            )

            if $cantidad_validas__xx < $minimo_real__xx {
                $insuficientes__xx = $insuficientes__xx + 1
                continue
            }

            # Conservar como maximo las mas recientes
            let juegos_finales__xx = (
                $juegos_validos__xx
                | sort-by started_at --reverse
                | first $maximo_real__xx
            )

            # Guardar JSON del jugador
            let registro__xx = {
                profile_id: $id__xx
                nombre: ($jugador__xx.name)
                modo: $modo_real__xx
                fecha_descarga: (date now)
                inicio_periodo: $corte_juegos__xx
                
            }

            let archivo__xx = $"data/raw/scout_($id__xx).json"

            
$registro__xx
| upsert games $juegos_finales__xx
| to json
| save -f $archivo__xx


            $seleccionados__xx = (
                $seleccionados__xx
                | append {
                    profile_id: $id__xx
                    nombre: ($jugador__xx.name)
                    rating: ($jugador__xx.rating)
                    partidas_validas: ($juegos_finales__xx | length)
                    archivo: $archivo__xx
                }
            )

            print $"Seleccionado: ($jugador__xx.name) - ($cantidad_validas__xx) partidas validas."
        }

        if $detener__xx {
            break
        }

        if ($ranking__xx | get -o next_page) == null {
            break
        }
    }

    # 7. Resumen de obtencion
    let resumen__xx = {
        pais: $pais_real__xx
        modo: $modo_real__xx
        fecha_ejecucion: (date now)
        inicio_periodo: $corte_juegos__xx
        objetivo_jugadores: $n_real__xx
        jugadores_revisados: $revisados__xx
        jugadores_activos: $activos__xx
        omitidos_inactivos: $inactivos__xx
        omitidos_pocas_partidas: $insuficientes__xx
        jugadores_seleccionados: ($seleccionados__xx | length)
        partidas_descargadas: $descargadas__xx
        consultas_contabilizadas: $consultas_usadas__xx
        limite_consultas: $consultas_real__xx
        limite_alcanzado: $detener__xx
        jugadores: $seleccionados__xx
    }

    $resumen__xx | save -f resultados/scout_resumen.json

    $resumen__xx
}

# ==========================================
# PIPELINE - LIMPIEZA REPRODUCIBLE
# ==========================================

export def "aoe clean" [] {

    # 1. Leer la base aplanada
    let archivo__xx = "resultados/partidas_aplanadas.csv"

    if not ($archivo__xx | path exists) {
        error make {
            msg: "No se encontro el CSV aplanado."
        }
    }

    let original__xx = (open $archivo__xx)

    let n_original__xx = ($original__xx | length)

    # 2. Conservar partidas terminadas,
    # individuales y con resultado valido
  let validas__xx = (
        $original__xx
        | where {|fila__xx| $fila__xx.resultado in ["win" "loss"]}
        | where {|fila__xx| ($fila__xx.ongoing | into string | str lowercase) == "false"}
        | where {|fila__xx| $fila__xx.kind == "rm_1v1"}
    )

    let n_validas__xx = ($validas__xx | length)

    # 3. Priorizar al menor profile_id
    let ordenadas__xx = (
        $validas__xx
        | sort-by {|fila__xx|
            $fila__xx.profile_id | into int
        }
    )

    let limpias__xx = (
        $ordenadas__xx
        | uniq-by game_id
    )

    let n_limpias__xx = ($limpias__xx | length)

    # 4. Conservar solo ratings completos
    # para la muestra candidata de modelacion
    let completas__xx = (
        $limpias__xx
        | where {|fila__xx|

            let r1__xx = (
                $fila__xx.rating
                | default ""
                | into string
                | str trim
            )

            let r2__xx = (
                $fila__xx.rating_rival
                | default ""
                | into string
                | str trim
            )

            ($r1__xx != "") and ($r2__xx != "")
        }
    )

    # 5. Preparar variables del modelo
    let modelo__xx = (
        $completas__xx
        | each {|fila__xx|

            let r1__xx = (
                $fila__xx.rating | into float
            )

            let r2__xx = (
                $fila__xx.rating_rival | into float
            )

            let duracion__xx = (
                ($fila__xx.duracion_seg | into float) / 60
                | math round --precision 2
            )

            {
                game_id: ($fila__xx.game_id | into int)
                profile_id: ($fila__xx.profile_id | into int)
                rival_id: ($fila__xx.rival_id | into int)
                fecha_inicio: $fila__xx.fecha_inicio
                mapa: $fila__xx.mapa
                civ: $fila__xx.civ
                civ_rival: $fila__xx.civ_rival
                duracion_min: $duracion__xx
                rating_observado: $r1__xx
                rating_rival_observado: $r2__xx
                diferencia_rating_observada: ($r1__xx - $r2__xx)
                resultado: $fila__xx.resultado
                victoria: (
                    if $fila__xx.resultado == "win" {
                        1
                    } else {
                        0
                    }
                )
            }
        }
    )

    # 6. Comprobar integridad
    let n_modelo__xx = ($modelo__xx | length)

    let ids_unicos__xx = (
        $modelo__xx
        | get game_id
        | uniq
        | length
    )

    if $n_modelo__xx != $ids_unicos__xx {
        error make {
            msg: "Hay partidas duplicadas en el modelo."
        }
    }

    let duraciones_invalidas__xx = (
        $modelo__xx
        | where duracion_min <= 0
        | length
    )

    if $duraciones_invalidas__xx > 0 {
        error make {
            msg: "Se encontraron duraciones no positivas."
        }
    }

    # 7. Guardar archivos procesados
    $limpias__xx
    | to csv
    | save -f data/processed/partidas_limpias.csv

    $modelo__xx
    | to csv
    | save -f data/processed/partidas_modelo_reproducible.csv

    # 8. Construir resumen
    let resumen__xx = {
        fecha_ejecucion: (date now | format date "%+")
        registros_originales: $n_original__xx
        excluidos_estado_tipo_resultado: ($n_original__xx - $n_validas__xx)
        duplicados_eliminados: ($n_validas__xx - $n_limpias__xx)
        registros_limpios: $n_limpias__xx
        excluidos_modelo_sin_ratings: ($n_limpias__xx - $n_modelo__xx)
        registros_modelacion: $n_modelo__xx
        partidas_unicas_modelo: $ids_unicos__xx
        duraciones_invalidas: $duraciones_invalidas__xx
    }

    $resumen__xx
    | to json
    | save -f resultados/clean_resumen.json

    $resumen__xx
}



# ======================================================
# COMANDOS INTEGRADOS DE PLAYER ONE (VERSION DE ENTREGA)
# Esta seccion consolida los comandos que antes estaban
# separados. Requiere ejecucion y prueba en Nushell 0.116.1.
# ======================================================

# Permite consultar el cruce de civilizaciones con la API
# y compararlo con las partidas depuradas de este equipo.
export def "aoe cruce" [
    civ1: string
    civ2: string
    --rango: string = ""
] {
    let liga = ($rango | str trim | str lowercase)
    if ($liga != "") and ($liga !~ '^[a-z0-9_]+$') {
        error make {msg: "El rango contiene caracteres no validos."}
    }

    let url_base = "https://aoe4world.com/api/v0/stats/rm_solo/matchups"
    let url = if $liga == "" {
        $url_base
    } else {
        $"($url_base)?rank_level=($liga)"
    }
    let cache = if $liga == "" {
        "data/cache/matchups_rm_solo.json"
    } else {
        $"data/cache/matchups_($liga).json"
    }

    let consulta = (consultar_api__xx $url $cache 12hr)
    let coincidencias = ($consulta | get -o data | default []
        | where {|fila| $fila.civilization == $civ1 and $fila.other_civilization == $civ2})
    if ($coincidencias | is-empty) {
        error make {msg: $"No hay estadistica de API para ($civ1) vs ($civ2) en ese rango. No se inventa una tasa."}
    }
    let dato = ($coincidencias | first)
    let bruto = ($dato.win_rate | into float)
    let p_api = if $bruto > 1 { $bruto / 100.0 } else { $bruto }

    let archivo = "data/processed/partidas_depuradas_entrega.csv"
    if not ($archivo | path exists) {
        error make {msg: "Falta la tabla depurada. Ejecuta aoe preparar."}
    }
    let muestra = (open $archivo
        | where {|fila| $fila.civ == $civ1 and $fila.civ_rival == $civ2})
    let n = ($muestra | length)
    let victorias = ($muestra | where resultado == "win" | length)
    let p_muestra = if $n == 0 { null } else { ($victorias / $n) }

    {
        civilizacion: $civ1
        civilizacion_rival: $civ2
        rango_solicitado: (if $liga == "" {"todos"} else {$liga})
        rango_api: ($consulta | get -o rank_level)
        parche_api: ($consulta | get -o patch)
        fecha_consulta: (date now | format date "%+")
        probabilidad_api: $p_api
        partidas_muestra: $n
        victorias_muestra: $victorias
        probabilidad_empirica: $p_muestra
        diferencia_api_muestra: (if $p_muestra == null {null} else {$p_muestra - $p_api})
    }
}

# Solo recibe como argumentos obligatorios DOS identificadores
# de perfil. Las civilizaciones son opcionales; si no se indican,
# la ventaja de cruce se fija en 0.5 y esto se informa.
export def "aoe duelo" [
    profile_id1: int
    profile_id2: int
    --civ1: string = ""
    --civ2: string = ""
    --rango: string = ""
] {
    if ($profile_id1 <= 0) or ($profile_id2 <= 0) or ($profile_id1 == $profile_id2) {
        error make {msg: "Indica dos profile_id positivos y distintos."}
    }
    let perfil1 = (consultar_api__xx
        $"https://aoe4world.com/api/v0/players/($profile_id1)"
        $"data/cache/perfil_($profile_id1).json" 1hr)
    let perfil2 = (consultar_api__xx
        $"https://aoe4world.com/api/v0/players/($profile_id2)"
        $"data/cache/perfil_($profile_id2).json" 1hr)
    let rating1 = ($perfil1 | get -o modes.rm_solo.rating)
    let rating2 = ($perfil2 | get -o modes.rm_solo.rating)
    if ($rating1 == null) or ($rating2 == null) {
        error make {msg: "Uno de los perfiles no tiene rating actual en rm_solo."}
    }
    if (($civ1 == "") and ($civ2 != "")) or (($civ2 == "") and ($civ1 != "")) {
        error make {msg: "Indica ambas civilizaciones o ninguna."}
    }

    let coef = (open resultados/coeficientes_logistica_846.json)
    let d = (($rating1 | into float) - ($rating2 | into float))
    let cruce = if ($civ1 == "") {
        {probabilidad_api: 0.5, parche_api: null, rango_api: null}
    } else {
        (aoe cruce $civ1 $civ2 --rango $rango)
    }
    let pcruce = ($cruce.probabilidad_api | into float)
    let intercepto = ($coef.intercepto | into float)
    let b1 = ($coef.coeficientes | get 0 | into float)
    let b2 = ($coef.coeficientes | get 1 | into float)
    let z = ($intercepto + $b1 * ($d / 100.0) + $b2 * (10.0 * ($pcruce - 0.5)))
    let p_logit = (1.0 / (1.0 + ((0.0 - $z) | math exp)))
    let expo_elo = (((0.0 - $d) / 400.0) * 2.302585092994046)
    let p_elo = (1.0 / (1.0 + ($expo_elo | math exp)))

    {
        profile_id1: $profile_id1
        jugador1: ($perfil1 | get -o name)
        rating1: ($rating1 | into float)
        profile_id2: $profile_id2
        jugador2: ($perfil2 | get -o name)
        rating2: ($rating2 | into float)
        civilizacion1: (if $civ1 == "" {"no especificada"} else {$civ1})
        civilizacion2: (if $civ2 == "" {"no especificada"} else {$civ2})
        fuente_ventaja: (if $civ1 == "" {"neutral por ausencia de civs"} else {"API AoE4 World"})
        parche_api: $cruce.parche_api
        diferencia_rating: $d
        probabilidad_elo_j1: $p_elo
        probabilidad_logistica_j1: $p_logit
        probabilidad_elo_j2: (1.0 - $p_elo)
        probabilidad_logistica_j2: (1.0 - $p_logit)
        diferencia_logistica_elo_j1: ($p_logit - $p_elo)
    }
}

# Reproduce la tabla depurada y los dos subconjuntos del modelo
# con Nushell a partir del CSV limpio y el JSON local de la API.
# No vuelve a consultar ni cambia las estadisticas historicas.
export def "aoe preparar" [] {
    let limpio = "data/processed/partidas_limpias.csv"
    let matchup = "data/raw/matchups_rm_solo.json"
    if not ($limpio | path exists) or not ($matchup | path exists) {
        error make {msg: "Faltan partidas_limpias.csv o matchups_rm_solo.json."}
    }
    let cruces = (open $matchup | get data)
    let catalogo = ($cruces | get civilization | uniq)
    let variantes = ["ayyubids" "jeanne_darc" "zhu_xis_legacy" "order_of_the_dragon" "house_of_lancaster" "jin_dynasty" "knights_templar" "sengoku_daimyo" "golden_horde" "tughlaq_dynasty" "macedonian_dynasty"]
    let base = (open $limpio)
    let completas = ($base | where {|fila|
        ($fila.rating | default "" | into string | str trim) != "" and ($fila.rating_rival | default "" | into string | str trim) != ""
    })

    let filas = ($completas | each {|fila|
        let r1 = ($fila.rating | into float)
        let r2 = ($fila.rating_rival | into float)
        let parejas = ($cruces | where {|r|
            $r.civilization == $fila.civ and $r.other_civilization == $fila.civ_rival
        })
        let tiene = (($parejas | length) > 0)
        let tasa = if $tiene {
            let tasa_original = (($parejas | first).win_rate | into float)
            if $tasa_original > 1.0 {$tasa_original / 100.0} else {$tasa_original}
        } else {0.5}
        let tipo = if ($fila.civ not-in $catalogo) {
            "fuera_catalogo_api"
        } else if ($fila.civ in $variantes) {
            "variante_historica_provisional"
        } else {
            "base_provisional"
        }
        let d = ($r1 - $r2)
        {
            game_id: ($fila.game_id | into int)
            fecha_inicio: $fila.fecha_inicio
            jugador: $fila.jugador
            rival: $fila.rival
            modo: "rm_solo"
            mapa: $fila.mapa
            civ: $fila.civ
            civ_rival: $fila.civ_rival
            tipo_civ: $tipo
            duracion_min: (($fila.duracion_seg | into float) / 60.0)
            resultado: $fila.resultado
            rating_previo: $r1
            rating_rival_previo: $r2
            victoria: (if $fila.resultado == "win" {1} else {0})
            d: $d
            d_100: ($d / 100.0)
            ventaja_cruce: $tasa
            ventaja_10pp: (10.0 * ($tasa - 0.5))
            fuente_cruce: (if $tiene {"directa"} else {"neutral_imputada"})
        }
    } | sort-by fecha_inicio)
    $filas | to csv | save -f data/processed/partidas_depuradas_entrega.csv

    let datos_modelo = ($filas | select game_id fecha_inicio victoria d d_100 ventaja_cruce ventaja_10pp fuente_cruce)
    $datos_modelo | to csv | save -f data/processed/partidas_modelo_846_reproducidas.csv
    let n = ($datos_modelo | length)
    let n_train = (($n * 0.7) | math floor | into int)
    let train = ($datos_modelo | first $n_train)
    let test = ($datos_modelo | skip $n_train)
    $train | to csv | save -f data/processed/entrenamiento_reproducido.csv
    $test | to csv | save -f data/processed/prueba_reproducida.csv
    {registros_limpios: ($base | length), modelacion: $n, entrenamiento: ($train | length), prueba: ($test | length), categorias_fuera_catalogo: ($filas | where tipo_civ == "fuera_catalogo_api" | length)}
}

# Muestra advertencia explicita cuando en la base hay nombres no
# reconocidos por el catalogo descargado de AoE4 World.
export def "aoe validar civs" [] {
    let api = (open data/raw/matchups_rm_solo.json | get data | get civilization | uniq)
    let tabla = (open data/processed/partidas_depuradas_entrega.csv)
    let no_reconocidas = ($tabla | where {|f| ($f.civ not-in $api) or ($f.civ_rival not-in $api)}
        | select civ civ_rival | uniq)
    if ($no_reconocidas | length) > 0 {
        print $no_reconocidas
        error make {msg: "Hay civilizaciones fuera del catalogo guardado. Validar fecha/parche antes de clasificar."}
    }
    {estado: "catalogo validado", partidas: ($tabla | length)}
}

# Exploracion con el plugin obligatorio Polars. Las tasas de
# victoria por grupo se calculan despues a partir de sumas y conteos.
export def "aoe explorar" [] {
    let archivo = "data/processed/partidas_depuradas_entrega.csv"
    if not ($archivo | path exists) {
        error make {msg: "Ejecuta primero aoe preparar."}
    }
    let df = (polars open $archivo)
    let por_civ = ($df | polars group-by civ | polars agg [
        (polars col victoria | polars count | polars as "partidas")
        (polars col victoria | polars sum | polars as "victorias")
    ] | polars collect | polars into-nu | each {|f|
        {civ: $f.civ, partidas: $f.partidas, victorias: $f.victorias, porcentaje: (100.0 * $f.victorias / $f.partidas)}
    } | sort-by partidas --reverse)
    let por_mapa = ($df | polars group-by mapa | polars agg [
        (polars col victoria | polars count | polars as "partidas")
        (polars col victoria | polars sum | polars as "victorias")
    ] | polars collect | polars into-nu | each {|f|
        {mapa: $f.mapa, partidas: $f.partidas, victorias: $f.victorias, porcentaje: (100.0 * $f.victorias / $f.partidas)}
    } | sort-by partidas --reverse)
    $por_civ | to csv | save -f resultados/polars_entrega_civilizaciones.csv
    $por_mapa | to csv | save -f resultados/polars_entrega_mapas.csv
    {civilizaciones: ($por_civ | length), mapas: ($por_mapa | length), tabla_civs: "resultados/polars_entrega_civilizaciones.csv", tabla_mapas: "resultados/polars_entrega_mapas.csv"}
}

# Motor Python permitido solo para ajuste y prediccion. Entrada
# generada por Nushell; evaluacion y metricas no van en Python.
export def "aoe model" [] {
    let train = "data/processed/entrenamiento_reproducido.csv"
    let test = "data/processed/prueba_reproducida.csv"
    if not ($train | path exists) or not ($test | path exists) {
        error make {msg: "Ejecuta primero aoe preparar."}
    }
    let py = if (".venv/bin/python" | path exists) {".venv/bin/python"} else {"python3"}
    run-external $py "modelos/motor_logistico_70.py" $train $test "resultados/predicciones_logistica_reproducida.csv" "resultados/coeficientes_logistica_reproducida.json"
    {predicciones: "resultados/predicciones_logistica_reproducida.csv", coeficientes: "resultados/coeficientes_logistica_reproducida.json"}
}

# Metricas calculadas exclusivamente por Nushell.
export def "aoe evaluar" [] {
    let test = (open data/processed/prueba_reproducida.csv)
    let pred = (open resultados/predicciones_logistica_reproducida.csv)
    let p0 = ((open data/processed/entrenamiento_reproducido.csv | get victoria | each {|v| $v | into int} | math sum) / (open data/processed/entrenamiento_reproducido.csv | length))
    let filas = ($test | each {|f|
        let logit = ($pred | where game_id == $f.game_id | first | get p_logistica | into float)
        let d = ($f.d | into float)
        let elo = (1.0 / (1.0 + (((0.0 - $d) / 400.0 * 2.302585092994046) | math exp)))
        {victoria: ($f.victoria | into int), constante: $p0, elo: $elo, logistica: $logit}
    })
    ["constante" "elo" "logistica"] | each {|modelo|
        let a = ($filas | each {|f|
            let y = $f.victoria
            let p = ($f | get $modelo | into float)
            let pclip = ([$p 0.000000000000001] | math max)
            let pseguro = ([ $pclip 0.999999999999999 ] | math min)
            let fallo = ((0.0 - ($y * ($pseguro | math ln) + (1 - $y) * ((1.0 - $pseguro) | math ln))))
            {ok: (if (if $p >= 0.5 {1} else {0}) == $y {1} else {0}), loss: $fallo}
        })
        {modelo: $modelo, partidas: ($a | length), exactitud: (100.0 * (($a | get ok | math sum) / ($a | length))), log_loss: (($a | get loss | math sum) / ($a | length))}
    }
}

# No vuelve a descargar datos: parte de los JSON ya guardados.
export def "aoe ejecutar" [] {
    let limpieza = (aoe clean)
    let preparacion = (aoe preparar)
    let exploracion = (aoe explorar)
    let ajuste = (aoe model)
    let metricas = (aoe evaluar)
    {limpieza: $limpieza, preparacion: $preparacion, exploracion: $exploracion, ajuste: $ajuste, metricas: $metricas}
}
