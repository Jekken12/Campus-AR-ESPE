# Instrucciones de ejecución

## Preparación

```powershell
flutter clean
flutter pub get
flutter doctor
```

## Ejecutar en un teléfono

```powershell
flutter devices
flutter run
```

Acepta los permisos de cámara y ubicación. Mantén activo el volumen multimedia para escuchar las indicaciones.

## Generar el APK

```powershell
flutter build apk
```

El archivo se genera en:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## Uso

1. Abre la aplicación.
2. Selecciona un destino exterior.
3. Revisa la distancia calculada y presiona **Iniciar AR**.
4. Sigue la flecha mostrada sobre la cámara.
5. Escucha las indicaciones por voz o siléncialas con el botón superior.
6. Cuando estés cerca, aparecerá una baliza virtual con el nombre del destino.
7. Al llegar, verás una pantalla verde y el teléfono vibrará y emitirá un aviso.

## Recomendaciones de prueba

- Prueba la aplicación al aire libre.
- Calibra la brújula moviendo el celular lentamente en forma de ocho si la flecha apunta mal.
- Mantén el GPS en modo de alta precisión.
- La flecha es una guía aumentada sobre la cámara; la posición depende del GPS y del magnetómetro del teléfono.
