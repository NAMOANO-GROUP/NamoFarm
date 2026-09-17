import 'package:flutter/foundation.dart';

/// Version publique de l'application (doit rester alignée avec pubspec.yaml).
const String kAppVersion = '1.0.0';

const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

String get baseUrl {
	if (_apiBaseUrlOverride.isNotEmpty) {
		return _apiBaseUrlOverride;
	}

	if (kIsWeb) {
		return 'http://localhost:5000/api';
	}

	switch (defaultTargetPlatform) {
		case TargetPlatform.android:
			return 'http://10.0.2.2:5000/api';
		default:
			return 'http://localhost:5000/api';
	}
}
