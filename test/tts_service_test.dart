import 'package:calofit_frontend/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza el texto como se dice en voz alta', () {
    expect(TtsService.normalizar('Haz 3x10 de sentadilla ✅'), 'Haz 3 series de 10 de sentadilla');
    expect(TtsService.normalizar('Hoy: 1375 / 2587 kcal (~620 kcal)'), 'Hoy: 1375 de 2587 kilocalorías, aproximadamente 620 kilocalorías');
    expect(TtsService.normalizar('P:23g C:55g G:12g'), 'proteína 23 gramos carbohidratos 55 gramos grasas 12 gramos');
    expect(TtsService.normalizar('Avanzado 80% con pre-entreno de 250 ml'), 'Avanzado 80 por ciento con pre-entreno de 250 mililitros');
    expect(TtsService.normalizar('**Pollo** a 1.5 kg'), 'Pollo a 1,5 kilos');
  });

  test('parte en frases y junta las cortas', () {
    final f = TtsService.frases('¡Excelente, Leonardo! Para tus piernas te sugiero sentadilla. ¡Dale!');
    expect(f, ['¡Excelente, Leonardo! Para tus piernas te sugiero sentadilla. ¡Dale!']); // las cortas se juntan
    expect(TtsService.frases('Para tu cena te propongo estas opciones: caldo de gallina. Pescado a la plancha con ensalada.').length, 2);
    expect(TtsService.frases('Hola.'), ['Hola.']);
  });

  test('prefiere calidad alta, acento latino y voces de red', () {
    final espana = {'locale': 'es-ES', 'quality': 'very high', 'network_required': '1'};
    final mexico = {'locale': 'es-MX', 'quality': 'very high', 'network_required': '1'};
    final local = {'locale': 'es-MX', 'quality': 'normal', 'network_required': '0'};
    expect(TtsService.puntaje(mexico) > TtsService.puntaje(espana), isTrue);
    expect(TtsService.puntaje(espana) > TtsService.puntaje(local), isTrue);
  });
}
