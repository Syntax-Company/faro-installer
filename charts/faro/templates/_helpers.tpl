{{/*
Helpers del chart de Faro.

Aquí viven las tres cosas que NO pueden divergir entre plantillas, porque cuando divergen el
síntoma aparece lejos de la causa:

  · los nombres de los objetos (el RoleBinding tiene que nombrar el MISMO ServiceAccount que monta
    el Deployment, o el primer build da 403);
  · la URL pública de Faro (FARO_FRONTEND_URL y el host del Ingress son el mismo dominio, o el
    login redirige a ninguna parte);
  · el host de la base de datos (el Service que crea el chart, o el externo del cliente).
*/}}

{{- define "faro.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "faro.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "faro.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Etiquetas comunes. SIN `app.kubernetes.io/version`: la versión no es una del chart sino una POR
IMAGEN (backend y frontend se publican por separado), así que la pone cada Deployment con su tag.
*/}}
{{- define "faro.labels" -}}
helm.sh/chart: {{ include "faro.chart" . }}
app.kubernetes.io/name: {{ include "faro.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: faro
{{- end -}}

{{/* Selector de un componente. Uso: include "faro.selectorLabels" (dict "ctx" $ "component" "backend") */}}
{{- define "faro.selectorLabels" -}}
app.kubernetes.io/name: {{ include "faro.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "faro.backend.fullname" -}}
{{- printf "%s-backend" (include "faro.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "faro.frontend.fullname" -}}
{{- printf "%s-frontend" (include "faro.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "faro.database.fullname" -}}
{{- printf "%s-postgresql" (include "faro.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
El ServiceAccount del backend. Con el nombre de release recomendado (`faro`) esto rinde
`faro-backend`, que es el nombre que usan los manifiestos originales de deploy/rbac del repo del
backend. Lo consumen TRES sitios y por eso es un helper: el ServiceAccount, el `serviceAccountName`
del Deployment y el `subjects` del RoleBinding. Si esos tres no coinciden, Kubernetes monta la
cuenta `default` —que no puede nada— y Faro arranca sin síntomas hasta el primer build.
*/}}
{{- define "faro.serviceAccountName" -}}
{{- include "faro.backend.fullname" . -}}
{{- end -}}

{{/* Constantes del contrato con las imágenes. No son values: las fija el Dockerfile de cada repo. */}}
{{- define "faro.backend.port" -}}8080{{- end -}}
{{- define "faro.frontend.port" -}}3000{{- end -}}
{{/* server.servlet.context-path del backend. El prefijo es parte de su ruta: el Ingress NO reescribe. */}}
{{- define "faro.backend.contextPath" -}}/api{{- end -}}

{{/*
¿La instalación se sirve por https?

Importa más de lo que parece: de esto sale el esquema de FARO_FRONTEND_URL, y con http el cookie de
sesión nunca se marca `Secure` (Spring lo deriva de request.isSecure() vía las cabeceras
X-Forwarded-*). Se considera https si hay TLS en el Ingress o si cert-manager va a emitir el
certificado.
*/}}
{{- define "faro.tlsEnabled" -}}
{{- if or .Values.ingress.tls.enabled .Values.certManager.issuer -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{- define "faro.scheme" -}}
{{- if eq (include "faro.tlsEnabled" .) "true" -}}https{{- else -}}http{{- end -}}
{{- end -}}

{{/*
La URL pública de Faro. Es FARO_FRONTEND_URL (destino del redirect post-login), la base de la que
cuelga `/setup` —donde se completa el asistente de primer arranque— y el host del Ingress.

El redirect URI del proveedor de identidad también cuelga de aquí, pero ya NO lo construye el chart:
depende de qué proveedor se elija, y eso se elige en el asistente, que es quien lo muestra.
*/}}
{{- define "faro.url" -}}
{{- $domain := required "global.domain es OBLIGATORIO: es el host único de Faro (portal + API). El backend no tiene default para FARO_FRONTEND_URL a propósito — el que tenía era una IP de LAN de desarrollo, y una instalación que la heredara mandaba a sus usuarios a una red ajena tras el login. Ej: --set global.domain=faro.tuempresa.com" .Values.global.domain -}}
{{- printf "%s://%s" (include "faro.scheme" .) $domain -}}
{{- end -}}

{{/*
Host de la base de datos: el Service del chart, o el externo. DB_HOST no tiene default en el
backend, así que con database.deploy=false es obligatorio.
*/}}
{{- define "faro.databaseHost" -}}
{{- if .Values.database.deploy -}}
{{- include "faro.database.fullname" . -}}
{{- else -}}
{{- required "database.host es OBLIGATORIO cuando database.deploy=false: DB_HOST no tiene valor por defecto en el backend y sin él la aplicación no arranca." .Values.database.host -}}
{{- end -}}
{{- end -}}

{{/* Nombre del Secret de la app. Desde la fase 6 solo lleva DB_PASSWORD: el client secret del
     proveedor de identidad y el token de GitOps los guarda cifrados el asistente. */}}
{{- define "faro.appSecretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "faro.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Nombre del secreto de arranque: la llave maestra y el token de acceso inicial. Separado del de la
app a propósito — lleva `resource-policy: keep` porque su contenido no se puede volver a conseguir.
*/}}
{{- define "faro.bootstrapSecretName" -}}
{{- if .Values.credentialKey.existingSecret -}}
{{- .Values.credentialKey.existingSecret -}}
{{- else -}}
{{- printf "%s-bootstrap" (include "faro.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Nombre del imagePullSecret que montan los DOS Deployments, o cadena vacía con mode=none.

Los paquetes de ghcr.io/syntax-company son privados: sin esto el pod se queda en ImagePullBackOff
con un `denied` del registry, que se lee como un tag equivocado y no como credenciales que faltan.

Devuelve solo el NOMBRE (y no el bloque `imagePullSecrets:` entero) para que el call site controle
la indentación sin pelearse con `nindent` sobre un bloque que a veces está vacío. La validación de
`mode` corre igual en los tres casos, porque `include` ejecuta esta plantilla siempre.
*/}}
{{- define "faro.imagePullSecretName" -}}
{{- $mode := required "imagePullSecret.mode es OBLIGATORIO: create | existing | none. Las imagenes de Faro estan en paquetes PRIVADOS de ghcr.io, asi que sin secreto de descarga los dos Deployments quedan en ImagePullBackOff con un 'denied' que parece un tag mal escrito. Usa 'none' solo si has replicado las imagenes en un registry que el cluster lee sin credenciales." .Values.imagePullSecret.mode -}}
{{- if eq $mode "create" -}}
{{- printf "%s-registry" (include "faro.fullname" .) -}}
{{- else if eq $mode "existing" -}}
{{- required "imagePullSecret.existingSecret es OBLIGATORIO con imagePullSecret.mode=existing." .Values.imagePullSecret.existingSecret -}}
{{- else if ne $mode "none" -}}
{{- fail (printf "imagePullSecret.mode invalido: %q. Valores admitidos: create | existing | none." $mode) -}}
{{- end -}}
{{- end -}}

{{/*
El nombre de la base de datos es SIEMPRE `faro`, y por eso es una constante y no un value.

Decisión de plans/059 F6: una pregunta menos y un valor menos que se puede escribir mal. Un nombre
equivocado no falla al instalar —falla al arrancar, con un error de conexión que no dice qué pasó—,
así que quitarlo elimina un modo de fallo entero. Coincide además con el default del backend
(`DB_NAME:faro`), de modo que las dos fuentes no pueden desincronizarse.
*/}}
{{- define "faro.database.name" -}}faro{{- end -}}

{{/*
⚠️⚠️ LA FORMA DE CADA VALOR. Esto no es cosmética: es lo que hace que confundir los dos secretos del
Secret de arranque sea IMPOSIBLE en vez de solo improbable.

Los dos son cadenas opacas de mucha entropía que se imprimen seguidas en la misma pantalla, y un
operador que copie la equivocada no se entera hasta que el token no le vale. Así que cada uno tiene
UNA forma, distinta y reconocible a simple vista, y quien la reciba la comprueba:

  FARO_BOOTSTRAP_TOKEN   40 caracteres HEXADECIMALES en minúscula.        ^[0-9a-f]{40}$
                         (`openssl rand -hex 20` — 160 bits)

  FARO_CREDENTIAL_KEY    44 caracteres en BASE64, y acaba en '='.         ^[A-Za-z0-9+/]{43}=$
                         (`openssl rand -base64 32` — 32 bytes, que es
                         lo que el backend exige)

Una acaba en '=' y la otra no puede: con verlo se distinguen. Y las dos formas se validan más abajo,
en secret-bootstrap.yaml, así que pasar una donde va la otra ABORTA la instalación con un mensaje
que lo dice, en vez de escribir el valor equivocado en el Secret.

⚠️ Antes de esto había TRES generadores discrepando —el script daba hex de 40, el chart alfanumérico
de 32, y la documentación de este mismo fichero un hex de 32— y cuál te tocaba dependía de quién
instalara. Ahora la forma la fija este helper y el script produce la misma; cualquier divergencia
futura la caza la validación en vez de llegar al cluster.
*/}}
{{- define "faro.newBootstrapToken" -}}
{{- /* 40 hex, la misma forma que `openssl rand -hex 20` del instalador. Sprig no tiene un generador
       hexadecimal, así que se toma el resumen de un aleatorio: `randAlphaNum` sale de crypto/rand y
       aporta ~190 bits, de los que el truncado a 40 hex conserva 160 — exactamente los del
       instalador. El resumen aquí es solo un cambio de alfabeto, no un secreto derivado de nada. */ -}}
{{- substr 0 40 (sha256sum (randAlphaNum 32)) -}}
{{- end -}}

{{/*
Resuelve el valor de una clave de un Secret que gestiona el chart, en este orden:

    el value que se pasa  ->  el que YA está en el cluster (lookup, si `reuse`)  ->  generar, o fallar

⚠️ El `lookup` es lo que hace que un `helm upgrade` NO rote los secretos. Sin él, una actualización
que no vuelva a pasar la llave maestra la regeneraría, y TODO lo cifrado con la anterior quedaría
ilegible. Es lo que permite que el fichero de valores que el instalador deja en disco no lleve
ningún secreto dentro y siga sirviendo para actualizar.

⚠️ Pero `reuse` NO es siempre true, y ahí está el matiz que costó un fallo. Este Secret lleva
`resource-policy: keep`, así que SOBREVIVE a un `helm uninstall`: cuando se instala de nuevo, el
lookup se lo encuentra. Eso es lo que se quiere para la llave maestra —los datos cifrados con ella
pueden seguir vivos, el volumen de la base también sobrevive— y es exactamente lo que NO se quiere
para el token de acceso inicial: una instalación nueva heredaba el acceso de la anterior, uno que ya
circuló y que alguien pudo apuntar. Por eso el token pasa `reuse .Release.IsUpgrade`: se conserva al
actualizar (rotarlo en cada upgrade dejaría inservible el que el operador tenga apuntado) y se
regenera al instalar.

⚠️ `keepEmpty` distingue «la clave no está» de «la clave está y está VACÍA». Vacía es como el
backend entiende «sin token», o sea el token retirado a propósito tras completar el asistente. Sin
esta distinción, un upgrade sobre una instalación ya configurada volvía a generar token y REABRÍA el
acceso inicial. La llave maestra no lo usa: para ella, vacía es un estado que no existe.

⚠️ `lookup` devuelve vacío en `helm template` y en `--dry-run`: ahí no hay conexión con el API
server. Por eso la llave maestra NUNCA se genera y el fallback es fallar con un mensaje: generarla
en ese caso rendiría un manifiesto con una llave distinta de la real, y aplicarlo sería exactamente
la catástrofe que se intenta evitar. El token de acceso inicial sí se genera, porque perderlo no
cuesta nada: está hecho para morirse.

Uso:
  include "faro.secretValue" (dict "ctx" $ "secret" NOMBRE "key" CLAVE "value" VALOR
                                   "reuse" BOOL "generateAs" FORMA "keepEmpty" BOOL "message" TEXTO)

`reuse` y `keepEmpty` son opcionales: sin ellos se comporta como antes (recuperar siempre, vacío no
es un estado). Solo el token de acceso inicial los cambia.

`generateAs` NOMBRA la forma a generar en vez de ser un booleano, y es a propósito: un `true` no
dice QUÉ se genera, y así fue como el chart acabó produciendo un token con una forma distinta de la
del instalador sin que nadie lo notara. "" = no generar (fallar con el mensaje). "token" = la forma
canónica del token de acceso inicial. Una forma desconocida aborta.
*/}}
{{- define "faro.secretValue" -}}
{{- if .value -}}
{{- .value -}}
{{- else -}}
{{- $found := "" -}}
{{- $present := false -}}
{{- /* `reuse` ausente = true. El default seguro es el de siempre: recuperar lo que ya está. Un
       call site que se olvide del parámetro sigue funcionando; el que quiera lo contrario —solo el
       token— tiene que pedirlo. Al revés, olvidarse rompería un upgrade sin previo aviso. */ -}}
{{- $reuse := true -}}
{{- if hasKey . "reuse" -}}
{{- $reuse = .reuse -}}
{{- end -}}
{{- if $reuse -}}
{{- $existing := (lookup "v1" "Secret" .ctx.Release.Namespace .secret) -}}
{{- if and $existing $existing.data -}}
{{- if hasKey $existing.data .key -}}
{{- $present = true -}}
{{- $found = (index $existing.data .key | default "") -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $found -}}
{{- $found | b64dec -}}
{{- else if and $present .keepEmpty -}}
{{- /* Presente y vacío: retirado a propósito. Se devuelve vacío, que es lo que había. */ -}}
{{- else if eq (.generateAs | default "") "token" -}}
{{- include "faro.newBootstrapToken" . -}}
{{- else if .generateAs -}}
{{- fail (printf "faro.secretValue: generateAs %q no es una forma conocida. Admitidas: \"\" (no generar) | \"token\"." .generateAs) -}}
{{- else -}}
{{- required .message "" -}}
{{- end -}}
{{- end -}}
{{- end -}}
