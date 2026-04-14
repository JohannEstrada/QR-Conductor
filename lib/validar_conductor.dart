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

  // Datos del conductor validado
  Map<String, dynamic>? _datosConductor;
  String? _estadoCredencial;
  String? _vigenciaExtraida; // Nueva variable para vigencia del QR
  String? _nombreConductor; // Nombre del conductor extraído del QR
  String? _vigenciaCredencial; // Vigencia de la credencial para mostrar

  // =============================================================================
  // MÉTODO PRINCIPAL: Validar vigencia localmente
  // =============================================================================
  void _validarVigenciaLocal(String qrCompleto, String? vigencia) {
    setState(() {
      _isLoading = true;
      _vigenciaExtraida = vigencia;
    });

    // Extraer nombre del QR
    String? nombreExtraido;
    if (qrCompleto.contains('NOMBRE:')) {
      final RegExp nombreRegex = RegExp(r'NOMBRE:([^|]+)');
      final Match? match = nombreRegex.firstMatch(qrCompleto);
      if (match != null) {
        nombreExtraido = match.group(1)?.trim();
        debugPrint('👤 Nombre extraído: $nombreExtraido');
      }
    }

    // Validar vigencia
    if (vigencia == null || vigencia.isEmpty) {
      _mostrarMensaje(
        'La credencial no contiene información de vigencia',
        Colors.red,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Parsear vigencia (ej: "DICIEMBRE 2026")
    final RegExp mesAnoRegex = RegExp(r'([A-Z]+)\s+(\d{4})');
    final Match? match = mesAnoRegex.firstMatch(vigencia.toUpperCase());

    if (match == null) {
      _mostrarMensaje('Formato de vigencia no reconocido', Colors.red);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final String mes = match.group(1)!;
    final int ano = int.parse(match.group(2)!);

    // Mapeo de meses a números
    final Map<String, int> meses = {
      'ENERO': 1,
      'FEBRERO': 2,
      'MARZO': 3,
      'ABRIL': 4,
      'MAYO': 5,
      'JUNIO': 6,
      'JULIO': 7,
      'AGOSTO': 8,
      'SEPTIEMBRE': 9,
      'OCTUBRE': 10,
      'NOVIEMBRE': 11,
      'DICIEMBRE': 12,
    };

    final int mesNumero = meses[mes] ?? 1;
    final DateTime fechaVigencia = DateTime(
      ano,
      mesNumero + 1,
      0,
    ); // Último día del mes
    final DateTime fechaActual = DateTime.now();

    debugPrint(
      '📅 Fecha actual: ${fechaActual.day}/${fechaActual.month}/${fechaActual.year}',
    );
    debugPrint(
      '📅 Fecha vigencia: ${fechaVigencia.day}/${fechaVigencia.month}/${fechaVigencia.year}',
    );

    // Verificar si está vencida
    if (fechaActual.isAfter(fechaVigencia)) {
      // CREDENCIAL VENCIDA
      setState(() {
        _isLoading = false;
        _codigoEscaneado = 'VENCIDA';
        _nombreConductor = nombreExtraido;
        _vigenciaCredencial = vigencia;
      });

      _mostrarMensaje(
        '❌ CREDENCIAL VENCIDA\nVigencia: $vigencia\nNo puede realizar la carga',
        Colors.red,
      );
    } else {
      // CREDENCIAL VIGENTE
      setState(() {
        _isLoading = false;
        _codigoEscaneado = 'VIGENTE';
        _nombreConductor = nombreExtraido;
        _vigenciaCredencial = vigencia;
      });

      _mostrarMensaje(
        '✅ CREDENCIAL VIGENTE\nConductor: $nombreExtraido\nVigencia: $vigencia\nPuede continuar con la carga',
        Colors.green,
      );
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
                final String rawValue = barcodes.first.rawValue!.trim();

                debugPrint('📷 QR Detectado: "$rawValue"');

                String? idExtraido;

                // Opción 1: QR con formato URL (?id=12345)
                final uri = Uri.tryParse(rawValue);
                if (uri?.queryParameters['id'] != null) {
                  idExtraido = uri!.queryParameters['id'];
                  debugPrint('🔗 ID desde URL: $idExtraido');
                }
                // Opción 2: QR con formato completo (RFC:EAHJ020624|NOMBRE:...)
                else if (rawValue.contains('CUIP:')) {
                  // Extraer CUIP del QR completo (prioridad sobre RFC)
                  final RegExp cuipRegex = RegExp(r'CUIP:([^|]+)');
                  final Match? match = cuipRegex.firstMatch(rawValue);
                  if (match != null) {
                    idExtraido = match.group(1)?.trim();
                    debugPrint('🆔 CUIP extraído: $idExtraido');
                  }
                } else if (rawValue.contains('RFC:')) {
                  // Extraer RFC del QR completo (alternativa)
                  final RegExp rfcRegex = RegExp(r'RFC:([^|]+)');
                  final Match? match = rfcRegex.firstMatch(rawValue);
                  if (match != null) {
                    idExtraido = match.group(1)?.trim();
                    debugPrint('📋 RFC extraído: $idExtraido');
                  }
                }
                // Opción 3: QR con texto simple (12345)
                else if (rawValue.isNotEmpty) {
                  idExtraido = rawValue;
                  debugPrint('📝 ID desde texto: $idExtraido');
                }

                // Extraer vigencia del QR si existe
                String? vigenciaExtraida;
                if (rawValue.contains('VIGENCIA:')) {
                  final RegExp vigenciaRegex = RegExp(r'VIGENCIA:([^|]+)');
                  final Match? match = vigenciaRegex.firstMatch(rawValue);
                  if (match != null) {
                    vigenciaExtraida = match.group(1)?.trim();
                    debugPrint('📅 Vigencia extraída: $vigenciaExtraida');
                  }
                }

                // Validar que se haya obtenido el ID
                if (idExtraido != null && idExtraido.isNotEmpty) {
                  // Detener escáner para evitar múltiples detecciones
                  _scannerController.stop();
                  Navigator.pop(context); // Cerrar escáner
                  _validarVigenciaLocal(
                    rawValue,
                    vigenciaExtraida,
                  ); // Validar localmente
                } else {
                  // QR no contiene ID válido
                  _scannerController.stop();
                  Navigator.pop(context);
                  _mostrarMensaje(
                    'El QR escaneado no contiene un ID válido',
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
    return _codigoEscaneado == 'VIGENTE' &&
        _nombreConductor != null &&
        _nombreConductor!.isNotEmpty;
  }

  // =============================================================================
  // MÉTODO: Continuar al flujo principal
  // =============================================================================
  void _continuar() {
    if (_puedeContinuar()) {
      // Retornar datos del conductor validado a la pantalla anterior
      Navigator.of(context).pop({
        'success': true,
        'nombre': _nombreConductor,
        'vigencia': _vigenciaCredencial,
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

            // Mostrar vigencia si está disponible
            if (_vigenciaExtraida != null) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vigencia: $_vigenciaExtraida',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
