import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// =============================================================================
// CLASE ValidarConductorScreen - Validación de credenciales mediante QR
// =============================================================================
// Función: Escanear QR, validar con API SIARH y determinar estado del conductor
// Características: Manejo de errores, estados de conductor, UI intuitiva
// =============================================================================

class ValidarConductorScreen extends StatefulWidget {
  const ValidarConductorScreen({super.key});

  @override
  State<ValidarConductorScreen> createState() => _ValidarConductorScreenState();
}

class _ValidarConductorScreenState extends State<ValidarConductorScreen> {
  // Controlador del escáner
  final MobileScannerController _scannerController = MobileScannerController();

  // Estado del conductor y UI
  String? _codigoEscaneado;
  bool _isLoading = false;
  bool _scannerActivo = true;

  // Datos del conductor validado
  Map<String, dynamic>? _datosConductor;
  String? _estadoCredencial;

  // =============================================================================
  // MÉTODO PRINCIPAL: Enviar datos a API SIARH
  // =============================================================================
  Future<void> _enviarDatosApi(String id) async {
    setState(() {
      _isLoading = true;
      _scannerActivo = false;
    });

    final url = Uri.parse(
      'http://187.216.141.163:8080/api_siarh/api_estatus_conductor.php',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'action': 'get_conductor', 'id': id}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        debugPrint('Respuesta API: ${response.body}');

        if (responseData['success'] == true && responseData['data'] != null) {
          final Map<String, dynamic> conductorData = responseData['data'];
          final String vigenciaEstado = responseData['vigencia'] ?? 'N/A';

          // Guardar datos del conductor
          setState(() {
            _datosConductor = conductorData;
            _estadoCredencial = vigenciaEstado;
            _codigoEscaneado = _formatearDatosConductor(
              conductorData,
              vigenciaEstado,
            );
          });

          // Mostrar mensaje de éxito
          _mostrarMensaje('Conductor validado correctamente', Colors.green);
        } else {
          // La API respondió pero no encontró datos
          final String message =
              responseData['message'] ??
              'No se encontraron detalles para el ID proporcionado.';
          setState(() {
            _codigoEscaneado = 'Error: $message';
          });
          _mostrarMensaje(message, Colors.orange);
        }
      } else {
        // Error HTTP
        final String errorMessage =
            'Error del servidor: ${response.statusCode}';
        setState(() {
          _codigoEscaneado = errorMessage;
        });
        _mostrarMensaje(
          'Error al consultar la credencial: ${response.statusCode}',
          Colors.red,
        );
      }
    } catch (e) {
      // Error de red o parseo
      final String errorMessage = 'Error de conexión: $e';
      setState(() {
        _codigoEscaneado = errorMessage;
      });
      _mostrarMensaje('Error de conexión al API: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // =============================================================================
  // MÉTODO AUXILIAR: Formatear datos del conductor para mostrar
  // =============================================================================
  String _formatearDatosConductor(
    Map<String, dynamic> conductorData,
    String vigenciaEstado,
  ) {
    return '''
RFC: ${conductorData['RFC'] ?? 'N/A'}
Nombre: ${conductorData['NOMBRE'] ?? 'N/A'} ${conductorData['PATERNO'] ?? ''} ${conductorData['MATERNO'] ?? ''}
Puesto: ${conductorData['PUESTO'] ?? 'N/A'}
Vigencia Credencial: ${conductorData['VIGENCIA'] ?? 'N/A'}
Estado de Credencial: $vigenciaEstado
    '''
        .trim();
  }

  // =============================================================================
  // MÉTODO AUXILIAR: Mostrar mensajes SnackBar
  // =============================================================================
  void _mostrarMensaje(String mensaje, Color color) {
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
  // MÉTODO PRINCIPAL: Abrir escáner QR
  // =============================================================================
  void _abrirEscanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Escanea el código QR del conductor'),
            backgroundColor: const Color(0xFF0A2E5C),
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final String rawValue = barcodes.first.rawValue!;
                final uri = Uri.tryParse(rawValue);
                final String? idExtraido = uri?.queryParameters['id'];

                // Validar que se haya obtenido el ID
                if (idExtraido != null && idExtraido.isNotEmpty) {
                  Navigator.pop(context); // Cerrar escáner
                  _enviarDatosApi(idExtraido); // Enviar a API
                } else {
                  // QR no contiene ID válido
                  Navigator.pop(context);
                  _mostrarMensaje(
                    'No se encontró un ID válido en el código QR',
                    Colors.red,
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  // =============================================================================
  // MÉTODO PRINCIPAL: Determinar si el conductor puede continuar
  // =============================================================================
  bool _puedeContinuar() {
    if (_datosConductor == null || _estadoCredencial == null) return false;

    // Estados permitidos para continuar
    final estadosPermitidos = ['VIGENTE', 'ACTIVO', 'VÁLIDO'];
    return estadosPermitidos.contains(_estadoCredencial?.toUpperCase());
  }

  // =============================================================================
  // MÉTODO: Continuar al flujo principal
  // =============================================================================
  void _continuar() {
    if (_puedeContinuar()) {
      // Retornar datos del conductor a la pantalla anterior
      Navigator.of(context).pop({
        'success': true,
        'conductor': _datosConductor,
        'estado': _estadoCredencial,
      });
    }
  }

  // =============================================================================
  // MÉTODO: Reintentar escaneo
  // =============================================================================
  void _reintentar() {
    setState(() {
      _codigoEscaneado = null;
      _datosConductor = null;
      _estadoCredencial = null;
      _scannerActivo = true;
    });
    _abrirEscanner();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validar Credencial de Conductor'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icono principal
            Icon(
              _codigoEscaneado == null
                  ? Icons.qr_code_scanner
                  : _puedeContinuar()
                  ? Icons.check_circle
                  : Icons.error,
              size: 100,
              color: _codigoEscaneado == null
                  ? const Color(0xFF0A2E5C)
                  : _puedeContinuar()
                  ? Colors.green
                  : Colors.red,
            ),
            const SizedBox(height: 20),

            // Título principal
            Text(
              _codigoEscaneado == null
                  ? "Presiona el botón para escanear la credencial del conductor"
                  : _puedeContinuar()
                  ? "Conductor Validado Correctamente"
                  : "Conductor No Autorizado",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _codigoEscaneado == null
                    ? Colors.black87
                    : _puedeContinuar()
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            const SizedBox(height: 30),

            // Botón de escanear (solo si no hay datos)
            if (_codigoEscaneado == null) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _abrirEscanner,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_isLoading ? "Validando..." : "Escanear Código QR"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2E5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],

            // Mostrar información escaneada
            if (_codigoEscaneado != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _puedeContinuar() ? Colors.green[50] : Colors.red[50],
                  border: Border.all(
                    color: _puedeContinuar() ? Colors.green : Colors.red,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      "Información del Conductor:",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      _codigoEscaneado!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Botones de acción
              if (_puedeContinuar()) ...[
                ElevatedButton.icon(
                  onPressed: _continuar,
                  icon: const Icon(Icons.check_circle),
                  label: const Text("Continuar con la Carga"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _reintentar,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Escanear Otra Credencial"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
