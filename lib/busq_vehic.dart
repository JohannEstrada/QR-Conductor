import 'package:flutter/material.dart';
import 'info_vehic.dart';
import 'services/laravel_api_service.dart';

class BusqVehic extends StatefulWidget {
  const BusqVehic({super.key});

  @override
  State<BusqVehic> createState() => _BusqVehicState();
}

class _BusqVehicState extends State<BusqVehic> {
  // Controller para el input del número de serie
  final TextEditingController _controller = TextEditingController();

  // Estado de carga para mostrar indicador durante búsqueda
  bool _isLoading = false;

  // =============================================================================
  // MÉTODO AUXILIAR: Mostrar mensajes de error/éxito al usuario
  // =============================================================================
  // Función: Mostrar SnackBar con mensaje personalizado
  // Parámetros: mensaje (texto), color (color del fondo)
  // Seguridad: Verifica que el widget esté montado antes de mostrar
  // =============================================================================
  void _mostrarMensaje(String mensaje, {Color color = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // =============================================================================
  // MÉTODO PRINCIPAL: Mostrar diálogo de búsqueda de vehículo
  // =============================================================================
  // Función: Abrir diálogo modal para ingresar número de serie
  // Flujo: Validar → Buscar API → Navegar o mostrar error
  // =============================================================================
  void _showManualInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // 🎨 Título del diálogo
        title: const Text('Buscar Vehículo'),

        // 📝 Campo de input para número de serie
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Número de serie',
            hintText: 'Ingrese el número de serie del vehículo',
            border: OutlineInputBorder(),
          ),
          autofocus: true, // Enfoca automáticamente al abrir
        ),

        // 🔘 Botones de acción del diálogo
        actions: [
          // ❌ Botón cancelar - cierra diálogo sin acción
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),

          // ✅ Botón buscar - inicia proceso de búsqueda
          ElevatedButton(
            onPressed: () async {
              final numSerie = _controller.text.trim();

              // 🛡️ Validación 1: Campo vacío
              if (numSerie.isEmpty) {
                _mostrarMensaje('Por favor, ingrese un número de serie');
                return;
              }

              // Obtener datos del vehículo desde la API
              try {
                final vehiculoData = await LaravelApiService.buscarVehiculo(
                  numSerie,
                );

                if (vehiculoData['success'] == true) {
                  // Vehículo encontrado - navegar con datos completos
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InfoVehic(
                        numeroSerie: numSerie,
                        datosVehiculo: vehiculoData['vehiculo'],
                        cargasDelVehiculo: vehiculoData['cargas'] ?? [],
                        tipoCargaPreseleccionado: 'extraordinaria',
                      ),
                    ),
                  );
                } else {
                  // Vehículo no encontrado - mostrar error
                  Navigator.of(context).pop();
                  _mostrarMensaje(
                    vehiculoData['message'] ?? 'Vehículo no encontrado',
                  );
                }
              } catch (e) {
                // Error de conexión - mostrar error
                Navigator.of(context).pop();
                _mostrarMensaje('Error al buscar el vehículo: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135DD8),
              foregroundColor: Colors.white,
            ),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Vehicular'),
        backgroundColor: const Color(0xFF135DD8),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Card(
            color: const Color(0xFFE3F2FD),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.search, size: 100, color: Color(0xFF135DD8)),
                  const SizedBox(height: 15),
                  const Text(
                    'Buscar Vehículo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF135DD8),
                    ),
                  ),
                  const Text(
                    'Ingrese el número de serie del vehículo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showManualInputDialog(context),
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Introducir número de serie'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF135DD8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
