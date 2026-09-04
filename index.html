#!/usr/bin/env bash
#
# ---------------------------------------------------------------------------------------------
# Instalador de Faro.
#
#     curl -fsSL https://raw.githubusercontent.com/Syntax-Company/faro-installer/master/install.sh | bash
#
# Comprueba el cluster, pregunta lo poco que no puede saber, genera los secretos y lanza Helm.
#
# ⚠️ ALCANCE REDUCIDO. Este instalador pregunta SOLO lo que no se puede configurar desde Faro
# porque Faro todavía no existe:
#
#     · la conexión a la base de datos          (dirección, usuario y contraseña — el NOMBRE es
#                                                siempre `faro`, fijo, no se pregunta)
#     · el dominio en que se sirve Faro         (el Ingress tiene que enrutarlo antes de que Faro
#                                                exista, así que Faro no puede decirlo)
#     · las credenciales para bajar las imágenes
#     · dos hechos del cluster que además detecta y ofrece: IngressClass y ClusterIssuer
#
# Y GENERA dos cosas: la llave maestra y el token de acceso inicial, que van al mismo Secret.
#
# El proveedor de identidad con sus credenciales, el registro donde Faro publica lo que construye,
# el repositorio de GitOps con su token y el dominio base de las apps NO se preguntan: los captura
# el ASISTENTE DE PRIMER ARRANQUE desde la propia interfaz, y viven en la base de datos. El backend
# retiró esas variables de entorno, así que ponerlas aquí no tendría ningún efecto. Se entra al
# asistente con el token que este script imprime al terminar.
#
# ⚠️ NOTA PARA QUIEN LO MANTENGA — por qué cada `read` lleva `< "$TTY"`:
#
#     Con `curl ... | bash`, la ENTRADA ESTÁNDAR del script es el propio script: bash lo va leyendo
#     de ahí mientras lo ejecuta. Un `read` normal se comería las líneas siguientes del código en
#     vez de esperar al usuario, y el script se rompería a mitad de una forma imposible de
#     diagnosticar. Por eso todas las preguntas leen del terminal explícitamente.
#
#     Y por eso tampoco se usa `exec < /dev/tty`: reasignar el descriptor 0 le quita a bash la
#     fuente desde la que sigue leyendo el script.
#
# ⚠️ SEGUNDA CONVENCIÓN, y romperla es un fallo silencioso: la variable que recibe cada respuesta
#     se llama IGUAL que la variable de entorno que la pre-responde (FARO_*). `ask` lee el valor
#     actual de esa misma variable para decidir si preguntar. Si el destino ya trae un valor por
#     defecto del script, la pregunta NO se hace nunca. Por eso los destinos de `ask` arrancan
#     siempre vacíos y los valores por defecto se pasan como tercer argumento.
#
# Dependencias: bash, kubectl y helm 3. Nada más — ni jq, ni yq, ni git, ni python. Por eso el poco
# JSON que se lee del cluster se parsea con sed, y no con un parser de verdad.
#
# Los secretos NO viajan nunca por la línea de órdenes: se construye el YAML y se aplica por la
# entrada estándar, así que no aparecen en `ps`.
# ---------------------------------------------------------------------------------------------

set -euo pipefail

# ── Constantes ───────────────────────────────────────────────────────────────────────────────

# ── De dónde sale el chart ───────────────────────────────────────────────────────────────────
#
# El sitio de GitHub Pages del repositorio publica TRES cosas bajo el mismo dominio:
#
#   https://get.faro.run                     este mismo script  (es lo que hace posible el
#                                            `curl -fsSL https://get.faro.run | bash`)
#   https://get.faro.run/index.yaml          el índice del repositorio Helm
#   https://get.faro.run/faro-<version>.tgz  el chart empaquetado, una version por release
#
# ⚠️ Un solo dominio y un solo sitio publicado a propósito. El script tiene que poder ejecutarse SIN
# repositorio clonado, así que necesita traerse el chart de algún sitio público; que ese sitio sea el
# mismo que ya sirve el script significa un despliegue, un DNS y una cosa que puede romperse en vez
# de dos. Y el `.tgz` se lo traga `helm` directamente, así que no hace falta ni `tar` ni `git`.
FARO_SITE="${FARO_SITE:-https://get.faro.run}"

# ⚠️ Los Secrets los crea EL CHART, no este script (ver la sección 5). Sus nombres los deriva del
# nombre de la release: `<release>-bootstrap` y `<release>-app`.

BUILD_NAMESPACE="faro-builds"
VALUES_OUT="${FARO_VALUES_OUT:-faro-values.yaml}"

# Versión que se ofrece por defecto. Es la misma que la `appVersion` del chart; se repite aquí
# porque el script tiene que poder proponerla ANTES de haber localizado el chart, y leerla de
# Chart.yaml exigiría un parser de YAML que este script no tiene. Al subir una release hay que
# tocar los dos sitios.
FARO_VERSION_DEFAULT="0.0.3"

# Versión DEL CHART que se descarga cuando no hay uno al lado. Es la `version:` de Chart.yaml, no la
# de Faro: son ciclos de vida distintos.
#
# ⚠️ Se fija aquí, en una constante, y no se resuelve a «la última». Dos razones:
#
#   · una instalación tiene que poder decir qué versión instaló y repetirse igual más tarde, y con
#     un puntero móvil eso no se puede;
#   · averiguar cuál es la última exigiría parsear el `index.yaml`, y este script no tiene parser de
#     YAML a propósito.
#
# Este script y el chart se publican JUNTOS, así que la constante y `charts/faro/Chart.yaml` no
# pueden divergir: el workflow de publicación aborta si no coinciden (.github/workflows/publish.yml).
CHART_VERSION_DEFAULT="0.1.1"
CHART_VERSION="${FARO_CHART_VERSION:-}"

RELEASE="${FARO_RELEASE:-faro}"
NAMESPACE_DEFAULT="faro"
NAMESPACE_FIXED=""      # lo pone --namespace: si viene por bandera, no se pregunta
CHART="${FARO_CHART:-}"
DRY_RUN=""
ASSUME_YES=""
SKIP_CHECKS=""

# ── Salida ───────────────────────────────────────────────────────────────────────────────────
#
# Todo lo humano va a stderr. Un instalador no es un filtro: nadie canaliza su salida, y así los
# mensajes se ven aunque el usuario redirija stdout.

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

say()  { printf '%s\n' "$*" >&2; }
ok()   { printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*" >&2; }
warn() { printf '  %s⚠%s  %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
bad()  { printf '  %s✘%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
step() { printf '\n%s%s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET" >&2; }
hint() { printf '    %s%s%s\n' "$C_DIM" "$*" "$C_RESET" >&2; }
rule() { printf '  ──────────────────────────────────────────────────────────────────────\n' >&2; }

die() {
  printf '\n%serror:%s %s\n\n' "$C_RED$C_BOLD" "$C_RESET" "$1" >&2
  exit "${2:-1}"
}

# ── Terminal ─────────────────────────────────────────────────────────────────────────────────

TTY=""
if { [ -r /dev/tty ] && [ -w /dev/tty ]; } 2>/dev/null; then
  TTY=/dev/tty
fi

have() { command -v "$1" >/dev/null 2>&1; }

# ── Preguntas ────────────────────────────────────────────────────────────────────────────────
#
#   ask VARIABLE "pregunta" "default" "validador"
#
# Si VARIABLE ya trae valor (de una variable de entorno del mismo nombre), se valida y no se
# pregunta. Es lo que permite correr el instalador sin terminal: en CI, o para repetir una
# instalación con las mismas respuestas.

ask() {
  local __var="$1" prompt="$2" default="${3:-}" validator="${4:-}"
  local value preset="${!__var:-}"

  if [ -n "$preset" ]; then
    if [ -n "$validator" ] && ! "$validator" "$preset"; then
      die "El valor de \$$__var no es válido: $preset"
    fi
    ok "$prompt: $preset  ${C_DIM}(desde \$$__var)${C_RESET}"
    return 0
  fi

  # Sin terminal: si hay valor por defecto, se usa. Solo se aborta cuando no hay nada que asumir.
  # Es lo que hace viable el modo no interactivo: si no, una instalación por variables de entorno
  # moriría en la primera pregunta con default que nadie se molestó en pre-responder (el namespace,
  # el puerto de la base, el tamaño del volumen), que es justo la que no hacía falta contestar.
  if [ -z "$TTY" ]; then
    [ -n "$default" ] || die "No hay terminal para preguntar «$prompt», y no hay valor por defecto.
       Define \$$__var, o descarga el script y ejecútalo:
         curl -fsSLO <url> && bash install.sh"
    if [ -n "$validator" ] && ! "$validator" "$default"; then
      die "El valor por defecto de «$prompt» no es válido: $default"
    fi
    printf -v "$__var" '%s' "$default"
    ok "$prompt: $default  ${C_DIM}(por defecto)${C_RESET}"
    return 0
  fi

  while true; do
    if [ -n "$default" ]; then
      printf '  %s [%s]: ' "$prompt" "$default" >&2
    else
      printf '  %s: ' "$prompt" >&2
    fi
    IFS= read -r value < "$TTY" || die "Entrada cerrada."
    value="${value:-$default}"
    if [ -z "$value" ]; then
      warn "Este valor es obligatorio."
      continue
    fi
    if [ -n "$validator" ] && ! "$validator" "$value"; then
      continue
    fi
    printf -v "$__var" '%s' "$value"
    return 0
  done
}

# Como ask, pero admite respuesta vacía (para lo que de verdad es opcional).
ask_opt() {
  local __var="$1" prompt="$2" default="${3:-}"
  local value preset="${!__var:-}"

  if [ -n "$preset" ]; then
    ok "$prompt: $preset  ${C_DIM}(desde \$$__var)${C_RESET}"
    return 0
  fi
  if [ -z "$TTY" ]; then
    printf -v "$__var" '%s' "$default"
    return 0
  fi

  if [ -n "$default" ]; then
    printf '  %s [%s]: ' "$prompt" "$default" >&2
  else
    printf '  %s %s(opcional, Intro para omitir)%s: ' "$prompt" "$C_DIM" "$C_RESET" >&2
  fi
  IFS= read -r value < "$TTY" || die "Entrada cerrada."
  printf -v "$__var" '%s' "${value:-$default}"
}

# Sin eco y sin valor por defecto. Para secretos.
ask_secret() {
  local __var="$1" prompt="$2"
  local value preset="${!__var:-}"

  if [ -n "$preset" ]; then
    ok "$prompt: ${C_DIM}(desde \$$__var)${C_RESET}"
    return 0
  fi

  [ -n "$TTY" ] || die "No hay terminal para preguntar «$prompt». Define \$$__var."

  while true; do
    printf '  %s: ' "$prompt" >&2
    IFS= read -rs value < "$TTY" || die "Entrada cerrada."
    printf '\n' >&2
    if [ -z "$value" ]; then
      warn "Este valor es obligatorio."
      continue
    fi
    printf -v "$__var" '%s' "$value"
    return 0
  done
}

# ask_yes_no VARIABLE "pregunta" "s|n"  -> deja "si" o "no"
ask_yes_no() {
  local __var="$1" prompt="$2" default="${3:-n}"
  local value preset="${!__var:-}" opts

  if [ -n "$preset" ]; then
    case "$preset" in
      si|SI|s|S|yes|y|true|1) printf -v "$__var" 'si' ;;
      *)                      printf -v "$__var" 'no' ;;
    esac
    return 0
  fi
  if [ -z "$TTY" ]; then
    case "$default" in s) printf -v "$__var" 'si' ;; *) printf -v "$__var" 'no' ;; esac
    return 0
  fi

  case "$default" in s) opts="S/n" ;; *) opts="s/N" ;; esac
  while true; do
    printf '  %s [%s]: ' "$prompt" "$opts" >&2
    IFS= read -r value < "$TTY" || die "Entrada cerrada."
    value="${value:-$default}"
    case "$value" in
      s|S|si|SI|Si|y|Y|yes) printf -v "$__var" 'si'; return 0 ;;
      n|N|no|NO|No)         printf -v "$__var" 'no'; return 0 ;;
      *) warn "Responde s o n." ;;
    esac
  done
}

# ask_choice VARIABLE "pregunta" "default" opcion1 opcion2 ...
ask_choice() {
  local __var="$1" prompt="$2" default="$3"; shift 3
  local options=("$@") value preset="${!__var:-}" opt

  if [ -n "$preset" ]; then
    for opt in "${options[@]}"; do
      if [ "$opt" = "$preset" ]; then
        ok "$prompt: $preset  ${C_DIM}(desde \$$__var)${C_RESET}"
        return 0
      fi
    done
    die "El valor de \$$__var no es válido: $preset (admitidos: ${options[*]})"
  fi

  [ -n "$TTY" ] || die "No hay terminal para preguntar «$prompt». Define \$$__var."

  while true; do
    printf '  %s (%s) [%s]: ' "$prompt" "$(IFS='/'; printf '%s' "${options[*]}")" "$default" >&2
    IFS= read -r value < "$TTY" || die "Entrada cerrada."
    value="${value:-$default}"
    for opt in "${options[@]}"; do
      if [ "$opt" = "$value" ]; then printf -v "$__var" '%s' "$value"; return 0; fi
    done
    warn "Elige una de: ${options[*]}"
  done
}

confirm_or_die() {
  local answer=""
  [ -z "$ASSUME_YES" ] || return 0
  [ -n "$TTY" ] || die "Hace falta confirmación y no hay terminal. Usa --yes si estás seguro."
  printf '\n  %s [s/N]: ' "$1" >&2
  IFS= read -r answer < "$TTY" || true
  case "$answer" in
    s|S|si|SI|Si|y|Y|yes) return 0 ;;
    *) die "Cancelado. No se ha tocado nada en el cluster." ;;
  esac
}

# ── Validadores ──────────────────────────────────────────────────────────────────────────────
#
# ⚠️ Aquí está media razón de ser de este script. Un dominio mal escrito NO produce ningún error:
# produce una instalación que nadie puede alcanzar, certificados que nunca se emiten y un login que
# redirige a ninguna parte. Se valida antes de tocar el cluster, no después.

valid_domain() {
  local d="$1"
  case "$d" in
    http://*|https://*) bad "Escribe solo el nombre del host, sin http:// ni https://."; return 1 ;;
    */*)                bad "Escribe solo el nombre del host, sin rutas ni barras.";     return 1 ;;
    *:*)                bad "Escribe solo el nombre del host, sin puerto.";              return 1 ;;
  esac
  if ! printf '%s' "$d" | grep -Eq '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$'; then
    bad "«$d» no es un nombre de dominio válido (ej: faro.tuempresa.com)."
    return 1
  fi
  case "$d" in
    *.local|localhost|*.localhost|*.internal|*.lan)
      bad "«$d» no resuelve fuera de tu máquina."
      hint "Faro generaría Ingress y certificados para un dominio inalcanzable y NADA fallaría:"
      hint "el portal simplemente no cargaría, sin un error que lo diga."
      return 1 ;;
  esac
  return 0
}

# ⚠️ Aquí había dos validadores más —el de la URL del repositorio de GitOps y el del registro de
# imágenes— y se han BORRADO con sus preguntas. La validación de esos dos la hace ahora el asistente,
# y mejor: contra el servicio real (que el repositorio existe y el token puede escribir en él) en vez
# de contra una expresión regular.

valid_host() {
  case "$1" in
    http://*|https://*|*/*) bad "Escribe solo el host, sin esquema ni rutas."; return 1 ;;
  esac
  printf '%s' "$1" | grep -Eq '^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$' && return 0
  bad "«$1» no parece un host válido."
  return 1
}

valid_port() {
  case "$1" in ''|*[!0-9]*) bad "El puerto tiene que ser un número."; return 1 ;; esac
  { [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; } && return 0
  bad "Puerto fuera de rango."
  return 1
}

valid_k8s_name() {
  printf '%s' "$1" | grep -Eq '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$' && return 0
  bad "«$1» no es un nombre válido de Kubernetes (minúsculas, números y guiones)."
  return 1
}

valid_size() {
  printf '%s' "$1" | grep -Eq '^[0-9]+(Mi|Gi|Ti|M|G|T)$' && return 0
  bad "Tamaño no válido. Usa por ejemplo 20Gi."
  return 1
}

valid_nonempty() { [ -n "$1" ]; }

# ⚠️ El tag de la IMAGEN no lleva `v`; el de git sí. El workflow de publicación normaliza con
# `${RAW#[vV]}` y deja dos nombres para la misma release: `v0.0.0` en git, `0.0.0` en el registro.
# Quien mire `git tag` para saber qué instalar copiará el de git, y el pod quedaría en
# ImagePullBackOff con un `manifest unknown` — que se lee como credenciales mal puestas.
valid_version() {
  case "$1" in
    v*|V*)
      bad "El tag de la imagen va SIN «v»: escribe ${1#[vV]}, no $1."
      hint "El tag de git es v${1#[vV]} y el de la imagen ${1#[vV]}: son dos nombres distintos"
      hint "para la misma release. Con la «v» el pod queda en ImagePullBackOff."
      return 1 ;;
  esac
  printf '%s' "$1" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' && return 0
  case "$1" in sha-*) return 0 ;; esac
  bad "«$1» no es una versión válida. Se espera X.Y.Z (ej: 0.0.0) o sha-<short>."
  return 1
}

# La versión DEL CHART, que no es la de Faro y no admite las mismas formas: no hay `sha-<short>` de
# un chart, solo las versiones publicadas en el índice. Se comprueba antes de construir la URL para
# que un error de tecleo salga como tal y no como un 404 sobre un dominio que parece caído.
valid_chart_version() {
  case "$1" in
    v*|V*) bad "La versión del chart va SIN «v»: escribe ${1#[vV]}, no $1." ; return 1 ;;
  esac
  printf '%s' "$1" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' && return 0
  bad "«$1» no es una versión de chart válida. Se espera X.Y.Z (ej: 0.1.0)."
  return 1
}

# Comprobación de DNS: informativa y nunca bloqueante. Que el DNS no esté propagado a mitad de una
# instalación es normal; que apunte a otro sitio también hay que saberlo, pero no es este script
# quien puede decidirlo. Devuelve 0 resuelve, 1 no resuelve, 2 no hay con qué comprobarlo.
dns_resolves() {
  local host="$1"
  if have getent;   then getent hosts "$host" >/dev/null 2>&1 && return 0 || return 1; fi
  if have dig;      then [ -n "$(dig +short "$host" 2>/dev/null)" ] && return 0 || return 1; fi
  if have host;     then host "$host" >/dev/null 2>&1 && return 0 || return 1; fi
  if have nslookup; then nslookup "$host" >/dev/null 2>&1 && return 0 || return 1; fi
  return 2
}

# ── Generadores ──────────────────────────────────────────────────────────────────────────────
#
# ⚠️ Todos limpian '\r' además de '\n', y no es paranoia: el openssl de MSYS/Git Bash emite CRLF.
# Con solo `tr -d '\n'`, la llave maestra se guardaría en el Secret con un retorno de carro pegado
# al final. El backend la valida como base64 de exactamente 32 bytes y la rechazaría — o peor, la
# aceptaría y cifraría con una llave que no es la que se le mostró al operador. Verificado: en este
# entorno `openssl rand -base64 32` devuelve 45 caracteres, no 44.

gen_key_32() {
  if have openssl; then
    openssl rand -base64 32 | tr -d '\r\n'
  elif [ -r /dev/urandom ]; then
    # head lee primero y termina solo: no hay SIGPIPE que haga saltar `pipefail`.
    head -c 32 /dev/urandom | base64 | tr -d '\r\n'
  else
    die "No hay forma de generar aleatoriedad segura (ni openssl ni /dev/urandom)."
  fi
}

gen_password() {
  if have openssl; then
    openssl rand -base64 18 | tr -d '\r\n=+/'
  else
    head -c 18 /dev/urandom | base64 | tr -d '\r\n=+/'
  fi
}

# El token de acceso inicial. Alfanumérico y sin símbolos a propósito: se copia y se pega a mano en
# una pantalla, y viaja en el cuerpo de una petición; un `+` o un `/` invitan a errores de
# transcripción que se leen como "el token no vale".
gen_token() {
  if have openssl; then
    openssl rand -hex 20 | tr -d '\r\n'
  else
    head -c 20 /dev/urandom | od -An -tx1 | tr -d ' \r\n'
  fi
}

# ── La forma de cada valor ───────────────────────────────────────────────────────────────────
#
# ⚠️⚠️ Esto no es cosmética: es lo que hace que confundir los dos secretos del Secret de arranque
# sea IMPOSIBLE en vez de solo improbable.
#
#   token de acceso inicial   40 caracteres HEXADECIMALES en minúscula.   Sin '='.
#   llave maestra             44 caracteres en BASE64.                    Acaba en '='.
#
# Los dos son cadenas opacas de mucha entropía y se imprimen seguidas en la misma pantalla al
# terminar de instalar. Copiar la equivocada no da ningún error en ninguna parte: el operador
# descubre que «el token no vale» cuando ya está delante del asistente. Que una acabe en '=' y la
# otra no pueda es lo que permite distinguirlas de un vistazo.
#
# El chart comprueba estas MISMAS dos formas antes de escribir nada (secret-bootstrap.yaml), así que
# pasar una donde va la otra aborta la instalación con un mensaje que dice cuál es cuál. Aquí se
# comprueban también, en el sitio donde se generan, para que una divergencia entre el generador del
# script y el del chart salga en la línea que la causa y no dentro de un error de Helm.
valid_token_shape() {
  case "$1" in
    *[!0-9a-f]*) return 1 ;;
  esac
  [ "${#1}" -eq 40 ]
}

valid_key_shape() {
  case "$1" in
    *[!A-Za-z0-9+/=]*) return 1 ;;
    *=) : ;;
    *) return 1 ;;
  esac
  [ "${#1}" -eq 44 ]
}

# Codifica un valor para el campo `data` de un Secret. El mismo cuidado con el '\r': un salto de
# carro dentro del base64 hace que el manifiesto sea inválido o que el valor llegue corrupto.
b64() { printf '%s' "$1" | base64 | tr -d '\r\n'; }

crd_exists() { kubectl get crd "$1" >/dev/null 2>&1; }

# ── Banderas ─────────────────────────────────────────────────────────────────────────────────

usage() {
  cat >&2 <<'EOF'
Instalador de Faro.

  curl -fsSL <url> | bash
  curl -fsSL <url> | bash -s -- [opciones]

Opciones:
  -n, --namespace NS    Namespace de Faro (por defecto se pregunta; default faro)
  -r, --release NAME    Nombre de la release de Helm (por defecto: faro)
      --chart REF       Ruta, .tgz o URL del chart. Por defecto usa el charts/faro que haya
                        junto al script (repositorio clonado), y si no lo descarga de
                        https://get.faro.run
      --chart-version V Versión del chart a descargar (por defecto la que trae el script).
                        No aplica si el chart es local o viene de --chart.
      --dry-run         Comprueba y pregunta todo, pero no crea ni instala nada.
      --skip-checks     Salta las comprobaciones del cluster. No lo uses.
  -y, --yes             No pide confirmación antes de aplicar.
  -h, --help            Esto.

Toda pregunta se puede pre-responder con una variable de entorno del mismo nombre que
aparece en la respuesta. Para una instalación sin terminal:

  FARO_DOMAIN=faro.acme.com FARO_DB_MODE=desplegar \
  curl -fsSL https://get.faro.run | bash -s -- --yes

El proveedor de identidad, el registro de imagenes, el repositorio de GitOps y el
dominio base de las apps ya NO se preguntan aqui: los configura el asistente de
primer arranque, desde la interfaz. El instalador imprime el token con el que se
entra a el.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--namespace) FARO_NAMESPACE="${2:?}"; NAMESPACE_FIXED=1; shift 2 ;;
    -r|--release)   RELEASE="${2:?}";  shift 2 ;;
    --chart)         CHART="${2:?}";         shift 2 ;;
    --chart-version) CHART_VERSION="${2:?}"; shift 2 ;;
    --dry-run)      DRY_RUN=1;         shift ;;
    --skip-checks)  SKIP_CHECKS=1;     shift ;;
    -y|--yes)       ASSUME_YES=1;      shift ;;
    -h|--help)      usage; exit 0 ;;
    *) die "Opción desconocida: $1  (--help para la lista)" ;;
  esac
done

# ⚠️ El chart NO nombra sus objetos con el nombre de la release a secas: usa la convención `fullname`
# de Helm, que antepone el nombre del chart cuando la release no lo contiene ya. Con `--release faro`
# los objetos salen `faro-*`; con `--release prod` salen `prod-faro-*`.
#
# Replicarlo aquí NO es cosmético. Este script busca el secreto de arranque POR NOMBRE para decidir
# si tiene que generar una llave maestra nueva. Buscándolo donde no está, no lo encontraría jamás:
# creería que cada ejecución es una instalación nueva, generaría otra llave y la pasaría como value
# —lo que gana sobre el `lookup` del chart—, ROTANDO la llave y dejando ilegible todo lo cifrado con
# la anterior. Sin un solo error, que es lo peor de todo.
#
# `contains` de sprig pregunta si el nombre de la release contiene el del chart, no al revés.
case "$RELEASE" in
  *faro*) FULLNAME="$RELEASE" ;;
  *)      FULLNAME="${RELEASE}-faro" ;;
esac

# ── Limpieza ─────────────────────────────────────────────────────────────────────────────────

WORKDIR=""
cleanup() { [ -z "$WORKDIR" ] || rm -rf "$WORKDIR"; }
trap cleanup EXIT INT TERM

umask 077
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/faro-install.XXXXXX")"

# =============================================================================================
# 1. COMPROBACIONES PREVIAS
#
# Todas ANTES de preguntar nada. Descubrir a la pregunta doce que falta helm, o que el cluster no
# responde, es peor que no haber empezado: parte del valor de un instalador es no hacerte perder el
# rato.
#
# ⚠️ Aquí NO se comprueban Argo CD ni Argo Rollouts, y es deliberado. Ver la sección 1.bis.
# =============================================================================================

say ""
say "${C_BOLD}  Instalador de Faro${C_RESET}"
say ""

step "Comprobaciones previas"

for tool in kubectl helm; do
  have "$tool" || die "Falta «$tool». Instálalo y vuelve a ejecutar."
done
ok "kubectl y helm encontrados"

HELM_VERSION="$(helm version --template='{{.Version}}' 2>/dev/null || printf '')"
case "$HELM_VERSION" in
  v3.*) ok "helm $HELM_VERSION" ;;
  "")   die "No se pudo determinar la versión de helm." ;;
  *)    die "Hace falta Helm 3; encontrado $HELM_VERSION." ;;
esac

KUBE_CONTEXT="$(kubectl config current-context 2>/dev/null || printf '(desconocido)')"
KUBE_SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || printf '')"

# ⚠️ --request-timeout, y no es un detalle. Contra un servidor que no responde, kubectl espera 32s
# y reintenta: la comprobación tardaría más de un minuto SIN IMPRIMIR NADA, y un instalador que
# parece congelado nada más arrancar se interrumpe con Ctrl-C antes de llegar a decir qué pasa.
#
# Una sola llamada, y además la que ya necesitamos: /version es un ida y vuelta real al API server
# (a diferencia de `kubectl version`, que también imprime la versión del cliente) y nos da de paso
# la versión del servidor, así que no se pagan dos viajes.
say "  Conectando con el cluster (contexto: ${KUBE_CONTEXT})..."
K8S_RAW="$(kubectl get --raw /version --request-timeout=15s 2>/dev/null || printf '')"
if [ -z "$K8S_RAW" ]; then
  die "No hay conexión con el cluster «${KUBE_CONTEXT}»${KUBE_SERVER:+ ($KUBE_SERVER)}.
       Comprueba tu kubeconfig:
         kubectl config current-context
         kubectl config get-contexts"
fi

ok "Cluster alcanzable — contexto ${C_BOLD}${KUBE_CONTEXT}${C_RESET}"
[ -z "$KUBE_SERVER" ] || hint "$KUBE_SERVER"

# La versión sale del JSON de /version, parseada con sed: sin jq, y `kubectl version` no tiene una
# salida estable que se pueda pedir por plantilla.
K8S_MAJOR="$(printf '%s' "$K8S_RAW" | sed -n 's/.*"major"[: ]*"\([0-9]*\)".*/\1/p')"
K8S_MINOR="$(printf '%s' "$K8S_RAW" | sed -n 's/.*"minor"[: ]*"\([0-9]*\)[^"]*".*/\1/p')"
if [ -n "$K8S_MAJOR" ] && [ -n "$K8S_MINOR" ]; then
  if [ "$K8S_MAJOR" -gt 1 ] || { [ "$K8S_MAJOR" -eq 1 ] && [ "$K8S_MINOR" -ge 24 ]; }; then
    ok "Kubernetes v${K8S_MAJOR}.${K8S_MINOR}"
  else
    bad "Kubernetes v${K8S_MAJOR}.${K8S_MINOR} — Faro necesita 1.24 o superior."
    [ -n "$SKIP_CHECKS" ] || die "Versión de Kubernetes insuficiente."
  fi
else
  warn "No se pudo determinar la versión de Kubernetes; se continúa."
fi

if kubectl auth can-i create namespace >/dev/null 2>&1; then
  ok "Permisos suficientes para instalar"
else
  bad "Tu usuario no puede crear namespaces en este cluster."
  hint "El chart crea el namespace de builds, que es un recurso de ámbito de cluster."
  [ -n "$SKIP_CHECKS" ] || die "Permisos insuficientes."
fi

# =============================================================================================
# 1.bis. POR QUÉ AQUÍ *NO* SE COMPRUEBAN ARGO CD NI ARGO ROLLOUTS
#
# Este script llegó a exigirlos en este punto, y estaba mal: era la comprobación de una topología
# que ya no existe.
#
# Argo CD y Argo Rollouts viven en CADA CLUSTER DE WORKLOAD —donde corren las apps—, no en el
# cluster de CONTROL donde se instala Faro. Faro habla con esos clusters usando el kubeconfig
# cifrado que guarda en su base de datos, y crea ahí los Application; con su identidad local no
# necesita ni permisos en un namespace `argocd`, ni que exista. El propio backend lo deja escrito:
# FARO_ARGOCD_NAMESPACE es "el namespace de Argo CD en cada cluster de workload, NO un namespace
# del cluster de Faro".
#
# Consecuencia: exigirlos aquí bloqueaba una instalación perfectamente válida —el caso normal, de
# hecho: un cluster de control limpio, con los workloads en otra parte.
#
# ⚠️ El aviso NO se pierde, solo cambia de sitio: las notas finales dicen que cada cluster de
# workload necesita las dos cosas. Y la verificación de verdad ya existe donde corresponde: el
# backend la hace AL REGISTRAR UN CLUSTER, que es el único momento en que se sabe de qué cluster
# se está hablando.
# =============================================================================================

# Namespace de Argo CD EN LOS CLUSTERS DE WORKLOAD. No se detecta —no hay nada que detectar en este
# cluster— y por eso es un valor global: se asume el mismo nombre en todos los clusters que se
# registren, que es el de la instalación por defecto de Argo. Se sobreescribe por entorno si algún
# cliente lo tiene en otro sitio.
ARGOCD_NS="${FARO_ARGOCD_NAMESPACE:-argocd}"

# --- IngressClass ---
INGRESS_CLASSES="$(kubectl get ingressclass -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || printf '')"
INGRESS_DEFAULT="$(kubectl get ingressclass \
    -o jsonpath='{range .items[?(@.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{end}' 2>/dev/null || printf '')"
if [ -n "$INGRESS_CLASSES" ]; then
  ok "IngressClass disponibles: $(printf '%s' "$INGRESS_CLASSES" | tr '\n' ' ')"
else
  bad "No hay ninguna IngressClass en el cluster."
  hint "El Ingress de Faro se creará y nunca obtendrá dirección: el portal será inalcanzable."
fi

# --- cert-manager ---
CLUSTER_ISSUERS=""
if crd_exists clusterissuers.cert-manager.io; then
  CLUSTER_ISSUERS="$(kubectl get clusterissuers -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || printf '')"
  if [ -n "$CLUSTER_ISSUERS" ]; then
    ok "cert-manager presente. ClusterIssuers: $(printf '%s' "$CLUSTER_ISSUERS" | tr '\n' ' ')"
  else
    warn "cert-manager instalado, pero sin ningún ClusterIssuer."
  fi
else
  warn "cert-manager no detectado."
fi

# =============================================================================================
# 2. EL CHART
# =============================================================================================

step "Localizando el chart"

# ⚠️ TRES ORÍGENES, y el orden es la política: lo que el operador manda, luego lo que tiene al lado,
# y solo si no hay nada, la red.
#
#   --chart                 gana siempre. Es la escapatoria para un chart modificado, un mirror
#                           interno o un .tgz que ya está en disco.
#   el chart de al lado     desarrollo: el repositorio clonado. Se prueba lo que hay en el árbol de
#                           trabajo, no lo publicado, que es justo lo que se quiere al iterar.
#   la descarga             `curl | bash` desde internet, que es el caso normal de un cliente. No
#                           hay repositorio alrededor, así que el chart se trae de $FARO_SITE.
#
# ⚠️ La detección del chart de al lado mira el directorio DEL SCRIPT, no el directorio actual. Con
# `./charts/faro` bastaba con ejecutar el instalador desde otra carpeta del propio repositorio para
# que no lo encontrara y se pusiera a descargar de internet una versión distinta de la que se está
# editando — el fallo más confuso posible mientras se desarrolla el chart.
#
# Con `curl | bash` no hay fichero: BASH_SOURCE vale "bash" o está vacío, no existe como ruta, y la
# detección se salta sola sin necesidad de preguntarle a nadie cómo se está ejecutando.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
fi

# Lo que se escribe en el fichero de valores y se imprime al terminar: la referencia con la que se
# puede REPETIR esta instalación. Con un chart local no hay referencia estable que dar, y el fichero
# lo dice en vez de inventarse una.
CHART_REF=""

if [ -n "$CHART" ]; then
  [ -e "$CHART" ] || case "$CHART" in
    http://*|https://*|oci://*) : ;;
    *) die "El chart indicado con --chart no existe: $CHART" ;;
  esac
  CHART_REF="$CHART"
  ok "Chart: $CHART  ${C_DIM}(--chart)${C_RESET}"
elif [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/charts/faro/Chart.yaml" ]; then
  CHART="$SCRIPT_DIR/charts/faro"
  ok "Chart local: $CHART  ${C_DIM}(repositorio clonado — se instala lo que hay en el árbol de trabajo)${C_RESET}"
elif [ -f "./charts/faro/Chart.yaml" ]; then
  CHART="./charts/faro"
  ok "Chart local: $CHART  ${C_DIM}(directorio actual)${C_RESET}"
else
  CHART_VERSION="${CHART_VERSION:-$CHART_VERSION_DEFAULT}"
  valid_chart_version "$CHART_VERSION" || die "Versión de chart no válida: «$CHART_VERSION».
       Las publicadas están en ${FARO_SITE}/index.yaml"
  CHART_REF="$FARO_SITE/faro-${CHART_VERSION}.tgz"
  say "  Descargando el chart ${CHART_REF}"
  # ⚠️ Se descarga el .tgz y se instala DESDE EL FICHERO, en vez de pasarle la URL a helm. Así la
  # descarga falla aquí —con un mensaje que dice qué versión no está y dónde mirar— y no veinte
  # líneas después, dentro de un error de Helm que habla de repositorios.
  if have curl; then
    curl -fsSL "$CHART_REF" -o "$WORKDIR/faro-chart.tgz" || die "No se pudo descargar el chart ${CHART_VERSION} de $CHART_REF.
       Comprueba que la versión existe — el índice las lista todas:
         ${FARO_SITE}/index.yaml
       O instala desde un repositorio clonado:
         bash install.sh --chart ./charts/faro"
  elif have wget; then
    wget -qO "$WORKDIR/faro-chart.tgz" "$CHART_REF" || die "No se pudo descargar el chart ${CHART_VERSION} de $CHART_REF.
       Las versiones publicadas están en ${FARO_SITE}/index.yaml"
  else
    die "Hace falta curl o wget para descargar el chart, o pásalo con --chart."
  fi
  CHART="$WORKDIR/faro-chart.tgz"
  ok "Chart ${C_BOLD}${CHART_VERSION}${C_RESET} descargado"
fi

# =============================================================================================
# 3. PREGUNTAS
# =============================================================================================

step "Configuración de la instalación"
say ""

# --- Versión ---
#
# ⚠️ SIN la `v`, y el instalador lo valida por eso: el workflow de publicación crea el tag de git
# `vX.Y.Z` y el tag de imagen `X.Y.Z`. Quien mire `git tag` para saber qué instalar copiará el
# primero, y el pod se quedaría en ImagePullBackOff con un `manifest unknown` — un síntoma que se
# lee como credenciales mal puestas, no como una letra de más.
say "  ${C_DIM}Las imágenes se publican en ghcr.io con tags X.Y.Z. No existe «latest»: una${C_RESET}"
say "  ${C_DIM}instalación tiene que poder decir qué versión corre.${C_RESET}"
FARO_VERSION="${FARO_VERSION:-}"
ask FARO_VERSION "Versión de Faro a instalar" "$FARO_VERSION_DEFAULT" valid_version
# Backend y frontend se publican por separado y pueden ir desacoplados; se pregunta una sola versión
# porque es lo normal, y se deja escapatoria por entorno para cuando no lo sea.
BACKEND_TAG="${FARO_BACKEND_TAG:-$FARO_VERSION}"
FRONTEND_TAG="${FARO_FRONTEND_TAG:-$FARO_VERSION}"
say ""

# --- Namespace ---
FARO_NAMESPACE="${FARO_NAMESPACE:-}"
if [ -n "$NAMESPACE_FIXED" ]; then
  valid_k8s_name "$FARO_NAMESPACE" || die "Namespace no válido: $FARO_NAMESPACE"
  ok "Namespace: $FARO_NAMESPACE  ${C_DIM}(--namespace)${C_RESET}"
else
  ask FARO_NAMESPACE "Namespace donde instalar Faro" "$NAMESPACE_DEFAULT" valid_k8s_name
fi
NAMESPACE="$FARO_NAMESPACE"

EXISTING_RELEASE=""
if helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1; then
  EXISTING_RELEASE=1
  warn "Ya existe la release «$RELEASE» en «$NAMESPACE»: esto será una ACTUALIZACIÓN."
fi
say ""

# --- Dominios ---
say "  ${C_BOLD}Dominios${C_RESET}"
say "  ${C_DIM}El portal y la API de Faro van bajo UN SOLO dominio. Las apps que despliegues van${C_RESET}"
say "  ${C_DIM}bajo OTRO, con un comodín. Son dos cosas distintas.${C_RESET}"
FARO_DOMAIN="${FARO_DOMAIN:-}"
ask FARO_DOMAIN "Dominio de Faro (portal y API)" "" valid_domain

DNS_RC=0
dns_resolves "$FARO_DOMAIN" || DNS_RC=$?
case "$DNS_RC" in
  0) ok "$FARO_DOMAIN resuelve" ;;
  1) warn "$FARO_DOMAIN todavía no resuelve."
     hint "Tiene que apuntar a la IP de tu Ingress ANTES de que cert-manager intente emitir el"
     hint "certificado, o el reto HTTP-01 falla y el Secret del certificado no llega a existir." ;;
  *) : ;;
esac

# ⚠️ El dominio base de las APPS ya no se pregunta aquí: lo pide el asistente. Éste es el único
# dominio que el instalador necesita saber, y por eso no se pudo mover — el Ingress tiene que
# enrutar este host ANTES de que Faro exista, así que Faro no puede ser quien lo diga.
say ""

# --- TLS ---
say "  ${C_BOLD}TLS${C_RESET}"
FARO_TLS_MODE="${FARO_TLS_MODE:-}"
FARO_CERT_ISSUER="${FARO_CERT_ISSUER:-}"
FARO_TLS_SECRET="${FARO_TLS_SECRET:-}"

if [ -n "$CLUSTER_ISSUERS" ]; then
  ask_choice FARO_TLS_MODE "¿Cómo se emite el certificado?" "cert-manager" "cert-manager" "propio" "ninguno"
else
  say "  ${C_DIM}Sin cert-manager con ClusterIssuers en este cluster.${C_RESET}"
  ask_choice FARO_TLS_MODE "¿Cómo se emite el certificado?" "propio" "propio" "ninguno"
fi

TLS_ENABLED="false"; TLS_SECRET="faro-tls"; SCHEME="http"
case "$FARO_TLS_MODE" in
  cert-manager)
    # shellcheck disable=SC2206
    ISSUER_OPTS=($CLUSTER_ISSUERS)
    ask_choice FARO_CERT_ISSUER "ClusterIssuer" "${ISSUER_OPTS[0]}" "${ISSUER_OPTS[@]}"
    TLS_ENABLED="true"; SCHEME="https"
    # ⚠️ Este nombre viaja a DOS clusters. Aquí emite el certificado del portal; y va también a
    # FARO_CERT_MANAGER_ISSUER, con el que Faro anota los Ingress de las apps EN CADA CLUSTER DE
    # WORKLOAD. Los ClusterIssuer que se acaban de listar son los de ESTE cluster: que exista uno
    # con el mismo nombre en los de destino no se puede comprobar desde aquí.
    hint "Este mismo issuer se usará para los certificados de las apps, así que tiene que existir"
    hint "con el mismo nombre en cada cluster de workload. Si no, esas apps irán por HTTP." ;;
  propio)
    ask FARO_TLS_SECRET "Nombre del Secret TLS (kubernetes.io/tls) en el namespace $NAMESPACE" "faro-tls" valid_k8s_name
    TLS_SECRET="$FARO_TLS_SECRET"; TLS_ENABLED="true"; SCHEME="https"
    if ! kubectl get secret "$TLS_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
      warn "El Secret «$TLS_SECRET» todavía no existe en «$NAMESPACE»."
      hint "Créalo antes de que nadie use la URL, o el Ingress servirá un certificado inválido."
    fi ;;
  ninguno)
    warn "Faro se servirá por HTTP."
    hint "La cookie de sesión no se marcará Secure, y la mayoría de proveedores de identidad"
    hint "rechazan un redirect URI http:// que no sea localhost. No sirve para producción." ;;
esac

FARO_INGRESS_CLASS="${FARO_INGRESS_CLASS:-}"
ask_opt FARO_INGRESS_CLASS "IngressClass" "${INGRESS_DEFAULT:-$(printf '%s' "$INGRESS_CLASSES" | head -n1)}"
say ""

# --- Base de datos ---
say "  ${C_BOLD}Base de datos${C_RESET}"
FARO_DB_MODE="${FARO_DB_MODE:-}"
ask_choice FARO_DB_MODE "¿La despliega el instalador, o usas una externa?" "desplegar" "desplegar" "externa"

FARO_DB_HOST="${FARO_DB_HOST:-}"
FARO_DB_PORT="${FARO_DB_PORT:-}"
FARO_DB_USER="${FARO_DB_USER:-}"
FARO_DB_PASSWORD="${FARO_DB_PASSWORD:-}"
FARO_DB_STORAGE="${FARO_DB_STORAGE:-}"
FARO_DB_STORAGE_CLASS="${FARO_DB_STORAGE_CLASS:-}"

if [ "$FARO_DB_MODE" = "desplegar" ]; then
  # ⚠️ La StorageClass por defecto solo importa si vamos a pedir un volumen, así que la comprobación
  # va aquí y no arriba: sin ella el PVC se queda en Pending PARA SIEMPRE y el síntoma es un
  # StatefulSet a 0/1 sin un solo error en los registros del contenedor.
  SC_DEFAULT="$(kubectl get storageclass \
      -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{end}' 2>/dev/null || printf '')"
  if [ -n "$SC_DEFAULT" ]; then
    ok "StorageClass por defecto: $SC_DEFAULT"
  else
    SC_ALL="$(kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || printf '')"
    bad "No hay ninguna StorageClass marcada como POR DEFECTO en este cluster."
    hint "El volumen de Postgres se quedaría en Pending para siempre y el pod nunca arrancaría."
    hint "El síntoma es un StatefulSet a 0/1 sin ningún error en los registros."
    if [ -n "$SC_ALL" ]; then
      say ""
      say "  ${C_DIM}Disponibles: $(printf '%s' "$SC_ALL" | tr '\n' ' ')${C_RESET}"
      ask FARO_DB_STORAGE_CLASS "StorageClass para el volumen de Postgres" "$(printf '%s' "$SC_ALL" | head -n1)" valid_k8s_name
    else
      die "El cluster no tiene ninguna StorageClass. Configura almacenamiento, o usa una base de datos externa."
    fi
  fi
  ask FARO_DB_STORAGE "Tamaño del volumen de Postgres" "20Gi" valid_size
  FARO_DB_USER="${FARO_DB_USER:-faro}"
  FARO_DB_PORT="5432"
  if [ -z "$FARO_DB_PASSWORD" ]; then
    FARO_DB_PASSWORD="$(gen_password)"
    ok "Contraseña de Postgres generada"
  fi
else
  # ⚠️ Dirección, usuario y contraseña. NADA MÁS: el NOMBRE de la base es siempre `faro`, fijo en el
  # chart. Una pregunta menos y un valor menos que se puede escribir mal — un nombre equivocado no
  # falla al instalar, falla al arrancar con un error de conexión que no dice qué pasó.
  ask FARO_DB_HOST "Host de la base de datos" "" valid_host
  ask FARO_DB_PORT "Puerto" "5432" valid_port
  ask FARO_DB_USER "Usuario" "faro" valid_nonempty
  ask_secret FARO_DB_PASSWORD "Contraseña"
  hint "La base tiene que llamarse «faro»."
  warn "El usuario necesita poder ejecutar: CREATE EXTENSION IF NOT EXISTS \"pgcrypto\""
  hint "Lo hace la primera migración de Faro. Si tu Postgres no lo permite, créala antes a mano."
fi
say ""

# ⚠️ AQUÍ YA NO SE PREGUNTA: el proveedor de identidad y sus credenciales, el registro donde Faro
# publica lo que construye, el repositorio de GitOps con su token, y el dominio base de las apps.
#
# Las cuatro las captura el ASISTENTE DE PRIMER ARRANQUE, desde la propia interfaz, y viven en la
# base de datos. No es una simplificación cosmética: el backend RETIRÓ esas variables de entorno, así
# que preguntarlas aquí y ponerlas en el chart no tendría ningún efecto — daría la impresión de haber
# configurado algo. Y el asistente puede hacer algo que el instalador no: validarlas contra el
# servicio real antes de guardarlas (que el repo de GitOps existe y el token puede escribir en él,
# que las credenciales del proveedor son buenas) en vez de descubrirlo en el primer despliegue.
#
# Se entra al asistente con el token de acceso inicial que se genera más abajo.

# --- Descarga de las imágenes de Faro ---
#
# ⚠️ YA NO SE PREGUNTA NADA, y no es una simplificación cosmética: es lo que hace posible el
# `curl -fsSL https://get.faro.run | bash`.
#
# Los paquetes de ghcr.io/syntax-company son PÚBLICOS, así que el cluster se baja las imágenes sin
# credenciales. Antes se pedían aquí un usuario de GitHub y un PAT con `read:packages`, y eso
# rompía la experiencia entera: una orden de una línea que a mitad te manda a la web de GitHub a
# fabricar un token es exactamente igual de larga que la instalación manual que quería sustituir.
#
# El chart tampoco crea ya ningún Secret de descarga. Queda `imagePullSecret.mode=existing` para
# quien haya replicado las imágenes en un registro propio que sí pida credenciales, pero eso es un
# caso que se configura a mano y no una pregunta del camino normal.

# =============================================================================================
# 4. RESUMEN Y CONFIRMACIÓN
# =============================================================================================

step "Resumen"
say ""
say "  Cluster           ${C_BOLD}${KUBE_CONTEXT}${C_RESET}"
say "  Namespace         ${NAMESPACE}"
say "  Release           ${RELEASE}$( [ -n "$EXISTING_RELEASE" ] && printf ' (actualización)' || printf ' (instalación nueva)' )"
say "  Versión           ${BACKEND_TAG} backend / ${FRONTEND_TAG} frontend"
say "  Chart             ${CHART_REF:-$CHART ${C_DIM}(local)${C_RESET}}"
say "  Faro              ${SCHEME}://${FARO_DOMAIN}"
case "$FARO_TLS_MODE" in
  cert-manager) say "  TLS               cert-manager — ${FARO_CERT_ISSUER}" ;;
  propio)       say "  TLS               certificado propio en el Secret ${TLS_SECRET}" ;;
  *)            say "  TLS               ${C_YELLOW}ninguno (HTTP)${C_RESET}" ;;
esac
say "  Ingress           ${FARO_INGRESS_CLASS:-(la del cluster por defecto)}"
if [ "$FARO_DB_MODE" = "desplegar" ]; then
  say "  Base de datos     desplegada por el chart — volumen ${FARO_DB_STORAGE}${FARO_DB_STORAGE_CLASS:+ (${FARO_DB_STORAGE_CLASS})}"
else
  say "  Base de datos     externa — ${FARO_DB_HOST}:${FARO_DB_PORT}/faro"
fi
say ""
say "  ${C_DIM}El proveedor de identidad, el registro de imágenes, el repositorio de GitOps y el${C_RESET}"
say "  ${C_DIM}dominio base de las apps se configuran DESPUÉS, en el asistente de primer arranque.${C_RESET}"
say ""

if [ -n "$DRY_RUN" ]; then
  warn "--dry-run: no se ha creado ni instalado nada."
  exit 0
fi

confirm_or_die "¿Instalar Faro con esta configuración?"

# =============================================================================================
# 5. LA LLAVE MAESTRA Y EL ACCESO INICIAL
#
# ⚠️ CAMBIO respecto a antes: los Secrets los crea EL CHART, no este script.
#
# El motivo salió probando la instalación a mano. El Secret de la llave maestra había que crearlo
# aparte con `kubectl create secret`, y olvidarlo dejaba la instalación a medias con un
# `CreateContainerConfigError` que no menciona en ningún sitio el comando que falta. Ahora se le dan
# los valores al chart y él lo crea: quien instale con `helm install` a pelo obtiene lo mismo que
# quien use este script, sin un paso previo que nadie documenta en el sitio donde se echa de menos.
#
# Lo que este script sí hace es GENERAR los dos valores que nadie puede inventarse:
#
#   · la llave maestra          32 bytes aleatorios. NUNCA se regenera si ya existe.
#   · el token de acceso inicial  con el que se entra la primera vez, antes de que haya proveedor
#                                 de identidad, para completar el asistente.
#
# Los dos van al MISMO Secret, que es donde el backend los espera.
#
# Y los secretos NO viajan por la línea de órdenes ni por el fichero de valores que queda en disco:
# van en un values aparte, dentro del directorio temporal, que se borra al salir.
# =============================================================================================

step "Preparando los secretos"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
ok "Namespace $NAMESPACE"

# ⚠️ DOS DECISIONES DISTINTAS, Y CON DISCRIMINANTES DISTINTOS. Antes eran una sola —«¿existe el
# Secret?»— y esa pregunta es la correcta para la llave y la EQUIVOCADA para el token.
#
# El Secret lleva `resource-policy: keep`: sobrevive a un `helm uninstall`. Encontrárselo NO
# significa «esto es una actualización», significa «aquí hubo algo alguna vez». Decidiendo el token
# con esa pregunta, una instalación NUEVA sobre los restos de otra heredaba el token de la anterior:
# un acceso que ya circuló, que alguien pudo apuntar, y que abre el asistente de la instalación
# nueva. El discriminante del token es la RELEASE (EXISTING_RELEASE, más arriba): eso sí distingue
# actualizar de instalar.
#
#   LA LLAVE MAESTRA   ¿existe el Secret?   → nunca se regenera si ya está. Regenerarla dejaría la
#                      base de datos intacta y completamente ilegible: los tokens, los accesos a
#                      clusters y las credenciales del proveedor están cifrados con la anterior. Es
#                      el único punto irreversible de esta instalación, y da igual que la release ya
#                      no exista: el volumen de la base también sobrevive a un uninstall, así que
#                      los datos cifrados con ella pueden seguir ahí.
#
#   EL TOKEN           ¿existe la release?  → en una ACTUALIZACIÓN se conserva: rotarlo en cada
#                      upgrade dejaría inservible el que el operador apuntó. En una instalación
#                      NUEVA se genera otro y se sobrescribe el que hubiera heredado.
BOOTSTRAP_SECRET="${FULLNAME}-bootstrap"
KEY_REUSED=""
CREDENTIAL_KEY=""
BOOTSTRAP_TOKEN=""
TOKEN_RETIRED=""

if kubectl get secret "$BOOTSTRAP_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  KEY_REUSED=1
  ok "Llave maestra: ya existía, se reutiliza ${C_DIM}(regenerarla dejaría ilegible lo ya cifrado)${C_RESET}"
else
  CREDENTIAL_KEY="$(gen_key_32)"
  valid_key_shape "$CREDENTIAL_KEY" || die "La llave maestra generada no tiene la forma esperada
       (44 caracteres en base64 acabados en '='). Es el contrato con el chart y con el backend;
       instalar con algo distinto dejaría el arranque fallando sin decir por qué."
  ok "Llave maestra generada"
fi

if [ -n "$EXISTING_RELEASE" ]; then
  # Actualización: se conserva el que haya. Puede seguir puesto (asistente sin terminar) o estar ya
  # retirado, y las dos cosas se respetan tal cual.
  BOOTSTRAP_TOKEN="$(kubectl get secret "$BOOTSTRAP_SECRET" -n "$NAMESPACE" \
      -o jsonpath='{.data.FARO_BOOTSTRAP_TOKEN}' 2>/dev/null | base64 -d 2>/dev/null || printf '')"
  if [ -n "$BOOTSTRAP_TOKEN" ]; then
    ok "Token de acceso inicial: se conserva el de la instalación existente"
  else
    # ⚠️ Vacío o ausente = la puerta ya se cerró. Y aquí NO basta con callarse: el `lookup` del chart
    # no distingue «no lo encuentro» de «está vacío», y en los dos casos GENERA uno nuevo, reabriendo
    # el acceso inicial de una instalación que ya pasó por el asistente. Conservar el estado retirado
    # hay que decirlo explícitamente.
    TOKEN_RETIRED=1
    ok "Token de acceso inicial: ya estaba retirado, se mantiene así"
  fi
else
  BOOTSTRAP_TOKEN="$(gen_token)"
  valid_token_shape "$BOOTSTRAP_TOKEN" || die "El token de acceso inicial generado no tiene la forma
       esperada (40 caracteres hexadecimales). Es la misma forma que comprueba el chart, así que
       instalar con algo distinto abortaría en Helm."
  if [ -n "$KEY_REUSED" ]; then
    ok "Token de acceso inicial NUEVO ${C_DIM}(instalación nueva: se sobrescribe el heredado)${C_RESET}"
  else
    ok "Token de acceso inicial generado"
  fi
fi

# =============================================================================================
# 6. VALUES Y HELM
# =============================================================================================

step "Instalando"

# El namespace de builds puede existir ya: hasta ahora había que crearlo a mano. Si existe y no lo
# gestiona esta release, el chart no debe intentar crearlo — `helm install` abortaría con
# "already exists" después de haber creado todo lo demás.
CREATE_BUILD_NS="true"
if kubectl get namespace "$BUILD_NAMESPACE" >/dev/null 2>&1; then
  OWNER="$(kubectl get namespace "$BUILD_NAMESPACE" \
             -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null || printf '')"
  if [ "$OWNER" != "$RELEASE" ]; then
    CREATE_BUILD_NS="false"
    warn "El namespace $BUILD_NAMESPACE ya existe: el chart no intentará crearlo."
  fi
fi

# Dos ficheros de valores, y la separación es el punto:
#
#   VALUES_FILE   la configuración. SIN un solo secreto. Se copia al directorio del usuario y es lo
#                 único que hace falta para actualizar después.
#   SECRETS_FILE  solo los secretos. Vive en el directorio temporal y se borra al salir.
#
# Helm admite varios `--values`, así que no hay que duplicar nada. Y en un `helm upgrade` posterior
# el segundo fichero no hace falta: el chart recupera los secretos que ya están en el cluster.
VALUES_FILE="$WORKDIR/values.yaml"
SECRETS_FILE="$WORKDIR/secrets.yaml"

# ⚠️ QUÉ CHART SE USÓ, escrito en el fichero que queda en disco. Es media respuesta a «¿se puede
# repetir esta instalación?»: sin esto, el fichero de valores dice cómo se configuró Faro pero no
# con qué versión del chart, y dentro de seis meses no hay forma de reproducirla.
#
# Con un chart descargado la referencia es una URL con la versión dentro, que sirve tal cual para
# volver a instalar exactamente lo mismo — `helm` acepta una URL a un .tgz igual que una ruta. Con
# un chart local no existe esa referencia y el fichero lo dice en vez de inventarse una: apuntar a
# una ruta del disco de quien instaló no le vale a nadie más.
if [ -n "$CHART_REF" ]; then
  CHART_RECORD="$CHART_REF"
  UPGRADE_CMD="helm upgrade ${RELEASE} ${CHART_REF} -n ${NAMESPACE} -f ${VALUES_OUT}"
else
  CHART_RECORD="chart local ($CHART) — no reproducible desde otra máquina"
  UPGRADE_CMD="helm upgrade ${RELEASE} <ruta-o-url-del-chart> -n ${NAMESPACE} -f ${VALUES_OUT}"
fi

{
  cat <<YAML
# Configuración de esta instalación de Faro, generada por install.sh.
#
# NO contiene ningún secreto: la llave maestra y el token de acceso inicial viven en el Secret
# «${BOOTSTRAP_SECRET}» del namespace ${NAMESPACE} y la contraseña de la base en «${FULLNAME}-app».
# Un \`helm upgrade\` con este fichero los recupera del cluster sin que haya que volver a tenerlos a
# mano.
#
# Chart usado en esta instalación: ${CHART_RECORD}
#
# Guárdalo: es lo único que hace falta para actualizar.
#
#   ${UPGRADE_CMD}
#
# ⚠️ Lo que NO está aquí y no es un olvido: el proveedor de identidad, el registro donde Faro publica
# lo que construye, el repositorio de GitOps y el dominio base de las apps. Eso se configura en el
# asistente de primer arranque y vive en la base de datos; ponerlo aquí no tendría ningún efecto.

global:
  domain: "${FARO_DOMAIN}"

images:
  backend:
    tag: "${BACKEND_TAG}"
  frontend:
    tag: "${FRONTEND_TAG}"

# Sin bloque `imagePullSecret`: los paquetes de las imágenes son públicos y el chart no crea ningún
# Secret de descarga. Si algún día las replicas en un registro privado, añade aquí:
#   imagePullSecret:
#     mode: existing
#     existingSecret: <el Secret docker-registry que hayas creado en el namespace de Faro>

ingress:
  className: "${FARO_INGRESS_CLASS}"
  tls:
    enabled: ${TLS_ENABLED}
    secretName: "${TLS_SECRET}"

certManager:
  issuer: "${FARO_CERT_ISSUER}"

database:
YAML
  if [ "$FARO_DB_MODE" = "desplegar" ]; then
    cat <<YAML
  deploy: true
  username: "${FARO_DB_USER}"
  persistence:
    enabled: true
    size: "${FARO_DB_STORAGE}"
    storageClassName: "${FARO_DB_STORAGE_CLASS}"
YAML
  else
    cat <<YAML
  deploy: false
  host: "${FARO_DB_HOST}"
  port: ${FARO_DB_PORT}
  username: "${FARO_DB_USER}"
YAML
  fi

  cat <<YAML

build:
  namespace: "${BUILD_NAMESPACE}"
  createNamespace: ${CREATE_BUILD_NS}

argocd:
  namespace: "${ARGOCD_NS}"
  project: default
YAML
} > "$VALUES_FILE"

# ⚠️ Solo los secretos, y solo los que hagan falta. La llave y el token ya NO se escriben juntos,
# porque ya no se deciden juntos (ver la sección 5).
{
  printf '# Generado por install.sh. Se borra al salir. NO lo guardes.\n'
  # La llave: solo si se acaba de generar. En una reinstalación va ausente a propósito —el chart
  # recupera del cluster la que ya existe—; escribirla aquí sería la única forma de rotarla sin
  # querer, y rotarla es irreversible.
  if [ -n "$CREDENTIAL_KEY" ]; then
    printf 'credentialKey:\n  value: "%s"\n' "$CREDENTIAL_KEY"
  fi
  # El token: al revés. Se pasa SIEMPRE que haya uno, también en una instalación nueva sobre un
  # Secret heredado, y ahí es justamente donde hace falta: si no le dan un value, el `lookup` del
  # chart recupera el token de la instalación anterior. El value gana sobre el lookup
  # (faro.secretValue), y el `stringData` del Secret sobrescribe la clave que hubiera.
  if [ -n "$TOKEN_RETIRED" ]; then
    printf 'bootstrapToken:\n  disabled: true\n'
  elif [ -n "$BOOTSTRAP_TOKEN" ]; then
    printf 'bootstrapToken:\n  value: "%s"\n' "$BOOTSTRAP_TOKEN"
  fi
  printf 'database:\n  password: "%s"\n' "$FARO_DB_PASSWORD"
} > "$SECRETS_FILE"

if [ -f "$VALUES_OUT" ]; then
  cp "$VALUES_OUT" "${VALUES_OUT}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
fi
if cp "$VALUES_FILE" "$VALUES_OUT" 2>/dev/null; then
  ok "Configuración guardada en $VALUES_OUT ${C_DIM}(sin secretos)${C_RESET}"
else
  warn "No se pudo escribir $VALUES_OUT (sin permisos aquí); la instalación continúa."
fi

say "  Ejecutando helm upgrade --install"
hint "El primer arranque migra el esquema de la base de datos: puede tardar varios minutos."
say ""

HELM_OK=""
if helm upgrade --install "$RELEASE" "$CHART" \
      --namespace "$NAMESPACE" \
      --values "$VALUES_FILE" \
      --values "$SECRETS_FILE" \
      --wait --timeout 15m; then
  HELM_OK=1
fi

if [ -z "$HELM_OK" ]; then
  say ""
  bad "Helm no terminó correctamente."
  # ⚠️ Si la llave se acaba de generar, se imprime AQUÍ TAMBIÉN. El fichero de secretos se borra al
  # salir, así que si Helm llegó a crear el Secret pero falló después, ésta es la única oportunidad
  # de verla sin ir a buscarla al cluster. Y si no llegó a crearlo, no se ha cifrado nada con ella:
  # volver a ejecutar el instalador genera otra sin consecuencias.
  if [ -n "$CREDENTIAL_KEY" ]; then
    say ""
    say "  ${C_BOLD}${C_RED}⚠️  Anota la llave maestra por si la instalación llegó a crearla:${C_RESET}"
    say "      ${C_BOLD}${CREDENTIAL_KEY}${C_RESET}"
    say ""
  fi
  # El token va en su propio `if`: en una instalación nueva sobre un Secret heredado la llave se
  # reutiliza (no se imprime) pero el token es NUEVO, y si Helm alcanzó a escribirlo, el que el
  # operador tuviera apuntado ya no vale. Sin esto, ese caso se quedaba sin imprimir nada.
  if [ -n "$BOOTSTRAP_TOKEN" ] && [ -z "$EXISTING_RELEASE" ]; then
    say "  ${C_DIM}Token de acceso inicial (nuevo): ${BOOTSTRAP_TOKEN}${C_RESET}"
    say ""
  fi
  hint "Para ver qué pasa:"
  hint "  kubectl -n $NAMESPACE get pods"
  hint "  kubectl -n $NAMESPACE logs deploy/${FULLNAME}-backend --tail=50"
  hint ""
  hint "Para reintentar: vuelve a ejecutar este instalador. La release queda registrada aunque haya"
  hint "fallado, así que el reintento cuenta como ACTUALIZACIÓN: la llave y el token se conservan"
  hint "tal cual. Si el Secret ni siquiera llegó a crearse, se generan otros y no se pierde nada,"
  hint "porque todavía no se ha cifrado nada con ellos."
  exit 1
fi

# =============================================================================================
# 7. QUÉ QUEDÓ INSTALADO
# =============================================================================================

say ""
step "Faro está instalado"
say ""
kubectl -n "$NAMESPACE" get pods --no-headers 2>/dev/null | sed 's/^/  /' >&2 || true
say ""
rule
say "  ${C_BOLD}Portal y API${C_RESET}"
say "      ${C_BOLD}${SCHEME}://${FARO_DOMAIN}${C_RESET}"
rule

# ── El acceso inicial ────────────────────────────────────────────────────────────────────────
#
# Es lo primero que hay que hacer y lo único que desbloquea el resto: sin proveedor de identidad no
# hay forma de hacer login, así que este token es la única puerta.
if [ -n "$BOOTSTRAP_TOKEN" ]; then
  say ""
  say "  ${C_BOLD}${C_YELLOW}1. ENTRA Y COMPLETA EL ASISTENTE${C_RESET}"
  say ""
  say "      ${C_BOLD}${SCHEME}://${FARO_DOMAIN}/setup${C_RESET}"
  say ""
  say "      Token de acceso inicial ${C_DIM}(40 hexadecimales — NO acaba en '=')${C_RESET}:"
  say ""
  say "        ${C_BOLD}${BOOTSTRAP_TOKEN}${C_RESET}"
  say ""
  # ⚠️ La forma va pegada al valor, en las dos pantallas. Más abajo se imprime la llave maestra, que
  # es la otra cadena opaca de esta misma salida, y copiar la equivocada no da ningún error: el
  # asistente simplemente no abre. Decir «40 hexadecimales / acaba en '='» al lado de cada una es lo
  # que convierte ese fallo en algo que se ve antes de pegarlo.
  say "      ${C_DIM}Es el valor corto y hexadecimal. Si lo que copiaste acaba en '=', es la llave${C_RESET}"
  say "      ${C_DIM}maestra de más abajo, no esto.${C_RESET}"
  say ""
  say "      Todavía no hay proveedor de identidad, así que no hay forma de hacer login:"
  say "      este token es la única puerta y da una sesión limitada a configurar."
  say ""
  say "      El asistente pide lo que este instalador ya no pregunta —el proveedor de"
  say "      identidad con sus credenciales, el registro de imágenes, el repositorio de"
  say "      GitOps y el dominio base de las apps— y los valida contra el servicio real"
  say "      antes de guardarlos."
  say ""
  say "      ⚠️  La URL de retorno que hay que registrar en tu proveedor la muestra el"
  say "          propio asistente. No puede decirla este instalador: depende de qué"
  say "          proveedor elijas, y eso se elige ahí."
  say ""
  say "      ${C_DIM}Retíralo cuando termines:${C_RESET}"
  say "      ${C_DIM}  ${UPGRADE_CMD} --set bootstrapToken.disabled=true${C_RESET}"
  say "      ${C_DIM}No es urgente: se cierra solo cuando un login real funcione, y caduca a las 24h.${C_RESET}"
  say ""
  rule
elif [ -n "$TOKEN_RETIRED" ]; then
  say ""
  say "  ${C_BOLD}Acceso inicial${C_RESET}"
  say "      Ya no está en el Secret: esta instalación pasó por el asistente y la puerta"
  say "      se cerró. Se entra por el proveedor de identidad configurado. Esta"
  say "      actualización NO lo ha reabierto."
  say ""
  rule
fi

if [ -z "$KEY_REUSED" ]; then
  say ""
  say "  ${C_BOLD}${C_RED}2. ⚠️  LA LLAVE MAESTRA — GUÁRDALA AHORA${C_RESET}"
  say ""
  say "      ${C_BOLD}${CREDENTIAL_KEY}${C_RESET}"
  say ""
  say "      ${C_DIM}44 caracteres en base64, acaba en '='. NO es el token de arriba: esto no${C_RESET}"
  say "      ${C_DIM}abre el asistente, y el token no descifra nada.${C_RESET}"
  say ""
  say "      Cifra TODO lo que Faro custodia: los tokens de acceso a repositorios, los"
  say "      accesos a los clusters, las credenciales del proveedor de identidad que"
  say "      captures en el asistente y los secretos de las aplicaciones."
  say ""
  say "      ${C_BOLD}Si se pierde, ese material es irrecuperable.${C_RESET} No hay copia ni forma de"
  say "      rescatarlo: la base de datos seguirá viva y será completamente ilegible."
  say ""
  say "      Cópiala a tu gestor de secretos antes de cerrar esta terminal."
  say ""
  say "      ${C_DIM}Vive en el Secret «${BOOTSTRAP_SECRET}» del namespace ${NAMESPACE}, con${C_RESET}"
  say "      ${C_DIM}resource-policy: keep — un «helm uninstall» no se la lleva.${C_RESET}"
  say ""
  say "      ${C_DIM}Para respaldar Faro hacen falta las dos cosas, esta llave y la base de datos.${C_RESET}"
  say "      ${C_DIM}Una sin la otra no sirve de nada.${C_RESET}"
else
  say ""
  say "  ${C_BOLD}Llave maestra${C_RESET}"
  say "      Se reutilizó la que ya había en el Secret «${BOOTSTRAP_SECRET}». No se ha"
  say "      regenerado: eso habría dejado ilegible todo lo ya cifrado."
fi
say ""
rule
say ""
say "  ${C_BOLD}Lo siguiente${C_RESET}"
say ""
say "   · Completa el asistente en ${SCHEME}://${FARO_DOMAIN}/setup"
say "   · Registra tus clusters de workload desde el portal, en Clusters."
say ""
rule
say ""
# ⚠️ El aviso que antes era una comprobación previa (equivocada) de este cluster. Va aquí porque es
# lo único cierto que se puede decir sin saber todavía a qué clusters va a desplegar el cliente.
say "  ${C_BOLD}${C_YELLOW}⚠️  Cada cluster de workload necesita Argo CD y Argo Rollouts${C_RESET}"
say ""
say "      Faro NO despliega las apps por su cuenta: escribe los manifiestos en el"
say "      repositorio de GitOps y crea un Application de Argo CD ${C_BOLD}en el cluster de${C_RESET}"
say "      ${C_BOLD}destino${C_RESET}. Este cluster de control no los necesita — por eso el instalador"
say "      no los ha comprobado."
say ""
say "      En cada cluster donde vayas a desplegar:"
say ""
say "      ${C_DIM}kubectl create namespace ${ARGOCD_NS}${C_RESET}"
say "      ${C_DIM}kubectl apply -n ${ARGOCD_NS} -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml${C_RESET}"
say "      ${C_DIM}kubectl create namespace argo-rollouts${C_RESET}"
say "      ${C_DIM}kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml${C_RESET}"
say ""
say "      Sin Argo CD, el despliegue falla con un error que no lo nombra. Sin Argo"
say "      Rollouts, se queda en curso para siempre: no falla y no termina."
say ""
say "      Faro lo comprueba al REGISTRAR el cluster y te avisa entonces, que es el"
say "      primer momento en que se sabe de qué cluster se trata."
say ""
if [ "$ARGOCD_NS" != "argocd" ]; then
  say "      ${C_DIM}Esta instalación espera Argo CD en el namespace «${ARGOCD_NS}» de cada cluster.${C_RESET}"
  say ""
fi
rule
say ""
say "  ${C_DIM}Actualizar:  ${UPGRADE_CMD}${C_RESET}"
say "  ${C_DIM}Estado:      kubectl -n $NAMESPACE get pods${C_RESET}"
say "  ${C_DIM}Registros:   kubectl -n $NAMESPACE logs deploy/${FULLNAME}-backend -f${C_RESET}"
say ""
