# Compila el APK release y lo sube a Firebase App Distribution.
# Uso:
#   .\scripts\distribute.ps1 "Notas de esta version: corrige X, agrega Y"
#
# Requisitos previos (una sola vez):
#   1. firebase login          (abre el navegador, inicia sesion con la cuenta de Firebase)
#   2. Tener un grupo "testers" creado en la consola de Firebase
#      (App Distribution > Testers y grupos > Agregar grupo "testers")
#      o pasar --testers-file en vez de --groups (ver mas abajo).

param(
    [string]$ReleaseNotes = "Nueva version de CaloFit."
)

$AppId = "1:712949385900:android:ea027ab73af1b001b96d09"

Write-Host "Compilando APK release..." -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Fallo el build de Flutter. Abortando." -ForegroundColor Red
    exit 1
}

$ApkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $ApkPath)) {
    Write-Host "No se encontro el APK en $ApkPath" -ForegroundColor Red
    exit 1
}

Write-Host "Subiendo a Firebase App Distribution..." -ForegroundColor Cyan
firebase appdistribution:distribute $ApkPath `
    --app $AppId `
    --groups "testers" `
    --release-notes $ReleaseNotes

if ($LASTEXITCODE -eq 0) {
    Write-Host "Listo. Los testers del grupo 'testers' recibiran la notificacion." -ForegroundColor Green
} else {
    Write-Host "Fallo la subida. Revisa que 'firebase login' este vigente y que el grupo 'testers' exista." -ForegroundColor Red
}
