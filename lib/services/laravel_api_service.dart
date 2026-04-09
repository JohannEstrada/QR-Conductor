import 'dart:convert'; // Para codificar/decodificar JSON
import 'package:http/http.dart' as http; // Para hacer peticiones HTTP

// ============================================================
// SERVICIO DE API LARAVEL - LOGIN Y TOKEN
// Propósito: Conectar con el backend Laravel para autenticación y datos
// ============================================================
class LaravelApiService {
  static String? _token; // Token JWT para autenticación (nulo si no hay sesión)
  static String? _idUsuario; // ID del usuario logueado (guardado globalmente)
  static String _baseUrl =
      'https://combustibles.sspmichoacan.com/api'; // URL base del servidor (producción)
  static final String _loginUrl =
      '$_baseUrl/login'; // Endpoint específico para login

  // ============================================================
  // MÉTODO DE LOGIN - Autenticación de usuarios
  // Propósito: Validar credenciales y obtener token de acceso
  // Parámetros: email (correo), password (contraseña)
  // Retorna: Map con éxito/fracaso y datos del usuario
  // ============================================================
  static Future<Map<String, dynamic>> login(
    String email, // Correo electrónico del usuario
    String password, // Contraseña del usuario
  ) async {
    try {
      // Logs para depuración - mostrar intento de conexión
      print('🔐 Conectando con Laravel API...');
      print('📧 Email: $email');

      // 🌐 Petición POST al servidor para autenticación
      final response = await http
          .post(
            Uri.parse(_loginUrl), // 🔗 URL del endpoint de login
            headers: {
              'Content-Type': 'application/json', // 📄 Indica que enviamos JSON
              'Accept': 'application/json', // 📄 Esperamos respuesta JSON
              'User-Agent': 'Flutter-App', // 📱 Identificar cliente
            },
            body: jsonEncode({
              'email': email,
              'password': password,
            }), // 📦 Credenciales en formato JSON
          )
          .timeout(
            const Duration(seconds: 3), // ⏰ Timeout de 30 segundos
            onTimeout: () {
              throw Exception('Timeout: La conexión tardó demasiado tiempo');
            },
          );

      // Logs para depuración - mostrar respuesta del servidor
      print(
        '📊 Status code: ${response.statusCode}',
      ); // Código HTTP (200=éxito)
      print('📋 Response body: ${response.body}'); // Contenido de la respuesta

      // Verificar si la petición fue exitosa (código 200)
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); // Convertir JSON a objeto Dart

        // Guardar credenciales para usar en futuras peticiones
        _token = data['token']; // Guardar token JWT para autenticación
        _idUsuario = data['user']['id']
            .toString(); // Guardar ID del usuario como texto

        // Logs de éxito - mostrar credenciales guardadas
        print('✅ Login exitoso');
        print(
          '🔑 Token: ${_token?.substring(0, 20)}...',
        ); // Primeros 20 caracteres del token
        print('🆔 ID Usuario: $_idUsuario'); // Mostrar ID guardado

        // Retornar respuesta exitosa con datos del usuario
        return {
          'success': true, // Indica que el login fue exitoso
          'token': _token, // Token para futuras peticiones
          'user': data['user'], // Datos completos del usuario
          'message': 'Login exitoso', // Mensaje de éxito
        };
      } else {
        // Manejo de errores de autenticación
        // Código 401 = credenciales incorrectas, otros = error del servidor
        final errorData = response.statusCode == 401
            ? {
                'message': 'Credenciales incorrectas',
              } // Usuario/contraseña inválidos
            : jsonDecode(response.body); // Otro error del servidor

        print('❌ Error en login: ${errorData['message']}');

        return {
          'success': false, // Indica que el login falló
          'message':
              errorData['message'] ??
              'Error al iniciar sesión', // Mensaje de error
        };
      }
    } catch (e) {
      // Manejo de errores de conexión o red
      // Ocurre cuando no hay internet, el servidor no responde, etc.
      print('❌ Error de conexión: $e'); // Log del error específico

      return {
        'success': false, // Indica que hubo un error técnico
        'message':
            'No se pudo conectar con el servidor', // Mensaje amigable para usuario
      };
    }
  }

  // ============================================================
  // GETTERS - Acceso a credenciales guardadas
  // Propósito: Permitir acceso controlado a las variables privadas
  // ============================================================

  // Verificar si hay sesión activa (token no es nulo)
  static bool get isLoggedIn =>
      _token != null; // true si hay token, false si no

  // Obtener token guardado (para usar en otras peticiones)
  static String? get token => _token; // Retorna token o null si no hay sesión

  // Obtener ID del usuario guardado
  static String? get idUsuario =>
      _idUsuario; // Retorna ID o null si no hay sesión

  // ============================================================
  // MÉTODO PARA OBTENER DATOS DEL USUARIO
  // Propósito: Obtener información del perfil del usuario logueado
  // Parámetros: Ninguno (usa token guardado)
  // Retorna: Map con datos del usuario
  // ============================================================

  // Obtener datos del usuario (opcional)
  static Future<Map<String, dynamic>> getUserData() async {
    if (_token == null) {
      throw Exception('No hay token activo'); // Requiere sesión activa
    }

    try {
      // Petición GET para obtener datos del usuario actual
      final response = await http.get(
        Uri.parse('$_baseUrl/user'), // Endpoint de datos de usuario
        headers: {
          'Content-Type': 'application/json', // Indica que esperamos JSON
          'Accept': 'application/json', // Esperamos respuesta JSON
          'Authorization': 'Bearer $_token', // Token para autenticación
        },
      );

      // Verificar respuesta exitosa
      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Convertir JSON a objeto Dart
      } else {
        throw Exception(
          'Error obteniendo datos del usuario',
        ); // Error del servidor
      }
    } catch (e) {
      throw Exception('Error de conexión'); // Error de red/conexión
    }
  }

  // ============================================================
  // MÉTODO DE LOGOUT - Cerrar sesión del usuario
  // Propósito: Limpiar credenciales y terminar sesión
  // Parámetros: Ninguno
  // Retorna: Vacío (void)
  // ============================================================
  static void logout() {
    _token = null; // Eliminar token de autenticación
    _idUsuario = null; // Limpiar ID también
    print('👋 Sesión cerrada - Token eliminado'); // Log de cierre de sesión
    print('🆔 ID Usuario eliminado'); // Log de ID eliminado
  }

  // ============================================================
  // MÉTODO DE BÚSQUEDA DE VEHÍCULOS
  // Propósito: Buscar vehículos por número de serie (últimos 8 dígitos)
  // Parámetros: numSerie (últimos 8 dígitos del número de serie)
  // Retorna: Map con datos del vehículo y sus cargas asociadas
  // ============================================================
  static Future<Map<String, dynamic>> buscarVehiculo(String numSerie) async {
    if (_token == null) {
      throw Exception('No hay token activo - Inicia sesión primero');
    }

    try {
      print('🔍 Buscando vehículo con num_serie: $numSerie');
      print('📏 Longitud del input: ${numSerie.length} caracteres');
      print('🔑 Usando token: ${_token?.substring(0, 20)}...');

      // 🧠 LÓGICA INTELIGENTE: Detectar si son 8 dígitos (últimos dígitos) o número completo
      String endpointUrl;
      String tipoBusqueda;

      if (numSerie.length == 8) {
        // 🎯 Son 8 dígitos: usar nueva ruta con filtro por día
        endpointUrl =
            '$_baseUrl/revisar-cargas/$numSerie'; // 🔗 Nueva ruta con filtro diario
        tipoBusqueda = 'por últimos 8 dígitos (con filtro de día)';
        print('🎯 Modo de búsqueda: $tipoBusqueda');
        print(
          '🔍 Usando nueva ruta /revisar-cargas/ con filtro automático por día',
        );
      } else {
        // 🎯 Es número completo: búsqueda exacta
        endpointUrl = '$_baseUrl/cargas/$numSerie';
        tipoBusqueda = 'por número completo (exacta)';
        print('🎯 Modo de búsqueda: $tipoBusqueda');
      }

      final response = await http.get(
        Uri.parse(endpointUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token', // Token de autenticación
        },
      );

      print('📊 Status code: ${response.statusCode}');
      print('📋 Response body: ${response.body}');
      print(
        '🔍 Headers enviados: Authorization: Bearer ${_token?.substring(0, 20)}...',
      );

      // DEPURACIÓN: Mostrar estructura exacta
      print('=== DEPURACIÓN DE ESTRUCTURA ===');
      try {
        final data = jsonDecode(response.body);
        print('Tipo de datos: ${data.runtimeType}');
        print('¿Es List? ${data is List}');
        print('¿Es Map? ${data is Map}');

        if (data is List) {
          final lista = data as List;
          print('Longitud de lista: ${lista.length}');
          if (lista.isNotEmpty) {
            print('Primer elemento: ${lista[0]}');
            print(
              'Keys del primer elemento: ${(lista[0] as Map).keys.toList()}',
            );
          }
        } else if (data is Map) {
          final mapa = data as Map;
          print('Keys del mapa: ${mapa.keys.toList()}');
          print('¿Tiene "success"? ${mapa.containsKey('success')}');
          print('¿Tiene "data"? ${mapa.containsKey('data')}');
        }
        print('=== FIN DEPURACIÓN ===');
      } catch (e) {
        print('Error en depuración: $e');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 🔍 DEPURACIÓN: Mostrar estructura exacta de la respuesta
        print('=== DEPURACIÓN DE RESPUESTA API ===');
        print('Tipo de datos: ${data.runtimeType}');
        print('Respuesta completa: $data');

        // 🆕 Con la nueva ruta /revisar-cargas/, el servidor ya filtra por día
        // La respuesta debe venir directamente como un mapa con datos del vehículo
        if (data is Map &&
            (data['success'] == true || data['success'] == 'true')) {
          // ✅ La API ya filtró por día y encontró el vehículo
          print('✅ Vehículo encontrado con filtro de día aplicado');
          print('🔍 Datos del vehículo: ${data['vehiculo']}');
          print('🔍 Keys disponibles: ${data.keys.toList()}');

          // 📋 Verificar que existan los campos necesarios
          final vehiculo = data['vehiculo'] ?? data;
          print('🔍 Keys del vehículo: ${vehiculo.keys.toList()}');
          print('🔍 Conductor: ${vehiculo['conductor']}');
          print('🔍 Placa: ${vehiculo['placa']}');
          print('🔍 Num económico: ${vehiculo['num_economico']}');
          print('🔍 Tipo combustible: ${vehiculo['tipo_combustible']}');

          return {
            'success': true,
            'num_serie': numSerie,
            'id_vehiculo':
                data['id_vehiculo'] ??
                vehiculo['id'] ??
                vehiculo['id_vehiculo'],
            'vehiculo': vehiculo, // Datos del vehículo con todos los campos
            'cargas': data['cargas'] ?? [], // Cargas ya filtradas por día
            'message': 'Vehículo encontrado con combustible autorizado hoy',
          };
        } else if (data is Map) {
          // ❌ La API no encontró vehículo o no tiene combustible hoy
          print('❌ Vehículo no encontrado o sin combustible hoy');
          print('🔍 Respuesta: $data');
          return {
            'success': false,
            'message':
                data['message'] ??
                'Vehículo no encontrado o sin combustible autorizado para hoy',
          };
        } else {
          // 📦 Si viene como lista (procesamiento antiguo)
          print('⚠️ La API devolvió lista, procesando con lógica antigua');
          final cargas = data as List;

          if (cargas.isNotEmpty) {
            final primerResultado = cargas.first as Map<String, dynamic>;
            print('🔍 Primer resultado: $primerResultado');
            return {
              'success': true,
              'num_serie': numSerie,
              'id_vehiculo':
                  primerResultado['id_vehiculo'] ??
                  primerResultado['vehiculo']?['id'],
              'vehiculo': primerResultado['vehiculo'] ?? primerResultado,
              'cargas': cargas,
              'message': 'Vehículo encontrado',
            };
          } else {
            return {
              'success': false,
              'message': 'No se encontraron resultados',
            };
          }
        }
      } else if (response.statusCode == 401) {
        print('Token expirado o inválido');
        return {
          'success': false,
          'message': 'Token expirado - Inicia sesión nuevamente',
        };
      } else {
        print('Error en la petición: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Error al conectar con el servidor',
        };
      }
    } catch (e) {
      print('Error de conexión: $e');
      return {
        'success': false,
        'message': 'No se pudo conectar con el servidor',
      };
    }
  }

  // 🆕 Obtener cargas extraordinarias de un vehículo
  static Future<Map<String, dynamic>> getCargasExtraordinarias(
    String numeroSerie,
  ) async {
    if (_token == null) {
      throw Exception('No hay token activo - Inicia sesión primero');
    }

    try {
      print('🔍 Buscando cargas extraordinarias para vehículo: $numeroSerie');
      print('🔍 URL: $_baseUrl/cargas-extraordinarias/$numeroSerie');
      print(
        '🔍 Headers enviados: Authorization: Bearer ${_token?.substring(0, 20)}...',
      );

      // 📥 Obtener cargas extraordinarias del servidor
      final response = await http.get(
        Uri.parse('$_baseUrl/cargas-extraordinarias/$numeroSerie'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      print('🔍 Status code: ${response.statusCode}');
      print('🔍 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Cargas extraordinarias encontradas: $data');

        // 🔍 Retornar la estructura completa: datos del vehículo + lista de cargas
        return data as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // 🔍 Manejar caso 404 - Diferenciar entre vehículo no encontrado y sin cargas
        final responseData = jsonDecode(response.body);
        print('🔍 404 Response: $responseData');

        if (responseData['message']?.toString().contains(
              'No hay cargas extraordinarias',
            ) ==
            true) {
          // 🟢 Caso normal: Vehículo existe pero no tiene cargas extraordinarias
          print('✅ Vehículo sin cargas extraordinarias pendientes');
          return {
            'success': false,
            'message': 'No hay cargas extraordinarias pendientes',
          };
        } else {
          // 🔴 Caso error: Vehículo no encontrado
          print('❌ Vehículo no encontrado');
          throw Exception('Vehículo no encontrado');
        }
      } else {
        print('❌ Error al obtener cargas extraordinarias: ${response.body}');
        throw Exception(
          'Error al obtener cargas extraordinarias: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error de conexión al obtener cargas extraordinarias: $e');

      // 🔍 Si es error de vehículo no encontrado, propagar la excepción sin mostrar mensaje
      if (e.toString().contains('Vehículo no encontrado')) {
        print('🔴 Propagando error de vehículo no encontrado');
        throw Exception('Vehículo no encontrado');
      }

      // 🔍 Para otros errores, retornar mapa vacío
      print('🟢 Error general, retornando mapa vacío');
      return {
        'success': false,
        'message': 'Error al obtener cargas extraordinarias',
      };
    }
  }

  // 🆕 Método para obtener cargas de bidones
  static Future<Map<String, dynamic>> getCargasBidones(
    String numeroSerie,
  ) async {
    if (_token == null) {
      throw Exception('No hay token activo - Inicia sesión primero');
    }

    try {
      print('🔍 Buscando cargas de bidones para vehículo: $numeroSerie');
      final url = '$_baseUrl/revisar-bidones/$numeroSerie';
      print('🔍 URL: $url');
      print(
        '🔍 Headers enviados: Authorization: Bearer ${_token?.substring(0, 20)}...',
      );

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      print('🔍 Status code: ${response.statusCode}');
      print('🔍 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Cargas de bidones encontradas: $data');

        // 🔍 DEBUG: Analizar la respuesta completa
        print('🔍 DEBUG: Tipo de data: ${data.runtimeType}');
        print(
          '🔍 DEBUG: Keys en data: ${data is Map ? (data as Map).keys.toList() : 'No es mapa'}',
        );
        print('🔍 DEBUG: Valor de combustible: ${data['combustible']}');
        print(
          '🔍 DEBUG: ¿Hay campo tipo_combustible?: ${data.containsKey('tipo_combustible')}',
        );
        print(
          '🔍 DEBUG: Valor de tipo_combustible: ${data['tipo_combustible']}',
        );

        // 🆕 El API retorna una lista de bidones dentro de "data"
        if (data['data'] != null) {
          final bidonesList = data['data'] as List<dynamic>;

          // 🆕 Retornar la estructura completa del vehículo con sus bidones
          if (bidonesList.isNotEmpty) {
            print('✅ Bidones encontrados: ${bidonesList.length}');

            // 🔍 DEBUG: Analizar el primer bidón
            final primerBidon = bidonesList.first;
            print('🔍 DEBUG: Primer bidón: $primerBidon');
            print(
              '🔍 DEBUG: Keys del primer bidón: ${primerBidon is Map ? (primerBidon as Map).keys.toList() : 'No es mapa'}',
            );
            print(
              '🔍 DEBUG: Combustible en primer bidón: ${primerBidon['combustible']}',
            );
            print(
              '🔍 DEBUG: Tipo_combustible en primer bidón: ${primerBidon['tipo_combustible']}',
            );
            print('🔍 DEBUG: Litros en primer bidón: ${primerBidon['litros']}');

            // 🆕 Construir estructura completa del vehículo con bidones
            final vehiculoConBidones = {
              'success': data['success'] ?? true,
              'num_serie': data['num_serie'],
              'estatus': data['estatus'],
              'num_economico': data['num_economico'],
              'conductor': data['conductor'],
              'placa': data['placa'],
              'ur': data['ur'],
              'combustible':
                  primerBidon['combustible'] ??
                  primerBidon['tipo_combustible'] ??
                  data['combustible'] ??
                  data['tipo_combustible'], // 🔍 INTENTAR OBTENER DE VARIOS LUGARES
              'litros':
                  primerBidon['litros'], // 🆕 AGREGAR CAMPO LITROS DEL PRIMER BIDÓN
              'id_carga_bidon':
                  primerBidon['id_carga_bidon'], // 🔧 CORREGIDO: 'id_carga_bidon' como clave
              'id_vehiculo':
                  primerBidon['id_vehiculo'], // 🆕 AGREGAR ID DEL VEHÍCULO
            };

            print(
              '✅ Estructura completa del vehículo con bidones: $vehiculoConBidones',
            );
            return vehiculoConBidones;
          } else {
            print('⚠️ No se encontraron bidones para este vehículo');
            // 🆕 RETORNAR ESTRUCTURA ESPECIAL PARA VEHÍCULO SIN BIDONES
            return {
              'success': false,
              'message': 'Este vehículo no tiene cargas de bidones asignadas',
              'vehiculo': {
                'num_serie': data['num_serie'],
                'estatus': data['estatus'],
                'num_economico': data['num_economico'],
                'conductor': data['conductor'],
                'placa': data['placa'],
                'ur': data['ur'],
                'combustible': data['combustible'],
              },
              'sin_bidones': true, // 🆕 Marcar especial para manejo en UI
              'data': [], // Lista vacía de bidones
            };
          }
        } else if (data is Map) {
          // Si viene como mapa directo (fallback)
          return data as Map<String, dynamic>;
        } else {
          print('⚠️ Formato de respuesta no reconocido');
          throw Exception('Formato de respuesta no reconocido');
        }
      } else {
        print('❌ Error al obtener cargas de bidones: ${response.body}');

        // 🆕 MANEJO ESPECIAL PARA BIDONES - 404 puede tener datos válidos
        if (response.statusCode == 404) {
          try {
            final responseData = jsonDecode(response.body);
            print('🔍 DEBUG: Respuesta 404 de bidones: $responseData');

            // 🆕 Si el 404 contiene success: false, manejar según el mensaje
            if (responseData.containsKey('success') &&
                responseData['success'] == false) {
              // 🆕 Diferenciar entre vehículo no encontrado y sin bidones
              final mensaje =
                  responseData['message']?.toString().toLowerCase() ?? '';

              if (mensaje.contains('vehículo no encontrado') ||
                  mensaje.contains('vehiculo no encontrado')) {
                // 🔴 Vehículo NO existe - propagar error para que lo maneje el UI
                print('❌ Vehículo no encontrado (validado por mensaje)');
                throw Exception('Vehículo no encontrado');
              } else {
                // 🟡 Vehículo existe pero sin bidones pendientes
                print('✅ Vehículo encontrado pero sin bidones pendientes');
                return {
                  'success': false,
                  'message':
                      responseData['message'] ?? 'No hay bidones pendientes',
                  'vehiculo':
                      responseData, // Pasar todos los datos del vehículo
                  'sin_bidones': true, // Marcar especial
                };
              }
            }
          } catch (e) {
            print('❌ Error al procesar respuesta 404: $e');
            // 🆕 Si es nuestra excepción de vehículo no encontrado, propagarla
            if (e.toString().contains('Vehículo no encontrado')) {
              rethrow; // 🚀 Propagar la excepción hacia arriba
            }
          }
        }

        throw Exception(
          'Error al obtener cargas de bidones: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error de conexión al obtener cargas de bidones: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // 🆕 Insertar carga completada (nueva funcionalidad)
  // ========================================================================
  // � FUNCIÓN PARA VERIFICAR SI UN ID DE CARGA ASIGNADA EXISTE
  static Future<bool> verificarExistenciaCargaAsignada(String idCarga) async {
    if (_token == null) return false;

    try {
      final url = '$_baseUrl/cargas-asignadas/$idCarga';
      print('🔍 Verificando existencia de carga asignada ID: $idCarga');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      print('🔍 Status code verificación: ${response.statusCode}');
      print('🔍 Response body verificación: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('🔍 Error verificando carga asignada: $e');
      return false;
    }
  }

  // �� FUNCIÓN PRINCIPAL: Esta función envía el POST al servidor Laravel
  // ========================================================================
  // Aquí recibimos todos los datos desde carga.dart y los preparamos para enviar
  static Future<Map<String, dynamic>> insertarCargaCompletada({
    required String idVehiculo, // 🚗 ID del vehículo en la base de datos
    required String litrosCargados, // ⛽ Cantidad de litros cargados
    required double importeCargado, // 💰 Costo total de la carga
    required String numSerie, // 🔍 Número de serie del vehículo
    required String tipoCarga, // 🆕 Tipo de carga (ordinaria/extraordinaria)
    required String
    idCargaAsignada, // 🆕 ID de la carga asignada (de /api/cargas)
    required String imagenTicket, // 🆕 Imagen del ticket en base64
    required String
    nombre_conductor, // 🆕 NOMBRE DE LA PERSONA QUE REALIZA LA CARGA - CAMPO CLAVE
    required String odometro, // 🆕 KILOMETRAJE DEL VEHÍCULO - NUEVO CAMPO
  }) async {
    // ========================================================================
    // 🔐 VERIFICACIÓN: Asegurarnos que tenemos token y usuario
    // ========================================================================
    if (_token == null) {
      throw Exception('No hay token activo - Inicia sesión primero');
    }

    if (_idUsuario == null) {
      throw Exception('No hay ID de usuario - Inicia sesión primero');
    }

    try {
      print('Insertando carga completada...');

      // ========================================================================
      // 📋 DEBUG: Mostrar los datos que recibimos de carga.dart
      // ========================================================================
      // Esto nos permite ver qué datos llegaron a esta función antes de procesarlos
      print('ID Vehiculo: $idVehiculo'); // ID del vehículo
      print('Litros cargados: $litrosCargados'); // Litros cargados
      print('Importe cargado: $importeCargado'); // Costo total
      print('Numero de serie: $numSerie'); // Número de serie del vehículo
      print(
        'ID Usuario: ${_idUsuario ?? '0'}',
      ); // ID del usuario que hace la carga
      print(
        'Tipo de carga: $tipoCarga',
      ); // Tipo de carga (ORDINARIA/extraordinaria)
      print(
        'Fecha: ${DateTime.now().toIso8601String()}',
      ); // Fecha y hora actual
      print('ID Carga Asignada: $idCargaAsignada'); // ID de la carga asignada
      print(
        'Nombre Conductor: $nombre_conductor',
      ); // 🆕 NOMBRE DE LA PERSONA QUE REALIZA LA CARGA - CAMPO CLAVE
      print('Odometro: $odometro'); // 🆕 KILOMETRAJE DEL VEHÍCULO - NUEVO CAMPO
      print(
        'Imagen Ticket length: ${imagenTicket.length} caracteres',
      ); // Tamaño de la imagen
      print(
        'Imagen Ticket preview: ${imagenTicket.substring(0, 50)}...',
      ); // Preview de la imagen
      print('Usando token: ${_token?.substring(0, 20)}...');

      // 🆕 Crear request multipart/form-data para enviar imagen como archivo
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '$_baseUrl/cargas-completadas',
        ), // 🎯 ENDPOINT del servidor Laravel
      );

      // ========================================================================
      // 🔐 AUTENTICACIÓN: Agregar headers de seguridad
      // ========================================================================
      // Estos headers son necesarios para que Laravel reconozca la petición
      request.headers.addAll({
        'Authorization': 'Bearer $_token', // 🔑 Token de autenticación
        'Accept': 'application/json', // 📄 Aceptar respuesta JSON
      });

      // ========================================================================
      // 📦 AGREGAR CAMPOS DEL FORMULARIO: Aquí se agregan todos los datos al POST
      // ========================================================================
      // ESTA ES LA PARTE CRÍTICA - Aquí agregamos el campo nombre_conductor al POST
      // ========================================================================
      // 🚨 CRÍTICO: Problema de datos - Backend guarda 8 dígitos pero necesita 17
      // ========================================================================
      print('🚨 PROBLEMA IDENTIFICADO:');
      print('   Backend guarda: 8 dígitos en extraordinarias y bidones');
      print('   Backend debería guardar: 17 dígitos completos');
      print('   Solución: Modificar backend para guardar num_serie completo');
      print('   Mientras tanto: Forzando uso de id_vehiculo correcto');
      print('   Enviando num_serie completo desde Flutter: $numSerie');
      print('');

      // 🆕 LÓGICA PARA ODOMETRO: Enviar string vacío para cargas de bidones
      // Las cargas de bidones no van directamente al vehículo, por lo que el kilometraje no es relevante
      final odometroParaEnviar = (tipoCarga == 'BIDON') ? '' : odometro;

      request.fields.addAll({
        'id_vehiculo': idVehiculo, // 🚗 ID del vehículo en la BD
        'litros_cargados': litrosCargados, // ⛽ Cantidad de combustible cargado
        'importe_cargado': importeCargado
            .toString(), // 💰 Costo total de la carga
        'num_serie':
            numSerie, // 🔍 Número de serie del vehículo (completo desde Flutter)
        'id_usuario': _idUsuario ?? '0', // ID del operador que realiza la carga
        'tipo_carga': tipoCarga, // Tipo de carga (ORDINARIA/extraordinaria)
        'fecha': DateTime.now()
            .toIso8601String(), // Fecha y hora actual en formato ISO
        // CAMPO DINÁMICO: Según el tipo de carga
        (tipoCarga == 'EXTRAORDINARIA'
                ? 'id_carga_extraordinaria'
                : tipoCarga == 'BIDON'
                ? 'id_bidon'
                : 'id_carga_asignada'):
            idCargaAsignada, // ID de la asignación previa (según tipo)
        'nombre_conductor':
            nombre_conductor, // NOMBRE DE LA PERSONA QUE REALIZA LA CARGA - CAMPO CLAVE
        'odometro_actual':
            odometroParaEnviar, // 🆕 KILOMETRAJE: null para bidones, valor para otros tipos
      });

      // DEBUG FINAL: Mostrar todos los campos que se enviarán en el POST
      // ========================================================================
      // Este DEBUG nos permite ver exactamente qué se está enviando al servidor
      print(''); // Espacio para legibilidad

      // DEBUG ESPECÍFICO PARA CARGAS EXTRAORDINARIAS
      if (tipoCarga == 'EXTRAORDINARIA') {
        print('=== DEBUG ESPECÍFICO: CARGA EXTRAORDINARIA ===');
        print('Tipo de carga detectado: $tipoCarga');
        print(
          'Campo que se enviará: ${tipoCarga == 'EXTRAORDINARIA' ? 'id_carga_extraordinaria' : 'id_carga_asignada'}',
        );
        print('Valor del campo: $idCargaAsignada');
        print(
          'Verificando que id_carga_extraordinaria tenga valor: ${idCargaAsignada.isNotEmpty ? 'OK' : 'ERROR - VACÍO'}',
        );
        print('ID Vehículo: $idVehiculo');
        print('Número de serie: $numSerie');
        print('Litros cargados: $litrosCargados');
        print('Importe cargado: $importeCargado');
        print('Nombre conductor: $nombre_conductor');
        print('=== FIN DEBUG EXTRAORDINARIA ===');
        print(''); // Espacio para legibilidad
      }

      print('🔍 DEBUG: Campos del POST:');
      print('🔍 id_vehiculo: $idVehiculo'); // ID del vehículo
      print('🔍 litros_cargados: $litrosCargados'); // Litros cargados
      print('🔍 importe_cargado: $importeCargado'); // Costo total
      print('🔍 num_serie: $numSerie'); // Número de serie
      print('🔍 id_usuario: ${_idUsuario ?? '0'}'); // ID del usuario
      print('🔍 tipo_carga: $tipoCarga'); // Tipo de carga
      print('🔍 fecha: ${DateTime.now().toIso8601String()}'); // Fecha y hora
      print('🔍 id_carga_asignada: $idCargaAsignada'); // ID de carga asignada
      print(
        '🔍 nombre_conductor: $nombre_conductor',
      ); // 🆕 NOMBRE DE LA PERSONA QUE REALIZA LA CARGA - CAMPO CLAVE
      print(
        '🔍 odometro_actual: $odometroParaEnviar',
      ); // 🆕 KILOMETRAJE: null para bidones, valor para otros tipos

      // 🔍 DEBUG: Verificar el request completo antes de enviar
      print('🔍 DEBUG: Request URL: ${request.url}');
      print('🔍 DEBUG: Request method: ${request.method}');
      print('🔍 DEBUG: Request headers: ${request.headers}');
      print('🔍 DEBUG: Request fields count: ${request.fields.length}');
      print('🔍 DEBUG: Request files count: ${request.files.length}');

      // 🔍 DEBUG: Verificar cada campo individualmente
      request.fields.forEach((key, value) {
        print('🔍 DEBUG: Campo [$key]: [$value]');
      });

      // 🆕 PROCESAMIENTO DE IMAGEN: Convertir base64 a archivo
      if (imagenTicket.startsWith('data:image/')) {
        // 🔄 Paso 1: Extraer datos base64 del data URI
        // Formato: "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ..."
        // Split por coma y tomar la parte después de la coma
        final base64String = imagenTicket.split(',')[1];

        // 🔄 Paso 2: Convertir string base64 a bytes binarios
        // base64Decode convierte el string codificado a bytes de imagen
        final imageBytes = base64Decode(base64String);

        // 🆕 Paso 3: Crear archivo multipart para enviar al servidor
        // MultipartFile permite enviar archivos binarios en requests HTTP
        request.files.add(
          http.MultipartFile.fromBytes(
            'imagen_ticket', // Nombre del campo que espera el backend
            imageBytes, // Bytes binarios de la imagen
            filename:
                'ticket_${DateTime.now().millisecondsSinceEpoch}.jpg', // 📄 Nombre único del archivo
          ),
        );
        print(
          '📷 Imagen agregada como archivo multipart (${imageBytes.length} bytes)',
        );
      } else {
        // 🔄 Caso alternativo: Si la imagen no tiene prefix data:image/
        // (por si viene como base64 puro)
        final imageBytes = base64Decode(imagenTicket);
        request.files.add(
          http.MultipartFile.fromBytes(
            'imagen_ticket', // 📷 Mismo nombre de campo
            imageBytes, // 📦 Bytes de la imagen
            filename:
                'ticket_${DateTime.now().millisecondsSinceEpoch}.jpg', // 📄 Nombre único
          ),
        );
        print(
          '📷 Imagen agregada como archivo multipart (sin prefix, ${imageBytes.length} bytes)',
        );
      }

      // 🆕 Enviar request multipart
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(' Status code: ${response.statusCode}');
      print(' Response body: ${response.body}');

      // DEBUG ADICIONAL ESPECÍFICO PARA CARGAS EXTRAORDINARIAS
      if (tipoCarga == 'EXTRAORDINARIA') {
        print('=== ANÁLISIS DE RESPUESTA: CARGA EXTRAORDINARIA ===');
        print('Status Code: ${response.statusCode}');

        if (response.statusCode == 500) {
          print('ERROR 500 DETECTADO - Analizando causa...');
          if (response.body.contains('id_carga_asignada')) {
            print('PROBLEMA: Backend todavía espera id_carga_asignada');
            print('SOLUCIÓN: Backend debe aceptar id_carga_extraordinaria');
          } else if (response.body.contains('id_carga_extraordinaria')) {
            print(
              'PROBLEMA: Backend reconoce id_carga_extraordinaria pero hay otro error',
            );
            print('VERIFICAR: Revisar estructura de tabla o validación');
          } else {
            print('PROBLEMA: Error diferente - Revisar logs completos');
          }
        } else if (response.statusCode == 200) {
          print('ÉXITO: Carga extraordinaria procesada correctamente');
        }
        print('=== FIN ANÁLISIS EXTRAORDINARIA ===');
        print('');
      }

      // DEBUG ADICIONAL: Analizar respuesta del servidor
      try {
        final responseData = jsonDecode(response.body);
        print('🔍 DEPURACIÓN: ¿Hay error en respuesta?');
        print(
          '🔍 DEPURACIÓN: Success: ${responseData['success'] ?? 'no definido'}',
        );
        print(
          '🔍 DEPURACIÓN: Message: ${responseData['message'] ?? 'no definido'}',
        );
        if (responseData.containsKey('errors')) {
          print('🔍 DEPURACIÓN: Errors: ${responseData['errors']}');
        }
        print(
          '🔍 DEPURACIÓN: ¿Contiene nombre_conductor? ${responseData.toString().contains('nombre_conductor')}',
        );
      } catch (e) {
        print('🔍 DEPURACIÓN: Error parseando respuesta: $e');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print(' Carga insertada exitosamente');
        return {
          'success': true,
          'message': 'Carga registrada correctamente',
          'data': data,
        };
      } else if (response.statusCode == 401) {
        print(' Token expirado o inválido');
        return {
          'success': false,
          'message': 'Token expirado - Inicia sesión nuevamente',
        };
      } else {
        print(' Error al insertar carga: ${response.statusCode}');
        return {'success': false, 'message': 'Error al registrar la carga'};
      }
    } catch (e) {
      print(' Error de conexión: $e');
      return {
        'success': false,
        'message': 'No se pudo conectar con el servidor',
      };
    }
  }

  // 📊 Obtener precios de combustible de hoy
  static Future<Map<String, dynamic>> obtenerPrecioCombustibleHoy() async {
    if (_token == null) {
      throw Exception('No hay token activo - Inicia sesión primero');
    }

    try {
      print('📊 Obteniendo precios de combustible de hoy...');
      print('🔑 Usando token: ${_token?.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/precios-combustible/hoy',
        ), // 📍 Endpoint de precios
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token', // 🔐 Token de autenticación
        },
      );

      print('📊 Status code: ${response.statusCode}');
      print('📋 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Precios obtenidos exitosamente');
        return {
          'success': true,
          'precios':
              data, // 📦 {"magna": 23.60, "premium": 25.80, "diesel": 22.40}
          'message': 'Precios obtenidos correctamente',
        };
      } else if (response.statusCode == 401) {
        print('❌ Token expirado o inválido');
        return {
          'success': false,
          'message': 'Token expirado - Inicia sesión nuevamente',
        };
      } else {
        print('❌ Error al obtener precios: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Error al obtener precios de combustible',
        };
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      return {
        'success': false,
        'message': 'No se pudo conectar con el servidor',
      };
    }
  }

  // ============================================================
  // REVISAR CARGAS DEL DÍA ACTUAL
  // ============================================================

  // 🔍 Obtiene las cargas de hoy para un vehículo (ruta CORRECTA)
  static Future<Map<String, dynamic>> getCargasDelDia(
    String numeroSerie,
  ) async {
    try {
      print('🔍 Consultando cargas de hoy para vehículo: $numeroSerie');

      final response = await http.get(
        Uri.parse('$_baseUrl/revisar-cargas/$numeroSerie'), // ← RUTA CORRECTA
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      print('📊 Respuesta del servidor: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Cargas del día obtenidas: ${data['data']}');

        // 🔍 CORRECCIÓN: Manejar caso cuando data['data'] es null
        final cargasHoy = data['data'] as List? ?? [];
        print('🔍 DEBUG: Cargas hoy procesadas: $cargasHoy');
        print('🔍 DEBUG: Mensaje del servidor: ${data['message']}');

        bool yaCargoOrdinariaHoy = false;

        // 🔍 NUEVA LÓGICA: Revisar mensaje del servidor
        final mensaje = data['message']?.toString().toLowerCase() ?? '';
        if (mensaje.contains('carga ya fue realizada') ||
            mensaje.contains('ya existe') ||
            mensaje.contains('ya cargó')) {
          yaCargoOrdinariaHoy = true;
          print('🚫 CANDADO ACTIVADO: El servidor indica que ya hay carga hoy');
        } else {
          // Revisar lista de cargas (si hay datos)
          for (var carga in cargasHoy) {
            if (carga['tipo_carga'] == 'ORDINARIA') {
              yaCargoOrdinariaHoy = true;
              print('🚫 CANDADO ACTIVADO: Ya existe carga ORDINARIA hoy');
              break;
            }
          }
        }

        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? '',
          'cargas_hoy': cargasHoy,
          'ya_cargo_ordinaria_hoy': yaCargoOrdinariaHoy, // 🆕 Nuevo campo
        };
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
          'cargas_hoy': [],
          'ya_cargo_ordinaria_hoy': false, // 🆕 Nuevo campo
        };
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      return {
        'success': false,
        'message': 'No se pudo conectar con el servidor',
        'cargas_hoy': [],
        'ya_cargo_ordinaria_hoy': false, // 🆕 Nuevo campo
      };
    }
  }
}
