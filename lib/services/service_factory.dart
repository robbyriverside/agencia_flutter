import 'package:flutter/foundation.dart';
import 'agencia_service.dart';
import 'agencia_service_web.dart';
import 'agencia_service_native.dart';

AgenciaService createAgenciaService() {
  if (kIsWeb) {
    return AgenciaServiceWeb();
  } else {
    // On macOS/Desktop, use Native (local) service
    return AgenciaServiceNative();
  }
}
