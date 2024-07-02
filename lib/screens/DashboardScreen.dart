import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'package:gestion_financiera_personal/screens/AddMovementScreen.dart';
import 'package:gestion_financiera_personal/screens/LoginScreen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(DashboardScreen());
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  double totalGastos = 0.0;
  double totalIngresos = 0.0;
  double saldo = 0.0;
  List<DocumentSnapshot> movimientos = [];
  bool isAdmin = false; // Variable para verificar si el usuario es admin

  @override
  void initState() {
    super.initState();
    _updateTotals(); // Actualizar los totales al iniciar la pantalla
  }

  Future<void> _updateTotals() async {
    try {
      // Obtener datos de Firebase
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('movimientos').get();

      // Calcular totales de gastos e ingresos
      double gastos = 0.0;
      double ingresos = 0.0;
      querySnapshot.docs.forEach((document) {
        if (document['tipo'] == 'Gasto') {
          gastos += document['monto'];
        } else if (document['tipo'] == 'Ingreso') {
          ingresos += document['monto'];
        }
      });

      // Actualizar estado
      setState(() {
        totalGastos = gastos;
        totalIngresos = ingresos;
        saldo = ingresos - gastos;
        movimientos = querySnapshot.docs;

        // Verificar si el usuario es admin
        isAdmin =
            FirebaseAuth.instance.currentUser?.email == 'super_admin@gmail.com';
      });
    } catch (e) {
      print('Error al obtener datos: $e');
    }
  }

  // Método para cerrar sesión
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada exitosamente'),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
    } catch (e) {
      print('Error al cerrar sesión: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error al cerrar sesión. Por favor, inténtelo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              _signOut(context); // Llama al método para cerrar sesión
            },
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Estadísticas',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryCard(
                  'Gastos',
                  '\$${totalGastos.toStringAsFixed(2)}',
                  Colors.red,
                ),
                _buildSummaryCard(
                  'Ingresos',
                  '\$${totalIngresos.toStringAsFixed(2)}',
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Saldo',
                  '\$${saldo.toStringAsFixed(2)}',
                  saldo >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            const Padding(
              padding: EdgeInsets.only(top: 15.0),
              child: Center(
                child: Text(
                  'Últimos Movimientos',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('movimientos')
                    .orderBy('fecha', descending: true)
                    .snapshots(),
                builder: (BuildContext context,
                    AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  // Obtener la lista de documentos
                  List<DocumentSnapshot> documents = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> data =
                          documents[index].data() as Map<String, dynamic>;
                      String tipo = data['tipo'];
                      double monto = data['monto'];
                      String descripcion = data['descripcion'];
                      DateTime fecha = (data['fecha'] as Timestamp).toDate();
                      IconData icono = tipo == 'Gasto'
                          ? Icons.money_off
                          : Icons.attach_money;

                      return ListTile(
                        leading: Icon(icono,
                            color: tipo == 'Gasto' ? Colors.red : Colors.green),
                        title: Text(descripcion),
                        subtitle: Text(
                            '${tipo.toUpperCase()} - \$${monto.toStringAsFixed(2)} - ${DateFormat.yMMMd().format(fecha)}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddMovementScreen(),
                      ),
                    );
                  },
                  backgroundColor: Colors.blue, // Cambiar el color aquí
                  child: Icon(Icons.add),
                ),
                SizedBox(height: 16),
                FloatingActionButton(
                  onPressed: () async {
                    final pdfFile = await _generatePdf();
                    await Printing.layoutPdf(
                      onLayout: (PdfPageFormat format) async => pdfFile,
                    );
                  },
                  backgroundColor: Colors.red, // Cambiar el color aquí
                  child: Icon(Icons.picture_as_pdf),
                ),
              ],
            )
          : FirebaseAuth.instance.currentUser?.email != 'super_admin@gmail.com'
              ? FloatingActionButton(
                  onPressed: () async {
                    final pdfFile = await _generatePdf();
                    await Printing.layoutPdf(
                      onLayout: (PdfPageFormat format) async => pdfFile,
                    );
                  },
                  backgroundColor: Colors.red, // Cambiar el color aquí
                  child: Icon(Icons.picture_as_pdf),
                )
              : Container(), // Ocultar el botón si el usuario no es admin ni super_admin@gmail.com
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Estadísticas',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Concepto', 'Valor'],
                data: [
                  ['Gastos', '\$${totalGastos.toStringAsFixed(2)}'],
                  ['Ingresos', '\$${totalIngresos.toStringAsFixed(2)}'],
                  ['Saldo', '\$${saldo.toStringAsFixed(2)}'],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black, // Color del texto en el encabezado
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.grey400, // Color de fondo del encabezado
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                },
                cellStyle: pw.TextStyle(
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Ultimos Movimientos',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Descripción', 'Tipo', 'Monto', 'Fecha'],
                data: _buildPdfMovementsList(),
                border: null,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellStyle: pw.TextStyle(
                  fontSize: 12,
                ),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  List<List<String>> _buildPdfMovementsList() {
    List<List<String>> movementsList = [];

    for (var doc in movimientos) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String tipo = data['tipo'];
      double monto = data['monto'];
      String descripcion = data['descripcion'];
      DateTime fecha = (data['fecha'] as Timestamp).toDate();

      movementsList.add([
        descripcion,
        tipo.toUpperCase(),
        '\$${monto.toStringAsFixed(2)}',
        DateFormat.yMMMd().format(fecha),
      ]);
    }

    return movementsList;
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.0),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
