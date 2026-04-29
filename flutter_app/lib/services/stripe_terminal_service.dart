import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mek_stripe_terminal/mek_stripe_terminal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_controller.dart';
import 'api_client.dart';

class StripeTerminalService extends ChangeNotifier {
  StripeTerminalService({required this.controller});

  static const MethodChannel _diagnosticsChannel = MethodChannel(
    'app.wiredevelop.pt/terminal_diagnostics',
  );

  final AppController controller;

  bool _initializing = false;
  bool _initialized = false;
  bool _discovering = false;
  bool _connecting = false;
  bool _processing = false;
  bool? _supported;
  String? _statusMessage;
  String? _locationId;
  double _feePercent = 0;
  double _feeFixed = 0;
  Reader? _reader;
  StreamSubscription<ConnectionStatus>? _connectionSubscription;
  Map<String, dynamic>? _deviceDiagnostics;
  final List<String> _logs = <String>[];
  TerminalExceptionCode? _lastTerminalErrorCode;
  String? _lastTerminalErrorMessage;

  bool get initializing => _initializing;
  bool get initialized => _initialized;
  bool get discovering => _discovering;
  bool get connecting => _connecting;
  bool get processing => _processing;
  bool get supported => _supported == true;
  bool get supportKnown => _supported != null;
  String? get statusMessage => _statusMessage;
  String? get locationId => _locationId;
  double get feePercent => _feePercent;
  double get feeFixed => _feeFixed;
  Reader? get reader => _reader;
  bool get isConnected => _reader != null;
  Map<String, dynamic>? get deviceDiagnostics => _deviceDiagnostics;
  List<String> get logs => List.unmodifiable(_logs);
  TerminalExceptionCode? get lastTerminalErrorCode => _lastTerminalErrorCode;
  String? get lastTerminalErrorMessage => _lastTerminalErrorMessage;

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
    _appendLog('A iniciar diagnóstico do Tap to Pay.');
    notifyListeners();

    try {
      await _loadDeviceDiagnostics(
        force: requestPermissions || _deviceDiagnostics == null,
      );

      if (requestPermissions) {
        await _requestPermissions();
      }

      if (!Terminal.isInitialized) {
        _appendLog(
          'A inicializar SDK Stripe Terminal '
          '(logs Stripe ${kDebugMode ? 'ativos' : 'ativos'}).',
        );
        await Terminal.initTerminal(
          shouldPrintLogs: true,
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
            _appendLog('Estado de ligação: ${status.name}.');
            notifyListeners();
          });

      _appendLog('A verificar suporte local a Tap to Pay.');
      _supported = await Terminal.instance.supportsReadersOfType(
        deviceType: DeviceType.tapToPay,
        discoveryConfiguration: const TapToPayDiscoveryConfiguration(
          isSimulated: false,
        ),
      );
      _appendLog(
        'Resultado de suporte Tap to Pay: ${_supported == true ? 'suportado' : 'não suportado'}.',
      );

      _reader = await Terminal.instance.getConnectedReader();
      _appendLog(
        _reader != null
            ? 'Leitor já ligado: ${_reader?.label ?? _reader?.deviceType?.name ?? 'Tap to Pay'}.'
            : 'Sem leitor ligado após inicialização.',
      );
      _initialized = true;
      _statusMessage = supported
          ? (_reader != null ? 'Terminal pronto.' : 'Tap to Pay disponível.')
          : _unsupportedReason();
    } catch (error) {
      _captureError(error, context: 'initialize');
      _statusMessage = _errorLabel(error);
      rethrow;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> connectLocalReader() async {
    await initialize(requestPermissions: true);
    if (!supported) {
      final message = _unsupportedReason();
      _appendLog('Ligação bloqueada: $message');
      throw Exception(message);
    }
    if (_locationId == null || _locationId!.isEmpty) {
      _appendLog('Ligação bloqueada: location_id Stripe Terminal em falta.');
      throw Exception(
        'STRIPE_TERMINAL_LOCATION_ID não configurado no servidor.',
      );
    }
    if (_reader != null || _connecting) {
      return;
    }

    _discovering = true;
    _statusMessage = 'A procurar terminal local...';
    _appendLog('A descobrir leitores Tap to Pay locais.');
    notifyListeners();

    try {
      final readers = await Terminal.instance
          .discoverReaders(
            const TapToPayDiscoveryConfiguration(isSimulated: false),
          )
          .first;

      _discovering = false;
      if (readers.isEmpty) {
        _appendLog('Nenhum leitor devolvido por discoverReaders.');
        throw Exception(
          'Nenhum terminal Tap to Pay encontrado neste dispositivo.',
        );
      }

      _connecting = true;
      _statusMessage = 'A ligar ao terminal local...';
      _appendLog(
        'Leitores encontrados: ${readers.length}. A ligar ao primeiro leitor.',
      );
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
      _appendLog(
        'Terminal ligado: ${connected.label ?? connected.deviceType?.name ?? 'Tap to Pay'}.',
      );
    } catch (error) {
      _captureError(error, context: 'connectLocalReader');
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
    _appendLog(
      'A iniciar pagamento presencial de ${(amountCents / 100).toStringAsFixed(2)} $currency.',
    );
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
      _appendLog('PaymentIntent criado: ${paymentIntentId ?? 'sem id'}.');
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
      _appendLog('PaymentIntent recuperado no SDK Stripe Terminal.');
      final processable = await Terminal.instance.collectPaymentMethod(
        paymentIntent,
      );
      _appendLog('Método de pagamento recolhido no Tap to Pay.');

      _statusMessage = 'A confirmar pagamento...';
      notifyListeners();

      final confirmed = await Terminal.instance.confirmPaymentIntent(
        processable,
      );
      _appendLog('PaymentIntent confirmado no terminal.');

      if (paymentIntentId != null && paymentIntentId.isNotEmpty) {
        final synced = await _client.post(
          '/stripe/payment-intent/sync',
          body: {'payment_intent_id': paymentIntentId},
        );
        _statusMessage = 'Pagamento confirmado.';
        _appendLog('Pagamento sincronizado com o servidor.');
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
      _captureError(error, context: 'processPayment');
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
      _appendLog('Terminal desligado.');
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
    final sdkInt = (_deviceDiagnostics?['sdkInt'] as num?)?.toInt() ?? 0;
    final permissions = <Permission>[
      Permission.locationWhenInUse,
      if (Platform.isAndroid && sdkInt >= 31) ...[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ] else ...[
        Permission.bluetooth,
      ],
    ];

    final beforeStatuses = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      beforeStatuses[permission] = await permission.status;
    }
    _appendLog(
      'Permissões antes do pedido: ${_formatPermissionStatuses(beforeStatuses)}.',
    );

    final statuses = await permissions.request();
    _appendLog(
      'Permissões depois do pedido: ${_formatPermissionStatuses(statuses)}.',
    );
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
    _appendLog('Serviço de localização: ${locationService.name}.');
    if (locationService != ServiceStatus.enabled) {
      throw Exception(
        'Ativa a localização do dispositivo para usar o terminal.',
      );
    }
  }

  Future<String> _fetchConnectionToken() async {
    _appendLog('A pedir connection token Stripe Terminal ao servidor.');
    final result = await _client.get('/stripe/connection-token');
    final data = (result['data'] as Map).cast<String, dynamic>();
    _locationId = data['location_id']?.toString();
    _feePercent = (data['fee_percent'] as num?)?.toDouble() ?? 0;
    _feeFixed = (data['fee_fixed'] as num?)?.toDouble() ?? 0;
    _appendLog(
      'Connection token recebido. Location: ${_locationId ?? 'sem location'}; '
      'taxa: ${_feePercent.toStringAsFixed(2)}% + ${_feeFixed.toStringAsFixed(2)}.',
    );
    notifyListeners();
    return data['secret']?.toString() ?? '';
  }

  void _setStatusMessage(String message) {
    _statusMessage = message;
    _appendLog(message);
    notifyListeners();
  }

  String _errorLabel(Object error) {
    if (error is TerminalException) {
      return '${_terminalErrorLabel(error.code)} ${error.message}'.trim();
    }
    if (error is ApiException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _loadDeviceDiagnostics({bool force = false}) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (_deviceDiagnostics != null && !force) {
      return;
    }
    try {
      final data = await _diagnosticsChannel.invokeMapMethod<String, dynamic>(
        'getDiagnostics',
      );
      if (data == null) {
        return;
      }
      _deviceDiagnostics = Map<String, dynamic>.from(data);
      final manufacturer =
          _deviceDiagnostics?['manufacturer']?.toString() ?? '—';
      final model = _deviceDiagnostics?['model']?.toString() ?? '—';
      final sdkInt = _deviceDiagnostics?['sdkInt']?.toString() ?? '—';
      _appendLog('Diagnóstico Android: $manufacturer $model, SDK $sdkInt.');
      final blocker = _diagnosticBlocker();
      if (blocker != null) {
        _appendLog('Bloqueio local detetado: $blocker');
      }
    } catch (error) {
      _appendLog(
        'Falha a ler diagnóstico Android: ${error.toString().replaceFirst('Exception: ', '')}.',
      );
    }
  }

  void _captureError(Object error, {required String context}) {
    if (error is TerminalException) {
      _lastTerminalErrorCode = error.code;
      _lastTerminalErrorMessage = error.message;
      _appendLog(
        '$context falhou com Stripe Terminal `${error.code.name}`: ${error.message}.',
      );
      return;
    }
    _lastTerminalErrorCode = null;
    _lastTerminalErrorMessage = error.toString().replaceFirst(
      'Exception: ',
      '',
    );
    _appendLog('$context falhou: $_lastTerminalErrorMessage.');
  }

  String _unsupportedReason() {
    final blocker = _diagnosticBlocker();
    if (blocker != null) {
      return blocker;
    }
    if (_lastTerminalErrorCode != null) {
      return _terminalErrorLabel(_lastTerminalErrorCode!);
    }
    return 'Este dispositivo não suporta Tap to Pay.';
  }

  String? _diagnosticBlocker() {
    if (!Platform.isAndroid) {
      return null;
    }
    final diagnostics = _deviceDiagnostics;
    if (diagnostics == null) {
      return null;
    }
    if (diagnostics['isDebuggableApp'] == true) {
      return 'A app está instalada em modo debug. O Tap to Pay da Stripe exige build release ou profile.';
    }
    if (diagnostics['developerOptionsEnabled'] == true) {
      return 'As opções de programador do Android estão ativas. Desativa-as para usar Tap to Pay.';
    }
    if (diagnostics['hasNfc'] == false) {
      return 'Este dispositivo não expõe NFC compatível para Tap to Pay.';
    }
    if (diagnostics['nfcEnabled'] == false) {
      return 'Ativa o NFC do dispositivo para usar Tap to Pay.';
    }
    if (diagnostics['hasGooglePlayServices'] == false ||
        diagnostics['hasGooglePlayStore'] == false) {
      return 'O dispositivo precisa de Google Play Services e Play Store para Tap to Pay.';
    }
    if (diagnostics['hasHardwareKeystore'] == false ||
        diagnostics['hardwareKeystoreVersion100'] == false) {
      return 'O dispositivo não expõe hardware keystore compatível com Tap to Pay.';
    }
    return null;
  }

  String _terminalErrorLabel(TerminalExceptionCode code) {
    return switch (code) {
      TerminalExceptionCode.tapToPayUnsupportedDevice =>
        'Dispositivo não suportado pelo SDK Tap to Pay.',
      TerminalExceptionCode.tapToPayUnsupportedOperatingSystemVersion =>
        'Versão de Android não suportada pelo Tap to Pay.',
      TerminalExceptionCode.tapToPayDeviceTampered =>
        'O dispositivo aparenta estar alterado, desbloqueado ou com integridade comprometida.',
      TerminalExceptionCode.tapToPayDebugNotSupported =>
        'A Stripe bloqueia Tap to Pay em builds debug. Instala uma build release/profile.',
      TerminalExceptionCode.tapToPayInsecureEnvironment =>
        'Ambiente inseguro para Tap to Pay. Desativa gravação de ecrã, overlays e opções de programador.',
      TerminalExceptionCode.locationServicesDisabled =>
        'A localização do Android está desligada.',
      TerminalExceptionCode.bluetoothPermissionDenied =>
        'As permissões Bluetooth necessárias não estão concedidas.',
      TerminalExceptionCode.nfcDisabled =>
        'O NFC está desligado ou inacessível.',
      TerminalExceptionCode.featureNotEnabledOnAccount =>
        'A conta Stripe ainda não tem a funcionalidade Tap to Pay ativada.',
      TerminalExceptionCode.tapToPayReaderMerchantBlocked =>
        'A conta Stripe está bloqueada para Tap to Pay.',
      TerminalExceptionCode.tapToPayReaderInvalidMerchant =>
        'O comerciante Stripe configurado não é válido para Tap to Pay.',
      TerminalExceptionCode.tapToPayReaderAccountDeactivated =>
        'A conta Stripe usada no terminal está desativada.',
      _ => 'Erro Stripe Terminal `${code.name}`.',
    };
  }

  String _formatPermissionStatuses(Map<Permission, PermissionStatus> statuses) {
    return statuses.entries
        .map(
          (entry) =>
              '${entry.key.toString().replaceFirst('Permission.', '')}=${entry.value.name}',
        )
        .join(', ');
  }

  void _appendLog(String message) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final line = '[$time] $message';
    _logs.insert(0, line);
    if (_logs.length > 30) {
      _logs.removeRange(30, _logs.length);
    }
    debugPrint('[TapToPay] $message');
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
