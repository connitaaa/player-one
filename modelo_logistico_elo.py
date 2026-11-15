"""Comparación temporal: regresión logística frente a referencia Elo.

Ejecutar desde la raíz del proyecto player-one:
    python3 modelos/modelo_logistico_elo.py

Dependencias: numpy y scikit-learn.
No descarga datos ni modifica los CSV de entrada.
"""

from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    brier_score_loss,
    log_loss,
    roc_auc_score,
)

BASE = Path("data/processed")
RESULTADOS = Path("resultados")


def leer(nombre: str) -> list[dict[str, str]]:
    ruta = BASE / nombre
    with ruta.open("r", encoding="utf-8-sig", newline="") as f:
        filas = list(csv.DictReader(f))
    if not filas:
        raise ValueError(f"Archivo vacío: {ruta}")
    return filas


def fecha_iso(texto: str) -> datetime:
    fecha = datetime.fromisoformat(texto.replace("Z", "+00:00"))
    return fecha if fecha.tzinfo else fecha.replace(tzinfo=timezone.utc)


def preparar(filas: list[dict[str, str]]):
    x = np.array(
        [float(f["diferencia_rating_observada"]) / 100.0 for f in filas],
        dtype=float,
    ).reshape(-1, 1)
    y = np.array([int(f["victoria"]) for f in filas], dtype=int)
    if not np.all(np.isfinite(x)) or not np.all(np.isin(y, (0, 1))):
        raise ValueError("Hay diferencias de rating no finitas o resultados inválidos.")
    return x, y


def metricas(y, probabilidades):
    predichas = (probabilidades >= 0.5).astype(int)
    return {
        "exactitud": round(float(accuracy_score(y, predichas)), 4),
        "auc_roc": round(float(roc_auc_score(y, probabilidades)), 4),
        "brier": round(float(brier_score_loss(y, probabilidades)), 4),
        "log_loss": round(float(log_loss(y, probabilidades, labels=[0, 1])), 4),
    }


def main() -> None:
    entrenamiento = leer("entrenamiento.csv")
    prueba = leer("prueba.csv")

    ids_entreno = {fila["game_id"] for fila in entrenamiento}
    ids_prueba = {fila["game_id"] for fila in prueba}
    if len(ids_entreno) != len(entrenamiento) or len(ids_prueba) != len(prueba):
        raise ValueError("Existen game_id duplicados dentro de uno de los conjuntos.")
    if ids_entreno & ids_prueba:
        raise ValueError("Hay partidas compartidas entre entrenamiento y prueba.")
    if max(fecha_iso(f["fecha_inicio"]) for f in entrenamiento) > min(
        fecha_iso(f["fecha_inicio"]) for f in prueba
    ):
        raise ValueError("La separación temporal entre entrenamiento y prueba es incorrecta.")

    x_train, y_train = preparar(entrenamiento)
    x_test, y_test = preparar(prueba)
    if len(np.unique(y_train)) != 2 or len(np.unique(y_test)) != 2:
        raise ValueError("Ambos conjuntos deben contener victorias y derrotas.")

    # Un predictor: (rating propio - rating rival) / 100.
    # El coeficiente se interpreta por cada 100 puntos de diferencia.
    modelo = LogisticRegression(max_iter=2000, random_state=42)
    modelo.fit(x_train, y_train)
    p_logistica = modelo.predict_proba(x_test)[:, 1]

    # Referencia Elo clásica (escala 400), NO calibrada para AoE IV.
    delta = x_test[:, 0] * 100.0
    p_elo = 1.0 / (1.0 + 10.0 ** (-delta / 400.0))

    RESULTADOS.mkdir(parents=True, exist_ok=True)
    informe = {
        "entrenamiento": len(entrenamiento),
        "prueba": len(prueba),
        "victorias_entrenamiento": int(y_train.sum()),
        "victorias_prueba": int(y_test.sum()),
        "predictor": "diferencia_rating_observada / 100",
        "advertencia": "La interpretación prepartida del rating debe validarse con los historiales.",
        "coeficiente_por_100_puntos": round(float(modelo.coef_[0, 0]), 6),
        "intercepto": round(float(modelo.intercept_[0]), 6),
        "logistica": metricas(y_test, p_logistica),
        "elo_referencia_400": metricas(y_test, p_elo),
    }

    with (RESULTADOS / "comparacion_logistica_elo.json").open("w", encoding="utf-8") as f:
        json.dump(informe, f, ensure_ascii=False, indent=2)

    with (RESULTADOS / "predicciones_prueba.csv").open(
        "w", encoding="utf-8", newline=""
    ) as f:
        columnas = [
            "game_id", "fecha_inicio", "victoria_real", "diferencia_rating",
            "prob_logistica", "prob_elo", "pred_logistica", "pred_elo",
        ]
        escritor = csv.DictWriter(f, fieldnames=columnas)
        escritor.writeheader()
        for i, fila in enumerate(prueba):
            escritor.writerow({
                "game_id": fila["game_id"],
                "fecha_inicio": fila["fecha_inicio"],
                "victoria_real": int(y_test[i]),
                "diferencia_rating": round(float(delta[i]), 2),
                "prob_logistica": round(float(p_logistica[i]), 6),
                "prob_elo": round(float(p_elo[i]), 6),
                "pred_logistica": int(p_logistica[i] >= 0.5),
                "pred_elo": int(p_elo[i] >= 0.5),
            })

    print(json.dumps(informe, ensure_ascii=False, indent=2))
    print("\nArchivos guardados en resultados/:")
    print("- comparacion_logistica_elo.json")
    print("- predicciones_prueba.csv")


if __name__ == "__main__":
    main()
