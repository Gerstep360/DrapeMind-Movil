import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});
  @override
  State<PredictionsScreen> createState() => _PredictionsState();
}

class _PredictionsState extends State<PredictionsScreen> {
  final api = ApiClient();
  Map<String, dynamic>? result;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool train = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = train
          ? await api.post('/business-predictions/train', body: {})
          : await api.get('/business-predictions');
      if (mounted) setState(() => result = Map<String, dynamic>.from(data));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No pudimos consultar la predicción.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tendencias de mi tienda')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Planifica los próximos días',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'Comparamos regresión, media móvil y Random Forest usando el historial de tu empresa.',
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (error != null) Text(error!),
        if (result?['estado'] == 'DATOS_INSUFICIENTES') Text(result!['motivo']),
        if (result?['estado'] == 'DISPONIBLE') ...[
          const SizedBox(height: 20),
          Text(
            result!['modelo'],
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Modelo guardado: ${result!['entrenamiento']?['fecha'] ?? 'Pendiente'}',
          ),
          Text(
            'Error medio por día · Regresión: ${result!['validacion']['mae_regresion']} · Media móvil: ${result!['validacion']['mae_base']} · Random Forest: ${result!['validacion']['mae_random_forest']}',
          ),
          for (final day in result!['predicciones'])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(day['fecha']),
              trailing: Text('${day['pedidos_estimados']} pedidos'),
            ),
          Text(result!['alcance']),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : () => load(),
          child: const Text('Consultar predicción'),
        ),
        TextButton(
          onPressed: busy ? null : () => load(train: true),
          child: const Text('Volver a entrenar'),
        ),
      ],
    ),
  );
}
