// =============================================================================
// SERVICIO GLOBAL DE CONDUCTOR - Gestión de estado del conductor validado
// =============================================================================
// Función: Almacenar y gestionar datos del conductor validado en toda la app
// Características: Variables globales, métodos de validación, limpieza de estado
// =============================================================================

class ConductorService {
  // Instancia única del servicio (Singleton)
  static final ConductorService _instance = ConductorService._internal();
  factory ConductorService() => _instance;
  ConductorService._internal();

  // =============================================================================
  // VARIABLES GLOBALES DE ESTADO DEL CONDUCTOR
  // =============================================================================

  // Datos del conductor validado
  static Map<String, dynamic>? _datosConductor;

  // Estado de la credencial (VIGENTE, VENCIDO, SUSPENDIDO, etc.)
  static String? _estadoCredencial;

  // Timestamp de cuándo se realizó la validación
  static DateTime? _fechaValidacion;

  // ID del conductor para referencia
  static String? _idConductor;

  // =============================================================================
  // GETTERS - Acceso público a los datos del conductor
  // =============================================================================

  /// Retorna los datos completos del conductor validado
  static Map<String, dynamic>? get datosConductor => _datosConductor;

  /// Retorna el estado de la credencial
  static String? get estadoCredencial => _estadoCredencial;

  /// Retorna la fecha de validación
  static DateTime? get fechaValidacion => _fechaValidacion;

  /// Retorna el ID del conductor
  static String? get idConductor => _idConductor;

  /// Retorna si hay un conductor validado actualmente
  static bool get hayConductorValidado => _datosConductor != null;

  /// Retorna el nombre completo del conductor
  static String get nombreConductor {
    if (_datosConductor == null) return 'No hay conductor';

    final nombre = _datosConductor!['NOMBRE'] ?? '';
    final paterno = _datosConductor!['PATERNO'] ?? '';
    final materno = _datosConductor!['MATERNO'] ?? '';

    return '$nombre $paterno $materno'.trim();
  }

  /// Retorna el RFC del conductor
  static String get rfcConductor {
    return _datosConductor?['RFC'] ?? 'N/A';
  }

  /// Retorna el puesto del conductor
  static String get puestoConductor {
    return _datosConductor?['PUESTO'] ?? 'N/A';
  }

  // =============================================================================
  // MÉTODOS PRINCIPALES - Gestión del estado del conductor
  // =============================================================================

  /// Guarda los datos del conductor validado
  static void guardarConductor({
    required Map<String, dynamic> conductor,
    required String estado,
    required String id,
  }) {
    _datosConductor = conductor;
    _estadoCredencial = estado;
    _idConductor = id;
    _fechaValidacion = DateTime.now();

    print('✅ Conductor guardado: ${nombreConductor}');
    print('📅 Validación: $_fechaValidacion');
    print('📋 Estado: $_estadoCredencial');
  }

  /// Verifica si el conductor puede realizar cargas
  static bool puedeCargar() {
    if (!hayConductorValidado) return false;

    // Estados permitidos para cargar
    final estadosPermitidos = ['VIGENTE', 'ACTIVO', 'VÁLIDO'];
    return estadosPermitidos.contains(_estadoCredencial?.toUpperCase());
  }

  /// Verifica si el conductor puede realizar un tipo específico de carga
  static bool puedeRealizarCarga(String tipoCarga) {
    if (!puedeCargar()) return false;

    // Por ahora, todos los conductores válidos pueden hacer cualquier tipo de carga
    // Esto se puede personalizar más adelante si se necesita
    return _estadoCredencial?.toUpperCase() == 'VIGENTE';
  }

  /// Verifica si la validación sigue vigente (opcional: por tiempo)
  static bool esValidacionVigente({int minutosMaximos = 480}) {
    if (_fechaValidacion == null) return false;

    final ahora = DateTime.now();
    final diferencia = ahora.difference(_fechaValidacion!);

    // Por defecto, vigente por 8 horas (480 minutos)
    return diferencia.inMinutes < minutosMaximos;
  }

  /// Verifica si necesita revalidación por tiempo
  static bool necesitaRevalidacion() {
    return !esValidacionVigente();
  }

  /// Limpia todos los datos del conductor (usar al cerrar sesión)
  static void limpiarConductor() {
    _datosConductor = null;
    _estadoCredencial = null;
    _idConductor = null;
    _fechaValidacion = null;

    print('🧹 Datos del conductor limpiados');
  }

  /// Retorna información resumida del conductor actual
  static String get resumenConductor {
    if (!hayConductorValidado) return 'Sin conductor validado';

    return '''
Conductor: ${nombreConductor}
RFC: ${rfcConductor}
Estado: ${_estadoCredencial ?? 'Desconocido'}
Validación: ${_fechaValidacion != null ? _formatoFecha(_fechaValidacion!) : 'N/A'}
    '''
        .trim();
  }

  /// Retorna mensaje específico según el estado
  static String get mensajeEstado {
    if (!hayConductorValidado) return 'No hay conductor validado';

    switch (_estadoCredencial?.toUpperCase()) {
      case 'VIGENTE':
      case 'ACTIVO':
      case 'VÁLIDO':
        return '✅ Conductor autorizado para cargar combustible';
      case 'VENCIDO':
        return '❌ Credencial vencida - No puede cargar combustible';
      case 'SUSPENDIDO':
        return '❌ Conductor suspendido - No puede cargar combustible';
      default:
        return '⚠️ Estado desconocido - Contacte a RRHH';
    }
  }

  // =============================================================================
  // MÉTODOS AUXILIARES - Formato y utilidades
  // =============================================================================

  /// Formatea fecha para mostrar
  static String _formatoFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  /// Para debugging - Imprime estado actual
  static void debugEstado() {
    print('🔍 DEBUG - Estado Conductor Service:');
    print('   Hay conductor: $hayConductorValidado');
    print('   Puede cargar: ${puedeCargar()}');
    print('   Es vigente: ${esValidacionVigente()}');
    print('   Nombre: $nombreConductor');
    print('   Estado: $_estadoCredencial');
    print('   ID: $_idConductor');
    print('   Fecha: $_fechaValidacion');
  }
}
