# faro-installer

El Helm chart de **Faro**: despliega `faro-backend`, `faro-frontend` y su base de datos sobre un
cluster de Kubernetes **que ya existe**.

```
charts/faro/          el chart
example-values.yaml   plantilla para copiar y rellenar
```

> **Estado.** El chart está escrito pero **nunca se ha instalado**: no se ha ejecutado `helm lint`,
> `helm template` ni `helm install` contra ningún cluster.
> Ver [Lo que falta para instalarlo de verdad](#lo-que-falta-para-instalarlo-de-verdad).

> **Versión.** El chart instala por defecto la `appVersion` **0.0.0**, que es la release publicada
> de `faro-backend` y `faro-frontend`.
> ⚠️ El tag de la imagen va **sin `v`**: en git la release es `v0.0.0` y en el registro es `0.0.0`.
> El workflow de publicación normaliza con `${RAW#[vV]}` y deja dos nombres para la misma cosa.
> Copiar el de `git tag` da un `ImagePullBackOff` con `manifest unknown`, que se lee como un
> problema de credenciales y no como una letra de más.

---

## Dos clusters, y no piden lo mismo

⚠️ **Faro no despliega donde vive.** Distinguir los dos papeles evita la mitad de los malentendidos
de esta instalación:

| | Qué es | Qué corre ahí |
|---|---|---|
| **Cluster de control** | donde instalas Faro con este chart | `faro-backend`, `faro-frontend`, su Postgres y los builds de kaniko |
| **Clusters de workload** | donde Faro despliega las apps de tus equipos | Argo CD, Argo Rollouts y las apps |

Faro habla con los clusters de workload usando el kubeconfig cifrado que guarda en su base de datos,
y crea el `Application` de Argo **allí**. Con su identidad local no toca nada fuera del namespace de
builds. Pueden ser el mismo cluster físico, pero los requisitos siguen siendo de cada papel.

### Lo que necesita el cluster de control

Faro **no instala infraestructura**. Antes de instalar tienen que existir, puestos por tu equipo:

| Pieza | Obligatoria | Qué pasa si falta |
|---|---|---|
| Kubernetes ≥ 1.24 | ✅ | — |
| Controlador de **Ingress** con su IngressClass | ✅ | El Ingress se crea y nunca obtiene dirección |
| **StorageClass** por defecto | ✅ si `database.deploy=true` | El PVC queda en `Pending` y Postgres no arranca |
| **Registro de imágenes** alcanzable desde el cluster | ✅ | Los builds empujan a un host que no existe |
| **DNS**: `faro.tudominio.com` + comodín `*.apps.tudominio.com` | ✅ | Sin el primero no hay certificado; sin el comodín las apps quedan inalcanzables |
| **cert-manager ≥ 1.15** + ClusterIssuer | 🟡 opcional | Sin él, HTTP plano. ⚠️ Con una versión < 1.15 es **peor que no tenerlo**: los Secrets de certificado nacen sin etiquetar y quedan huérfanos para siempre |
| **PostgreSQL** externo con permiso para `CREATE EXTENSION pgcrypto` | 🟡 solo si `database.deploy=false` | Flyway falla en la primera migración |

⚠️ **Argo CD y Argo Rollouts NO están en esta tabla, y no es un olvido.** El cluster de control no
los necesita. Exigirlos aquí bloquearía una instalación válida.

### Lo que necesita cada cluster de workload

| Pieza | Obligatoria | Qué pasa si falta |
|---|---|---|
| **Argo CD** | ✅ | El despliegue falla con un error que **no nombra a Argo CD** |
| **Argo Rollouts** | ✅ de facto | Los despliegues se quedan en curso para siempre: no fallan y no terminan |
| Controlador de **Ingress** con su IngressClass | ✅ para exponer apps | El Ingress de la app se crea y nunca obtiene dirección |
| **cert-manager ≥ 1.15** con el ClusterIssuer de `certManager.issuer` | 🟡 opcional | Las apps desplegadas ahí van por HTTP. ⚠️ Es independiente del cert-manager del cluster de control: `certManager.issuer` es **un solo value con dos usos en dos clusters** — el certificado del portal y los de las apps |

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

Esto **no lo comprueba el instalador**: no sabe todavía a qué clusters vas a desplegar. Lo comprueba
Faro **al registrar un cluster**, que es el primer momento en que se sabe de cuál se trata, y avisa
entonces. `argocd.namespace` en los values dice en qué namespace esperarlo — es un valor global, el
mismo para todos los clusters que registres.

---

## Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/Syntax-Company/faro-installer/master/install.sh | bash
```

`install.sh` comprueba el cluster, pregunta lo poco que no puede saber, genera la llave maestra y el
token de acceso inicial, y lanza Helm. Es el camino recomendado: **no hace falta leer `values.yaml`**.

### La instalación son dos momentos, no uno

Éste es el cambio que más se nota. Antes había que resolver nueve cosas **antes** de instalar, y una
sola mal escrita se descubría semanas después. Ahora:

| | Dónde | Qué |
|---|---|---|
| **1. El instalador** | terminal, antes de que Faro exista | La conexión a Postgres, el dominio de Faro, las credenciales para bajar las imágenes, y los dos hechos del cluster que además detecta y te ofrece: IngressClass y ClusterIssuer |
| **2. El asistente** | en el navegador, dentro de Faro | El proveedor de identidad con sus credenciales, el registro donde Faro publica lo que construye, el repositorio de GitOps con su token, y el dominio base de las apps |

El corte no es arbitrario: en el primer grupo está **lo que no puede venir de Faro porque Faro
todavía no existe** — lo que da acceso a su base de datos, la llave que la descifra, y el dominio que
el Ingress tiene que enrutar antes de que haya nada que enrutar.

Lo del segundo grupo se configura mejor desde dentro, y no solo por comodidad: el asistente **valida
contra el servicio real** antes de guardar (que el repositorio de GitOps existe y que el token puede
escribir en él, que las credenciales del proveedor son buenas) en vez de descubrirlo en el primer
despliegue, con un 502 que llega tres días tarde.

⚠️ Esas cuatro cosas **ya no son variables de entorno del backend**. Ponerlas en el chart no tiene
ningún efecto: solo daría la impresión de haber configurado algo.

### Qué pregunta

Dirección, usuario y contraseña de la base de datos —⚠️ **el nombre es siempre `faro`**, no se
pregunta—, el dominio de Faro, la IngressClass, el ClusterIssuer, y el usuario y token de GitHub para
bajar las imágenes.

Antes de preguntar nada comprueba que estén `kubectl` y `helm` 3, que haya conexión con un cluster
≥ 1.24 y que tengas permiso para crear namespaces. Si vas a desplegar la base de datos, comprueba
además que haya una StorageClass por defecto: sin ella el volumen se queda en `Pending` para siempre
y el síntoma no lo dice.

⚠️ **No comprueba Argo CD ni Argo Rollouts**, porque van en los clusters de workload y éste es el de
control. En su lugar, las notas finales recuerdan que cada cluster de workload los necesita.

### Qué imprime al terminar

- **El token de acceso inicial** y la URL del asistente (`{dominio}/setup`). Es lo primero que hay
  que hacer: todavía no hay proveedor de identidad, así que ese token es la única puerta.
- **La llave maestra**, con el aviso de que si se pierde las credenciales cifradas son
  irrecuperables.
- Cómo retirar el token cuando el asistente termine.

⚠️ **La URL de retorno del proveedor de identidad ya no la da el instalador**: depende de qué
proveedor elijas, y eso se elige en el asistente. La muestra el propio asistente, en su pantalla.

Deja en el directorio actual un `faro-values.yaml` **sin ningún secreto** —viven en Secrets de
Kubernetes— que es lo único que hace falta para actualizar después:

```bash
helm upgrade faro ./charts/faro -n faro -f faro-values.yaml
```

Opciones útiles: `--dry-run` (pregunta y comprueba, no toca el cluster), `--namespace`, `--chart`
para un chart local, `-y`. Toda pregunta se puede pre-responder con una variable de entorno del
mismo nombre que el script imprime junto a la respuesta, lo que permite correrlo sin terminal:

```bash
FARO_DOMAIN=faro.acme.com FARO_DB_MODE=desplegar \
FARO_GHCR_USER=... FARO_GHCR_TOKEN=... \
bash install.sh --yes
```

⚠️ Si vuelves a ejecutarlo sobre una instalación existente, **ni la llave maestra ni el token se
regeneran**: se reutilizan los que ya están en el cluster. Regenerar la llave dejaría la base de
datos viva y completamente ilegible.

---

## Instalar a mano

Si prefieres no usar el script, o ya tienes tu propio flujo de GitOps.

### 1. Genera la llave maestra y guárdala fuera del cluster

```bash
openssl rand -base64 32
```

⚠️ Esta llave cifra **todas** las credenciales que Faro guarda: los PAT de git, los kubeconfig de
los clusters registrados y los secrets de las aplicaciones. **Si se pierde, ese material es
irrecuperable** — la base de datos sigue viva y completamente ilegible. Guárdala en tu gestor de
secretos **antes** de instalar. Ver [La llave maestra](#la-llave-maestra).

### 2. Rellena los values

```bash
cp example-values.yaml mis-values.yaml
$EDITOR mis-values.yaml
```

Ahí van la llave maestra, la contraseña de la base y las credenciales de descarga de ghcr.io. **El
chart crea los dos Secrets** —el de arranque y el `dockerconfigjson`— con esos valores; no hay que
hacer ningún `kubectl create secret` previo.

> Esto era un tropiezo real: había que crearlos a mano antes, y olvidar cualquiera de los dos dejaba
> la instalación a medias con un `CreateContainerConfigError` o un `ImagePullBackOff` que no menciona
> en ningún sitio el comando que falta.

### 3. Instala

```bash
helm install faro ./charts/faro --namespace faro --create-namespace -f mis-values.yaml
```

Usa **`faro`** como nombre de release salvo que tengas un motivo: los objetos salen con los nombres
que usa la documentación (`faro-backend`, `faro-frontend`, `faro-postgresql`), y el nombre de release
importa al reinstalar (ver [La llave maestra](#la-llave-maestra)).

### 4. Entra con el token de acceso inicial y completa el asistente

`NOTES.txt` imprime cómo leerlo (lo genera el chart, así que hay que sacarlo del Secret):

```bash
kubectl get secret faro-bootstrap -n faro \
  -o jsonpath='{.data.FARO_BOOTSTRAP_TOKEN}' | base64 -d
```

Y con él, a `https://faro.tudominio.com/setup`. Todavía no hay proveedor de identidad, así que no hay
forma de hacer login: ese token es la única puerta, y da una sesión limitada a configurar.

El asistente pide el proveedor de identidad con sus credenciales, el registro de imágenes, el
repositorio de GitOps y el dominio base de las apps, y los valida contra el servicio real antes de
guardarlos.

⚠️ **La URL de retorno que hay que registrar en tu proveedor la muestra el asistente**, en su
pantalla. Ni el chart ni el instalador pueden decirla: depende de qué proveedor elijas.

### 5. Retira el token

```bash
helm upgrade faro ./charts/faro -n faro -f mis-values.yaml --set bootstrapToken.disabled=true
```

No es urgente: el backend lo cierra solo en cuanto un login real por el proveedor funcione, y caduca
a las 24h del primer arranque de la instalación aunque nadie complete el asistente. Pero mientras
siga puesto con la puerta ya cerrada, el arranque deja un WARN.

---

## Lo que hay que decidir (los obligatorios)

El chart **no renderiza** sin estos. Es deliberado: un valor de desarrollo heredado no falla al
instalar, falla semanas después en el login o en el primer build, con un síntoma que no nombra la
causa.

| Value | Qué es | Por qué no tiene default |
|---|---|---|
| `global.domain` | El host **único** de Faro: portal y API | El default del backend era una IP de LAN de desarrollo. Heredarlo manda a tus usuarios a una red ajena tras el login |
| `database.password` | Contraseña de la base | El default era `1234`, el del Postgres de desarrollo, y viajaba horneado en la imagen |
| `database.host` (si `deploy=false`) | Dónde está la base | Sin default en el backend: la app no arranca |
| `credentialKey.value` o `.existingSecret` | La llave maestra | Un default sería la **misma llave en todas las instalaciones**: el cifrado no protegería de nada |
| `imagePullSecret.mode` | `create` \| `existing` \| `none` | Los paquetes son privados; sin secreto, `ImagePullBackOff` con un error que se lee como un tag mal escrito |

En un `helm upgrade` los tres secretos se pueden omitir: el chart recupera del cluster los que ya
existen. Es lo que permite que el `faro-values.yaml` del instalador no lleve ninguno dentro.

**No hay `database.name`**: la base se llama siempre `faro`, fijo en el chart. Un valor menos que se
puede escribir mal, y un nombre equivocado no falla al instalar — falla al arrancar, con un error de
conexión que no dice qué pasó.

`images.backend.tag` e `images.frontend.tag` **no** son obligatorios: vacíos, se instala la
`appVersion` del chart (0.0.0). Se rellenan solo para fijar otra versión o para desacoplar backend y
frontend, que se publican por separado. **No existe el tag `latest`** a propósito: una instalación
tiene que poder decir qué versión corre.

### Lo que ya no está en el chart

⚠️ `auth.*`, `gitops.*`, `apps.baseDomain` y `build.registry` **desaparecieron**. Esa configuración
la captura el asistente de primer arranque y vive en la base de datos; el backend retiró las
variables de entorno correspondientes, así que declararlas aquí **no tendría ningún efecto**.

Las ~55 variables de tuning del backend (`FARO_BUILD_*`, `FARO_EXEC_*`, `FARO_CLUSTERS_*`,
`FARO_TLS_*`, `FARO_TEARDOWN_*`, `FARO_LOGS_*`) tampoco se exponen: tienen default sensato en el
`application.yaml` del backend. `backend.extraEnv` sobreescribe cualquiera sin tocar el chart.

---

## Los tres invariantes que el chart codifica

### 1. Una sola réplica del backend

`replicas: 1` está **fijo en la plantilla** y no es un value. No es una decisión de tamaño: es de
corrección. El backend tiene cinco componentes `@Scheduled` —reconciliador de despliegues, de
ejecuciones, de desmantelado, vigilante de certificados y recolector— y **no hay ningún mecanismo de
bloqueo distribuido**. Los procesos de fondo de Spring corren en cada instancia, así que dos réplicas
son dos desmantelados compitiendo por el mismo borrado y dos reconciliadores tocando el mismo
`Application` de Argo.

Subir la réplica **no da alta disponibilidad: produce operaciones duplicadas.** Si el backend se
queda corto, la salida es **vertical** (`backend.resources`), no horizontal.

Está fijo en la plantilla y no como default porque un default se cambia sin leer nada; una constante
obliga a abrir el archivo y encontrarse el porqué. Un `--set backend.replicas=2` falla contra el
`values.schema.json` en vez de ser ignorado en silencio.

La estrategia de despliegue es `Recreate` por lo mismo: un rolling update haría convivir dos juegos
de temporizadores durante la transición.

### 2. Un solo dominio, con `/api` al backend

```
https://faro.tudominio.com/api/...  ->  faro-backend  (8080)
https://faro.tudominio.com/...      ->  faro-frontend (3000)
```

Tres hechos del código lo obligan:

1. El backend sirve **todo** bajo `server.servlet.context-path: /api`. El prefijo es parte de su
   ruta: el Ingress **no reescribe**. Un `rewrite-target: /` de ingress-nginx rompe todo el API.
2. El portal llama al API con base **relativa** `/api`, horneada en la imagen. `NEXT_PUBLIC_API_URL`
   es una variable de tiempo de *build* que Next sustituye en el bundle del navegador; la imagen se
   publica sin definirla para que sirva en cualquier instalación. **No se puede apuntar el portal a
   otro origen sin reconstruir la imagen.**
3. Por eso tienen que compartir origen. Con dos hostnames el navegador bloquea la cookie de sesión
   en los XHR de la SPA (el backend no fija `SameSite=None; Secure`), y el síntoma es un portal que
   carga y un login que nunca termina.

El `/api` también es lo que evita nueve colisiones de ruta entre los dos (`/login`, `/clusters`,
`/connections`, `/teams`, `/users`, `/roles`, `/access-rules`, `/resource-profiles`, `/metrics`).

### 3. El namespace de builds y sus permisos, del mismo sitio

`build.namespace` alimenta **cuatro** cosas a la vez: el `Namespace`, el `Role`, el `RoleBinding` y
la variable `FARO_BUILD_NAMESPACE` que lee el backend. En los manifiestos sueltos de `deploy/rbac/`
del repo del backend estaban cableados por separado, y el desajuste **no avisa**: la instalación
queda verde y el primer build falla con un 403.

El namespace de Faro también deja de estar cableado: sale de `.Release.Namespace`, así que el chart
se instala donde el cliente quiera sin editar manifiestos.

El `Role` es **namespaced y mínimo** — `jobs` (create, get), `pods` + `pods/log` (get, list),
`secrets` (create, patch). **No hay ningún `ClusterRole`**: con esta identidad Faro no sale del
namespace de builds. Todo lo que hace contra los clusters de workload va con el kubeconfig cifrado
que guarda en su base de datos.

⚠️ `pods` y `pods/log` **se olvidan siempre**. Omitirlos no rompe el build: rompe solo la lectura de
logs, que es el síntoma que se lee como *"el build se colgó"*.

---

## El secreto de arranque: la llave maestra y el acceso inicial

Las dos cosas que tienen que existir antes de que Faro pueda hacer nada, y ninguna se puede pedir por
la interfaz porque la interfaz todavía no es alcanzable. Van en el **mismo Secret**
(`<release>-bootstrap`), que es donde el backend las espera.

### `FARO_CREDENTIAL_KEY` — la llave maestra

Cifra en AES-256 todo lo que Faro custodia: los tokens de acceso a repositorios, los kubeconfig de
los clusters, **las credenciales del proveedor de identidad que capture el asistente** y los secrets
de las aplicaciones.

- **Si se pierde**, ese material es irrecuperable. No hay copia, no hay rescate.
- **Si se cambia**, lo ya cifrado deja de poder leerse.

El chart **nunca la genera**. En un `helm upgrade` se puede omitir y la recupera del cluster; si no
la encuentra, **falla con un mensaje** en vez de inventar una nueva. Generarla en un `helm template`
o un `--dry-run` —donde no hay acceso al cluster— produciría un manifiesto con una llave distinta de
la real, y aplicarlo es justo la catástrofe que se intenta evitar.

Dos formas de que sobreviva a `helm uninstall`:

**A. `credentialKey.existingSecret` — recomendada en producción.**

```bash
kubectl create secret generic faro-bootstrap \
  --namespace faro \
  --from-literal=FARO_CREDENTIAL_KEY="$(openssl rand -base64 32)" \
  --from-literal=FARO_BOOTSTRAP_TOKEN="$(openssl rand -hex 20)"
```

Helm no lo crea ni lo posee, así que no puede perderlo. Es la única opción en la que la llave nunca
pasa por un `values.yaml` ni por el historial de releases de Helm.

**B. `credentialKey.value` — el chart crea el Secret con `helm.sh/resource-policy: keep`.**

Un `helm uninstall` lo deja en el cluster y una reinstalación **con el mismo nombre de release y
namespace** recupera las credenciales existentes.

⚠️ El precio: con **otro** nombre de release, Helm aborta con `invalid ownership metadata` sobre ese
Secret y hay que borrarlo a mano — para lo cual hace falta tener la llave guardada fuera igualmente.

### `FARO_BOOTSTRAP_TOKEN` — el acceso inicial

Rompe el círculo *"hace falta el proveedor de identidad para entrar, y entrar para configurarlo"*: se
canjea en `POST /platform/onboarding/session` por una sesión **limitada a los endpoints del
asistente**. No es un usuario con contraseña —eso sería un camino de autenticación permanente—: está
hecho para morirse, y el backend lo mata por tres vías a la vez.

- Un login real por el proveedor recién configurado **lo cierra** (reclamo atómico).
- Se comprueba **en cada petición**, no al arrancar: completar el asistente invalida en el acto una
  sesión ya abierta.
- **Caduca a las 24h** del primer arranque de la instalación, aunque nadie complete nada. Reiniciar
  el pod no reabre la ventana.

Lo genera el instalador (o el chart, si instalas con `helm` a pelo) y **un `helm upgrade` no lo
rota**. Retirarlo cuando el asistente termine es la higiene recomendada:

```bash
helm upgrade faro ./charts/faro -n faro -f faro-values.yaml --set bootstrapToken.disabled=true
```

⚠️ `--set bootstrapToken.value=""` **no** lo retira: el chart lo recuperaría del Secret. Hace falta
`disabled=true`.

### Por qué van en un Secret aparte

Los otros secretos —la contraseña de la base, las credenciales de descarga— se pueden volver a pedir
a su fuente. Éstos no: la llave no se puede re-derivar, y el token es la única puerta mientras no
haya proveedor de identidad. Por eso este Secret lleva `resource-policy: keep` y el resto no.

### Qué respaldar

1. El Secret de la llave maestra.
2. La base de datos de Postgres.

Uno sin el otro no sirve de nada: la llave sin la base no descifra nada, y la base sin la llave es
ilegible.

---

## La base de datos

**`database.deploy: true`** — el chart despliega un `StatefulSet` de Postgres con `volumeClaimTemplates`.

El PVC **no lo borra** `helm uninstall` ni la eliminación del StatefulSet: los datos sobreviven.
Borrarlos es un `kubectl delete pvc` explícito.

`database.persistence.enabled: false` monta un `emptyDir`. ⚠️ Un reinicio del pod borra la
instalación entera. Solo para una demo que se va a tirar.

Este Postgres es de **una instancia**, sin alta disponibilidad. Si eso hace falta, la respuesta es
`deploy: false` y una base gestionada.

**`database.deploy: false`** — base externa. Rellena `database.host`.

⚠️ El usuario necesita poder ejecutar `CREATE EXTENSION IF NOT EXISTS "pgcrypto"` (lo hace la primera
migración de Flyway). En RDS o Cloud SQL suele estar permitido; si no, crea la extensión a mano antes.

En los dos casos, **Faro migra y valida su propio esquema al arrancar**. Nadie lo toca a mano: un
`ALTER TABLE` por fuera hace que la aplicación no arranque.

---

## Actualizar y desinstalar

```bash
helm upgrade faro ./charts/faro --namespace faro -f mis-values.yaml \
  --set images.backend.tag=0.1.0 --set images.frontend.tag=0.1.0   # opcional: fija otra version
```

Un `helm upgrade` que solo cambie configuración reinicia el backend igualmente: los Deployments
llevan un `checksum/config` de su ConfigMap y su Secret. Sin eso, el pod seguiría corriendo con los
valores viejos y la instalación parecería aplicada sin estarlo.

```bash
helm uninstall faro --namespace faro
```

Lo que **sobrevive**: el secreto de arranque (`resource-policy: keep`) y el PVC de Postgres. Lo que
**se va**: los Deployments, los Services, el Ingress, el ConfigMap, el Secret de la app, el de
descarga, el RBAC y —si el chart lo creó— el namespace de builds **con los builds que estuvieran
corriendo dentro**.

---

## Cuando algo no arranca

| Síntoma | Causa habitual |
|---|---|
| `ImagePullBackOff` con `denied` | Falta el secreto de descarga, o su PAT no tiene `read:packages`. Los paquetes son privados |
| Backend en `CrashLoopBackOff` desde el primer arranque | Falta la conexión a la base o la llave maestra. `kubectl logs` lo dice con una frase: el backend es fail-fast en eso |
| Backend reinicia en bucle **sin** error de configuración | Flyway migrando en un arranque en frío. La `startupProbe` da 5 minutos; súbelos en `backend.startupProbe.failureThreshold` |
| La pantalla de login dice "sin configurar" | Es lo normal antes del asistente: ya no hay proveedor de identidad en el arranque. Entra por `/setup` con el token de acceso inicial |
| El token de acceso inicial da 401 | Tres causas con el **mismo** mensaje a propósito (distinguirlas diría si acertaste el valor): el token no es ése, caducó a las 24h, o el onboarding ya se cerró |
| El login termina en `redirect_uri_mismatch` | El redirect URI registrado en el proveedor no coincide con el que muestra el asistente. Lo muestra él porque depende del proveedor que elijas |
| El portal carga pero el login nunca termina | Portal y API no comparten origen. Tienen que salir por el mismo `global.domain` |
| El portal carga y todas las llamadas dan 404 | Alguien puso `rewrite-target: /` en las anotaciones del Ingress. El `/api` no se reescribe |
| El primer build da `403 Forbidden` | `FARO_BUILD_NAMESPACE` y el namespace del `Role`/`RoleBinding` no coinciden, o el Deployment no monta el ServiceAccount |
| El build "se cuelga" y no hay logs | Faltan `pods` / `pods/log` en el `Role`. El build funciona; lo que falla es leer su salida |
| Postgres `0/1` sin errores en el contenedor | El PVC en `Pending`: el cluster no tiene StorageClass por defecto |
| El build falla con 422 `PLATFORM_REGISTRY_NOT_CONFIGURED` | Falta el registro de imágenes. Se configura **en el asistente**, no en el chart |
| El deploy falla con 422 `PLATFORM_BASE_DOMAIN_NOT_CONFIGURED` | Falta el dominio base de las apps. También en el asistente |
| El despliegue de una app falla con 503 | Falta el repositorio de GitOps. Se configura en el asistente |
| Guardaste algo en el asistente y no surte efecto | El registro y el dominio base son "fríos": se aplican al reiniciar, y el asistente lo dice. Los bloqueos miran lo que está **en efecto**, no lo guardado |
| El despliegue falla con un error que no nombra a nadie | Falta **Argo CD en el cluster de workload** (no en el de control). Registrar de nuevo el cluster lo diagnostica |
| El despliegue nunca converge: ni falla ni termina | Falta **Argo Rollouts en el cluster de workload** |
| Argo CD está, pero Faro sigue sin desplegar | Está en otro namespace del que espera `argocd.namespace` (por defecto `argocd`), que es un valor global para todos los clusters |

---

## Lo que falta para instalarlo de verdad

Por orden de bloqueo:

1. 🔴 **El chart no se ha renderizado nunca.** No se ha ejecutado `helm lint`, `helm template` ni
   `helm install --dry-run`: no hay `helm` en la máquina donde se escribió. Toda la sintaxis de las
   plantillas está sin verificar por una herramienta.

   ⚠️ Y ahora hay algo más que verificar que antes: el chart resuelve tres secretos con **`lookup`**,
   que solo funciona contra un cluster real. La lógica "valor dado → el que ya existe → generar o
   fallar" está escrita pero **no ejecutada ni una vez**, y es la que decide si un `helm upgrade`
   rota la llave maestra. Es lo primero que hay que probar, y con una instalación desechable.

   Del instalador sí se verificó lo que se podía sin cluster: `bash -n` y las comprobaciones sobre
   validadores y mecanismo de pregunta. Lo que **no** está probado es el camino completo.

2. 🟠 **Nada de esto se ha probado contra un cluster.** En particular:
   - el `lookup` del punto anterior;
   - que la `startupProbe` da margen suficiente para Flyway en un arranque en frío real;
   - que `/api/actuator/health/liveness` y `/readiness` responden bajo el context-path (es el
     comportamiento estándar de Spring Boot cuando `management.server.port` no está declarado, pero
     no se ha comprobado);
   - que el orden de las reglas del Ingress se resuelve como se espera en el controlador concreto
     del cliente;
   - que el token que imprime el instalador es aceptado por `POST /platform/onboarding/session`.

3. 🟠 **`readOnlyRootFilesystem` del frontend está en `false`.** Es lo único del chart que se relaja
   sin haberlo verificado: el servidor standalone de Next escribe en `.next/cache` y no se ha
   comprobado que ésa sea la única ruta que necesita. Se cierra arrancando con `true` +
   `emptyDir` en `/app/.next/cache` y `/tmp`, y mirando si el portal se sirve completo.

4. 🟡 **El chart no siembra la allowlist del primer administrador.** Ojo con el matiz, porque una
   versión anterior de este README lo contaba mal: el primer super-admin **no es una carrera**. La
   decisión es atómica (`claimOnce`, un `INSERT … ON CONFLICT DO NOTHING`), entre N logins
   concurrentes gana exactamente uno, y **sí** existen `POST /users/{id}/promote` y `/demote` para
   corregirlo después, con protección contra quedarse sin administradores.

   Lo que el chart no hace es sembrar una fila en `access_rule` con el email del administrador antes
   de exponer el Ingress, que limitaría **quién puede registrarse** desde el primer momento. Con el
   acceso inicial esto pesa menos que antes —quien tiene el token controla la instalación—, pero
   sigue siendo una decisión pendiente. No está aquí porque escribir en la base de datos desde el
   chart obliga a fijar el esquema de esa tabla y a meter una imagen con `psql` en el camino crítico.

5. 🟡 **Tres propiedades del backend no son configurables por ninguna vía.** Existen solo como
   default de un `@Value` y no aparecen ni en `application.yaml` ni en `.env.example`:
   `faro.deploy.reaper-interval`, `faro.deploy.reaper-deadline` y
   `faro.tls.auto-renewal-overdue-fraction`. Ni este chart ni ningún otro puede ofrecerlas hasta que
   se promuevan. No bloquea: sus defaults funcionan.

6. 🟡 **Los manifiestos de `deploy/rbac/` siguen en el repo del backend.** Este chart los sustituye,
   pero mientras los dos existan pueden divergir. Toca borrarlos de allí y dejar un puntero a este
   repo — y ese cambio es en `faro-backend`, fuera del alcance de este encargo.

7. 🟡 **Sin `PodDisruptionBudget` ni `NetworkPolicy`.** Un PDB para el backend no tiene sentido con
   una sola réplica (bloquearía los drenados de nodo); para el frontend sí lo tendría. Las
   NetworkPolicy dependen de que el cluster tenga un CNI que las aplique.
