import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'info_vehic.dart';
import 'login_page.dart';
import 'services/laravel_api_service.dart';
import 'services/conductor_service.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(), // Convierte el texto a mayúsculas
      selection: newValue.selection,
    );
  }
}

class PagInicio extends StatefulWidget {
  const PagInicio({super.key});

  @override
  State<PagInicio> createState() => _PagInicioState();
}

class _PagInicioState extends State<PagInicio> {
  // Variables de estado para validación de credencial
  bool _credencialValidada = false;
  String? _nombreConductorValidado;
  String? _vigenciaCredencial;

  // Método para mostrar mensajes emergentes en la pantalla
  void _mostrarMensaje(String mensaje, {Color color = Colors.red}) {
    if (mounted) {
      // Verifica que la página siga activa
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje), // Contenido del mensaje
          backgroundColor: color, // Color del mensaje (rojo por defecto)
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // =============================================================================
  // MÉTODO PARA ESCANEAR QR Y VALIDAR CREDENCIAL DIRECTAMENTE
  // =============================================================================
  Future<void> _escanearQRValidarCredencial() async {
    final controller = MobileScannerController();

    // Mostrar diálogo con cámara directamente
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                title: const Text('Escanear Credencial'),
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Expanded(
                child: MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty &&
                        barcodes.first.rawValue != null) {
                      final String rawValue = barcodes.first.rawValue!.trim();

                      // Detener escáner
                      controller.stop();
                      Navigator.of(context).pop();

                      // Validar QR localmente
                      _validarQRDirectamente(rawValue);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================================
  // MÉTODO PARA VALIDAR QR DIRECTAMENTE (LÓGICA LOCAL)
  // =============================================================================
  void _validarQRDirectamente(String qrCompleto) {
    // Extraer vigencia del QR
    String? vigenciaExtraida;
    if (qrCompleto.contains('VIGENCIA:')) {
      final RegExp vigenciaRegex = RegExp(r'VIGENCIA:([^|]+)');
      final Match? match = vigenciaRegex.firstMatch(qrCompleto);
      if (match != null) {
        vigenciaExtraida = match.group(1)?.trim();
      }
    }

    // Extraer nombre del QR
    String? nombreExtraido;
    if (qrCompleto.contains('NOMBRE:')) {
      final RegExp nombreRegex = RegExp(r'NOMBRE:([^|]+)');
      final Match? match = nombreRegex.firstMatch(qrCompleto);
      if (match != null) {
        nombreExtraido = match.group(1)?.trim();
      }
    }

    // Validar vigencia
    if (vigenciaExtraida == null || vigenciaExtraida.isEmpty) {
      _mostrarMensaje(
        'La credencial no contiene información de vigencia',
        color: Colors.red,
      );
      setState(() {
        _credencialValidada = false;
        _nombreConductorValidado = null;
        _vigenciaCredencial = null;
      });
      return;
    }

    // Parsear vigencia
    final RegExp mesAnoRegex = RegExp(r'([A-Z]+)\s+(\d{4})');
    final Match? match = mesAnoRegex.firstMatch(vigenciaExtraida.toUpperCase());

    if (match == null) {
      _mostrarMensaje('Formato de vigencia no reconocido', color: Colors.red);
      setState(() {
        _credencialValidada = false;
        _nombreConductorValidado = null;
        _vigenciaCredencial = null;
      });
      return;
    }

    final String mes = match.group(1)!;
    final int ano = int.parse(match.group(2)!);

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
    final DateTime fechaVigencia = DateTime(ano, mesNumero + 1, 0);
    final DateTime fechaActual = DateTime.now();

    // Verificar si está vencida
    if (fechaActual.isAfter(fechaVigencia)) {
      // CREDENCIAL VENCIDA
      setState(() {
        _credencialValidada = false;
        _nombreConductorValidado = null;
        _vigenciaCredencial = null;
      });

      // Mostrar ventana emergente de credencial vencida
      _mostrarDialogoCredencialVencida(vigenciaExtraida);
    } else {
      // CREDENCIAL VIGENTE
      setState(() {
        _credencialValidada = true;
        _nombreConductorValidado = nombreExtraido;
        _vigenciaCredencial = vigenciaExtraida;
      });

      _mostrarMensaje(
        'CREDENCIAL VIGENTE\nConductor: $nombreExtraido\nVigencia: $vigenciaExtraida',
        color: Colors.green,
      );
    }
  }

  // =============================================================================
  // MÉTODO PARA MOSTRAR DIÁLOGO DE CREDENCIAL VENCIDA
  // =============================================================================
  void _mostrarDialogoCredencialVencida(String vigenciaExtraida) {
    showDialog(
      context: context,
      barrierDismissible: false, // No cerrar al tocar fuera
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width:
              MediaQuery.of(context).size.width *
              0.8, // 80% del ancho de la pantalla
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de error/vencimiento
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 20),

              // Título
              const Text(
                'Credencial Vencida',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 16),

              // Mensaje principal
              const Text(
                'No puede realizar la carga',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
              ),

              const SizedBox(height: 8),

              // Mensaje de vigencia
              Text(
                'La credencial está vencida\nVigencia: $vigenciaExtraida',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              // Botón de regresar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar ventana
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Regresar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================================
  // MÉTODO DE VALIDACIÓN DE CONDUCTOR - Verifica conductor antes de cargar
  // =============================================================================
  Future<bool> _validarConductor({String tipoCarga = 'ordinaria'}) async {
    // Verificar si la credencial ya está validada localmente
    if (_credencialValidada && _nombreConductorValidado != null) {
      _mostrarMensaje(
        'Conductor ya validado: $_nombreConductorValidado',
        color: Colors.green,
      );
      return true;
    } else {
      _mostrarMensaje(
        'Debe validar la credencial primero escaneando el QR',
        color: Colors.red,
      );
      return false;
    }
  }

  // 🆕 Método para mostrar diálogo de vehículo no encontrado
  void _mostrarDialogoVehiculoNoEncontrado(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando afuera
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🎨 Icono y título en la parte superior
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2E5C).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_off,
                      color: Color(0xFF0A2E5C),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🎯 Título principal
                  const Text(
                    'Vehículo No Encontrado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2E5C),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 📝 Mensaje de error
                  const Text(
                    'El número de serie ingresado no existe en el sistema',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 💡 Sugerencia
                  const Text(
                    'Por favor, verifique el número de serie e intente nuevamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // 🔘 Botón de acción
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Cierra el diálogo
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2E5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Entendido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🆕 Método para mostrar diálogo de sin cargas extraordinarias
  void _mostrarDialogoSinCargasExtraordinarias(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando afuera
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🎯 Ícono de advertencia
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 📝 Título
                  const Text(
                    'Sin Cargas Extraordinarias',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2E5C),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 📝 Mensaje específico
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 💡 Sugerencia
                  const Text(
                    'Este vehículo no tiene cargas extraordinarias pendientes para hoy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // 🔘 Botón de regresar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Cierra el diálogo
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Regresar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Método para cerrar la sesión del usuario
  void _cerrarSesion() {
    // Muestra diálogo de confirmación antes de cerrar sesión
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'), // Título del diálogo
        content: const Text(
          '¿Estás seguro de que quieres cerrar sesión?',
        ), // Mensaje de confirmación
        actions: [
          // Botón para cancelar el cierre de sesión
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'), // Texto del botón
          ),
          // Botón para confirmar el cierre de sesión
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cierra el diálogo de confirmación

              // Limpiar datos del conductor al cerrar sesión
              ConductorService.limpiarConductor();

              // Limpiar estado de validación local
              setState(() {
                _credencialValidada = false;
                _nombreConductorValidado = null;
                _vigenciaCredencial = null;
              });

              // Navega a la página de login y limpia todo el historial
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ), // Crea la página de login
                (route) => false, // Elimina todas las páginas del historial
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Cerrar Sesión',
            ), // Texto del botón de confirmación
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Combustible'), // Título de la barra
        backgroundColor: Color(0xFF0A2E5C), // Azul marino más oscuro
        foregroundColor: Colors.white, // Texto e íconos en blanco
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Card(
                  color: const Color(
                    0xFFE3F2FD,
                  ), // Color azul claro para la tarjeta
                  elevation: 4, // Sombra suave debajo de la tarjeta
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      15.0,
                    ), // Bordes redondeados de 15px
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(
                      16.0,
                    ), // Espacio interno de 16px
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min, // Ocupa solo el espacio necesario
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch, // Ocupan todo el ancho
                      children: [
                        Image.asset(
                          'assets/images/Estrella.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20), // 📏 Espacio vertical

                        const Text(
                          'Sistema de Combustible', // Nombre del sistema
                          textAlign: TextAlign.center, // Texto centrado
                          style: TextStyle(
                            fontSize: 24, // Tamaño grande de fuente
                            fontWeight: FontWeight.bold, // Texto en negrita
                            color: Color(0xFF0A2E5C), // Azul marino más oscuro
                          ),
                        ),
                        const SizedBox(height: 15), // Espacio vertical

                        const Text(
                          'Introducir número de serie', // Instrucción para el usuario
                          textAlign: TextAlign.center, // Texto centrado
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ), // Texto más pequeño y gris
                        ),
                        const SizedBox(height: 20), // Espacio vertical
                        // Botón de validación de credencial (QR)
                        ElevatedButton.icon(
                          onPressed: _escanearQRValidarCredencial,
                          icon: const Icon(
                            Icons.qr_code_scanner,
                          ), // Ícono de QR
                          label: Text(
                            _credencialValidada
                                ? 'Credencial Validada: $_nombreConductorValidado'
                                : 'Escanear QR para Validar Credencial',
                          ), // Texto dinámico
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _credencialValidada
                                ? Colors.green
                                : const Color(
                                    0xFF135DD8,
                                  ), // Azul para no validado
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                          ),
                        ),
                        const SizedBox(height: 20), // Espacio vertical
                        // Información de estado
                        if (_credencialValidada) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Conductor: $_nombreConductorValidado\nVigencia: $_vigenciaCredencial',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Botón 1: Carga Ordinaria (deshabilitado hasta validar QR)
                        ElevatedButton.icon(
                          onPressed: _credencialValidada
                              ? () async {
                                  // 1. Primero validar conductor para carga ordinaria
                                  final conductorValido =
                                      await _validarConductor(
                                        tipoCarga: 'ordinaria',
                                      );

                                  if (conductorValido) {
                                    // 2. Si es válido, continuar con búsqueda de vehículo
                                    _showInputDialog(
                                      context,
                                      nombreConductor: _nombreConductorValidado,
                                    );
                                  }
                                  // Si no es válido, el método _validarConductor ya mostró el error
                                }
                              : null, // Deshabilitado si no hay credencial validada
                          icon: const Icon(Icons.search), // Ícono de búsqueda
                          label: const Text(
                            'Carga Ordinaria',
                          ), // Texto del botón
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _credencialValidada
                                ? const Color(0xFF0A2E5C)
                                : Colors.grey, // Gris si está deshabilitado
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: _credencialValidada ? 3 : 0,
                          ),
                        ),
                        const SizedBox(height: 12), // Espacio entre botones
                        // Botón 2: Carga Extraordinaria (deshabilitado hasta validar QR)
                        ElevatedButton.icon(
                          onPressed: _credencialValidada
                              ? () async {
                                  // 1. Primero validar conductor para carga extraordinaria
                                  final conductorValido =
                                      await _validarConductor(
                                        tipoCarga: 'extraordinaria',
                                      );

                                  if (conductorValido) {
                                    // 2. Si es válido, continuar con búsqueda de vehículo
                                    _showInputDialog(
                                      context,
                                      tipoCarga: 'extraordinaria',
                                      nombreConductor: _nombreConductorValidado,
                                    );
                                  }
                                  // Si no es válido, el método _validarConductor ya mostró el error
                                }
                              : null, // Deshabilitado si no hay credencial validada
                          icon: const Icon(Icons.star), // Ícono de estrella
                          label: const Text(
                            'Carga Extraordinaria',
                          ), // Texto del botón
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _credencialValidada
                                ? const Color(0xFF0A2E5C)
                                : Colors.grey, // Gris si está deshabilitado
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: _credencialValidada ? 3 : 0,
                          ),
                        ),
                        const SizedBox(height: 12), // Espacio entre botones
                        // Botón 3: Carga de Bidones (deshabilitado hasta validar QR)
                        ElevatedButton.icon(
                          onPressed: _credencialValidada
                              ? () async {
                                  // 1. Primero validar conductor para carga de bidones
                                  final conductorValido =
                                      await _validarConductor(
                                        tipoCarga: 'bidones',
                                      );

                                  if (conductorValido) {
                                    // 2. Si es válido, continuar con búsqueda de vehículo
                                    _showInputDialog(
                                      context,
                                      tipoCarga: 'bidones',
                                      nombreConductor: _nombreConductorValidado,
                                    );
                                  }
                                  // Si no es válido, el método _validarConductor ya mostró el error
                                }
                              : null, // Deshabilitado si no hay credencial validada
                          icon: const Icon(
                            Icons.inventory_2,
                          ), // Ícono de bidones
                          label: const Text(
                            'Carga de Bidones',
                          ), // Texto del botón
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _credencialValidada
                                ? const Color(0xFF0A2E5C)
                                : Colors.grey, // Gris si está deshabilitado
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: _credencialValidada ? 3 : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 8,
            ), // Espacio reducido entre botones de carga y cerrar sesión
            // Botón de cerrar sesión en la parte inferior
            Container(
              width: double.infinity, // Ocupa todo el ancho disponible
              padding: const EdgeInsets.only(
                bottom: 16.0,
              ), // Espacio inferior de 16px
              child: ElevatedButton.icon(
                onPressed: _cerrarSesion, // Llama al método para cerrar sesión
                icon: const Icon(Icons.logout), // Ícono de salir/cerrar sesión
                label: const Text('Cerrar Sesión'), // Texto del botón
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.red, // Color rojo para indicar acción peligrosa
                  foregroundColor: Colors.white, // Texto e ícono en blanco
                  padding: const EdgeInsets.symmetric(
                    vertical:
                        18, // Aumentado de 12 a 18 para hacer el botón más alto
                  ), // Padding vertical
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      8,
                    ), // Bordes ligeramente redondeados
                  ),
                  elevation: 2, // Sombra suave
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 Método para mostrar diálogo de búsqueda de vehículos con cargas de bidones
  Future<void> _mostrarDialogoBuscarVehiculoBidones(
    BuildContext context,
  ) async {
    // Crea controlador para el campo de texto del diálogo
    final TextEditingController controller = TextEditingController();

    // Muestra diálogo modal para ingresar número de serie
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Buscar Vehículo con Cargas de Bidones',
            style: TextStyle(
              color: Color(0xFF8B4513), // Color café para bidones
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Introduce los últimos 8 dígitos del número de serie:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Últimos 8 dígitos',
                  hintText: 'Ej: A004352',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2, color: Color(0xFF8B4513)),
                  labelStyle: TextStyle(color: Color(0xFF8B4513)),
                ),
                autofocus: true,
                inputFormatters: [UpperCaseTextFormatter()],
              ),
            ],
          ),
          actions: [
            // Botón para cancelar la búsqueda
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
              child: const Text('Cancelar'),
            ),
            // Botón para buscar el vehículo
            ElevatedButton(
              onPressed: () async {
                final numSerie = controller.text.trim();
                if (numSerie.length == 8) {
                  Navigator.of(context).pop(); // Cierra el diálogo
                  await _buscarVehiculoBidones(
                    context,
                    numSerie,
                  ); // Busca con ruta de bidones
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, introduce 8 dígitos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B4513),
                foregroundColor: Colors.white,
              ),
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
  }

  // 🆕 Método para buscar vehículo con cargas de bidones
  Future<void> _buscarVehiculoBidones(
    BuildContext context,
    String numSerie,
  ) async {
    try {
      // 🆕 DEBUG: Mostrar URL específica de bidones
      final url =
          'https://combustibles.sspmichoacan.com/api/revisar-bidones/$numSerie';
      print('🔍 DEBUG: URL de bidones: $url');

      // 🆕 Llamar a API específica de bidones
      final result = await LaravelApiService.getCargasBidones(numSerie);

      // 🆕 DEBUG: Mostrar respuesta
      print('🔍 DEBUG: Respuesta de bidones: $result');

      // 🆕 Si hay respuesta, navegar a info_vehic con tipo bidones
      if (result.isNotEmpty && result['id'] != null) {
        // 🆕 Crear estructura de vehículo para bidones
        final vehiculoData = {
          'success': true,
          'num_serie': numSerie,
          'vehiculo': result['vehiculo'] ?? {},
          'cargas': [result], // Envolver en lista
          'message': 'Cargas de bidones encontradas',
          'tipo_carga': 'bidones',
        };

        // 🆕 Navegar a info_vehic con datos de bidones
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InfoVehic(
              numeroSerie: numSerie,
              datosVehiculo: vehiculoData['vehiculo'],
              cargasDelVehiculo: vehiculoData['cargas'],
              tipoCargaPreseleccionado: 'bidones',
            ),
          ),
        );
      } else {
        _mostrarDialogoVehiculoNoEncontrado(
          'No se encontraron cargas de bidones para este vehículo',
        );
      }
    } catch (e) {
      print('❌ Error al buscar vehículo con bidones: $e');
      _mostrarDialogoVehiculoNoEncontrado(
        'Error al buscar cargas de bidones: $e',
      );
    }
  }

  // Método para mostrar diálogo de entrada de número de serie
  Future<void> _showInputDialog(
    BuildContext context, {
    String tipoCarga = 'ordinaria',
    String? nombreConductor,
  }) async {
    // Crea controlador para el campo de texto del diálogo
    final TextEditingController controller = TextEditingController();

    // Muestra diálogo modal para ingresar número de serie
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Introducir Número de Serie', // Título del diálogo
            style: TextStyle(
              color: Color(0xFF0A2E5C),
            ), // Color azul corporativo
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Ocupa solo el espacio necesario
            children: [
              // Instrucción para el usuario
              const Text(
                'Introduce los últimos 8 dígitos del número de serie:', // Instrucción específica
                style: TextStyle(fontSize: 14), // Tamaño de fuente pequeño
              ),
              const SizedBox(height: 16), // Espacio vertical de 16px
              // Campo de texto para ingresar el número de serie
              TextField(
                controller: controller, // Asocia el controlador al campo
                maxLength: 8, // Limita a 8 caracteres
                textCapitalization:
                    TextCapitalization.characters, // Fuerza mayúsculas
                decoration: const InputDecoration(
                  labelText: 'Últimos 8 dígitos', // Etiqueta del campo
                  hintText: 'Ej: A004352', // 💡 Ejemplo de formato
                  border: OutlineInputBorder(), // Borde normal del campo
                  prefixIcon: Icon(
                    Icons.numbers,
                    color: Color(0xFF0A2E5C),
                  ), // Ícono de números
                  labelStyle: TextStyle(
                    color: Color(0xFF0A2E5C), // Azul marino más oscuro
                  ), // Color de etiqueta cuando está activa
                ),
                autofocus: true, // Enfoca automáticamente el campo
                inputFormatters: [
                  UpperCaseTextFormatter(), // Formateador personalizado
                ],
              ),
            ],
          ),
          actions: [
            //  Botón para cancelar la búsqueda
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(), // Cierra el diálogo sin hacer nada
              child: const Text(
                'Cancelar', // 📝 Texto del botón
                style: TextStyle(
                  color: Colors.grey,
                ), // Color gris para indicar acción secundaria
              ),
            ),
            // Botón para buscar el vehículo
            ElevatedButton(
              onPressed: () async {
                // Obtiene el texto del campo y elimina espacios
                final numSerie = controller.text.trim();

                // Validación: verifica que no esté vacío
                if (numSerie.isEmpty) {
                  _mostrarMensaje(
                    'Por favor, ingrese un número de serie',
                  ); // Mensaje de error
                  return; // Detiene la ejecución
                }
                // Llamar a la API real para buscar vehículo
                try {
                  Map<String, dynamic> result;

                  // 🔄 Seleccionar la API según el tipo de carga
                  switch (tipoCarga) {
                    case 'extraordinaria':
                      print(
                        '🔍 Buscando cargas extraordinarias para: $numSerie',
                      );

                      // 🆕 DEBUG: Mostrar URL exacta que se está llamando
                      final url =
                          'https://combustibles.sspmichoacan.com/cargas-extraordinarias/$numSerie';
                      print('🔍 DEBUG: URL de API extraordinaria: $url');

                      final cargasExtraordinarias =
                          await LaravelApiService.getCargasExtraordinarias(
                            numSerie,
                          );

                      // 🆕 DEBUG: Mostrar respuesta completa de la API
                      print(
                        '🔍 DEBUG: Respuesta completa de API extraordinaria:',
                      );
                      print(
                        '🔍 DEBUG: Tipo de respuesta: ${cargasExtraordinarias.runtimeType}',
                      );
                      print('🔍 DEBUG: Contenido: $cargasExtraordinarias');

                      // 🆕 Verificar si hay cargas extraordinarias
                      if (cargasExtraordinarias['success'] == true &&
                          cargasExtraordinarias['data'] != null &&
                          (cargasExtraordinarias['data'] as List).isNotEmpty) {
                        // 🆕 Hay cargas, construir resultado normal
                        // La API devuelve datos del vehículo + lista de cargas en 'data'
                        result = {
                          'success': true,
                          'num_serie': numSerie,
                          'vehiculo':
                              cargasExtraordinarias, // Usar el objeto completo que contiene datos del vehículo
                          'cargas':
                              cargasExtraordinarias['data'], // La lista de cargas está en 'data'
                          'message': 'Cargas extraordinarias encontradas',
                        };
                      } else {
                        // 🆕 No hay cargas extraordinarias
                        result = {
                          'success': false,
                          'num_serie': numSerie,
                          'message':
                              'No hay cargas extraordinarias pendientes para este vehículo',
                          'sin_cargas': true,
                        };
                      }
                      break;

                    case 'bidones':
                      print('🔍 Buscando cargas de bidones para: $numSerie');

                      // 🆕 DEBUG: Mostrar URL específica de bidones
                      final urlBidones =
                          'https://combustibles.sspmichoacan.com/api/revisar-bidones/$numSerie';
                      print('🔍 DEBUG: URL de API bidones: $urlBidones');

                      final datosBidones =
                          await LaravelApiService.getCargasBidones(numSerie);

                      // 🆕 DEBUG: Mostrar respuesta completa de la API
                      print('🔍 DEBUG: Respuesta completa de API bidones:');
                      print(
                        '🔍 DEBUG: Tipo de respuesta: ${datosBidones.runtimeType}',
                      );
                      print('🔍 DEBUG: Contenido: $datosBidones');

                      // 🆕 MANEJO ESPECIAL PARA BIDONES - Nueva estructura completa
                      if (datosBidones.containsKey('success') &&
                          datosBidones['success'] == false) {
                        // 🆕 Caso: Vehículo encontrado pero sin bidones pendientes
                        print(
                          '✅ Vehículo encontrado pero sin bidones pendientes',
                        );
                        result = {
                          'success': true, // El vehículo existe
                          'num_serie': numSerie,
                          'vehiculo':
                              datosBidones['vehiculo'] ??
                              datosBidones, // Usar datos del vehículo
                          'cargas': [], // Sin cargas de bidones
                          'message':
                              datosBidones['message'] ??
                              'No hay bidones pendientes para este vehículo hoy',
                          'sin_bidones': true, // Marcar especial
                        };
                      } else {
                        // 🆕 Caso: Hay bidones disponibles - Nueva estructura completa
                        print('✅ Bidones encontrados con nueva estructura');
                        result = {
                          'success': true,
                          'num_serie': numSerie,
                          'vehiculo':
                              datosBidones, // Toda la estructura del vehículo
                          'cargas':
                              datosBidones['data'] ?? [], // Lista de bidones
                          'message': 'Cargas de bidones encontradas',
                          'pendientes': datosBidones['pendientes'] ?? 0,
                        };
                      }
                      break;

                    default:
                      // 🔄 Para cargas ordinarias, usar el método existente
                      result = await LaravelApiService.buscarVehiculo(numSerie);
                      break;
                  }

                  // Verifica si el servidor encontró el vehículo
                  if (result['success']) {
                    // Vehículo encontrado - Muestra mensaje de éxito
                    _mostrarMensaje(
                      result['message'], // Mensaje del servidor con cantidad de cargas
                      color: Colors.green, // Color verde para indicar éxito
                    );

                    // Cierra el diálogo de búsqueda
                    Navigator.of(context).pop();

                    // DEBUG: Verificar que el nombre se está pasando correctamente
                    print(
                      'DEBUG: pag_inicio - nombreConductor = $nombreConductor',
                    );
                    print('DEBUG: pag_inicio - tipoCarga = $tipoCarga');

                    // Navega a la página de información del vehículo
                    Navigator.push(
                      context, // Contexto actual de navegación
                      MaterialPageRoute(
                        builder: (context) => InfoVehic(
                          numeroSerie: numSerie, // Número de serie buscado
                          datosVehiculo:
                              result['vehiculo']
                                  as Map<
                                    String,
                                    dynamic
                                  >?, // Datos completos del vehículo
                          cargasDelVehiculo:
                              result['cargas']
                                  as List<
                                    dynamic
                                  >?, // TODAS las cargas del vehículo
                          tipoCargaPreseleccionado:
                              tipoCarga, // Pasar tipo de carga
                          nombreConductorValidado:
                              nombreConductor, // Pasar nombre del conductor validado
                        ),
                      ),
                    );
                  } else if (result['sin_cargas'] == true) {
                    // 🆕 Caso especial: Vehículo encontrado pero sin cargas extraordinarias
                    _mostrarDialogoSinCargasExtraordinarias(result['message']);
                  } else {
                    // Vehículo no encontrado o error del servidor
                    _mostrarDialogoVehiculoNoEncontrado(result['message']);
                  }
                } catch (e) {
                  // Si hay problemas de conexión o red, captura el error

                  // 🔍 Verificar si es error de vehículo no encontrado
                  if (e.toString().contains('Vehículo no encontrado')) {
                    // 🔴 Mostrar ventana emergente de vehículo no encontrado
                    _mostrarDialogoVehiculoNoEncontrado(
                      'El número de serie ingresado no existe en el sistema.',
                    );
                  } else {
                    // 🔴 Mostrar SnackBar para otros errores de conexión
                    _mostrarMensaje(
                      'Error de conexión: $e',
                    ); // Muestra error específico de conexión
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF0A2E5C,
                ), // Azul marino más oscuro
                foregroundColor: Colors.white, // Texto e ícono en blanco
              ),
              child: const Text('Buscar'), // Texto del botón de búsqueda
            ),
          ],
        );
      },
    );
  }
}
