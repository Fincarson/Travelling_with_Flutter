# Font Assets

Put custom app font files in this folder.

The app currently uses Flutter's default platform font because
`AppFontSource.family` is `null` in `lib/core/theme/app_theme.dart`. After a
font is added to `pubspec.yaml`, update that single variable to the font family
name and the app theme will pick it up everywhere.
