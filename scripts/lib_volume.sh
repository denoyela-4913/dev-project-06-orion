# shellcheck shell=bash
# Fonctions communes à backup.sh et restore.sh: accès au volume de données pendant que le back est arrêté.
# Attend les variables `namespace` et `release`, et définit `volume_pod`. À inclure avec `.`, pas à exécuter.
# shellcheck disable=SC2154 # `namespace` et `release` viennent du script appelant

volume_pod=""

has_data_volume() {
  kubectl -n "$namespace" get persistentvolumeclaim "$release-data" >/dev/null 2>&1
}

# Arrête le back, démarre un pod qui monte son volume (nom dans `volume_pod`), et programme la remise en route à
# la sortie du script, réussie ou non.
with_volume_pod() {
  local replicas image
  replicas=$(kubectl -n "$namespace" get deployment "$release-back" -o jsonpath='{.spec.replicas}')
  image=$(kubectl -n "$namespace" get deployment "$release-back" -o jsonpath='{.spec.template.spec.containers[0].image}')
  volume_pod="$release-volume-$$"
  # shellcheck disable=SC2064 # valeurs figées au moment de l'armement du trap
  trap "restore_back '$replicas'" EXIT

  kubectl -n "$namespace" scale deployment "$release-back" --replicas=0 >/dev/null
  kubectl -n "$namespace" wait --for=delete pod \
    -l "app.kubernetes.io/instance=$release,app.kubernetes.io/component=back" --timeout=120s >/dev/null

  # Même image que le back (déjà présente sur le nœud, avec `tar`), même utilisateur, mêmes protections.
  kubectl -n "$namespace" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: $volume_pod
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: volume
      image: $image
      command: ["sleep", "600"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: [ALL]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: $release-data
YAML
  kubectl -n "$namespace" wait --for=condition=Ready "pod/$volume_pod" --timeout=120s >/dev/null
}

restore_back() {
  kubectl -n "$namespace" delete pod "$volume_pod" --ignore-not-found --wait=true >/dev/null
  kubectl -n "$namespace" scale deployment "$release-back" --replicas="$1" >/dev/null
  kubectl -n "$namespace" rollout status deployment "$release-back" --timeout=180s >/dev/null
}
