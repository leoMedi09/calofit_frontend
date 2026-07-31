import 'package:flutter/material.dart';

/// Pantalla estática con Términos y Condiciones + Política de Privacidad.
/// Accesible sin sesión iniciada desde LoginScreen (requisito de las tiendas
/// de apps: la política debe poder verse antes de loguearse).
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Privacidad'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Header(),
              _SectionTitle('Términos y Condiciones de Uso'),
              _Paragraph(
                '1. Aceptación\n'
                'Al usar la aplicación CaloFit aceptas los presentes Términos y '
                'Condiciones y la Política de Privacidad descrita más abajo.',
              ),
              _Paragraph(
                '2. Naturaleza del servicio\n'
                'CaloFit es una herramienta de apoyo del Gimnasio World Light para '
                'el seguimiento nutricional y de ejercicio de sus clientes. No es un '
                'servicio médico ni reemplaza la consulta con un profesional de la '
                'salud, nutricionista o médico tratante.',
              ),
              _Paragraph(
                '3. Cuentas de usuario\n'
                'Las cuentas de cliente son creadas y administradas por el personal '
                'del gimnasio (nutricionistas o administradores). Eres responsable '
                'de mantener la confidencialidad de tu contraseña y de toda '
                'actividad realizada desde tu cuenta.',
              ),
              _Paragraph(
                '4. Asistente con inteligencia artificial\n'
                'Las recomendaciones de comidas, rutinas y macronutrientes son '
                'generadas por un sistema de inteligencia artificial y modelos de '
                'aprendizaje automático, en base a los datos que tú proporcionas. '
                'Estas recomendaciones son orientativas: no reemplazan el criterio '
                'profesional de tu nutricionista ni el de tu médico.',
              ),
              _Paragraph(
                '5. Veracidad de la información\n'
                'Debes proporcionar información real y actualizada (peso, talla, '
                'condiciones médicas, alergias, restricciones alimentarias). El '
                'gimnasio no se hace responsable de recomendaciones inadecuadas '
                'originadas por datos falsos, incompletos o desactualizados que '
                'hayas ingresado.',
              ),
              _Paragraph(
                '6. Condiciones médicas preexistentes\n'
                'Si tienes una condición médica (diabetes, hipertensión u otra), '
                'consulta siempre con tu médico antes de seguir cualquier plan '
                'nutricional o de ejercicio sugerido por la aplicación.',
              ),
              _Paragraph(
                '7. Uso aceptable\n'
                'No debes usar la cuenta de otra persona ni introducir '
                'información falsa o dañina de forma deliberada. El gimnasio '
                'puede suspender el acceso ante uso indebido de la plataforma.',
              ),
              _Paragraph(
                '8. Cambios en los términos\n'
                'Estos términos pueden actualizarse periódicamente. Los cambios '
                'relevantes se reflejarán en esta misma pantalla dentro de la app.',
              ),
              _SectionTitle('Política de Privacidad'),
              _Paragraph(
                '1. Responsable del tratamiento\n'
                'Gimnasio World Light — Lambayeque, Perú.',
              ),
              _Paragraph(
                '2. Datos que recolectamos\n'
                '• Datos de identificación: nombre, DNI, correo electrónico.\n'
                '• Datos físicos: peso, talla, edad, género.\n'
                '• Datos de salud: condiciones médicas, alergias y restricciones '
                'alimentarias que declares.\n'
                '• Datos de actividad: comidas y ejercicios registrados, rutinas, '
                'historial de progreso.\n'
                '• Mensajes que envías al asistente conversacional.',
              ),
              _Paragraph(
                '3. Finalidad del tratamiento\n'
                'Usamos estos datos para generar tu plan nutricional y de '
                'ejercicio personalizado, calcular recomendaciones mediante '
                'modelos de inteligencia artificial, dar seguimiento a tu '
                'progreso y enviarte notificaciones (recordatorios, alertas de '
                'racha, avisos de tu nutricionista).',
              ),
              _Paragraph(
                '4. Terceros que procesan datos\n'
                '• Firebase (Google): autenticación de cuenta y notificaciones push.\n'
                '• Groq: procesamiento del asistente conversacional (modelo de '
                'lenguaje).\n'
                '• USDA FoodData Central y FatSecret: consulta de valores '
                'nutricionales de alimentos.\n'
                'Estos terceros reciben únicamente los datos necesarios para '
                'prestar su servicio específico.',
              ),
              _Paragraph(
                '5. Almacenamiento y seguridad\n'
                'Tus datos se almacenan en la base de datos del sistema, con '
                'acceso restringido al personal autorizado del gimnasio. El '
                'acceso a la app está protegido con autenticación por token y '
                'contraseñas cifradas.',
              ),
              _Paragraph(
                '6. Tus derechos\n'
                'De acuerdo con la Ley N.º 29733, Ley de Protección de Datos '
                'Personales del Perú, puedes solicitar acceso, rectificación, '
                'cancelación u oposición sobre tus datos personales contactando '
                'directamente al gimnasio.',
              ),
              _Paragraph(
                '7. Conservación de datos\n'
                'Tus datos se conservan mientras mantengas una cuenta activa en '
                'el gimnasio, y se eliminan o anonimizan si solicitas la baja de '
                'tu cuenta.',
              ),
              _Paragraph(
                '8. Menores de edad\n'
                'Si eres menor de edad, tu cuenta debe estar autorizada y '
                'gestionada con el consentimiento de tu padre, madre o tutor '
                'legal.',
              ),
              _Paragraph(
                '9. Contacto\n'
                'Para consultas sobre estos Términos o tus datos personales, '
                'comunícate con el Gimnasio World Light directamente en '
                'recepción o con tu nutricionista asignado.',
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4, bottom: 12),
      child: Text(
        'Última actualización: 2026',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
      ),
    );
  }
}
