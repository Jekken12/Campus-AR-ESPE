# Campus AR ESPE – versión final

Aplicación Flutter de navegación exterior para el campus ESPE Belisario Quevedo.

## Experiencia principal

- Selección de destinos sin usuarios, inicio de sesión ni registro.
- Navegación mediante cámara a pantalla completa.
- Flecha aumentada única con perspectiva, sombra y rotación suavizada.
- Indicaciones visuales y por voz en español.
- Baliza virtual cuando el destino está a menos de 75 metros.
- Recalculo de ruta desde el GPS.
- Confirmación de llegada con pantalla verde, puerta virtual, vibración, sonido y voz.
- No contiene mapa 2D ni herramienta de mapeo para desarrolladores.

## Ejecución

```powershell
flutter clean
flutter pub get
flutter analyze
flutter build apk
```

APK generado:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## Prueba recomendada

1. Activar GPS, volumen multimedia y permisos de cámara/ubicación.
2. Seleccionar un destino exterior.
3. Iniciar la guía AR.
4. Mover el teléfono lentamente en forma de ocho si la brújula apunta mal.
5. Comprobar la voz, la rotación de la flecha, la baliza cercana y la llegada.
