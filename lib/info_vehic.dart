import 'package:flutter/material.dart';
import 'services/laravel_api_service.dart';
import 'pag_inicio.dart';
import 'carga.dart';

class InfoVehic extends StatefulWidget {
  // Parámetros recibidos desde PagInicio
  final String numeroSerie; // Número de serie del vehículo
  final Map<String, dynamic>? datosVehiculo; // Datos completos del vehículo
  final List<dynamic>? cargasDelVehiculo; // Lista de cargas asignadas
  final String? tipoCombustible; // Tipo de combustible (MAGNA/PREMIUM)
  final String?
  tipoCargaPreseleccionado; // Tipo de carga (ordinaria/extraordinaria/bidones)
  final String? idCargaAsignada; // ID específico de carga asignada
  final String?
  idVehiculoCorrecto; // ID correcto del vehículo (para cargas especiales)
  final String? nombreConductorValidado; // Nombre del conductor validado por QR

  const InfoVehic({
    super.key,
    required this.numeroSerie,
    this.datosVehiculo,
    this.cargasDelVehiculo,
    this.tipoCombustible,
    this.tipoCargaPreseleccionado,
    this.idCargaAsignada, // ID de carga asignada
    this.idVehiculoCorrecto, // ID correcto del vehículo
    this.nombreConductorValidado, // Nombre del conductor validado
  });

  // Crear estado mutable para el widget
  @override
  State<InfoVehic> createState() => _InfoVehicState();
}

class _InfoVehicState extends State<InfoVehic> {
  // Inicialización del estado del widget
  @override
  void initState() {
    super.initState();
    // Eliminada verificación diaria al iniciar para mejor experiencia
  }

  // Método helper para reemplazar NULL con guiones
  String _formatearDato(dynamic dato) {
    if (dato == null) {
      return '------------'; // Guiones para NULL
    }
    final String texto = dato.toString();
    if (texto.isEmpty || texto.toLowerCase() == 'null') {
      return '------------'; // Guiones para vacío o "null" string
    }
    return texto; // Retornar dato válido
  }

  // =============================================================================
  // MÉTODO AUXILIAR: Obtener ID de carga asignada
  // =============================================================================
  String? _getIdCargaAsignada() {
    // Verificar si hay cargas disponibles
    if (widget.cargasDelVehiculo == null || widget.cargasDelVehiculo!.isEmpty) {
      return null; // No hay cargas asignadas
    }

    // Obtener ID de la primera carga de la lista
    final primeraCarga = widget.cargasDelVehiculo!.first; // Primer elemento
    final idCarga = primeraCarga['id']; // Extraer ID del mapa

    return idCarga?.toString(); // Retornar ID como string
  }

  // =============================================================================
  // MÉTODO AUXILIAR: Obtener ID de carga de bidones
  // =============================================================================

  String? _getIdCargaBidon(Map<String, dynamic> datosBidones) {
    // Obtener ID del bidón desde el campo id_carga_bidon del GET
    final idCargaBidon = datosBidones['id_carga_bidon']?.toString();
    return idCargaBidon;
  }

  // =============================================================================
  // DIÁLOGO DE SIN EXTRAORDINARIAS - Ventana emergente
  // =============================================================================
  void _mostrarDialogoSinExtraordinarias(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // No cerrar al tocar fuera
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F5F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de documento vacío
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                // Título
                const Text(
                  'Sin Cargas Extraordinarias',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 16),

                // Mensaje principal
                const Text(
                  'Este vehículo no tiene cargas extraordinarias asignadas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
                ),

                const SizedBox(height: 24),

                // Botón de regreso
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cerrar diálogo

                      // 🏠 Volver a página de inicio
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => PagInicio()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      'Volver al inicio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =============================================================================
  // MÉTODO AUXILIAR: color del estatus del vehículo
  // =============================================================================

  Color _getColorEstatus() {
    // Extraer estatus y convertir a minúsculas para comparación
    final estatus = widget.datosVehiculo?['estatus']?.toString().toLowerCase();

    // Asignar color según estatus
    switch (estatus) {
      case 'activo': // Vehículo operativo
      case 'taller': // Vehículo en mantenimiento (pero autorizado)
        return Colors.green; // Verde = autorizado

      case 'inactivo': // Vehículo no operativo
      case 'baja': // Vehículo dado de baja
        return Colors.red; // Rojo = no autorizado

      default: // Estatus desconocido
        return Colors.grey; // Gris = desconocido
    }
  }

  // Método para obtener icono según estatus
  IconData _getIconoEstatus() {
    // Extraer estatus y convertir a minúsculas para comparación
    final estatus = widget.datosVehiculo?['estatus']?.toString().toLowerCase();

    // Asignar icono según estatus
    switch (estatus) {
      case 'activo': // Vehículo operativo
        return Icons.check_circle; // Círculo con check
      case 'taller': // Vehículo en mantenimiento
        return Icons.build; // Herramienta/martillo
      case 'inactivo': // Vehículo no operativo
        return Icons.cancel; // Círculo con X
      case 'baja': //  Vehículo dado de baja
        return Icons.block; // Círculo con bloqueo
      default: // Estatus desconocido
        return Icons.help_outline; // Signo de interrogación
    }
  }

  // =============================================================================
  // MÉTODO AUXILIAR: Obtener mensaje de autorización según estatus
  // =============================================================================

  String _getMensajeEstatus() {
    // Extraer estatus y convertir a minúsculas para comparación
    final estatus = widget.datosVehiculo?['estatus']?.toString().toLowerCase();

    // Asignar mensaje según estatus
    switch (estatus) {
      case 'activo': // Vehículo operativo
        return 'Vehículo AUTORIZADO para realizar carga'; // Mensaje positivo
      case 'taller': // Vehículo en mantenimiento (pero autorizado)
        return 'Vehículo en taller - AUTORIZADO para carga'; // Mensaje informativo
      case 'inactivo': // Vehículo no operativo
        return 'Vehículo INACTIVO - NO AUTORIZADO para carga'; // Mensaje negativo
      case 'baja': // Vehículo dado de baja
        return 'Vehículo de BAJA - NO AUTORIZADO para carga'; // Mensaje negativo
      default: // Estatus desconocido
        return 'Estatus desconocido - Contactar administrador'; // Mensaje de ayuda
    }
  }

  // Método para verificar si está autorizado
  bool _estaAutorizado() {
    final estatus = widget.datosVehiculo?['estatus']?.toString().toLowerCase();
    return estatus == 'activo' || estatus == 'taller';
  }

  // =============================================================================
  // MÉTODO PARA VERIFICAR CAMPO 'REALIZADO' - Candado de carga ordinaria
  // =============================================================================

  Future<void> _verificarCargaYContinuar(BuildContext context) async {
    try {
      // Llamar a API para verificar campos 'realizado' y 'autorizado'
      final resultado = await LaravelApiService.buscarVehiculo(
        widget.numeroSerie,
      );

      // CORRECCIÓN: Los campos están anidados en 'vehiculo'
      final realizado = resultado['vehiculo']?['realizado'] ?? false;
      final autorizado = resultado['vehiculo']?['autorizado'] ?? false;

      if (resultado['success'] == true) {
        // Validación combinada para cargas ordinarias
        if (widget.tipoCargaPreseleccionado == 'ordinaria') {
          if (realizado == true) {
            // Caso 1: Ya realizó carga hoy
            _mostrarDialogoCargaBloqueada(context);
          } else if (autorizado == false) {
            // Caso 2: Hoy no es día autorizado
            _mostrarDialogoDiaNoAutorizado(context);
          } else {
            // Caso 3: Puede cargar
            _navegarACargaNormal(context);
          }
        } else {
          // Para extraordinarias y bidones, continuar normal
          _navegarACargaNormal(context);
        }
      } else {
        // Si hay error en API, continuar por seguridad
        _navegarACargaNormal(context);
      }
    } catch (e) {
      // Error en verificación - Continuar por seguridad
      _navegarACargaNormal(context);
    }
  }

  // =============================================================================
  // DIÁLOGO DE DÍA NO AUTORIZADO - Ventana emergente
  // =============================================================================

  void _mostrarDialogoDiaNoAutorizado(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // No cerrar al tocar fuera
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de calendario
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 40,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(height: 20),

              // Título
              const Text(
                'Día No Autorizado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(height: 16),

              // Mensaje principal
              const Text(
                'Hoy no es día de carga para este vehículo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
              ),

              const SizedBox(height: 8),

              // Mensaje secundario
              Text(
                'El vehículo no está autorizado para cargar ordinaria hoy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              // Botón de regreso
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar diálogo

                    // Volver a página de inicio
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => PagInicio()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Volver al inicio',
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
  // DIÁLOGO DE CARGA BLOQUEADA - Ventana emergente por carga repetida
  // =============================================================================

  void _mostrarDialogoCargaBloqueada(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // No cerrar al tocar fuera
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de bloqueo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2E5C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block,
                  size: 40,
                  color: Color(0xFF0A2E5C),
                ),
              ),

              const SizedBox(height: 20),

              // Título
              const Text(
                'Carga Ordinaria Bloqueada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2E5C),
                ),
              ),

              const SizedBox(height: 16),

              // Mensaje principal
              const Text(
                'Este vehículo ya tiene registrada una carga ordinaria hoy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
              ),

              const SizedBox(height: 8),

              // Mensaje secundario
              Text(
                'No se puede realizar otra carga ordinaria el mismo día.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              // Botón de regreso
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar diálogo

                    // Volver a página de inicio
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => PagInicio()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Volver al inicio',
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
  // MÉTODO DE NAVEGACIÓN A CARGA - Flujo normal (para candado)
  // =============================================================================
  void _navegarACargaNormal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Carga(
          datosVehiculo: widget.datosVehiculo,
          cargasDelVehiculo: widget.cargasDelVehiculo ?? [],
          numeroSerie:
              widget.datosVehiculo?['num_serie'] ??
              widget.numeroSerie, // Usar número completo del vehículo
          // Para bidones usar 'combustible', para otros usar 'tipo_combustible'
          tipoCombustible:
              widget.datosVehiculo?['combustible'] ??
              widget.datosVehiculo?['tipo_combustible'],
          tipoCargaPreseleccionado: widget.tipoCargaPreseleccionado,
          nombreConductorValidado: widget
              .nombreConductorValidado, // Pasar nombre del conductor validado
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Siempre mostrar el flujo normal sin restricciones
    return Scaffold(
      appBar: AppBar(
        title: const Text('Información del Vehículo'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo y título
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/Estrella.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.directions_car,
                        size: 60,
                        color: Color(0xFF0A2E5C),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Información del Vehículo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2E5C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Número de Serie: ${widget.numeroSerie}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            Card(
              color:
                  _getColorEstatus(), // Solo depende del estatus del vehículo
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Icono centrado
                    Center(
                      child: Icon(
                        _getIconoEstatus(),
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Título centrado
                    const Text(
                      'Estatus del vehículo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Estatus centrado
                    Text(
                      _formatearDato(
                        widget.datosVehiculo?['estatus'],
                      ).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    // Mensaje centrado
                    Text(
                      _getMensajeEstatus(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Color(0xFFE3F2FD),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.numbers,
                        color: Color(0xFF0A2E5C),
                      ),
                      title: const Text('Número económico:'),
                      subtitle: Text(
                        _formatearDato(widget.datosVehiculo?['num_economico']),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.person,
                        color: Color(0xFF0A2E5C),
                      ),
                      title: const Text('Conductor asignado al vehículo:'),
                      subtitle: Text(
                        _formatearDato(widget.datosVehiculo?['conductor']),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.badge,
                        color: Color(0xFF0A2E5C),
                      ),
                      title: const Text('Placa:'),
                      subtitle: Text(
                        _formatearDato(widget.datosVehiculo?['placa']),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.local_gas_station,
                        color: Color(0xFF0A2E5C),
                      ),
                      title: const Text('Tipo de combustible:'),
                      subtitle: Text(
                        _formatearDato(
                          // Para bidones usar 'combustible', para otros usar 'tipo_combustible'
                          (() {
                            final combustible =
                                widget.datosVehiculo?['combustible'];
                            final tipoCombustible =
                                widget.datosVehiculo?['tipo_combustible'];

                            return combustible ?? tipoCombustible;
                          })(),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _estaAutorizado()
                    ? () async {
                        // Para cargas ordinarias, verificar campo 'realizado'
                        // Para cargas extraordinarias, verificar aquí si hay cargas
                        final tipoCarga = widget.tipoCargaPreseleccionado
                            ?.toLowerCase();
                        if (tipoCarga == 'ordinaria') {
                          await _verificarCargaYContinuar(context);
                        } else if (tipoCarga == 'extraordinaria') {
                          // VALIDAR CARGAS EXTRAORDINARIAS AQUÍ
                          await _verificarCargasExtraordinariasYContinuar(
                            context,
                          );
                        } else {
                          // Para bidones, ir directamente
                          _navegarACarga(context, tipoCarga ?? 'bidones');
                        }
                      }
                    : null, // null inhabilita el botón si no está autorizado
                style: ElevatedButton.styleFrom(
                  backgroundColor: _estaAutorizado()
                      ? const Color(0xFF0A2E5C)
                      : Colors.grey, // Gris si no está autorizado
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 40,
                  ),
                  minimumSize: const Size(200, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  // Mensaje simple según autorización
                  !_estaAutorizado() ? 'Vehículo no autorizado' : 'Continuar',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // MÉTODO PARA VERIFICAR CARGAS EXTRAORDINARIAS - Flujo optimizado
  // =============================================================================

  Future<void> _verificarCargasExtraordinariasYContinuar(
    BuildContext context,
  ) async {
    try {
      //  Usar las cargas que ya tenemos disponibles en lugar de llamar a la API nuevamente
      final cargasDisponibles = widget.cargasDelVehiculo ?? [];

      //  Verificar si hay cargas extraordinarias
      if (cargasDisponibles.isEmpty) {
        //  No hay cargas extraordinarias - Mostrar diálogo
        _mostrarDialogoSinExtraordinarias(context);
      } else {
        //  Hay cargas extraordinarias - Continuar normal
        _navegarACarga(context, 'extraordinaria');
      }
    } catch (e) {
      //  Error en verificación - Mostrar diálogo por seguridad
      _mostrarDialogoSinExtraordinarias(context);
    }
  }

  // =============================================================================
  // MÉTODO PARA NAVEGAR A CARGA CON TIPO SELECCIONADO
  // =============================================================================

  // Método para navegar a Carga con tipo seleccionado
  bool _isProcessing = false; // 🆕 Bandera para evitar doble ejecución

  void _navegarACarga(BuildContext context, String tipoCarga) async {
    // Evitar doble ejecución
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;

    if (tipoCarga == 'extraordinaria') {
      // Para cargas extraordinarias, usar los datos ya disponibles
      try {
        // Usar las cargas que ya tenemos disponibles
        final cargasDisponibles = widget.cargasDelVehiculo ?? [];

        if (cargasDisponibles.isNotEmpty) {
          final primerElemento =
              cargasDisponibles.first as Map<String, dynamic>;
          final idCargaAsignada =
              primerElemento['id_carga_extraordinaria']?.toString() ??
              primerElemento['id']?.toString() ??
              '';
          // Extraer el ID correcto del vehículo (no de la carga)
          final idVehiculoCorrecto =
              primerElemento['id_vehiculo']?.toString() ??
              widget.datosVehiculo?['id']?.toString() ??
              widget.datosVehiculo?['id_vehiculo']?.toString() ??
              '';

          // Navegación con el ID correcto
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Carga(
                datosVehiculo: widget.datosVehiculo,
                cargasDelVehiculo: cargasDisponibles,
                numeroSerie:
                    widget.datosVehiculo?['num_serie'] ??
                    widget.numeroSerie, // Usar número completo del vehículo
                tipoCombustible:
                    widget.datosVehiculo?['combustible'] ??
                    widget.datosVehiculo?['tipo_combustible'],
                tipoCargaPreseleccionado: tipoCarga,
                idCargaAsignada: idCargaAsignada,
                idVehiculoCorrecto:
                    idVehiculoCorrecto, // Pasar ID correcto del vehículo
                nombreConductorValidado: widget
                    .nombreConductorValidado, // Pasar nombre del conductor validado
              ),
            ),
          );
        } else {
          _mostrarDialogoSinExtraordinarias(context);
        }
      } catch (e) {
        _mostrarDialogoErrorGeneral(context, e.toString());
      }
    } else if (tipoCarga == 'bidones') {
      // Para cargas de bidones, obtener datos específicos
      try {
        final datosBidones = await LaravelApiService.getCargasBidones(
          widget.numeroSerie,
        );

        // VERIFICAR SI HAY BIDONES O NO
        if (datosBidones['success'] == false &&
            datosBidones['sin_bidones'] == true) {
          // 📍 VEHÍCULO EXISTE PERO NO TIENE BIDONES
          _mostrarDialogoVehiculoSinBidones(context);
          return;
        }

        // Extraer litros del campo 'litros' de la respuesta
        final litrosAutorizados = datosBidones['litros']?.toString() ?? '0';

        // Extraer ID del vehículo de los datos base
        final idVehiculo =
            widget.datosVehiculo?['id']?.toString() ??
            widget.datosVehiculo?['id_vehiculo']?.toString() ??
            widget.datosVehiculo?['vehiculo_id']?.toString() ??
            'NO_ENCONTRADO';

        // Extraer ID de carga asignada (usar método específico para bidones)
        final idCargaAsignada = _getIdCargaBidon(
          datosBidones,
        ); // Método específico para bidones
        // Crear datos modificados para la página de carga
        final datosModificados = {
          ...widget.datosVehiculo ?? {},
          'litros_autorizados_bidones':
              litrosAutorizados, // Campo especial para bidones
          'id_vehiculo_real': idVehiculo, // Guardar ID real para el POST
        };

        // Crear lista de cargas para bidones (estructura similar a ordinarias)
        final cargasBidones = [
          {
            'id':
                datosBidones['id_carga_bidon']?.toString() ??
                'bidones_${widget.numeroSerie}', //  Usar ID_CARGA_BIDÓN real del bidón
            'litros_autorizados': litrosAutorizados,
            'tipo_carga': 'bidones',
            'id_vehiculo': idVehiculo, //  Agregar ID del vehículo
            'id_carga_asignada':
                idCargaAsignada, //  ID de la tabla base (tronco común)
          },
        ];

        // Navegar a Carga con datos de bidones
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Carga(
              datosVehiculo: datosModificados,
              cargasDelVehiculo: cargasBidones,
              numeroSerie:
                  widget.datosVehiculo?['num_serie'] ??
                  widget.numeroSerie, // Usar número completo del vehículo
              // Para bidones usar 'combustible', para otros usar 'tipo_combustible'
              tipoCombustible:
                  widget.datosVehiculo?['combustible'] ??
                  widget.datosVehiculo?['tipo_combustible'],
              tipoCargaPreseleccionado: tipoCarga,
              idCargaAsignada: idCargaAsignada, // Usar ID de la tabla base
              idVehiculoCorrecto: idVehiculo, // Pasar ID correcto del vehículo
              nombreConductorValidado: widget
                  .nombreConductorValidado, // Pasar nombre del conductor validado
            ),
          ),
        );
      } catch (e) {
        // CORRECCIÓN: Validar context antes de usar ScaffoldMessenger
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al obtener cargas de bidones: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      // Para cargas ordinarias, usar flujo normal
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Carga(
            datosVehiculo: widget.datosVehiculo, // Pasar datos del vehículo
            cargasDelVehiculo: widget
                .cargasDelVehiculo, // Pasar cargas del vehículo (tabla ordinaria)
            numeroSerie:
                widget.datosVehiculo?['num_serie'] ??
                widget
                    .numeroSerie, // Usar número completo del vehículo // Pasar número de serie
            tipoCombustible:
                widget.datosVehiculo?['combustible'] ??
                widget
                    .datosVehiculo?['tipo_combustible'], // Pasar tipo de combustible
            tipoCargaPreseleccionado:
                tipoCarga, // Pasar tipo de carga seleccionado
            idCargaAsignada:
                _getIdCargaAsignada(), // Pasar ID extraído de /api/cargas
          ),
        ),
      );
    }
  }

  // =============================================================================
  // MÉTODO PARA MOSTRAR DIÁLOGO DE VEHÍCULO SIN BIDONES
  // =============================================================================
  void _mostrarDialogoVehiculoSinBidones(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de bidones
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_drink,
                  size: 40,
                  color: Colors.brown,
                ),
              ),

              const SizedBox(height: 20),

              // Título
              const Text(
                'Vehículo Sin Bidones',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),

              const SizedBox(height: 16),

              // Mensaje principal
              const Text(
                'Este vehículo no tiene bidones asignados.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
              ),

              const SizedBox(height: 8),

              // Mensaje secundario con número de serie
              Text(
                'Número de serie: ${widget.numeroSerie}\n\nEl vehículo existe en el sistema pero actualmente no tiene cargas de bidones pendientes.\n\nPuede continuar con cargas ordinarias o extraordinarias.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              // Botón de regreso
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar diálogo

                    // Volver a página de inicio
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => PagInicio()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Volver al inicio',
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
  // MÉTODO PARA MOSTRAR DIÁLOGO DE ERROR GENERAL
  // =============================================================================
  void _mostrarDialogoErrorGeneral(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de error
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error, size: 40, color: Colors.red),
              ),

              const SizedBox(height: 20),

              // Título
              const Text(
                'Error Inesperado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 16),

              // Mensaje de error
              Text(
                'Ocurrió un error al procesar la solicitud:\n\n$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 24),

              // Botón de regreso
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar diálogo
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
                    'Cerrar',
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
}
