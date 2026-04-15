import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🆕 Para detectar plataforma
import 'package:flutter/services.dart'; // 🆕 Para input formatters
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
//import 'ticket.dart';
import 'pag_inicio.dart'; // 🆕 Importar PagInicio para navegación
import 'services/laravel_api_service.dart';

// =============================================================================
// CLASE CARGA - Página para registrar cargas de combustible
// =============================================================================
// Función: Permite registrar cargas ordinarias y extraordinarias
// Características: Implementa candado de carga diaria y validaciones
// =============================================================================

// 🆕 Formatter para convertir texto a mayúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class Carga extends StatefulWidget {
  // Parámetros recibidos desde InfoVehic
  final Map<String, dynamic>? datosVehiculo; // Datos completos del vehículo
  final List<dynamic>? cargasDelVehiculo; // Lista de cargas asignadas
  final String numeroSerie; // Número de serie del vehículo
  final String? tipoCombustible; // Tipo de combustible (MAGNA/PREMIUM)
  final String?
  tipoCargaPreseleccionado; // Tipo de carga (ordinaria/extraordinaria/bidones)
  final String? idCargaAsignada; // ID específico de carga asignada
  final String?
  idVehiculoCorrecto; // ID correcto del vehículo (para cargas especiales)
  final String? nombreConductorValidado; // Nombre del conductor validado por QR

  const Carga({
    super.key,
    this.datosVehiculo,
    this.cargasDelVehiculo,
    required this.numeroSerie,
    this.tipoCombustible,
    this.tipoCargaPreseleccionado,
    this.idCargaAsignada, // ID de carga asignada
    this.idVehiculoCorrecto, // ID correcto del vehículo
    this.nombreConductorValidado, // Nombre del conductor validado
  });

  @override
  State<Carga> createState() => _CargaState();
}

// =============================================================================
// ESTADO DE LA CLASE - Variables y controladores
// =============================================================================

class _CargaState extends State<Carga> {
  // Controladores de texto para inputs del formulario
  final TextEditingController _litrosCargadosController =
      TextEditingController(); // Input para litros cargados
  final TextEditingController _precioCombustibleController =
      TextEditingController(); // Input para precio por litro
  final TextEditingController _personaQueCargaController =
      TextEditingController(); // 🆕 Input para persona que realiza la carga
  final TextEditingController _kilometrajeController =
      TextEditingController(); // 🆕 Input para kilometraje del vehículo

  // Gestor de imágenes para capturar tickets
  final ImagePicker _imagePicker = ImagePicker(); // Selector de imágenes
  XFile? _imagenTicket; // Imagen capturada (compatible Web/Móvil)
  String _imagenBase64 = ''; // Imagen convertida a base64 para API
  String _imagenUrl = ''; // URL de imagen para plataforma Web

  // Variables de estado para el cálculo y UI
  double _precioTotal = 0.0; // Precio total calculado
  bool _mostrarResultado = false; // Mostrar/ocultar resultado del cálculo
  String _precioCombustible = '---'; // Precio del combustible desde API
  bool _cargandoPrecio = true; // Estado de carga de precio
  String _tipoCarga = 'ordinaria'; // Tipo de carga actual (por defecto)

  // ===========================================
  // VARIABLES PARA CANDADO DE CARGA DIARIA
  // ===========================================
  bool _verificandoCargaDiaria = false; // Estado: verificando si ya cargó hoy
  bool _yaCargoOrdinariaHoy = false; // Resultado: ya cargó ordinaria hoy
  Map<String, dynamic>?
  _datosCargaAnterior; // Datos de la carga anterior encontrada

  // =============================================================================
  // INITSTATE - Inicialización del estado
  // =============================================================================
  // Función: Se ejecuta al crear la página
  // Acciones: Inicia verificación de carga diaria si es ordinaria
  // =============================================================================
  @override
  void initState() {
    super.initState();

    // 🔍 CORRECCIÓN: Asignar tipo de carga desde el widget
    _tipoCarga = widget.tipoCargaPreseleccionado ?? 'ordinaria';

    print('DEBUG: initState() - Tipo de carga asignado: $_tipoCarga');
    print(
      'DEBUG: widget.tipoCargaPreseleccionado: ${widget.tipoCargaPreseleccionado}',
    );

    // Llenar automáticamente el campo del conductor si viene del QR validado
    print('DEBUG: Verificando nombre del conductor...');
    print(
      'DEBUG: widget.nombreConductorValidado = ${widget.nombreConductorValidado}',
    );
    print(
      'DEBUG: widget.tipoCargaPreseleccionado = ${widget.tipoCargaPreseleccionado}',
    );

    if (widget.nombreConductorValidado != null &&
        widget.nombreConductorValidado!.isNotEmpty) {
      _personaQueCargaController.text = widget.nombreConductorValidado!;
      print(
        'DEBUG: Nombre del conductor validado asignado automáticamente: ${widget.nombreConductorValidado}',
      );
    } else {
      print(
        'DEBUG: Nombre del conductor es NULL o está vacío - No se asigna automáticamente',
      );
    }

    // Si es carga ordinaria, verificar si ya cargó hoy (candado de seguridad)
    if (_tipoCarga == 'ordinaria') {
      print(
        'DEBUG: Es carga ordinaria - Iniciando verificación de carga diaria',
      );
      _verificarSiYaCargoHoy();
    } else {
      print(
        'DEBUG: No es carga ordinaria (${_tipoCarga}) - No se verifica carga diaria',
      );
    }

    // Obtener precio del combustible al iniciar (solo si está montado)
    if (mounted) {
      _obtenerPrecioCombustible();
    }
  }

  // =============================================================================
  // VERIFICACIÓN DE CARGA DIARIA - Candado con API /revisar-cargas/
  // =============================================================================
  // Función: Verifica si el vehículo ya realizó carga ordinaria hoy
  // API: /api/revisar-cargas/{numero_serie}
  // Campo: 'realizado' (true = ya cargó, false = no ha cargado)
  // Acción: Bloquea la carga si realizado es true
  // =============================================================================
  Future<void> _verificarSiYaCargoHoy() async {
    // 🆕 CORRECCIÓN: Validar que el widget esté montado antes de hacer setState
    if (!mounted) return;

    setState(() {
      _verificandoCargaDiaria = true; // Mostrar loading
    });

    try {
      // 🆕 CAMBIO: Usar API /revisar-cargas/ para verificar campo 'realizado'
      final resultado = await LaravelApiService.buscarVehiculo(
        widget.numeroSerie,
      );

      // 🆕 CORRECCIÓN: Validar que el widget esté montado antes de hacer setState
      if (!mounted) return;

      setState(() {
        _verificandoCargaDiaria = false; // Ocultar loading
      });

      print('🔍 DEBUG: Respuesta completa del API: $resultado');
      print('🔍 DEBUG: Success: ${resultado['success']}');
      print('🔍 DEBUG: Campo realizado: ${resultado['realizado']}');

      if (resultado['success']) {
        // 🆕 NUEVA LÓGICA: Usar campo 'realizado' de /revisar-cargas/
        // CORRECCIÓN: Validar que el widget esté montado antes de hacer setState
        if (!mounted) return;

        setState(() {
          _yaCargoOrdinariaHoy = resultado['realizado'] ?? false;
          // 🗑️ Ya no necesitamos datos de carga anterior para esta validación
          _datosCargaAnterior = null;
        });

        print('🔍 DEBUG: ¿Ya cargó ORDINARIA hoy?: $_yaCargoOrdinariaHoy');
        print(
          '🔍 DEBUG: litros_autorizados disponible: ${widget.datosVehiculo?['litros_autorizados']}',
        );
        print(
          '🔍 DEBUG: Validación usando campo realizado de /revisar-cargas/',
        );
        print(
          '🔍 DEBUG: 🚨 Si realizado=true, litros_autorizados desaparece (comportamiento esperado)',
        );
      }
    } catch (e) {
      print('🔍 DEBUG: Error en verificación: $e');
      // Error en la verificación - Permitir carga por seguridad
      // CORRECCIÓN: Validar que el widget esté montado antes de hacer setState
      if (!mounted) return;

      setState(() {
        _verificandoCargaDiaria = false;
        _yaCargoOrdinariaHoy = false;
      });
    }
  }

  // =============================================================================
  // FUNCIÓN ESPECÍFICA PARA EXTRAER ID DE CARGA ASIGNADA DE BIDONES
  // =============================================================================
  Future<String> _extraerIdCargaAsignadaBidones() async {
    print('DEBUG: Buscando id_carga_asignada para bidones');
    print('DEBUG: widget.cargasDelVehiculo: ${widget.cargasDelVehiculo}');

    if (widget.cargasDelVehiculo != null &&
        widget.cargasDelVehiculo!.isNotEmpty) {
      final primerBidon = widget.cargasDelVehiculo!.first;
      print('DEBUG: primerBidon completo: $primerBidon');
      print('DEBUG: Keys del primerBidon: ${primerBidon.keys.toList()}');
      print('DEBUG: Valores de cada campo:');
      primerBidon.forEach((key, value) {
        print('  - $key: $value (${value.runtimeType})');
      });

      final idBidon = primerBidon['id'];
      print('DEBUG: idBidon extraído: $idBidon');
      print('DEBUG: Tipo de idBidon: ${idBidon.runtimeType}');

      if (idBidon != null) {
        // SOLUCIÓN CORRECTA: Usar el ID real del bidón que viene del GET
        // El campo 'id' ahora contiene el valor de 'id_carga_bidon' del GET
        final idCargaAsignada = idBidon.toString();
        print('DEBUG: ID de bidón para POST (ID real): $idCargaAsignada');
        print('DEBUG: ID original del bidón (para referencia): $idBidon');
        print('DEBUG: Estructura completa del bidón: $primerBidon');
        print(
          'DEBUG: Campos disponibles en bidón: ${primerBidon.keys.toList()}',
        );
        return idCargaAsignada;
      } else {
        print('DEBUG: ID de bidón no encontrado o es null');
        _mostrarErrorBidonesSinID();
        return 'ERROR';
      }
    } else {
      print('DEBUG: No hay bidones disponibles');
      _mostrarErrorSinBidonesDisponibles();
      return 'ERROR';
    }
  }

  // =============================================================================
  // FUNCIONES ESPECÍFICAS PARA MANEJO DE ERRORES DE BIDONES
  // =============================================================================

  // Muestra error cuando no hay bidones válidos disponibles
  void _mostrarErrorBidonesInvalidos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '❌ No hay bidones válidos disponibles para este vehículo',
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Muestra error cuando el ID del bidón no existe en el servidor
  void _mostrarErrorBidonNoExiste(String idBidon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '❌ El ID de bidón ($idBidon) no existe en el servidor\n💡 Contacte al administrador para sincronizar los datos',
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Entendido',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Muestra error cuando los bidones no tienen ID válido
  void _mostrarErrorBidonesSinID() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '❌ Los bidones no tienen un ID válido. Contacte al administrador',
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Muestra error cuando no hay bidones asignados al vehículo
  void _mostrarErrorSinBidonesDisponibles() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ No hay bidones asignados a este vehículo'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // =============================================================================
  // UI DE CANDADO - Pantalla cuando ya cargó ordinaria hoy
  // =============================================================================
  // Función: Muestra UI de bloqueo con información de la carga anterior
  // Acción: Informa al usuario y muestra detalles de la carga del día
  // =============================================================================
  Widget _mostrarUICandadoCargaDiaria() {
    final datosCarga = _datosCargaAnterior;

    return Scaffold(
      appBar: AppBar(
        title: Text('Carga - ${widget.numeroSerie}'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: Colors.orange[50],
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.orange[300]!, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block, size: 80, color: Colors.orange),
                  const SizedBox(height: 20),
                  const Text(
                    'CARGA ORDINARIA BLOQUEADA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Este vehículo ya realizó una carga ORDINARIA hoy',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Número de serie: ${widget.numeroSerie}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Mostrar datos de la carga anterior si existen
                  if (datosCarga != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Última carga ORDINARIA registrada hoy:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (datosCarga['created_at'] != null)
                            Text(
                              'Hora: ${_formatearHora(datosCarga['created_at'])}',
                            ),
                          if (datosCarga['litros_cargados'] != null)
                            Text('Litros: ${datosCarga['litros_cargados']}'),
                          if (datosCarga['importe_cargado'] != null)
                            Text('Importe: \$${datosCarga['importe_cargado']}'),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Regresar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 30,
                      ),
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

  // =============================================================================
  // FORMATEAR HORA - Helper para mostrar hora de carga anterior
  // =============================================================================
  // Función: Convierte timestamp a formato HH:MM
  // Uso: Muestra hora de la carga ordinaria anterior
  // =============================================================================
  String _formatearHora(String fechaString) {
    try {
      final fecha = DateTime.parse(fechaString);
      return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Hora no disponible';
    }
  }

  // =============================================================================
  // UI DE RESTRICCIÓN EXTRAORDINARIA - Bloqueo sin asignación
  // =============================================================================
  // Función: Muestra UI cuando no hay cargas extraordinarias asignadas
  // Condición: Solo se muestra para tipo 'extraordinaria' sin registros
  // Acción: Informa que solo tiene cargas ordinarias disponibles
  // =============================================================================
  Widget _mostrarUIRestriccionExtraordinaria() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga de Vehículo'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: Image.asset(
                  'assets/images/Estrella.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.local_gas_station,
                      size: 60,
                      color: Color(0xFF0A2E5C),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            Card(
              color: Colors.orange[400],
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Carga Extraordinaria No Asignada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No se tiene una carga extraordinaria asignada para el vehículo ${widget.numeroSerie}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'A pesar de que tiene carga ordinaria disponible',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Regresar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // BUILD - Método principal de construcción de UI
  // =============================================================================
  // Función: Construye la interfaz basada en el estado actual
  // Flujo: 1) Loading → 2) Candado → 3) Validaciones → 4) UI normal
  // Prioridades: Seguridad primero, luego funcionalidad
  // =============================================================================
  @override
  Widget build(BuildContext context) {
    // ===========================================
    // PASO 1: VERIFICACIÓN INICIAL - Loading de carga diaria
    // ===========================================
    // Si está verificando si ya cargó hoy, mostrar loading
    if (_verificandoCargaDiaria) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Carga - ${widget.numeroSerie}'),
          backgroundColor: const Color(0xFF0A2E5C),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0A2E5C)),
              SizedBox(height: 20),
              Text('Verificando si el vehículo ya cargó ORDINARIA hoy...'),
            ],
          ),
        ),
      );
    }

    // ===========================================
    // PASO 2: CANDADO DE CARGA DIARIA - Bloqueo por seguridad
    // ===========================================
    // Si ya cargó ordinaria hoy, mostrar UI de bloqueo
    if (_yaCargoOrdinariaHoy && _tipoCarga == 'ordinaria') {
      return _mostrarUICandadoCargaDiaria();
    }

    // ===========================================
    // PASO 3: VALIDACIÓN DE EXTRAORDINARIA - Sin asignación
    // ===========================================
    // Si es extraordinaria pero no tiene asignaciones, bloquear
    if (widget.tipoCargaPreseleccionado == 'extraordinaria' &&
        (widget.cargasDelVehiculo == null ||
            widget.cargasDelVehiculo!.isEmpty)) {
      return _mostrarUIRestriccionExtraordinaria();
    }

    // ===========================================
    // PASO 4: UI NORMAL - Formulario de carga
    // ===========================================
    // Si pasó todas las validaciones, mostrar formulario completo
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga del Vehículo'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Center(
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
                      // Logo corporativo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(60),
                          child: Image.asset(
                            'assets/images/Estrella.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.local_gas_station,
                                size: 60,
                                color: Color(0xFF0A2E5C),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Carga del Vehículo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2E5C),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Número de Serie: ${widget.numeroSerie}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Litros autorizados',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.numbers,
                            color: Color(0xFF0A2E5C),
                          ),
                        ),
                        child: Text(
                          _getLitrosAutorizados(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _litrosCargadosController,
                        decoration: InputDecoration(
                          labelText: 'Litros cargados',
                          hintText: 'Ingrese los litros cargados',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.opacity,
                            color: Color(0xFF0A2E5C),
                          ),
                          errorText:
                              _litrosCargadosController.text.isNotEmpty &&
                                  !_validarLitrosCargados(
                                    _litrosCargadosController.text,
                                  )
                              ? 'No puede exceder los ${_getLitrosAutorizados()} litros'
                              : null,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _personaQueCargaController,
                        decoration: InputDecoration(
                          labelText: 'Conductor que realiza la carga',
                          hintText: 'Ingrese el nombre completo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.person,
                            color: Color(0xFF0A2E5C),
                          ),
                        ),
                        keyboardType: TextInputType.text,
                        textCapitalization:
                            TextCapitalization.characters, // 🆕 Solo mayúsculas
                        inputFormatters: [
                          UpperCaseTextFormatter(), // 🆕 Forzar mayúsculas
                        ],
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _kilometrajeController,
                        decoration: InputDecoration(
                          labelText: 'Kilometraje del vehículo',
                          hintText: 'Ingrese el kilometraje actual',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.speed,
                            color: Color(0xFF0A2E5C),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 20),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Precio por litro',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: Color(0xFF0A2E5C),
                          ),
                        ),
                        child: _cargandoPrecio
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF0A2E5C),
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                _precioCombustible,
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _calcularPrecioTotal,
                        icon: const Icon(Icons.calculate),
                        label: const Text('Calcular'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2E5C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (_mostrarResultado) ...[
                        const SizedBox(height: 20),
                        Card(
                          color: Colors.green.shade50,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Colors.green.shade300,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.monetization_on,
                                      color: Colors.green.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'PRECIO TOTAL',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '\$${_precioTotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '(${_litrosCargadosController.text} L × \$${_precioCombustibleController.text})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed:
                              (_mostrarResultado && _imagenTicket == null)
                              ? _capturarImagenTicket
                              : null,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            _imagenTicket == null
                                ? 'Capturar foto del número de folio'
                                : 'Foto capturada',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (_mostrarResultado && _imagenTicket == null)
                                ? const Color(0xFF0A2E5C)
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                      if (_imagenTicket != null) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _guardarYContinuar,
                          icon: const Icon(Icons.check_circle, size: 28),
                          label: const Text(
                            'Finalizar',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 40,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(280, 60),
                            elevation: 8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '📋 Al presionar "Finalizar" se guardará la carga y podrás registrar otro vehículo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Obtener precio según tipo de combustible
  Future<void> _obtenerPrecioCombustible() async {
    // CORRECCIÓN: Validar que el widget esté montado ANTES de empezar
    if (!mounted) return;

    if (widget.tipoCombustible == null) {
      if (mounted) {
        setState(() {
          _precioCombustible = '---';
          _cargandoPrecio = false;
        });
      }
      return;
    }

    try {
      final result = await LaravelApiService.obtenerPrecioCombustibleHoy();

      // 🆕 CORRECCIÓN: Validar MONTADO antes de procesar respuesta
      if (!mounted) return;

      if (result['success']) {
        final precios = result['precios'] as Map<String, dynamic>;
        final tipo = widget.tipoCombustible!.toLowerCase();
        final precio = precios[tipo] ?? 0.0;

        // 🆕 CORRECCIÓN: Validar MONTADO antes de setState final
        if (mounted) {
          setState(() {
            _precioCombustible = precio.toString();
            _precioCombustibleController.text = precio.toString();
            _cargandoPrecio = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _precioCombustible = '---';
            _cargandoPrecio = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error en _obtenerPrecioCombustible: $e');
      if (mounted) {
        setState(() {
          _precioCombustible = '---';
          _cargandoPrecio = false;
        });
      }
    }
  }

  // Método para obtener litros autorizados como double (para validación)
  double _getLitrosAutorizadosAsDouble() {
    // 🎯 Para cargas ordinarias, tomar directamente de datos del vehículo
    // El campo 'litros_autorizados' viene de la API /revisar-cargas/
    // 🚨 IMPORTANTE: Cuando realizado=true, este campo desaparece
    final litrosDesdeAPI = widget.datosVehiculo?['litros_autorizados'];

    // Verificar si es carga de bidones para usar campo especial
    if (widget.tipoCargaPreseleccionado == 'bidones') {
      // 🛢️ Para bidones, usar el campo especial de datos del vehículo
      final litrosBidones = widget.datosVehiculo?['litros_autorizados_bidones'];
      if (litrosBidones != null) {
        return double.tryParse(litrosBidones.toString()) ?? 0.0;
      }
    }

    // ✅ Para cargas ordinarias y extraordinarias, usar dato directo de la API
    if (litrosDesdeAPI != null) {
      return double.tryParse(litrosDesdeAPI.toString()) ?? 0.0;
    }

    // 🚨 NUEVA LÓGICA: Si no hay litros_autorizados, verificar si ya realizó carga
    final realizado = widget.datosVehiculo?['realizado'];
    if (realizado == true) {
      // 🔴 Si ya realizó carga, retornar 0 para bloquear validación
      return 0.0;
    }

    // 🔄 Si no hay dato en API, intentar con método antiguo
    if (widget.cargasDelVehiculo == null || widget.cargasDelVehiculo!.isEmpty) {
      return 0.0;
    }

    final primeraCarga = widget.cargasDelVehiculo!.first;
    // 🆕 Para bidones usar 'litros', para otros usar 'litros_autorizados'
    final litrosAutorizados = widget.tipoCargaPreseleccionado == 'bidones'
        ? primeraCarga['litros']
        : primeraCarga['litros_autorizados'];

    return double.tryParse(litrosAutorizados?.toString() ?? '0') ?? 0.0;
  }

  // Validar que litros cargados no excedan autorizados
  // 🔍 Validar que litros cargados no excedan autorizados
  bool _validarLitrosCargados(String valor) {
    final litrosCargados = double.tryParse(valor) ?? 0.0;
    final litrosAutorizados = _getLitrosAutorizadosAsDouble();

    return litrosCargados <= litrosAutorizados;
  }

  // 🔍 Método para obtener litros autorizados de las cargas
  String _getLitrosAutorizados() {
    // 🎯 Para cargas ordinarias, tomar directamente de datos del vehículo
    // El campo 'litros_autorizados' viene de la API /revisar-cargas/
    // 🚨 IMPORTANTE: Cuando realizado=true, este campo desaparece
    final litrosDesdeAPI = widget.datosVehiculo?['litros_autorizados'];

    if (widget.tipoCargaPreseleccionado == 'bidones') {
      //   Para bidones, obtener litros del campo 'litros' que viene del servicio
      //  El campo 'litros' ahora viene directamente del servicio desde data[0]
      final litrosBidones = widget.datosVehiculo?['litros'];
      if (litrosBidones != null && litrosBidones.toString() != '0') {
        print('  DEBUG: Litros para bidones: $litrosBidones');
        return litrosBidones.toString();
      }
    }

    // ✅ Para cargas ordinarias y extraordinarias, usar dato directo de la API
    if (litrosDesdeAPI != null) {
      return litrosDesdeAPI.toString();
    }

    // 🚨 NUEVA LÓGICA: Si no hay litros_autorizados, verificar si ya realizó carga
    final realizado = widget.datosVehiculo?['realizado'];
    if (realizado == true) {
      // 🔴 Si ya realizó carga, mostrar mensaje especial
      return 'Ya cargó hoy';
    }

    // 🔄 Si no hay dato en API, intentar con método antiguo
    if (widget.cargasDelVehiculo == null || widget.cargasDelVehiculo!.isEmpty) {
      return '---';
    }

    // 🎯 Obtener ID de la primera carga
    final primeraCarga = widget.cargasDelVehiculo!.first;
    // 🆕 Para bidones usar 'litros', para otros usar 'litros_autorizados'
    final litrosAutorizados = widget.tipoCargaPreseleccionado == 'bidones'
        ? primeraCarga['litros']
        : primeraCarga['litros_autorizados'];

    if (litrosAutorizados != null) {
      return litrosAutorizados.toString();
    }

    return '0'; // Valor por defecto
  }

  void _calcularPrecioTotal() {
    // 🔍 Validar que los litros cargados no excedan los autorizados
    if (!_validarLitrosCargados(_litrosCargadosController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Los litros cargados no pueden exceder los ${_getLitrosAutorizados()} litros autorizados',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final litrosCargados =
        double.tryParse(_litrosCargadosController.text) ?? 0.0;
    final precioCombustible =
        double.tryParse(_precioCombustibleController.text) ?? 0.0;

    setState(() {
      _precioTotal = litrosCargados * precioCombustible;
      _mostrarResultado = true;
    });
  }

  // 🔍 Método para obtener ID del vehículo
  String _getIdVehiculo() {
    //  Si tenemos un ID correcto del vehículo (para cargas especiales), usarlo
    if (widget.idVehiculoCorrecto != null &&
        widget.idVehiculoCorrecto!.isNotEmpty) {
      print(
        ' DEBUG: Usando ID correcto del vehículo: ${widget.idVehiculoCorrecto}',
      );
      return widget.idVehiculoCorrecto!;
    }

    //  Para cargas ordinarias, intentar obtener de datosVehiculo
    if (_tipoCarga == 'ordinaria' && widget.datosVehiculo != null) {
      print(' DEBUG: Buscando ID de vehículo para ordinaria');
      print(' DEBUG: datosVehiculo: ${widget.datosVehiculo}');

      final idDesdeDatos =
          widget.datosVehiculo!['id_vehiculo'] ??
          widget.datosVehiculo!['id'] ??
          widget.datosVehiculo!['id_carga'];

      if (idDesdeDatos != null && idDesdeDatos.toString() != 'NO_ENCONTRADO') {
        print(' DEBUG: ID encontrado en datosVehiculo: $idDesdeDatos');
        return idDesdeDatos.toString();
      }
    }

    //  Para cargas de bidones, obtener ID de datosVehiculo desde data[0]
    if (_tipoCarga == 'bidones' && widget.datosVehiculo != null) {
      print(' DEBUG: Buscando ID de vehículo para bidones');
      print(' DEBUG: datosVehiculo: ${widget.datosVehiculo}');

      //  El campo 'id_vehiculo' viene directamente del servicio desde data[0]
      final idVehiculoDesdeDatos = widget.datosVehiculo!['id_vehiculo'];
      if (idVehiculoDesdeDatos != null &&
          idVehiculoDesdeDatos.toString() != 'NO_ENCONTRADO') {
        print(
          ' DEBUG: ID_vehiculo encontrado en datosVehiculo: $idVehiculoDesdeDatos',
        );
        return idVehiculoDesdeDatos.toString();
      }

      print(' DEBUG: No se encontró ID válido para bidones');
    }

    //  Método original como fallback
    if (widget.cargasDelVehiculo == null || widget.cargasDelVehiculo!.isEmpty) {
      return '---';
    }

    //  Obtener ID de la primera carga
    final primeraCarga = widget.cargasDelVehiculo!.first;
    final idVehiculo = primeraCarga['id_vehiculo'];

    return idVehiculo?.toString() ?? '---';
  }

  // Método para capturar imagen del ticket (compatible con Web y móvil)
  Future<void> _capturarImagenTicket() async {
    try {
      final XFile? imagen = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Calidad de imagen
      );

      if (imagen != null) {
        // Convertir a base64 para el POST
        final bytes = await imagen.readAsBytes();
        final base64 = base64Encode(bytes);

        // Agregar prefix de data URI para que Laravel lo reconozca como imagen
        final base64WithPrefix = 'data:image/jpeg;base64,$base64';

        setState(() {
          _imagenTicket = imagen;
          _imagenBase64 = base64WithPrefix; // Guardar con prefix
          // En Web, usar la URL para mostrar la imagen
          if (kIsWeb) {
            _imagenUrl = imagen.path; // En Web, path es una URL
          }
        });

        // Ya no hace POST automático, solo muestra la imagen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket capturado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se tomó ninguna foto'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al capturar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🆕 Método para mostrar vista previa de la imagen (compatible con Web y móvil)
  void _mostrarVistaPrevia() {
    if (_imagenTicket != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📷 Vista previa del ticket'),
          content: kIsWeb
              ? Image.network(
                  _imagenUrl,
                  height: 300,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        const Text('No se puede mostrar la imagen'),
                        Text('URL: ${_imagenUrl}'),
                      ],
                    );
                  },
                )
              : Image.file(
                  File(_imagenTicket!.path),
                  height: 300,
                  fit: BoxFit.contain,
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('✅ OK'),
            ),
          ],
        ),
      );
    }
  }

  // Método combinado: Guardar importe y continuar
  Future<void> _guardarYContinuar() async {
    if (_precioTotal > 0) {
      // Validar que la imagen haya sido capturada
      if (_imagenBase64.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Debes tomar una foto del ticket primero'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 📝 Insertar carga completada en la base de datos
      try {
        final idVehiculo = _getIdVehiculo();
        final litrosCargados = _litrosCargadosController.text.trim();
        final importeCargado = _precioTotal;
        final numSerie = widget.numeroSerie;
        final tipoCarga = _tipoCarga == 'ordinaria'
            ? 'ORDINARIA'
            : _tipoCarga == 'bidones'
            ? 'BIDON'
            : 'EXTRAORDINARIA';

        // 🆕 DEBUG: Mostrar IDs que vamos a enviar
        String idCargaAsignadaParaEnviar = '0';

        // 🎯 PRIORIDAD 1: BIDONES - Extraer ID específico para bidones
        if (_tipoCarga == 'bidones') {
          idCargaAsignadaParaEnviar = await _extraerIdCargaAsignadaBidones();
          if (idCargaAsignadaParaEnviar == 'ERROR') {
            return; // El error ya se mostró en la función específica
          }
        } else if (widget.idCargaAsignada != null &&
            widget.idCargaAsignada!.isNotEmpty) {
          idCargaAsignadaParaEnviar = widget.idCargaAsignada!;
          print(
            '🔍 DEBUG: Usando widget.idCargaAsignada: $idCargaAsignadaParaEnviar',
          );
        } else if (widget.cargasDelVehiculo != null &&
            widget.cargasDelVehiculo!.isNotEmpty &&
            _tipoCarga == 'extraordinaria') {
          // 🎯 EXTRAER ID de widget.cargasDelVehiculo para cargas extraordinarias
          final primeraCarga = widget.cargasDelVehiculo!.first;
          if (primeraCarga is Map<String, dynamic> &&
              primeraCarga.containsKey('id')) {
            // 🔍 VERIFICACIÓN: El campo 'id' de la API es el mismo que 'id_carga_asignada' del POST
            final idDeLaAPI = primeraCarga['id'];
            idCargaAsignadaParaEnviar = idDeLaAPI.toString();
            print(
              '🔍 DEBUG: ID de extraordinaria encontrado: $idCargaAsignadaParaEnviar',
            );
          } else {
            print('🔍 DEBUG: ID de extraordinaria no encontrado, usando 0');
          }
        } else if (_tipoCarga == 'ordinaria' && widget.datosVehiculo != null) {
          // 🆕 Para cargas ordinarias, obtener ID de datosVehiculo
          print('🔍 DEBUG: Buscando id_carga_asignada para ordinaria');
          final idCarga = widget.datosVehiculo!['id_carga'];
          if (idCarga != null) {
            idCargaAsignadaParaEnviar = idCarga.toString();
            print(
              '🔍 DEBUG: ID de ordinaria encontrado: $idCargaAsignadaParaEnviar',
            );
          } else {
            print('🔍 DEBUG: ID de ordinaria no encontrado, usando 0');
          }
        }

        print('🔍 DEBUG: DATOS DEL POST - ANTES DE ENVIAR');
        print('🔍 DEBUG: idVehiculo: $idVehiculo');
        print('🔍 DEBUG: litrosCargados: $litrosCargados');
        print('🔍 DEBUG: importeCargado: $importeCargado');
        print('🔍 DEBUG: numSerie: $numSerie');
        print('🔍 DEBUG: tipoCarga: $tipoCarga');
        print(
          '🔍 DEBUG: widget.tipoCargaPreseleccionado: ${widget.tipoCargaPreseleccionado}',
        );
        print('🔍 DEBUG: widget.idCargaAsignada: ${widget.idCargaAsignada}');
        print(
          '🔍 DEBUG: idCargaAsignadaParaEnviar: $idCargaAsignadaParaEnviar',
        );
        print(
          '🔍 DEBUG: nombre_conductor: ${_personaQueCargaController.text.trim()}',
        );

        // ========================================================================
        // 📋 DEBUG: Mostrar todos los datos que vamos a enviar al servidor
        // ========================================================================
        // Estos prints nos permiten ver exactamente qué datos estamos enviando
        // antes de hacer el POST al servidor Laravel
        print(
          '🔍 DEBUG: tipoCarga: $tipoCarga',
        ); // Tipo de carga (ORDINARIA/extraordinaria)
        print(
          '🔍 DEBUG: idCargaAsignada: $idCargaAsignadaParaEnviar',
        ); // ID de la carga asignada
        print(
          '🔍 DEBUG: nombre_conductor: ${_personaQueCargaController.text.trim()}',
        ); // 🆕 NOMBRE DE LA PERSONA QUE REALIZA LA CARGA - ESTE ES EL CAMPO CLAVE
        print(
          'DEBUG: odometro: ${(_tipoCarga == 'bidones' || _tipoCarga == 'BIDON') ? '0' : _kilometrajeController.text.trim()}',
        ); // KILOMETRAJE DEL VEHÍCULO - NUEVO CAMPO (0 para BIDONES)
        print(
          '🔍 DEBUG: widget.datosVehiculo: ${widget.datosVehiculo}',
        ); // Datos completos del vehículo
        print(
          '🔍 DEBUG: widget.cargasDelVehiculo: ${widget.cargasDelVehiculo}',
        ); // Todas las cargas del vehículo

        // ========================================================================
        // 🛡️ VALIDACIÓN: Verificar que los campos requeridos no estén vacíos
        // ========================================================================
        // Esta validación es CRÍTICA - no permite enviar el POST si los campos están vacíos
        if (_personaQueCargaController.text.trim().isEmpty) {
          // Si el campo está vacío, mostramos un error y DETENEMOS la ejecución
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Debe ingresar el nombre de la persona que realiza la carga',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return; // ← DETIENE LA EJECUCIÓN - NO SE HACE EL POST
        }

        if (_kilometrajeController.text.trim().isEmpty) {
          // Si el kilometraje está vacío, mostramos un error y DETENEMOS la ejecución
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Debe ingresar el kilometraje del vehículo'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return; // ← DETIENE LA EJECUCIÓN - NO SE HACE EL POST
        }

        // ========================================================================
        // 🚀 LLAMADA A LA API: Enviar todos los datos al servidor Laravel
        // ========================================================================
        // Aquí es donde se envía el POST con todos los datos incluyendo nombre_conductor

        // DEBUG: Verificar valor exacto de _tipoCarga
        print('DEBUG: _tipoCarga = "$_tipoCarga"');
        print('DEBUG: ¿_tipoCarga == "bidones"? ${_tipoCarga == 'bidones'}');
        print('DEBUG: ¿_tipoCarga == "BIDON"? ${_tipoCarga == 'BIDON'}');
        final result = await LaravelApiService.insertarCargaCompletada(
          idVehiculo: idVehiculo, // ID del vehículo en la base de datos
          litrosCargados: litrosCargados, // Cantidad de litros cargados
          importeCargado: importeCargado, // Costo total de la carga
          numSerie: numSerie, // Número de serie del vehículo
          tipoCarga: tipoCarga, // Tipo de carga seleccionado
          idCargaAsignada: idCargaAsignadaParaEnviar, // ID de la carga asignada
          imagenTicket: _imagenBase64, // Imagen del ticket en formato base64
          nombre_conductor: _personaQueCargaController.text
              .trim(), // 🆕 NOMBRE DE LA PERSONA QUE REALIZA LA CARGA - CAMPO CLAVE
          odometro: (_tipoCarga == 'bidones' || _tipoCarga == 'BIDON')
              ? '0'
              : _kilometrajeController.text
                    .trim(), // KILOMETRAJE DEL VEHÍCULO - NUEVO CAMPO (0 para BIDONES)
        );

        if (result['success']) {
          // 🎉 Mostrar confirmación al usuario
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Carga $tipoCarga registrada correctamente'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // 🚀 Regresar a página de inicio después de finalizar carga
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const PagInicio(),
            ), // 🆕 Navegación directa a PagInicio
            (Route<dynamic> route) =>
                false, // Eliminar todas las rutas anteriores
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Debes calcular el precio total primero'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
