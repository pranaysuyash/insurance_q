import 'package:flutter/material.dart';

IconData iconForDocumentType(String? documentType) {
  if (documentType == null) return Icons.description;

  switch (documentType.toLowerCase()) {
    case 'health insurance':
      return Icons.health_and_safety;
    case 'auto insurance':
      return Icons.directions_car;
    case 'life insurance':
      return Icons.favorite;
    case 'home insurance':
      return Icons.home;
    case 'travel insurance':
      return Icons.flight;
    default:
      return Icons.description;
  }
}

Color colorForDocumentType(String? documentType) {
  if (documentType == null) return Colors.grey;

  switch (documentType.toLowerCase()) {
    case 'health insurance':
      return Colors.red;
    case 'auto insurance':
      return Colors.blue;
    case 'life insurance':
      return Colors.pink;
    case 'home insurance':
      return Colors.brown;
    case 'travel insurance':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}
