import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'busq_vehic.dart';
import 'info_vehic.dart';
import 'login_page.dart';
import 'services/laravel_api_service.dart';
import 'validar_conductor.dart';
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
  // MÉTODO DE VALIDACIÓN DE CONDUCTOR - Verifica conductor antes de cargar
  // =============================================================================
  Future<bool> _validarConductor({String tipoCarga = 'ordinaria'}) async {
    // Si ya hay un conductor validado, verificar estado
    if (ConductorService.hayConductorValidado) {
      // Verificar si necesita revalidación por tiempo
      if (ConductorService.necesitaRevalidacion()) {
        ConductorService.limpiarConductor();
        _mostrarMensaje(
          'Validación expirada, por favor valide nuevamente',
          color: Colors.orange,
        );
        // Continuar con validación nueva
      } else if (ConductorService.puedeRealizarCarga(tipoCarga)) {
        _mostrarMensaje(
          'Conductor ya validado: ${ConductorService.nombreConductor}',
          color: Colors.green,
        );
        return true;
      } else {
        _mostrarMensaje(ConductorService.mensajeEstado, color: Colors.red);
        return false;
      }
    }

    // Abrir pantalla de validación
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ValidarConductorScreen()),
    );

    // Procesar resultado de la validación
    if (resultado != null && resultado['success'] == true) {
      // Guardar datos del conductor en el servicio global
      ConductorService.guardarConductor(
        conductor: resultado['conductor'],
        estado: resultado['estado'],
        id: resultado['conductor']['id']?.toString() ?? 'desconocido',
      );

      _mostrarMensaje(
        'Conductor validado: ${ConductorService.nombreConductor}',
        color: Colors.green,
      );

      return true;
    } else {
      // La validación falló o fue cancelada
      _mostrarMensaje(
        'Conductor no validado. No puede continuar con la carga.',
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

                        ElevatedButton.icon(
                          onPressed: () async {
                            // 1. Primero validar conductor para carga ordinaria
                            final conductorValido = await _validarConductor(
                              tipoCarga: 'ordinaria',
                            );

                            if (conductorValido) {
                              // 2. Si es válido, continuar con búsqueda de vehículo
                              _showInputDialog(context);
                            }
                            // Si no es válido, el método _validarConductor ya mostró el error
                          },
                          icon: const Icon(Icons.search), // Ícono de búsqueda
                          label: const Text(
                            'Carga Ordinaria',
                          ), // Texto del botón
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF0A2E5C,
                            ), // Azul marino más oscuro
                            foregroundColor:
                                Colors.white, // Texto e ícono en blanco
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ), // Padding vertical
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                10,
                              ), // Bordes redondeados de 10px
                            ),
                            elevation: 3, // Sombra suave
                          ),
                        ),
                        const SizedBox(height: 12), // Espacio entre botones
                        // Botón 2: Carga Extraordinaria (temporalmente deshabilitado)
                        ElevatedButton.icon(
                          onPressed: () async {
                            // 1. Primero validar conductor para carga extraordinaria
                            final conductorValido = await _validarConductor(
                              tipoCarga: 'extraordinaria',
                            );

                            if (conductorValido) {
                              // 2. Si es válido, continuar con búsqueda de vehículo
                              _showInputDialog(
                                context,
                                tipoCarga: 'extraordinaria',
                              );
                            }
                            // Si no es válido, el método _validarConductor ya mostró el error
                          },
                          icon: const Icon(Icons.star), // Ícono de estrella
                          label: const Text(
                            'Carga Extraordinaria',
                          ), // Texto del botón
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF0A2E5C,
                            ), // Azul marino
                            foregroundColor:
                                Colors.white, // Texto e ícono en blanco
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ), // Padding vertical
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                10,
                              ), // Bordes redondeados
                            ),
                            elevation: 3, // Sombra suave
                          ),
                        ),
                        const SizedBox(height: 12), // Espacio entre botones
                        // Botón 3: Carga de Bidones (temporalmente deshabilitado)
                        ElevatedButton.icon(
                          onPressed: () async {
                            // 1. Primero validar conductor para carga de bidones
                            final conductorValido = await _validarConductor(
                              tipoCarga: 'bidones',
                            );

                            if (conductorValido) {
                              // 2. Si es válido, continuar con búsqueda de vehículo
                              _showInputDialog(context, tipoCarga: 'bidones');
                            }
                            // Si no es válido, el método _validarConductor ya mostró el error
                          },
                          icon: const Icon(
                            Icons.inventory_2,
                          ), // Ícono de bidones
                          label: const Text(
                            'Carga de Bidones',
                          ), // Texto del botón
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF0A2E5C,
                            ), // Azul marino como los otros
                            foregroundColor:
                                Colors.white, // Texto e ícono en blanco
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ), // Padding vertical igual que los otros
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                10,
                              ), // Bordes redondeados de 10px como los otros
                            ),
                            elevation: 3, // Sombra suave igual que los otros
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
                              tipoCarga, // 🆕 Pasar tipo de carga
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
