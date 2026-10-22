import 'package:flutter/material.dart';

import '../../services/apollo/apollo_service.dart';

/// Settings > Validation: traffic, hazard injection, safety reports and
/// scenario benchmarks (KAIRO gateway, docs/validation_api.md).
///
/// Entry point only - the screens live in lib/features/validation/.
class ValidationSettings extends StatelessWidget {
  const ValidationSettings({super.key, required this.apollo});

  final ApolloService apollo;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Validation tools are being built.'),
    );
  }
}
