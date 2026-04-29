import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mek_stripe_terminal/mek_stripe_terminal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_controller.dart';
import 'api_client.dart';

class StripeTerminalService extends ChangeNotifier {
  StripeTerminalService({required this.controller});

  final AppController controller;

  bool _initializing = false;
  bool _initialized = false;
  bool _discovering = false;
  bool _connecting = false;
  bool _processing = false;
  bool _supported = false;
  String? _statusMessage;
  String? _locationId;
  double _feePercent = 0;
  double _feeFixed = 0;
  Reader? _reader;
  StreamSubscription<ConnectionStatus>? _connectionSubscription;

  bool get initializing => _initializing;
  bool get initialized => _initialized;
  bool get discovering => _discovering;
  bool get connecting => _connecting;
  bool get processing => _processing;
  bool get supported => _supported;
  String? get statusMessage => _statusMessage;
  String? get locationId => _locationId;
  double get feePercent => _feePercent;
  double get feeFixed => _feeFixed;
  Reader? get reader => _reader;
  bool get isConnected => _reader != null;

  ApiClient get _client => controller.client;

  Future<void> initialize({bool requestPermissions = false}) async {
    if (_initializing) {
      return;
    }

    if (_initialized && !requestPermissions) {
      return;
    }

    _initializing = true;
    _statusMessage = 'A preparar Tap to Pay...';
    notifyListeners();

    try {
      if (requestPermissions) {
        await _requestPermissions();
      }

      if (!Terminal.isInitialized) {
        await Terminal.initTerminal(
          shouldPrintLogs: false,
          fetchToken: _fetchConnectionToken,
        );
      } else if (_locationId == null || _locationId!.isEmpty) {
        await _fetchConnectionToken();
      }

      _connectionSubscription ??= Terminal.instance.onConnectionStatusChange
          .listen((status) {
            _statusMessage = switch (status) {
              ConnectionStatus.connected => 'Terminal ligado.',
              ConnectionStatus.connecting => 'A ligar ao terminal...',
              ConnectionStatus.discovering => 'A procurar terminal...',
              ConnectionStatus.notConnected => 'Terminal desligado.',
            };
            notifyListeners();
          });

      _supported = await Terminal.instance.supportsReadersOfType(
        deviceType: DeviceType.tapToPay,
        discoveryConfiguration: const TapToPayDiscoveryConfiguration(
          isSimulated: false,
        ),
      );

      _reader = await Terminal.instance.getConnectedReader();
      _initialized = true;
      _statusMessage = _supported
          ? (_reader != null ? 'Terminal pronto.' : 'Tap to Pay disponível.')
          : 'Este dispositivo não suporta Tap to Pay.';
    } catch (error) {
      _statusMessage = _errorLabel(error);
      rethrow;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> connectLocalReader() async {
    await initialize(requestPermissions: true);
    if (!_supported) {
      throw Exception('Este dispositivo não suporta Tap to Pay.');
    }
    if (_locationId == null || _locationId!.isEmpty) {
      throw Exception(
        'STRIPE_TERMINAL_LOCATION_ID não configurado no servidor.',
      );
    }
    if (_reader != null || _connecting) {
      return;
    }

    _discovering = true;
    _statusMessage = 'A procurar terminal local...';
    notifyListeners();

    try {
      final readers = await Terminal.instance
          .discoverReaders(
            const TapToPayDiscoveryConfiguration(isSimulated: false),
          )
          .first;

      _discovering = false;
      if (readers.isEmpty) {
        throw Exception(
          'Nenhum terminal Tap to Pay encontrado neste dispositivo.',
        );
      }

      _connecting = true;
      _statusMessage = 'A ligar ao terminal local...';
      notifyListeners();

      final connected = await Terminal.instance.connectReader(
        readers.first,
        configuration: TapToPayConnectionConfiguration(
          locationId: _locationId!,
          merchantDisplayName: 'WireDevelop',
          readerDelegate: _TapToPayDelegate(_setStatusMessage),
        ),
      );

      _reader = connected;
      _statusMessage = 'Terminal ligado com sucesso.';
    } catch (error) {
      _statusMessage = _errorLabel(error);
      rethrow;
    } finally {
      _discovering = false;
      _connecting = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> processPayment(
    int amountCents, {
    String currency = 'eur',
    String? description,
  }) async {
    if (amountCents <= 0) {
      throw Exception('Indica um valor válido.');
    }

    await initialize(requestPermissions: true);

    if (!isConnected) {
      await connectLocalReader();
    }

    _processing = true;
    _statusMessage = 'A criar pagamento presencial...';
    notifyListeners();

    String? paymentIntentId;
    try {
      final created = await _client.post(
        '/stripe/payment-intent',
        body: {
          'amount': amountCents,
          'currency': currency,
          'description': description,
        },
      );

      final data = (created['data'] as Map).cast<String, dynamic>();
      paymentIntentId = data['payment_intent_id']?.toString();
      final clientSecret = data['client_secret']?.toString() ?? '';
      if (clientSecret.isEmpty) {
        throw Exception(
          'O servidor não devolveu o client secret do PaymentIntent.',
        );
      }

      _statusMessage = 'A recolher método de pagamento...';
      notifyListeners();

      final paymentIntent = await Terminal.instance.retrievePaymentIntent(
        clientSecret,
      );
      final processable = await Terminal.instance.collectPaymentMethod(
        paymentIntent,
      );

      _statusMessage = 'A confirmar pagamento...';
      notifyListeners();

      final confirmed = await Terminal.instance.confirmPaymentIntent(
        processable,
      );

      if (paymentIntentId != null && paymentIntentId.isNotEmpty) {
        final synced = await _client.post(
          '/stripe/payment-intent/sync',
          body: {'payment_intent_id': paymentIntentId},
        );
        _statusMessage = 'Pagamento confirmado.';
        return (synced['data'] as Map).cast<String, dynamic>();
      }

      _statusMessage = 'Pagamento confirmado.';
      return {
        'payment': {
          'payment_intent_id': confirmed.id,
          'status': confirmed.status.name,
        },
      };
    } catch (error) {
      if (paymentIntentId != null && paymentIntentId.isNotEmpty) {
        try {
          await _client.post(
            '/stripe/payment-intent/sync',
            body: {'payment_intent_id': paymentIntentId},
          );
        } catch (_) {}
      }
      _statusMessage = _errorLabel(error);
      rethrow;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (!Terminal.isInitialized) {
      _reader = null;
      notifyListeners();
      return;
    }

    try {
      await Terminal.instance.disconnectReader();
    } catch (_) {
    } finally {
      _reader = null;
      _statusMessage = 'Terminal desligado.';
      notifyListeners();
    }
  }

  int calculateGrossCents(int netCents) {
    final net = netCents / 100;
    final percent = feePercent / 100;
    final fixed = feeFixed;
    if (percent >= 1) {
      return netCents;
    }
    final gross = (net + fixed) / max(0.000001, (1 - percent));
    return (gross * 100).ceil();
  }

  int calculateFeeCents(int grossCents) {
    final gross = grossCents / 100;
    final fee = (gross * (feePercent / 100)) + feeFixed;
    return (fee * 100).round();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetooth,
      if (Platform.isAndroid) ...[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ],
    ];

    final statuses = await permissions.request();
    final permanentlyDenied = statuses.entries.where(
      (entry) => entry.value.isPermanentlyDenied || entry.value.isRestricted,
    );
    if (permanentlyDenied.isNotEmpty) {
      throw Exception(
        'As permissões de localização e bluetooth foram recusadas. '
        'Abre as definições da app para as ativares e tenta novamente.',
      );
    }

    final denied = statuses.entries.where(
      (entry) => !entry.value.isGranted && !entry.value.isLimited,
    );
    if (denied.isNotEmpty) {
      throw Exception(
        'É necessário permitir localização e bluetooth para usar o terminal. '
        'Aceita o pedido de permissão do Android e tenta novamente.',
      );
    }

    final locationService = await Permission.locationWhenInUse.serviceStatus;
    if (locationService != ServiceStatus.enabled) {
      throw Exception(
        'Ativa a localização do dispositivo para usar o terminal.',
      );
    }
  }

  Future<String> _fetchConnectionToken() async {
    final result = await _client.get('/stripe/connection-token');
    final data = (result['data'] as Map).cast<String, dynamic>();
    _locationId = data['location_id']?.toString();
    _feePercent = (data['fee_percent'] as num?)?.toDouble() ?? 0;
    _feeFixed = (data['fee_fixed'] as num?)?.toDouble() ?? 0;
    notifyListeners();
    return data['secret']?.toString() ?? '';
  }

  void _setStatusMessage(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  String _errorLabel(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _TapToPayDelegate extends TapToPayReaderDelegate {
  _TapToPayDelegate(this.onStatus);

  final void Function(String message) onStatus;

  @override
  void onAcceptTermsOfService() {
    onStatus('Termos do Tap to Pay aceites.');
  }

  @override
  void onDisconnect(DisconnectReason reason) {
    onStatus('Terminal desligado: ${reason.name}.');
  }

  @override
  void onFinishInstallingUpdate(
    ReaderSoftwareUpdate? update,
    TerminalException? exception,
  ) {
    if (exception != null) {
      onStatus('Atualização do terminal falhou.');
      return;
    }
    onStatus('Atualização do terminal concluída.');
  }

  @override
  void onReaderReconnectFailed(Reader reader) {
    onStatus('Falha ao restabelecer a ligação ao terminal.');
  }

  @override
  void onReaderReconnectStarted(
    Reader reader,
    Cancellable cancelReconnect,
    DisconnectReason reason,
  ) {
    onStatus('A tentar restabelecer ligação ao terminal...');
  }

  @override
  void onReaderReconnectSucceeded(Reader reader) {
    onStatus('Ligação ao terminal restabelecida.');
  }

  @override
  void onReportReaderSoftwareUpdateProgress(double progress) {
    onStatus('Atualização do terminal: ${(progress * 100).round()}%.');
  }

  @override
  void onRequestReaderDisplayMessage(ReaderDisplayMessage message) {
    onStatus('Terminal: ${message.name}.');
  }

  @override
  void onRequestReaderInput(List<ReaderInputOption> options) {
    onStatus('A aguardar cartão ou wallet no terminal.');
  }

  @override
  void onStartInstallingUpdate(
    ReaderSoftwareUpdate update,
    Cancellable cancelUpdate,
  ) {
    onStatus('A iniciar atualização do terminal...');
  }
}
