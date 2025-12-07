import 'package:server/service/portforward_service.dart';

/// Example usage of PortForwardService
Future<void> main() async {
  final service = PortForwardService();

  try {
    // Initialize the service
    await service.initialize();
    print('PortForward service initialized');

    // Example: Create a port forwarder
    // Replace these with your actual Kubernetes configuration
    final pfID = await service.createPortForwarder(
      url: 'https://kubernetes.default.svc',
      ports: '8080:80,9090:90', // Local:Remote port mappings
      address: 'localhost',
    );
    print('Port forwarder created with ID: $pfID');

    // Start forwarding
    final taskID = await service.startForwardPorts(pfID);
    print('Port forwarding started with task ID: $taskID');

    // Get forwarded ports information
    final portsInfo = await service.getForwardedPorts(pfID);
    print('Forwarded ports info: $portsInfo');

    // Keep the service running for some time
    print('Port forwarding is active. Press Ctrl+C to stop.');
    await Future.delayed(Duration(seconds: 60));

    // Stop forwarding
    service.stopTask(taskID);
    await service.stopForwardPorts(pfID);
    print('Port forwarding stopped');
  } catch (e) {
    print('Error: $e');
  } finally {
    // Cleanup
    service.dispose();
    print('Service disposed');
  }
}
