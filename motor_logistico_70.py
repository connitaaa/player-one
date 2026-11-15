
import csv
import json
import sys

from sklearn.linear_model import LogisticRegression
import sklearn

archivo_train, archivo_test, archivo_pred, archivo_coef = sys.argv[1:]

with open(archivo_train, encoding="utf-8-sig", newline="") as f:
    train = list(csv.DictReader(f))

with open(archivo_test, encoding="utf-8-sig", newline="") as f:
    test = list(csv.DictReader(f))

X_train = [
    [float(f["d_100"]), float(f["ventaja_10pp"])]
    for f in train
]

y_train = [int(f["victoria"]) for f in train]

X_test = [
    [float(f["d_100"]), float(f["ventaja_10pp"])]
    for f in test
]

modelo = LogisticRegression(max_iter=2000)
modelo.fit(X_train, y_train)

probabilidades = modelo.predict_proba(X_test)[:, 1]

with open(archivo_pred, "w", encoding="utf-8", newline="") as f:
    escritor = csv.writer(f)
    escritor.writerow(["game_id", "p_logistica"])
    for fila, prob in zip(test, probabilidades):
        escritor.writerow([fila["game_id"], float(prob)])

coeficientes = {
    "motor": "scikit-learn",
    "version": sklearn.__version__,
    "variables": ["d_100", "ventaja_10pp"],
    "intercepto": float(modelo.intercept_[0]),
    "coeficientes": modelo.coef_[0].tolist(),
    "entrenamiento": len(train),
    "prueba": len(test)
}

with open(archivo_coef, "w", encoding="utf-8") as f:
    json.dump(coeficientes, f, indent=2)

print("MODELO LOGISTICO ENTRENADO")
print("Entrenamiento:", len(train))
print("Prueba:", len(test))
print("Coeficientes guardados correctamente")
