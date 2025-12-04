// Implementación móvil (no hace nada, las descargas se manejan de otra forma)
import 'dart:typed_data';

void downloadFile(Uint8List bytes, String filename, String mimeType) {
  // En móvil, esto no se usa - se comparte directamente
  throw UnimplementedError('Use Share.shareXFiles en móvil');
}

void downloadTextFile(String content, String filename) {
  // En móvil, esto no se usa - se comparte directamente
  throw UnimplementedError('Use Share.shareXFiles en móvil');
}
