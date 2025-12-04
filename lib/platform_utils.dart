// Utilidades para manejo multiplataforma (web vs móvil)
export 'platform_utils_web.dart'
    if (dart.library.io) 'platform_utils_mobile.dart';
