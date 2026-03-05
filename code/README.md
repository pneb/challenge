# PQS TLS Measurements

Dieses Repository wurde für die Reproduktion der Ergebnisse von [Sosnowski et al. (2023)](https://doi.org/10.1145/3624354.3630585) angelegt.
Es basiert auf dem [Docker-Setup](https://github.com/tumi8/pqs-tls-measurements) der Autoren und wurde auf einen aktuellen Software-Stack angepasst.

Die von den Änderungen betroffenen Dateien sind:
- code/docker-compose.yml
- code/run_and_evaluate.sh
- code/docker/run_single_experiment.sh
- code/docker/clientserver/Dockerfile
- code/docker/clientserver/measurement-openssl-client.sh
- code/docker/clientserver/measurement-openssl-server.sh
- code/loop_vars/all-kem.yml
- code/loop_vars/all-sig.yml
- code/loop_vars/all-kem-scenarios.yml
- code/loop_vars/all-sig-scenarios.yml
- code/loop_vars/level1.yml
- code/loop_vars/level3.yml
- code/loop_vars/level5.yml
- code/loop_vars/test.yml
- code/finalization/create-analysis.py
- code/finalization/eval_profiling.py

Außerdem wurde ein Skript erstellt, mit dem die Ergebnisse visualisiert werden können (evaluate_script.ipynb).
Die Ergebnisse selber lassen sich in dem results Ordner finden.
Ein Teil der Ergebnisse der Autoren (der für die Visualisierungen benötigt wurde) befindet sich in dem tum-evaluate Ordner.
Diese Ergebnisse stammen von [https://mediatum.ub.tum.de/1725057](https://mediatum.ub.tum.de/1725057).

Der main Branch enthält die unangepasste OpenSSL 3.6 Version, die das von den Autoren beschriebene Buffer Verhalten ebenfalls aufweist.
Der flush Branch benutzt einen angepassten Fork von OpenSSL 3.6 der das Buffer Verhalten, wie von den Autoren beschrieben, verändert.

Requirements:
* Linux
* Docker, wir haben wie die gleiche Version wie die Autoren verwendet (Version 24.0.6)
* Python3 `apt-get install python3`
* Python3 Libraries: `apt-get install python3-click python3-yaml matplotlib pandas numpy`

Um die Experimente durchzuführen:

```bash
./experiment.py --output-dir $RESULTS all-kem all-sig
```

Die Autoren haben folgende Experimente vordefiniert (Wir haben diese Experimente für OpenSSL 3.6 angepasst):
* all-kem
    * Evaluiere alle Schlüsselaustauschalgorithmen (KA) zusammen mit rsa:2048 als Signaturalgorithmus (SA)
* all-sig
    * Evaluiere alle SA zusammen mit X25519 als KA
* all-[kem|sig]-scenarios
  * das gleiche wie all-kem/all-sig aber unter emulierten Netzwerkbedingungen
* level[1,3,5]
  * Jede mögliche Kombination zwischen SA und KA auf einem bestimmten Level (die Autoren haben Level 1 und 2 zusammen gruppiert) -> wurde von uns nicht verwendet

Um die Ergebnisse zu erhalten kann das `evaluate.py` Skript ausgeführt werden

```bash
./evaluate.py --output-dir $EVAL_OUTPUT $RESULTS/*
```

Wir haben die Experimente wie folgt ausgeführt (und die Ergebnisse unter `$RESULTS` gespeichert):

```bash
./experiment.py --output-dir $RESULTS all-kem all-sig all-kem-scenarios all-sig-scenarios
./evaluate.py --output-dir $EVAL_OUTPUT $RESULTS/*
```
