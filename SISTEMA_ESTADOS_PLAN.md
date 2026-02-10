# Sistema de Estados del Plan Nutricional ✨

## 📋 Resumen de Implementación

Se ha integrado completamente el sistema de estados del plan nutricional desde el backend hacia el frontend de Flutter. Este sistema proporciona feedback visual claro al usuario sobre el estado de su plan.

## 🎨 Componentes Creados

### 1. **Modelo de Datos Actualizado**
📁 `lib/models/dashboard_data.dart`

Se añadieron los siguientes campos a `PlanNutricional`:

```dart
final String estadoPlan;           // "provisional_ia", "validado", "en_revision", "modificado"
final bool requiereValidacion;
final bool esCondicionCritica;
final String alertaSeguridad;
final bool generadoAutomaticamente;
final String? fechaGeneracion;
final bool validoHastaValidacion;
final String mensajeCliente;
final String descripcionEstado;
```

### 2. **Widgets Nuevos**

#### 📌 PlanStatusBadge
📁 `lib/widgets/plan_status_badge.dart`

Badge compacto que muestra el estado del plan con colores distintivos:
- 🟢 **Verde**: Plan validado
- 🔵 **Azul**: Plan personalizado
- 🟠 **Naranja**: Plan provisional
- 🔴 **Rojo**: Revisión urgente / Condición crítica

```dart
PlanStatusBadge(
  estadoPlan: plan.estadoPlan,
  esCondicionCritica: plan.esCondicionCritica,
)
```

#### 📋 PlanAlertCard
📁 `lib/widgets/plan_alert_card.dart`

Card informativa que muestra mensajes contextuales según el estado:
- ✅ Mensaje de aprobación para planes validados
- 🤖 Barra de progreso para planes provisionales
- ⚠️ Botón de contacto para condiciones críticas

```dart
PlanAlertCard(
  estadoPlan: plan.estadoPlan,
  esCondicionCritica: plan.esCondicionCritica,
  mensajeCliente: plan.mensajeCliente,
  onContactarNutricionista: () {
    // Navegar al chat
  },
)
```

### 3. **Dashboard Actualizado**
📁 `lib/screens/dashboard_screen.dart`

Se integró la card de alerta justo antes del plan nutricional:

```dart
if (_dailySummary!.planObjetivo != null) ...[
  // ✨ Card de alerta de estado
  PlanAlertCard(
    estadoPlan: _dailySummary!.planObjetivo!.estadoPlan,
    esCondicionCritica: _dailySummary!.planObjetivo!.esCondicionCritica,
    mensajeCliente: _dailySummary!.planObjetivo!.mensajeCliente,
    onContactarNutricionista: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userName: 'Tu Nutricionista',
            initialMessage: '¡Hola! Necesito que revises mi plan...',
          ),
        ),
      );
    },
  ),
  const SizedBox(height: 16),
  _buildPlanNutricionalCompact(),
]
```

## 🔄 Estados Posibles

| Estado | Color | Significado | Visualización |
|--------|-------|-------------|---------------|
| `provisional_ia` | 🟠 Naranja | Plan generado por IA, pendiente de revisión | Barra de progreso animada |
| `validado` | 🟢 Verde | Nutricionista aprobó el plan | Mensaje de confirmación |
| `modificado` | 🔵 Azul | Plan personalizado por nutricionista | Badge "Personalizado" |
| `en_revision` | 🔴 Rojo | Condición crítica, urgente | Alerta de revisión |

## 📱 Flujo de Usuario

### Caso 1: Usuario Nuevo (Plan Provisional)
1. Usuario se registra
2. Backend genera plan automático con IA
3. Dashboard muestra:
   - Badge naranja "Provisional"
   - Card azul con mensaje de la IA
   - Barra de progreso animada
   - Texto: "Tu nutricionista revisará este plan pronto"

### Caso 2: Condición Médica Crítica
1. Usuario tiene diabetes/hipertensión detectada
2. Backend marca `esCondicionCritica: true`
3. Dashboard muestra:
   - Badge rojo "Requiere Validación"
   - Card roja con alerta médica
   - Botón "Contactar a mi nutricionista"
   - Alerta de seguridad específica (ej: "⚠️ Ajuste por Diabetes: Carbohidratos controlados")

### Caso 3: Plan Validado
1. Nutricionista aprueba el plan
2. Backend actualiza `estadoPlan: "validado"`
3. Dashboard muestra:
   - Badge verde "Validado"
   - Card verde con mensaje de aprobación
   - Sin alertas adicionales

## 🔗 Integración con Backend

El backend en `ia_service.py` retorna:

```python
{
  "calorias_diarias": 2020,
  "macros": {"P": 126, "C": 253, "G": 63},
  "dias": [...],
  
  # Nuevos campos
  "estado_plan": "provisional_ia",
  "requiere_validacion": false,
  "es_condicion_critica": false,
  "alerta_seguridad": "",
  "generado_automaticamente": true,
  "fecha_generacion": "2026-02-09T16:40:00",
  "valido_hasta_validacion": true,
  "mensaje_cliente": "🤖 Este plan fue generado automáticamente...",
  "descripcion_estado": "Plan generado automáticamente - Pendiente de validación"
}
```

Flutter parsea estos campos automáticamente en `PlanNutricional.fromJson()`.

## ✅ Ventajas de esta Implementación

1. **Transparencia Total**: El usuario siempre sabe el estado de su plan
2. **Seguridad Médica**: Alertas específicas para condiciones críticas
3. **Comunicación Directa**: Botón de contacto cuando se requiere validación
4. **Feedback Visual**: Colores y animaciones que guían al usuario
5. **Escalabilidad**: Fácil añadir nuevos estados si es necesario

## 🚀 Próximos Pasos Sugeridos

1. **Notificaciones Push**: Cuando el nutricionista valide el plan
2. **Historial de Estados**: Ver cuándo cambió de provisional a validado
3. **Comentarios del Nutricionista**: Mostrar notas específicas
4. **Recordatorios**: Notificar si el plan lleva mucho tiempo sin validar

## 🐛 Casos de Prueba

Para probar esta funcionalidad:

1. **Registro nuevo usuario sin condiciones**: Debe ver plan provisional naranja
2. **Usuario con diabetes**: Debe ver badge rojo y alerta de carbohidratos
3. **Después de validación**: Badge debe cambiar a verde
4. **Click en "Contactar"**: Debe abrir el chat con mensaje prellenado

---

**Última actualización**: 2026-02-09  
**Autor**: Sistema Integrado Backend-Frontend  
**Versión**: 1.0
