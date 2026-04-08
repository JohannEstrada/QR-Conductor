import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'pag_inicio.dart';

class Ticket extends StatefulWidget {
  const Ticket({super.key});

  @override
  State<Ticket> createState() => _TicketState();
}

class _TicketState extends State<Ticket> {
  bool _folioGuardado = false;
  bool _fotoTomada = false;
  final TextEditingController _folioController = TextEditingController();

  Future<void> _tomarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _fotoTomada = true;
      });

      // Aquí se guardaría la foto en base de datos (futuro)
      print('Foto guardada: ${image.path}');

      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto del ticket guardada correctamente'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _terminarProceso() {
    // Simular guardado en base de datos (futuro)
    print('Proceso completado - guardado en base de datos');

    // Mostrar mensaje de proceso terminado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Proceso terminado correctamente'),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );

    // Navegar a página de inicio después de 2 segundos
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const PagInicio()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket'),
        backgroundColor: const Color(0xFF135DD8),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Card(
              color: const Color(0xFFE3F2FD),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 80,
                      color: Color(0xFF135DD8),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Registro de Ticket',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF135DD8),
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _folioController,
                      maxLength: 7,
                      decoration: const InputDecoration(
                        labelText: 'Folio del Ticket',
                        hintText: 'Ingrese el folio (7 caracteres)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.receipt,
                          color: Color(0xFF135DD8),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      autofocus: true,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Permitir guardar folio vacío o con texto
                        setState(() {
                          _folioGuardado = true;
                        });

                        // Mostrar mensaje según si hay folio o no
                        if (_folioController.text.isNotEmpty) {
                          print('Folio guardado: ${_folioController.text}');
                        } else {
                          print('Guardando sin folio - se tomará foto');
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: Text(
                        _folioController.text.isNotEmpty
                            ? 'Guardar Folio'
                            : 'Continuar sin Folio',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF135DD8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (_folioGuardado) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _tomarFoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tomar Foto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                    if (_fotoTomada) ...[
                      const SizedBox(height: 20),
                      Card(
                        color: const Color(0xFFE8F5E8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: const Color(0xFF81C784),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: const Color(0xFF1B5E20),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Foto tomada y guardada',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1B5E20),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'El ticket ha sido registrado correctamente',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _terminarProceso,
                        icon: const Icon(Icons.check_circle, size: 28),
                        label: const Text(
                          'TERMINAR',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 40,
                          ),
                          minimumSize: const Size(200, 60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
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
    );
  }
}
