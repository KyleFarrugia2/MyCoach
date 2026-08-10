# Info.plist usage description snippets

Add these keys to the app target `Info.plist` (or the target’s Info tab in Xcode). Strings are specific to the features that use each API.

## Camera — progress photos

```xml
<key>NSCameraUsageDescription</key>
<string>My Coach uses the camera so you can take weekly front, side, and back progress photos to track physique changes.</string>
```

## HealthKit — optional step read

Only required if HealthKit step import is enabled in the build. Manual step entry always works without this permission. Health access is never required for Coach AI or other paid features.

```xml
<key>NSHealthShareUsageDescription</key>
<string>My Coach can read your step count from Apple Health to fill daily step logs. You can always enter steps manually instead.</string>
```

## URL scheme (optional — morning weigh-in deep link)

Used by `CoachNotificationDeepLink.morningWeight` (`mycoach://weigh-in/morning`):

```xml
<key>CFBundleURLTypes</key>
<array>
	<dict>
		<key>CFBundleURLName</key>
		<string>com.company.mycoach</string>
		<key>CFBundleURLSchemes</key>
		<array>
			<string>mycoach</string>
		</array>
	</dict>
</array>
```

## Notes

- Do not add vague strings like “This app needs access to your camera.”
- Do not declare `NSHealthUpdateUsageDescription` unless the app writes to Health (it currently does not).
- Do not declare photo library usage unless you add album import later.
