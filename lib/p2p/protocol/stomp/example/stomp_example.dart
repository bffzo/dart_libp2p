/// Example demonstrating the STOMP protocol implementation for dart-libp2p
///
/// This example shows how to:
/// 1. Set up a STOMP server
/// 2. Connect clients to the server
/// 3. Send and receive messages
/// 4. Use subscriptions and transactions
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_libp2p/dart_libp2p.dart';
import 'package:dart_libp2p/p2p/protocol/stomp.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  // Set up logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  print('🚀 Starting STOMP Protocol Example');

  try {
    await runStompExample();
  } catch (e, stackTrace) {
    print('❌ Error running STOMP example: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

Future<void> runStompExample() async {
  // Create two hosts - one will be the server, one will be the client
  final serverHost = await createHost('server');
  final clientHost = await createHost('client');

  print('📡 Server Host ID: ${serverHost.id}');
  print('📱 Client Host ID: ${clientHost.id}');

  // Start the STOMP server
  print('\n🏗️  Setting up STOMP server...');
  final stompService = await serverHost.addStompService(
    options: const StompServiceOptions.serverEnabled(
      serverName: 'dart-libp2p-stomp-example/1.0',
    ),
  );

  print('✅ STOMP server started');

  // Give the server a moment to start
  await Future<void>.delayed(const Duration(milliseconds: 100));

  // Connect client to server
  print('\n🔗 Connecting client to server...');
  final client = await clientHost.connectStomp(
    peerId: serverHost.id,
    hostName: 'example.com',
  );

  print('✅ Client connected to server');
  print('   Session ID: ${client.sessionId}');
  print('   Server Info: ${client.serverInfo}');

  // Example 1: Simple message sending
  await demonstrateSimpleMessaging(client);

  // Example 2: Subscriptions and message delivery
  await demonstrateSubscriptions(client);

  // Example 3: Transactions
  await demonstrateTransactions(client);

  // Example 4: Server-side message broadcasting
  await demonstrateServerBroadcast(stompService, client);

  // Clean up
  print('\n🧹 Cleaning up...');
  await client.close();
  await stompService.stop();
  await serverHost.close();
  await clientHost.close();

  print('✅ STOMP example completed successfully!');
}

Future<Host> createHost(String name) async {
  // In a real application, you would configure the host with proper transports,
  // security, and other settings. This is a simplified example.

  // For this example, we'll create a basic host configuration
  // Note: This is pseudo-code as the actual host creation depends on your
  // specific libp2p implementation details

  print('Creating host: $name');
  // return await Host.create(/* your host configuration */);

  // Since we can't actually create a real host in this example without
  // the full libp2p setup, we'll throw an informative error
  throw UnimplementedError('Host creation requires full libp2p setup. '
      'This example shows the STOMP protocol usage patterns.');
}

Future<void> demonstrateSimpleMessaging(StompClient client) async {
  print('\n📨 Example 1: Simple Message Sending');

  // Send a simple message to a destination
  final receiptId = await client.send(
    destination: '/queue/example',
    body: 'Hello, STOMP World!',
    contentType: 'text/plain',
    requestReceipt: true,
  );

  print('✅ Message sent with receipt ID: $receiptId');
}

Future<void> demonstrateSubscriptions(StompClient client) async {
  print('\n📬 Example 2: Subscriptions and Message Delivery');

  // Subscribe to a destination
  final subscription = await client.subscribe(
    destination: '/topic/news',
    ackMode: StompAckMode.client,
    requestReceipt: true,
  );

  print('✅ Subscribed to /topic/news with ID: ${subscription.id}');

  // Listen for messages
  final messageCompleter = Completer<void>();
  late StreamSubscription messageSubscription;

  messageSubscription = subscription.messages.listen((message) async {
    print('📩 Received message:');
    print('   Message ID: ${message.messageId}');
    print('   Destination: ${message.destination}');
    print('   Content: ${message.body}');

    // Acknowledge the message
    if (message.requiresAck && message.ackId != null) {
      await client.ack(messageId: message.ackId!);
      print('✅ Message acknowledged');
    }

    messageCompleter.complete();
  });

  // Send a message to the subscribed destination
  await client.send(
    destination: '/topic/news',
    body: 'Breaking news: STOMP protocol working perfectly!',
    contentType: 'text/plain',
  );

  // Wait for the message to be received
  await messageCompleter.future.timeout(const Duration(seconds: 5));
  await messageSubscription.cancel();

  // Unsubscribe
  await client.unsubscribe(subscriptionId: subscription.id);
  print('✅ Unsubscribed from /topic/news');
}

Future<void> demonstrateTransactions(StompClient client) async {
  print('\n💳 Example 3: Transactions');

  // Begin a transaction
  final transaction = await client.beginTransaction();
  print('✅ Transaction started: ${transaction.id}');

  try {
    // Send multiple messages within the transaction
    await client.send(
      destination: '/queue/orders',
      body: 'Order #1: 10 widgets',
      transactionId: transaction.id,
    );

    await client.send(
      destination: '/queue/orders',
      body: 'Order #2: 5 gadgets',
      transactionId: transaction.id,
    );

    print('📦 Added 2 orders to transaction');

    // Commit the transaction
    await client.commitTransaction(transactionId: transaction.id);
    print('✅ Transaction committed successfully');
  } catch (e) {
    // Abort the transaction on error
    await client.abortTransaction(transactionId: transaction.id);
    print('❌ Transaction aborted due to error: $e');
    rethrow;
  }
}

Future<void> demonstrateServerBroadcast(
  StompService service,
  StompClient client,
) async {
  print('\n📡 Example 4: Server-side Broadcasting');

  // Subscribe to a broadcast destination
  final subscription = await client.subscribe(
    destination: '/broadcast/all',
  );

  print('✅ Subscribed to broadcast destination');

  // Set up message listener
  final messageCompleter = Completer<void>();
  late StreamSubscription messageSubscription;

  messageSubscription = subscription.messages.listen((message) {
    print('📻 Received broadcast message: ${message.body}');
    messageCompleter.complete();
  });

  // Server broadcasts a message
  await service.server?.sendToDestination(
    destination: '/broadcast/all',
    body: 'System announcement: Server is running smoothly!',
    contentType: 'text/plain',
  );

  // Wait for the broadcast message
  await messageCompleter.future.timeout(const Duration(seconds: 5));
  await messageSubscription.cancel();

  print('✅ Broadcast example completed');
}
