# PTMS — Personal Tetra Management System

Núcleo SwMI para varias estaciones PTBS unidas por PTCP. Se instala en un VPS o en una placa (Raspberry Pi y compatibles) sin compilar: el instalador baja el binario ya construido para tu arquitectura.

Mantenido por **Aitor, EA4HBL**.

---

## Qué es

PTMS es el núcleo de la red: las celdas PTBS se unen por **PTCP**, el núcleo reparte registro, voz y SDS, y opcionalmente abre un uplink Brew hacia TetraPack (modo gateway).

No hace falta Rust en el servidor. La actualización OTA del panel descarga el mismo tipo de binario que el instalador.

## Arquitecturas

| `uname -m` | Asset del release |
|---|---|
| `aarch64` / `arm64` | `ptms-aarch64` |
| `x86_64` / `amd64` | `ptms-x86_64` |
| `i686` / `i386` | `ptms-i686` |

## Canales

| Canal | Rama en este repo | Release de GitHub |
|---|---|---|
| Estable | `main` | `latest-stable` |
| Beta | `beta` | `latest-beta` |

## Instalación

En el VPS o la placa (Debian/Ubuntu o similar con systemd):

Canal estable:

```bash
curl -fsSL https://raw.githubusercontent.com/Aitorrio/ptms-dist/main/contrib/install/install-ptms.sh | sudo bash
```

Canal beta:

```bash
curl -fsSL https://raw.githubusercontent.com/Aitorrio/ptms-dist/beta/contrib/install/install-ptms.sh | sudo env PTMS_BRANCH=beta bash
```

El script:

1. Detecta la arquitectura e instala `curl` si falta.
2. Descarga el asset y `ptms.sha256` del release del canal y comprueba la suma.
3. Instala `/usr/local/bin/ptms` y la unidad `ptms.service`.
4. Crea `/etc/ptms/nucleus.toml` si no existe (panel en `0.0.0.0:7480`, usuario `admin` / `1234`).
5. Activa y arranca el servicio.

Al terminar imprime la URL del panel.

| | |
|---|---|
| Panel | `http://<ip>:7480/` |
| Usuario inicial | `admin` |
| Contraseña inicial | `1234` |
| Configuración | `/etc/ptms/nucleus.toml` |
| Servicio | `ptms.service` |
| Binario | `/usr/local/bin/ptms` |

**Cambia la contraseña** antes de exponer el panel a Internet. Abre el puerto 7480 (panel) y el 7400 (PTCP) en el firewall según tu red.

## Actualización

Desde el panel: **Actualizar** → elige canal Estable o Beta → Comprobar → Actualizar.

O reejecuta el script de instalación del mismo canal. OTA e instalador usan los mismos assets y el mismo checksum.

## Primer uso

1. Entra al panel y cambia usuario/contraseña en Gestión.
2. Da de alta las celdas (token, portadora, colour code, área).
3. En cada PTBS configura **Gestión remota** hacia la IP:7400 de este núcleo con el token de la celda.
4. Si la red sale a TetraPack, activa el gateway Brew en el fichero / perfiles TMO.

## Ficheros útiles

- `contrib/install/install-ptms.sh` — instalador
- `contrib/install/ptms.service` — unidad systemd
- `example_config/nucleus.toml` — plantilla de configuración
- `CHANGELOG.md` — novedades por versión

El código fuente vive en el repositorio privado de desarrollo; este repo solo publica instaladores y releases rodantes.
