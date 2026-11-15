
.profile_id as $id__xx
| .games[]
| . as $partida__xx
| [.teams[][] | .player] as $jugadores__xx
| ($jugadores__xx | map(select(.profile_id == $id__xx)) | first) as $propio__xx
| ($jugadores__xx | map(select(.profile_id != $id__xx)) | first) as $rival__xx
| select($propio__xx != null and $rival__xx != null)
| [
    $partida__xx.game_id,
    $id__xx,
    $propio__xx.name,
    $rival__xx.profile_id,
    $rival__xx.name,
    $partida__xx.started_at,
    $partida__xx.duration,
    $partida__xx.map,
    $partida__xx.kind,
    $partida__xx.leaderboard,
    $partida__xx.ongoing,
    $propio__xx.civilization,
    $rival__xx.civilization,
    $propio__xx.result,
    $propio__xx.rating,
    $rival__xx.rating,
    $propio__xx.rating_diff,
    $rival__xx.rating_diff
]
| @csv
