# Luminous

App de prueba en SwiftUI para experimentar con iOS. Nada serio, solo jugando con el Liquid Glass y la firma/sideload desde GitHub Actions.

- SwiftUI + Liquid Glass (iOS 26)
- Tab bar: Inicio, Favoritos, Ajustes
- Build y `.ipa` firmado mediante el workflow de `.github/workflows/ios-build.yml` (solo se lanza manualmente)

Para replicarlo se necesita una cuenta de desarrollador de Apple (y el certificado/provisioning profile correspondiente).

## Archivos necesarios

- `Development.p12` — certificado de firma (cifrado con contraseña)
- `Development.mobileprovision` — provisioning profile ligado a tu dispositivo

Ambos se generan desde la cuenta de desarrollador de Apple (o un servicio de firma).

## Secrets y variables (Settings → Secrets and variables → Actions)

**Secrets:**

| Nombre | Valor |
|---|---|
| `APPLE_CERT_BASE64` | el `.p12` en base64 (`base64 -w0 Development.p12`) |
| `PROFILE_BASE64` | el `.mobileprovision` en base64 (`base64 -w0 Development.mobileprovision`) |
| `PROFILE_UUID` | UUID del perfil (aparece en `security cms -D -i Development.mobileprovision`) |
| `CERTIFICATE_NAME` | nombre del certificado (ej. `iPhone Developer: Created via API (XXXXXXXXXX)`) |
| `CODE_SIGN_IDENTITY` | el mismo nombre del certificado |
| `APPLE_CERT_PASSWORD` | contraseña del `.p12` |
| `KEYCHAIN_PASSWORD` | contraseña del keychain temporal del runner (puede ser cualquiera) |
| `PAT_PAT` | Personal Access Token de GitHub (fine-grained, solo lectura de repos) que la app usa para mostrar tus commits |

**⚠️ Seguridad:** el `PAT_PAT` queda embebido en el binario de la app. Cualquiera con el `.ipa` podría extraerlo, así que solo úsalo en una app personal que no compartas. Revoca/rota el token si lo pierdes o compartes la app.

**Variables:**

| Nombre | Valor |
|---|---|
| `ENABLE_SIGNED_RELEASE` | `true` (para activar el job de firma y generar el `.ipa`) |

Además, `PRODUCT_BUNDLE_IDENTIFIER` en el proyecto debe coincidir con el bundle ID autorizado por el provisioning profile.