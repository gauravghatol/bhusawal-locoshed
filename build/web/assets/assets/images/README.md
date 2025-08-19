# Images Assets

This folder contains image assets for the Loco Info app.

## Logo Files
Place your app logo files here with these recommended naming conventions:
- `logo.png` - Main app logo
- `logo_large.png` - High resolution logo for splash screens
- `logo_small.png` - Small logo for icons/notifications

## Usage in Flutter
To use images from this folder in your Flutter app:

```dart
Image.asset('assets/images/logo.png')
```

## Supported Formats
- PNG (recommended for logos with transparency)
- JPEG (for photos)
- SVG (requires flutter_svg package)
- WebP (for web optimization)

## Resolution Guidelines
- Provide multiple resolutions for better display on different devices
- 1x, 2x, 3x variants recommended
- Example: logo.png, logo@2x.png, logo@3x.png
