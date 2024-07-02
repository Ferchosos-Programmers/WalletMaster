import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_financiera_personal/screens/DashboardScreen.dart';

void main() {
  runApp(AddMovementScreen());
}

class AddMovementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agregar Movimiento',
      theme: ThemeData.dark(),
      home: AddMovement(),
    );
  }
}

class AddMovement extends StatefulWidget {
  @override
  _AddMovementState createState() => _AddMovementState();
}

class _AddMovementState extends State<AddMovement> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _type = 'Gasto'; // Valor por defecto

  void _addMovement(BuildContext context) async {
    String description = _descriptionController.text.trim();
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    String type = _type;
    DateTime date = DateTime.now();

    if (description.isNotEmpty && amount > 0.0) {
      try {
        // Guardar en Firestore
        await FirebaseFirestore.instance.collection('movimientos').add({
          'descripcion': description,
          'monto': amount,
          'tipo': type,
          'fecha': date,
        });

        // Limpiar campos después de guardar
        _descriptionController.clear();
        _amountController.clear();

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Movimiento registrado correctamente')),
        );
      } catch (e) {
        print('Error al guardar el movimiento: $e');
        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el movimiento')),
        );
      }
    } else {
      // Mostrar mensaje de validación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, completa todos los campos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DashboardScreen(),
              ),
            );
          },
        ),
      ),
      body: Container(
        child: Center(
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      "Registrar Movimientos",
                      style: TextStyle(fontSize: 20.0),
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 16.0),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Monto',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 16.0),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                    ),
                    SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: _type,
                      onChanged: (String? newValue) {
                        setState(() {
                          _type = newValue!;
                        });
                      },
                      items: <String>['Gasto', 'Ingreso']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Movimiento',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 16.0),
                      ),
                    ),
                    SizedBox(height: 32.0),
                    ElevatedButton(
                      onPressed: () => _addMovement(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .blueAccent, // Cambia el color de fondo del botón
                        padding: EdgeInsets.symmetric(
                            vertical: 16.0), // Ajusta el padding del botón
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              8.0), // Redondea los bordes del botón
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text('Guardar Movimiento',
                            style: TextStyle(fontSize: 16.0)),
                      ),
                    ),
                    SizedBox(height: 16.0), // Espacio adicional al final
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
