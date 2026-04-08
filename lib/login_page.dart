import 'package:flutter/material.dart';
import 'services/laravel_api_service.dart';
import 'pag_inicio.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 🔑 Llave única para identificar y validar el formulario completo
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose(); // Libera el controlador del email
    _passwordController.dispose(); // Libera el controlador de la contraseña
    super.dispose();
  }

  void _handleLogin() async {
    // ✅ Verifica que todos los campos del formulario sean válidos (email válido, contraseña no vacía)
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    //  Obtiene el texto del campo email y elimina espacios al inicio y final
    final email = _emailController.text.trim();
    //  Obtiene el texto del campo contraseña
    final password = _passwordController.text;

    //  Bloque para capturar errores durante el proceso de login
    try {
      //  Llama al servicio de API para autenticar al usuario en el servidor
      final result = await LaravelApiService.login(email, password);

      //  Verifica si el servidor respondió que el login fue exitoso
      if (result['success']) {
        if (mounted) {
          //  Muestra mensaje verde de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          // Navegar a la página principal después de 2 segundos
          Future.delayed(const Duration(seconds: 1), () {
            // 📱 Verifica que la página siga activa antes de navegar
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const PagInicio(),
                ), //  Crea la página principal
                (route) => false, //  Elimina todas las páginas de la pila
              );
            }
          });
        }
      } else {
        //  Si el login falló, muestra mensaje de error
        if (mounted) {
          //  Muestra mensaje rojo de error en la parte inferior
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Si hay problemas de conexión o red, captura el error
      if (mounted) {
        // Muestra mensaje de error de conexión
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error de conexión: $e',
            ), //  Muestra el error específico
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Construye la interfaz visual de la página de login
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Color de fondo gris claro para toda la pantalla
      backgroundColor: const Color(0xFFF5F5F5),
      // Centra todo el contenido en la pantalla
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          // Tarjeta blanca con sombra para el formulario
          child: Card(
            elevation: 10, // Sombra suave debajo de la tarjeta
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // Bordes redondeados
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              // Formulario que agrupa los campos de entrada
              child: Form(
                key:
                    _formKey, // Asocia el formulario con su llave de validación
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min, // Ocupa solo el espacio necesario
                  children: [
                    //  Logo corporativo de la aplicación
                    Container(
                      width: 100, // Ancho del logo
                      height: 100, // Alto del logo
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          50,
                        ), // Hace el logo circular
                        child: Image.asset(
                          'assets/images/Estrella.png', // Ruta del archivo de imagen
                          width: 100, // Ancho de la imagen
                          height: 100, // Alto de la imagen
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            //  Si no encuentra la imagen, muestra un ícono
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  50,
                                ), // 🔄 Fondo circular
                                color: const Color(
                                  0xFF135DD8,
                                ), // 🎨 Color azul corporativo
                              ),
                              child: const Icon(
                                Icons.local_gas_station, // Ícono de gasolinera
                                size: 50, // 📏 Tamaño del ícono
                                color: Colors.white, // Ícono blanco
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Título principal de la aplicación
                    const Text(
                      'Combustible App', // Nombre de la aplicación
                      style: TextStyle(
                        fontSize: 28, // Tamaño grande para el título
                        fontWeight: FontWeight.bold, // Texto en negrita
                        color: Color(0xFF0A2E5C), // Azul marino más oscuro
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ), // Espacio pequeño después del título
                    // Subtítulo informativo
                    const Text(
                      'Inicia sesión para continuar', // Instrucción para el usuario
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ), // Texto más pequeño y gris
                    ),
                    const SizedBox(
                      height: 32,
                    ), // Espacio grande antes de los campos
                    // Campo de entrada para el correo electrónico
                    TextFormField(
                      controller:
                          _emailController, // Asocia el controlador del email
                      keyboardType: TextInputType
                          .emailAddress, // Teclado optimizado para emails
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico', // Etiqueta del campo
                        hintText: 'usuario@ejemplo.com', // Ejemplo de formato
                        prefixIcon: Icon(
                          Icons.email,
                          color: Color(0xFF0A2E5C), // Azul marino más oscuro
                        ), // Ícono de email
                        border: OutlineInputBorder(), // Borde normal del campo
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF0A2E5C),
                          ), // Borde azul cuando está activo
                        ),
                        labelStyle: TextStyle(
                          color: Color(0xFF0A2E5C), // Azul marino más oscuro
                        ), // Color de etiqueta cuando está activa
                      ),
                      // Validación del campo de email
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu correo'; // Error si está vacío
                        }
                        if (!value.contains('@')) {
                          return 'Ingresa un correo válido'; // Error si no tiene @
                        }
                        return null; // Sin errores
                      },
                    ),
                    const SizedBox(height: 16), // Espacio entre campos
                    // Campo de entrada para la contraseña
                    TextFormField(
                      controller:
                          _passwordController, // Asocia el controlador de contraseña
                      obscureText:
                          _obscurePassword, // Oculta/muestra la contraseña
                      decoration: InputDecoration(
                        labelText: 'Contraseña', // Etiqueta del campo
                        hintText: 'Ingresa tu contraseña', // Texto de ayuda
                        prefixIcon: const Icon(
                          Icons.lock, // Ícono de candado
                          color: Color(0xFF0A2E5C), // Azul marino más oscuro
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword // Cambia ícono según estado
                                ? Icons
                                      .visibility // Ojo visible (contraseña visible)
                                : Icons
                                      .visibility_off, // Ojo tachado (contraseña oculta)
                            color: const Color(
                              0xFF0A2E5C,
                            ), // Azul marino más oscuro
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword; //  Invierte el estado de visibilidad
                            });
                          },
                        ),
                        border:
                            const OutlineInputBorder(), //  Borde normal del campo
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF0A2E5C),
                          ), //  Borde azul cuando está activo
                        ),
                        labelStyle: const TextStyle(
                          color: Color(0xFF0A2E5C), // Azul marino más oscuro
                        ), // Color de etiqueta cuando está activa
                      ),
                      // Validación del campo de contraseña
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu contraseña'; // Error si está vacía
                        }
                        if (value.length < 6) {
                          // Verifica longitud mínima
                          return 'La contraseña debe tener al menos 6 caracteres'; // Error si es muy corta
                        }
                        return null; // Sin errores
                      },
                    ),
                    const SizedBox(height: 24),

                    //  Botón principal de login
                    SizedBox(
                      width: double.infinity, // Ocupa todo el ancho disponible
                      height: 50, // Altura fija del botón
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _handleLogin, // Deshabilitado si está cargando
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF0A2E5C,
                          ), // Azul marino más oscuro
                          foregroundColor: Colors.white, // Texto blanco
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // Bordes ligeramente redondeados
                          ),
                          elevation: 2, // Sombra suave
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                // Muestra círculo de carga
                                color: Colors.white, // Círculo blanco
                                strokeWidth: 2, // Grosor del círculo
                              )
                            : const Text(
                                'Iniciar Sesión', // Texto del botón
                                style: TextStyle(
                                  fontSize: 16, // Tamaño del texto
                                  fontWeight:
                                      FontWeight.bold, // Texto en negrita
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
