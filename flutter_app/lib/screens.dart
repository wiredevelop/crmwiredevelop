import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controller.dart';
import 'services/api_client.dart';
import 'services/stripe_terminal_service.dart';
import 'widgets/ui.dart';

String formatDate(dynamic value) {
  if (value == null || value.toString().isEmpty) return '—';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}

String formatDateTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return '—';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
}

String money(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '0') ?? 0;
  return NumberFormat.currency(
    locale: 'pt_PT',
    symbol: '€',
    decimalDigits: 2,
  ).format(number);
}

String moneyOrDash(dynamic value) {
  if (value == null || value.toString().isEmpty) return '—';
  return money(value);
}

String signedHours(dynamic secondsValue) {
  final seconds = secondsValue is num
      ? secondsValue.toInt()
      : int.tryParse(secondsValue?.toString() ?? '0') ?? 0;
  final sign = seconds < 0 ? '-' : '';
  final abs = seconds.abs();
  final hrs = abs ~/ 3600;
  final mins = (abs % 3600) ~/ 60;
  final secs = abs % 60;
  final base = '$sign${hrs}h ${mins.toString().padLeft(2, '0')}m';
  return secs > 0 ? '$base ${secs.toString().padLeft(2, '0')}s' : base;
}

String walletTransactionTypeLabel(String type) {
  switch (type) {
    case 'purchase':
      return 'Compra';
    case 'expense':
      return 'Gasto';
    case 'usage':
      return 'Consumo';
    default:
      return 'Ajuste';
  }
}

String projectStatusLabel(String? status) {
  switch (status) {
    case 'planeamento':
      return 'Planeamento';
    case 'em_andamento':
      return 'Em andamento';
    case 'aguardar_conteudos':
      return 'Aguardar conteúdos';
    case 'em_revisao':
      return 'Em revisão';
    case 'concluido':
      return 'Concluído';
    case 'pausado':
      return 'Pausado';
    case 'cancelado':
      return 'Cancelado';
    default:
      return status ?? 'Sem estado';
  }
}

Color projectStatusColor(String? status) {
  switch (status) {
    case 'concluido':
      return const Color(0xFF2E7D57);
    case 'em_andamento':
      return const Color(0xFF1565C0);
    case 'em_revisao':
      return const Color(0xFF6A1B9A);
    case 'aguardar_conteudos':
    case 'planeamento':
      return const Color(0xFFB26A00);
    case 'cancelado':
      return const Color(0xFFC62828);
    case 'pausado':
      return const Color(0xFF616161);
    default:
      return const Color(0xFF0E4D50);
  }
}

num toNumber(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _biometricLoading = false;
  bool _canUseBiometrics = false;
  bool _reveal = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareBiometrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _reveal = true);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _prepareBiometrics() async {
    final canUse = await widget.controller.canUseBiometrics();
    if (mounted) {
      setState(() => _canUseBiometrics = canUse);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.controller.login(
        baseUrl: widget.controller.baseUrl,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!widget.controller.mustChangePassword) {
        await _askToEnableBiometrics();
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível entrar. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitBiometric() async {
    setState(() {
      _biometricLoading = true;
      _error = null;
    });

    try {
      final authenticated =
          _canUseBiometrics &&
          await widget.controller.authenticateWithBiometrics();

      if (!authenticated) {
        if (mounted) {
          setState(
            () => _error = 'A autenticação biométrica foi cancelada ou falhou.',
          );
        }
        return;
      }

      await widget.controller.loginWithCachedCredentials();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível entrar com biometria.');
      }
    } finally {
      if (mounted) {
        setState(() => _biometricLoading = false);
      }
    }
  }

  Future<void> _askToEnableBiometrics() async {
    if (widget.controller.biometricEnabled) return;
    final canUseBiometrics = await widget.controller.canUseBiometrics();
    if (!canUseBiometrics || !mounted) return;

    final enable = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Login rápido'),
        content: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Pode ativar impressão digital ou Face ID para entrar mais rápido. '
            'Ao continuar vamos abrir Mais > Segurança.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Agora não'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );

    if (enable == true) {
      widget.controller.queueOpenSecurityShortcut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canQuickLogin =
        widget.controller.biometricEnabled &&
        widget.controller.hasCachedCredentials &&
        _canUseBiometrics;

    return CupertinoPageScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  offset: _reveal ? Offset.zero : const Offset(0, 0.08),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 540),
                    opacity: _reveal ? 1 : 0,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GlassPanel(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Entrar',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: CupertinoColors.white,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'WireDevelop CRM',
                              style: TextStyle(
                                color: CupertinoColors.white.withValues(
                                  alpha: 0.72,
                                ),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _lineInput(
                              label: 'Email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                            ),
                            const SizedBox(height: 14),
                            _lineInput(
                              label: 'Password',
                              controller: _passwordController,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: CupertinoColors.systemRed,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            CupertinoButton(
                              color: CupertinoColors.white.withValues(
                                alpha: 0.95,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              onPressed: _loading || _biometricLoading
                                  ? null
                                  : _submit,
                              child: _loading
                                  ? const CupertinoActivityIndicator(
                                      color: kBrandColor,
                                    )
                                  : const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        color: kBrandColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                            if (_canUseBiometrics &&
                                widget.controller.hasCachedCredentials &&
                                !widget.controller.biometricEnabled) ...[
                              const SizedBox(height: 8),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                onPressed: _loading || _biometricLoading
                                    ? null
                                    : _askToEnableBiometrics,
                                child: const Text(
                                  'Ativar impressão digital / Face ID',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (canQuickLogin) ...[
                              const SizedBox(height: 8),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                onPressed: _loading || _biometricLoading
                                    ? null
                                    : _submitBiometric,
                                child: _biometricLoading
                                    ? const CupertinoActivityIndicator(
                                        color: CupertinoColors.white,
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            CupertinoIcons.lock_fill,
                                            color: CupertinoColors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Entrar com biometria',
                                            style: TextStyle(
                                              color: CupertinoColors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineInput({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<String>? autofillHints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: CupertinoColors.white.withValues(alpha: 0.82),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autocorrect: false,
          autofillHints: autofillHints,
          style: const TextStyle(color: CupertinoColors.white, fontSize: 18),
          cursorColor: CupertinoColors.white,
          padding: const EdgeInsets.only(bottom: 10, top: 2),
          decoration: BoxDecoration(
            color: CupertinoColors.transparent,
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.white.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ForcedPasswordChangeScreen extends StatefulWidget {
  const ForcedPasswordChangeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ForcedPasswordChangeScreen> createState() =>
      _ForcedPasswordChangeScreenState();
}

class _ForcedPasswordChangeScreenState
    extends State<ForcedPasswordChangeScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.controller.completePasswordChange(
        password: _passwordController.text,
      );
      await _askToEnableBiometrics();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Não foi possível atualizar a senha.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _askToEnableBiometrics() async {
    if (widget.controller.biometricEnabled) return;

    final canUseBiometrics = await widget.controller.canUseBiometrics();
    if (!canUseBiometrics || !mounted) return;

    final enable = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ativar biometria'),
        content: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Pode ativar Face ID ou impressão digital para entrar mais rápido neste dispositivo. '
            'Ao continuar vamos abrir Mais > Segurança.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Agora não'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );

    if (enable == true) {
      widget.controller.queueOpenSecurityShortcut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassPanel(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Alterar senha',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: CupertinoColors.white,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A conta tem uma senha temporária. Define uma nova senha para continuar.',
                          style: TextStyle(
                            color: CupertinoColors.white.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _lineInput(
                          label: 'Nova senha',
                          controller: _passwordController,
                          obscureText: true,
                        ),
                        const SizedBox(height: 14),
                        _lineInput(
                          label: 'Confirmar senha',
                          controller: _confirmController,
                          obscureText: true,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        CupertinoButton(
                          color: CupertinoColors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const CupertinoActivityIndicator(
                                  color: kBrandColor,
                                )
                              : const Text(
                                  'Guardar nova senha',
                                  style: TextStyle(
                                    color: kBrandColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        CupertinoButton(
                          onPressed: _saving ? null : widget.controller.logout,
                          child: const Text(
                            'Terminar sessão',
                            style: TextStyle(color: CupertinoColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineInput({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: CupertinoColors.white.withValues(alpha: 0.72),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: CupertinoColors.white, fontSize: 18),
          cursorColor: CupertinoColors.white,
          padding: const EdgeInsets.only(bottom: 10, top: 2),
          decoration: BoxDecoration(
            color: CupertinoColors.transparent,
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.white.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final CupertinoTabController _tabController;
  final GlobalKey<NavigatorState> _moreTabNavigatorKey =
      GlobalKey<NavigatorState>();
  int _lastHandledHomeShortcutVersion = 0;
  int _lastHandledNavigationVersion = 0;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
    widget.controller.addListener(_handleControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleControllerChange();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted) return;

    final version = widget.controller.homeShortcutVersion;
    if (version != _lastHandledHomeShortcutVersion) {
      _lastHandledHomeShortcutVersion = version;

      final shortcut = widget.controller.consumePendingHomeShortcut();
      if (shortcut == 'security') {
        _openMoreModule('security');
      }
    }

    final navigationVersion = widget.controller.navigationRequestVersion;
    if (navigationVersion != _lastHandledNavigationVersion) {
      _lastHandledNavigationVersion = navigationVersion;
      final request = widget.controller.consumePendingNavigationRequest();
      if (request != null) {
        _openNavigationRequest(request);
      }
    }
  }

  void _openNavigationRequest(AppNavigationRequest request) {
    switch (request.route) {
      case 'clients':
        if (!widget.controller.isClientUser) {
          _tabController.index = 1;
        }
        return;
      case 'objects':
        if (widget.controller.isClientUser) {
          _tabController.index = 1;
        }
        return;
      case 'projects':
        _tabController.index = 2;
        return;
      case 'wallet':
        _openMoreModule('wallet');
        return;
      case 'wallets':
        _openMoreModule('wallets', clientId: request.clientId);
        return;
      case 'invoices':
        _openMoreModule('documents', invoiceStatus: request.status);
        return;
      case 'more':
        if (request.module == null || request.module!.isEmpty) {
          _tabController.index = 3;
          return;
        }
        _openMoreModule(request.module!);
        return;
    }
  }

  void _openMoreModule(
    String module, {
    String? clientId,
    String? invoiceStatus,
  }) {
    _tabController.index = 3;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final screen = _buildMoreModuleScreen(
        module,
        clientId: clientId,
        invoiceStatus: invoiceStatus,
      );
      if (screen == null) {
        return;
      }
      _moreTabNavigatorKey.currentState?.push(
        CupertinoPageRoute(builder: (_) => screen),
      );
    });
  }

  Widget? _buildMoreModuleScreen(
    String module, {
    String? clientId,
    String? invoiceStatus,
  }) {
    switch (module) {
      case 'wallet':
        return ClientWalletScreen(controller: widget.controller);
      case 'security':
        return SecurityScreen(controller: widget.controller);
      case 'documents':
        return InvoicesScreen(
          controller: widget.controller,
          initialStatusFilter: invoiceStatus,
        );
      case 'quotes':
        return QuotesScreen(controller: widget.controller);
      case 'products':
        return ProductsScreen(controller: widget.controller);
      case 'finance':
        return FinanceScreen(controller: widget.controller);
      case 'terminal':
        return TapToPayScreen(controller: widget.controller);
      case 'interventions':
        return InterventionsScreen(controller: widget.controller);
      case 'wallets':
        return WalletsScreen(
          controller: widget.controller,
          initialClientId: clientId,
        );
      case 'company':
        return CompanyScreen(controller: widget.controller);
      case 'settings':
        return SettingsScreen(controller: widget.controller);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClientUser = widget.controller.isClientUser;
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.white.withValues(alpha: 0.16),
        activeColor: CupertinoColors.white,
        inactiveColor: CupertinoColors.white.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.white.withValues(alpha: 0.28),
            width: 0.7,
          ),
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            label: isClientUser ? 'Objetos' : 'Clientes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.folder),
            label: 'Projetos',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            label: 'Mais',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          navigatorKey: index == 3 ? _moreTabNavigatorKey : null,
          builder: (context) {
            switch (index) {
              case 0:
                return DashboardScreen(controller: widget.controller);
              case 1:
                return isClientUser
                    ? ObjectsScreen(controller: widget.controller)
                    : ClientsScreen(controller: widget.controller);
              case 2:
                return ProjectsScreen(controller: widget.controller);
              default:
                return MoreModulesScreen(controller: widget.controller);
            }
          },
        );
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _payload;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get('/dashboard');
      setState(
        () => _payload = (result['data'] as Map).cast<String, dynamic>(),
      );
      unawaited(widget.controller.refreshWidgetData());
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openInvoiceDetails(Map<String, dynamic> invoice) async {
    final id = invoice['id'];
    if (id == null) {
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => InvoiceDetailScreen(
          controller: widget.controller,
          invoiceId: id.toString(),
          initialInvoice: invoice,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        widget.controller.user?['name']?.toString() ?? 'Utilizador';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.white.withValues(alpha: 0.2),
            width: 0.6,
          ),
        ),
        middle: const Text('Dashboard'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _load,
              child: const Icon(
                CupertinoIcons.refresh,
                color: CupertinoColors.white,
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(left: 10),
              onPressed: widget.controller.logout,
              child: const Icon(
                CupertinoIcons.square_arrow_right,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: CupertinoColors.white,
                    ),
                  )
                : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    cacheExtent: 1100,
                    children: [
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Text(
                          'Bem-vindo, $userName',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: CupertinoColors.white,
                            letterSpacing: -0.9,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                        child: Text(
                          'Visão geral do CRM',
                          style: TextStyle(
                            color: CupertinoColors.white.withValues(
                              alpha: 0.72,
                            ),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!widget.controller.isClientUser)
                        CardSection(
                          title: 'Atalhos rápidos',
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => InterventionsScreen(
                                    controller: widget.controller,
                                  ),
                                ),
                              );
                            },
                            child: const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Iniciar intervenção'),
                            ),
                          ),
                        ),
                      CardSection(
                        title: 'Indicadores',
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _StatChip(
                              label: widget.controller.isClientUser
                                  ? 'Objetos'
                                  : 'Clientes',
                              value:
                                  _payload?['stats']?['total_clients']
                                      ?.toString() ??
                                  '0',
                            ),
                            _StatChip(
                              label: 'Projetos ativos',
                              value:
                                  _payload?['stats']?['active_projects']
                                      ?.toString() ??
                                  '0',
                            ),
                            _StatChip(
                              label: 'Projetos concluídos',
                              value:
                                  _payload?['stats']?['completed_projects']
                                      ?.toString() ??
                                  '0',
                            ),
                            if (!widget.controller.isClientUser)
                              _StatChip(
                                label: 'Faturação paga',
                                value: money(
                                  _payload?['stats']?['paid_amount'],
                                ),
                              ),
                            if (widget.controller.isClientUser)
                              _StatChip(
                                label: 'Pendentes',
                                value: money(
                                  _payload?['stats']?['pending_values'],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.controller.isClientUser)
                        CardSection(
                          title: 'Vendas registadas',
                          child: _SimpleList(
                            items: (_payload?['sales'] as List? ?? []),
                            titleKey: 'description',
                            subtitleBuilder: (item) =>
                                '${item['type'] ?? 'Venda'} · ${money(item['amount'])} · ${item['invoice_status'] ?? item['status'] ?? '—'}',
                          ),
                        ),
                      if (widget.controller.isClientUser)
                        CardSection(
                          title: 'Parcelas registadas',
                          child: _SimpleList(
                            items: (_payload?['installments'] as List? ?? []),
                            titleKey: 'project',
                            subtitleBuilder: (item) =>
                                '${money(item['amount'])} · ${item['invoice'] ?? 'Sem documento'} · ${formatDate(item['paid_at'])}',
                          ),
                        ),
                      if (widget.controller.isClientUser)
                        CardSection(
                          title: 'Documentos registados',
                          child: _SimpleList(
                            items:
                                (_payload?['registered_invoices'] as List? ??
                                []),
                            titleKey: 'number',
                            subtitleBuilder: (item) =>
                                '${item['project']?['name'] ?? '—'} · ${money(item['total'])} · ${item['status'] ?? '—'}',
                            onItemTap: _openInvoiceDetails,
                          ),
                        ),
                      CardSection(
                        title: 'Últimos documentos',
                        child: _SimpleList(
                          items: (_payload?['recent_invoices'] as List? ?? []),
                          titleKey: 'number',
                          subtitleBuilder: (item) =>
                              '${item['client']?['name'] ?? '—'} · ${money(item['total'])}',
                          onItemTap: _openInvoiceDetails,
                        ),
                      ),
                      CardSection(
                        title: 'Projetos recentes',
                        child: _SimpleList(
                          items: (_payload?['recent_projects'] as List? ?? []),
                          titleKey: 'name',
                          subtitleBuilder: (item) =>
                              '${item['client']?['name'] ?? '—'} · ${item['status'] ?? '—'}',
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class ObjectsScreen extends StatefulWidget {
  const ObjectsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends State<ObjectsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _client = {};
  List<dynamic> _objects = [];
  final Set<int> _revealedPasswords = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get('/objects');
      final data = (result['data'] as Map).cast<String, dynamic>();
      setState(() {
        _client = (data['client'] as Map?)?.cast<String, dynamic>() ?? {};
        _objects = data['objects'] as List<dynamic>? ?? [];
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyPassword(String value) async {
    if (value.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    await showMessage(
      context,
      title: 'Senha copiada',
      message: 'A senha foi copiada para a área de transferência.',
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'planeamento':
        return 'Planeamento';
      case 'em_andamento':
        return 'Em andamento';
      case 'aguardar_conteudos':
        return 'Aguardar conteúdos';
      case 'em_revisao':
        return 'Em revisão';
      case 'concluido':
        return 'Concluído';
      case 'pausado':
        return 'Pausado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status ?? 'Sem estado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Objetos'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _objects.isEmpty
            ? const EmptyState('Sem objetos disponíveis.')
            : ListView(
                children: [
                  CardSection(
                    title: _client['name']?.toString() ?? 'Cliente',
                    child: Text(
                      _client['company']?.toString() ?? 'Objetos e senhas',
                    ),
                  ),
                  for (final rawObject in _objects)
                    Builder(
                      builder: (context) {
                        final object = (rawObject as Map)
                            .cast<String, dynamic>();
                        final credentials =
                            (object['credentials'] as List<dynamic>? ?? []);
                        final project = (object['project'] as Map?)
                            ?.cast<String, dynamic>();

                        return CardSection(
                          title: object['name']?.toString() ?? 'Objeto',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${object['credentials_count'] ?? credentials.length} senha(s)',
                              ),
                              if (project != null) ...[
                                const SizedBox(height: 6),
                                Text('Projeto: ${project['name'] ?? '—'}'),
                                const SizedBox(height: 4),
                                Text(
                                  'Estado: ${_statusLabel(project['status']?.toString())}',
                                ),
                              ],
                              if ((object['notes']?.toString() ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(object['notes'].toString()),
                              ],
                              const SizedBox(height: 12),
                              if (credentials.isEmpty)
                                const Text('Sem senhas neste objeto.')
                              else
                                for (final rawCredential in credentials)
                                  Builder(
                                    builder: (context) {
                                      final credential = (rawCredential as Map)
                                          .cast<String, dynamic>();
                                      final credentialId =
                                          credential['id'] as int? ?? 0;
                                      final isVisible = _revealedPasswords
                                          .contains(credentialId);

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F7F8),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              credential['label']?.toString() ??
                                                  'Serviço',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Utilizador: ${credential['username']?.toString().isNotEmpty == true ? credential['username'] : '—'}',
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Senha: ${isVisible ? credential['password'] ?? '—' : '******'}',
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                CupertinoButton(
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () {
                                                    setState(() {
                                                      if (isVisible) {
                                                        _revealedPasswords
                                                            .remove(
                                                              credentialId,
                                                            );
                                                      } else {
                                                        _revealedPasswords.add(
                                                          credentialId,
                                                        );
                                                      }
                                                    });
                                                  },
                                                  child: Text(
                                                    isVisible
                                                        ? 'Ocultar'
                                                        : 'Mostrar',
                                                    style: const TextStyle(
                                                      color: Color(0xFF0E4D50),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                CupertinoButton(
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () =>
                                                      _copyPassword(
                                                        credential['password']
                                                                ?.toString() ??
                                                            '',
                                                      ),
                                                  child: const Text(
                                                    'Copiar',
                                                    style: TextStyle(
                                                      color: Color(0xFF0E4D50),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if ((credential['url']
                                                        ?.toString() ??
                                                    '')
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                credential['url'].toString(),
                                              ),
                                            ],
                                            if ((credential['notes']
                                                        ?.toString() ??
                                                    '')
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                credential['notes'].toString(),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class _ClientsScreenState extends State<ClientsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _clients = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get('/clients?per_page=50');
      setState(() => _clients = result['data'] as List<dynamic>);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? client]) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) =>
            ClientFormScreen(controller: widget.controller, client: client),
      ),
    );
    _load();
  }

  Future<void> _openDetails(Map<String, dynamic> client) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ClientDetailScreen(
          controller: widget.controller,
          clientId: client['id'] as int,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Clientes'),
        trailing: widget.controller.isClientUser
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _openForm(),
                child: const Icon(CupertinoIcons.add),
              ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _clients.isEmpty
            ? const EmptyState('Sem clientes.')
            : ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                cacheExtent: 900,
                itemCount: _clients.length,
                itemBuilder: (context, index) {
                  final client = _clients[index] as Map<String, dynamic>;
                  return _EntityListCard(
                    title: client['name']?.toString() ?? 'Cliente',
                    subtitle: client['company']?.toString() ?? 'Sem empresa',
                    metaLines: [
                      if ((client['email']?.toString() ?? '').isNotEmpty)
                        client['email'].toString(),
                      if ((client['phone']?.toString() ?? '').isNotEmpty)
                        client['phone'].toString(),
                    ],
                    onTap: () => _openDetails(client),
                    footer: _DetailLinkButton(
                      label: 'Ver cliente',
                      onTap: () => _openDetails(client),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, required this.controller, this.client});

  final AppController controller;
  final Map<String, dynamic>? client;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _vat;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  late final TextEditingController _hourlyRate;
  late final TextEditingController _portalEmail;
  late final TextEditingController _portalPassword;
  bool _createPortalUser = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _name = TextEditingController(text: client?['name']?.toString() ?? '');
    _company = TextEditingController(
      text: client?['company']?.toString() ?? '',
    );
    _email = TextEditingController(text: client?['email']?.toString() ?? '');
    _phone = TextEditingController(text: client?['phone']?.toString() ?? '');
    _vat = TextEditingController(text: client?['vat']?.toString() ?? '');
    _address = TextEditingController(
      text: client?['address']?.toString() ?? '',
    );
    _notes = TextEditingController(text: client?['notes']?.toString() ?? '');
    _hourlyRate = TextEditingController(
      text: client?['hourly_rate']?.toString() ?? '',
    );
    _portalEmail = TextEditingController(
      text: client?['email']?.toString() ?? '',
    );
    _portalPassword = TextEditingController();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final body = {
      'name': _name.text,
      'company': _company.text,
      'email': _email.text,
      'phone': _phone.text,
      'vat': _vat.text,
      'address': _address.text,
      'notes': _notes.text,
      'hourly_rate': _hourlyRate.text,
      'create_portal_user': widget.client == null && _createPortalUser,
      'portal_email': _portalEmail.text,
      'portal_password': _portalPassword.text,
    };

    try {
      Map<String, dynamic> response;
      if (widget.client == null) {
        response = await widget.controller.client.post('/clients', body: body);
      } else {
        response = await widget.controller.client.put(
          '/clients/${widget.client!['id']}',
          body: body,
        );
      }

      final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final temporaryPassword = data['temporary_password']?.toString();
      final portalUser = (data['portal_user'] as Map?)?.cast<String, dynamic>();

      if (temporaryPassword != null && mounted) {
        await showMessage(
          context,
          title: 'Senha temporária',
          message:
              'Login: ${portalUser?['email'] ?? _portalEmail.text}\nSenha: $temporaryPassword',
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormPage(
      title: widget.client == null ? 'Novo cliente' : 'Editar cliente',
      saving: _saving,
      onSave: _save,
      children: [
        _field('Nome', _name),
        _field('Empresa', _company),
        _field('Email', _email),
        _field('Telefone', _phone),
        _field('NIF', _vat),
        _field('Morada', _address),
        _field('Valor/hora', _hourlyRate),
        _field('Notas', _notes, maxLines: 4),
        if (widget.client == null) ...[
          Row(
            children: [
              const Expanded(child: Text('Criar acesso portal')),
              CupertinoSwitch(
                value: _createPortalUser,
                onChanged: (value) => setState(() => _createPortalUser = value),
              ),
            ],
          ),
          if (_createPortalUser) ...[
            const SizedBox(height: 8),
            _field('Email de acesso', _portalEmail),
            _field('Senha temporária', _portalPassword),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                const chars =
                    'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
                final random = Random.secure();
                var password = '';
                for (var i = 0; i < 12; i++) {
                  password += chars[random.nextInt(chars.length)];
                }
                _portalPassword.text = password;
                setState(() {});
              },
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Gerar senha temporária'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.controller,
    required this.clientId,
  });

  final AppController controller;
  final int clientId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _payload;
  final Set<int> _revealedPasswords = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get(
        '/clients/${widget.clientId}',
      );
      setState(
        () => _payload = (result['data'] as Map).cast<String, dynamic>(),
      );
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitNote() async {
    final controller = TextEditingController();
    final confirmed = await _prompt(context, 'Nova nota', controller);
    if (!confirmed) return;

    try {
      await widget.controller.client.post(
        '/clients/${widget.clientId}/notes',
        body: {'note': controller.text},
      );
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _copyPassword(String value) async {
    if (value.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    await showMessage(
      context,
      title: 'Senha copiada',
      message: 'A senha foi copiada para a área de transferência.',
    );
  }

  Future<void> _openObjectTransfer(Map<String, dynamic> object) async {
    final transferTargets =
        (_payload?['transfer_targets'] as List?)?.cast<dynamic>() ?? [];
    if (transferTargets.isEmpty) {
      await showMessage(
        context,
        title: 'Sem destino',
        message:
            'Não existem outros clientes disponíveis para a transferência.',
      );
      return;
    }

    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ClientObjectTransferScreen(
          controller: widget.controller,
          clientId: widget.clientId,
          object: object,
          transferTargets: transferTargets,
        ),
      ),
    );

    if (result == true) {
      await _load();
    }
  }

  Future<void> _openObjectPromotion(Map<String, dynamic> object) async {
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ClientObjectPromotionScreen(
          controller: widget.controller,
          clientId: widget.clientId,
          object: object,
        ),
      ),
    );

    if (result is int && mounted) {
      await Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => ClientDetailScreen(
            controller: widget.controller,
            clientId: result,
          ),
        ),
      );
      return;
    }

    if (result == true) {
      await _load();
    }
  }

  Future<void> _openForm() async {
    final client = (_payload?['client'] as Map?)?.cast<String, dynamic>();
    if (client == null) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) =>
            ClientFormScreen(controller: widget.controller, client: client),
      ),
    );
    await _load();
  }

  Future<void> _deleteClient() async {
    final client = (_payload?['client'] as Map?)?.cast<String, dynamic>();
    if (client == null) return;
    final confirmed = await confirmDelete(
      context,
      'Eliminar ${client['name'] ?? 'este cliente'}?',
    );
    if (!confirmed) return;

    try {
      await widget.controller.client.delete('/clients/${widget.clientId}');
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _submitObject() async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Novo objeto'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: nameController, placeholder: 'Nome'),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: notesController,
              placeholder: 'Notas',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.controller.client.post(
        '/clients/${widget.clientId}/credential-objects',
        body: {'name': nameController.text, 'notes': notesController.text},
      );
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _submitCredential(List<dynamic> objects) async {
    if (objects.isEmpty) {
      await showMessage(
        context,
        title: 'Sem objetos',
        message: 'Cria primeiro um objeto para associar a credencial.',
      );
      return;
    }

    var objectId = objects.first['id'].toString();
    final label = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final url = TextEditingController();
    final notes = TextEditingController();

    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => CupertinoAlertDialog(
          title: const Text('Nova credencial'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: objectId,
                children: {
                  for (final object in objects.take(3))
                    object['id'].toString(): Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        object['name'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setStateDialog(() => objectId = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              CupertinoTextField(controller: label, placeholder: 'Serviço'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: username,
                placeholder: 'Utilizador',
              ),
              const SizedBox(height: 8),
              CupertinoTextField(controller: password, placeholder: 'Senha'),
              const SizedBox(height: 8),
              CupertinoTextField(controller: url, placeholder: 'URL'),
              const SizedBox(height: 8),
              CupertinoTextField(controller: notes, placeholder: 'Notas'),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await widget.controller.client.post(
        '/clients/${widget.clientId}/credentials',
        body: {
          'object_id': int.parse(objectId),
          'label': label.text,
          'username': username.text,
          'password': password.text,
          'url': url.text,
          'notes': notes.text,
        },
      );
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _createPortalUser() async {
    final email = TextEditingController(
      text:
          _payload?['client']?['user']?['email']?.toString() ??
          _payload?['client']?['email']?.toString() ??
          '',
    );
    final password = TextEditingController();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Criar acesso'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(controller: email, placeholder: 'Email'),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: password,
              placeholder: 'Senha temporária',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await widget.controller.client.post(
        '/clients/${widget.clientId}/portal-user',
        body: {'portal_email': email.text, 'portal_password': password.text},
      );
      final data = (result['data'] as Map).cast<String, dynamic>();
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Senha temporária',
        message:
            'Login: ${data['portal_user']?['email'] ?? email.text}\nSenha: ${data['temporary_password']}',
      );
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _regenerateTemporaryPassword(String deliveryMode) async {
    try {
      final result = await widget.controller.client.post(
        '/clients/${widget.clientId}/temporary-password',
        body: {'delivery_mode': deliveryMode},
      );
      final data = (result['data'] as Map).cast<String, dynamic>();
      if (!mounted) return;
      await showMessage(
        context,
        title: deliveryMode == 'email' ? 'Email enviado' : 'Senha temporária',
        message:
            'Login: ${data['portal_user']?['email'] ?? '—'}\nSenha: ${data['temporary_password']}',
      );
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientData =
        (_payload?['client'] as Map?)?.cast<String, dynamic>() ?? {};
    final portalUser =
        (clientData['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final transferTargets =
        (_payload?['transfer_targets'] as List?)?.cast<dynamic>() ?? [];

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_payload?['client']?['name']?.toString() ?? 'Cliente'),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : ListView(
                children: [
                  CardSection(
                    title: 'Dados do cliente',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _payload?['client']?['company']?.toString() ?? '—',
                        ),
                        const SizedBox(height: 4),
                        Text(_payload?['client']?['email']?.toString() ?? '—'),
                        const SizedBox(height: 4),
                        Text(_payload?['client']?['phone']?.toString() ?? '—'),
                      ],
                    ),
                  ),
                  if (!widget.controller.isClientUser)
                    CardSection(
                      title: 'Ações',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _IconActionButton(
                            action: _EntityAction(
                              icon: CupertinoIcons.pencil,
                              label: 'Editar',
                              onTap: _openForm,
                            ),
                          ),
                          _IconActionButton(
                            action: _EntityAction(
                              icon: CupertinoIcons.delete,
                              label: 'Eliminar',
                              color: CupertinoColors.systemRed,
                              onTap: _deleteClient,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if ((clientData['billing_name']?.toString() ?? '')
                          .isNotEmpty ||
                      (clientData['billing_email']?.toString() ?? '')
                          .isNotEmpty ||
                      (clientData['billing_vat']?.toString() ?? '')
                          .isNotEmpty ||
                      (clientData['billing_address']?.toString() ?? '')
                          .isNotEmpty)
                    CardSection(
                      title: 'Faturação',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoLine(
                            'Nome',
                            clientData['billing_name']?.toString() ?? '—',
                          ),
                          _InfoLine(
                            'Email',
                            clientData['billing_email']?.toString() ?? '—',
                          ),
                          _InfoLine(
                            'Telefone',
                            clientData['billing_phone']?.toString() ?? '—',
                          ),
                          _InfoLine(
                            'NIF',
                            clientData['billing_vat']?.toString() ?? '—',
                          ),
                          _InfoLine(
                            'Morada',
                            clientData['billing_address']?.toString() ?? '—',
                          ),
                          _InfoLine(
                            'Código postal',
                            clientData['billing_postal_code']?.toString() ??
                                '—',
                          ),
                          _InfoLine(
                            'Cidade',
                            clientData['billing_city']?.toString() ?? '—',
                          ),
                          _InfoLine(
                            'País',
                            clientData['billing_country']?.toString() ?? '—',
                          ),
                        ],
                      ),
                    ),
                  CardSection(
                    title: 'Acesso portal',
                    trailing: widget.controller.isClientUser
                        ? null
                        : CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: portalUser.isEmpty
                                ? _createPortalUser
                                : () => _regenerateTemporaryPassword('copy'),
                            child: Text(
                              portalUser.isEmpty ? 'Criar' : 'Gerar senha',
                            ),
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          portalUser['email']?.toString() ??
                              'Sem acesso criado.',
                        ),
                        if (portalUser.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            portalUser['must_change_password'] == true
                                ? 'A aguardar troca de senha'
                                : 'Ativo',
                          ),
                          if (!widget.controller.isClientUser) ...[
                            const SizedBox(height: 8),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  _regenerateTemporaryPassword('email'),
                              child: const Text('Gerar e enviar email'),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (!widget.controller.isClientUser) ...[
                    CardSection(
                      title: 'Notas internas',
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _submitNote,
                        child: const Text('Adicionar'),
                      ),
                      child: _SimpleList(
                        items: (_payload?['notes'] as List? ?? []),
                        titleKey: 'text',
                        subtitleBuilder: (item) =>
                            item['created_at']?.toString() ?? '—',
                      ),
                    ),
                    CardSection(
                      title: 'Objetos e credenciais',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _submitObject,
                            child: const Text('Objeto'),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(left: 8),
                            onPressed: () => _submitCredential(
                              _payload?['client']?['credential_objects']
                                      as List? ??
                                  [],
                            ),
                            child: const Text('Senha'),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          for (final object
                              in (_payload?['client']?['credential_objects']
                                      as List? ??
                                  []))
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F7F8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    object['name']?.toString() ?? 'Objeto',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if ((object['notes']?.toString() ?? '')
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(object['notes'].toString()),
                                    ),
                                  if (object['project'] is Map) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Projeto ligado: ${object['project']['name'] ?? '—'}',
                                      style: const TextStyle(
                                        color: Color(0xFF0E4D50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: transferTargets.isEmpty
                                            ? null
                                            : () => _openObjectTransfer(
                                                (object as Map)
                                                    .cast<String, dynamic>(),
                                              ),
                                        child: const Text('Transferir'),
                                      ),
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _openObjectPromotion(
                                          (object as Map)
                                              .cast<String, dynamic>(),
                                        ),
                                        child: const Text('Promover'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  for (final credential
                                      in (object['credentials'] as List? ?? []))
                                    Builder(
                                      builder: (context) {
                                        final credentialId =
                                            credential['id'] as int? ?? 0;
                                        final isVisible = _revealedPasswords
                                            .contains(credentialId);
                                        return Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFFFF),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x180E4D50),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${credential['label']} · ${credential['username'] ?? '—'}',
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Senha: ${isVisible ? credential['password'] ?? '—' : '******'}',
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  CupertinoButton(
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () {
                                                      setState(() {
                                                        if (isVisible) {
                                                          _revealedPasswords
                                                              .remove(
                                                                credentialId,
                                                              );
                                                        } else {
                                                          _revealedPasswords
                                                              .add(
                                                                credentialId,
                                                              );
                                                        }
                                                      });
                                                    },
                                                    child: Text(
                                                      isVisible
                                                          ? 'Ocultar'
                                                          : 'Mostrar',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF0E4D50,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  CupertinoButton(
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () =>
                                                        _copyPassword(
                                                          credential['password']
                                                                  ?.toString() ??
                                                              '',
                                                        ),
                                                    child: const Text(
                                                      'Copiar',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF0E4D50,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class ClientObjectTransferScreen extends StatefulWidget {
  const ClientObjectTransferScreen({
    super.key,
    required this.controller,
    required this.clientId,
    required this.object,
    required this.transferTargets,
  });

  final AppController controller;
  final int clientId;
  final Map<String, dynamic> object;
  final List<dynamic> transferTargets;

  @override
  State<ClientObjectTransferScreen> createState() =>
      _ClientObjectTransferScreenState();
}

class _ClientObjectTransferScreenState
    extends State<ClientObjectTransferScreen> {
  bool _saving = false;
  int? _targetClientId;

  Future<void> _pickTargetClient() async {
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Cliente de destino'),
        actions: [
          for (final target in widget.transferTargets)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(target['id'] as int),
              child: Text(
                target['company']?.toString().isNotEmpty == true
                    ? '${target['name']} · ${target['company']}'
                    : target['name']?.toString() ?? 'Cliente',
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _targetClientId = selected);
    }
  }

  Future<void> _save() async {
    if (_targetClientId == null) {
      await showMessage(
        context,
        title: 'Destino em falta',
        message: 'Selecione o cliente que vai receber este objeto.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.controller.client.post(
        '/clients/${widget.clientId}/credential-objects/${widget.object['id']}/transfer',
        body: {'target_client_id': _targetClientId},
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTarget = widget.transferTargets.cast<Map>().firstWhere(
      (target) => target['id'] == _targetClientId,
      orElse: () => {},
    );
    final project = (widget.object['project'] as Map?)?.cast<String, dynamic>();
    final selectedLabel = selectedTarget.isEmpty
        ? 'Selecionar cliente'
        : (selectedTarget['company']?.toString().isNotEmpty == true
              ? '${selectedTarget['name']} · ${selectedTarget['company']}'
              : selectedTarget['name']?.toString() ?? 'Cliente');

    return _FormPage(
      title: 'Transferir objeto',
      saving: _saving,
      onSave: _save,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Objeto: ${widget.object['name'] ?? '—'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            project == null
                ? 'Este objeto não tem projeto associado.'
                : 'O projeto "${project['name'] ?? '—'}" também será movido.',
          ),
        ),
        const SizedBox(height: 12),
        _selectorField(
          label: 'Cliente de destino',
          value: selectedLabel,
          onTap: _pickTargetClient,
        ),
      ],
    );
  }
}

class ClientObjectPromotionScreen extends StatefulWidget {
  const ClientObjectPromotionScreen({
    super.key,
    required this.controller,
    required this.clientId,
    required this.object,
  });

  final AppController controller;
  final int clientId;
  final Map<String, dynamic> object;

  @override
  State<ClientObjectPromotionScreen> createState() =>
      _ClientObjectPromotionScreenState();
}

class _ClientObjectPromotionScreenState
    extends State<ClientObjectPromotionScreen> {
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _vat;
  late final TextEditingController _address;
  late final TextEditingController _hourlyRate;
  late final TextEditingController _notes;
  late final TextEditingController _portalEmail;
  late final TextEditingController _portalPassword;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.object['name']?.toString() ?? '',
    );
    _company = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _vat = TextEditingController();
    _address = TextEditingController();
    _hourlyRate = TextEditingController();
    _notes = TextEditingController(
      text: widget.object['notes']?.toString() ?? '',
    );
    _portalEmail = TextEditingController();
    _portalPassword = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    _phone.dispose();
    _vat.dispose();
    _address.dispose();
    _hourlyRate.dispose();
    _notes.dispose();
    _portalEmail.dispose();
    _portalPassword.dispose();
    super.dispose();
  }

  void _generateTemporaryPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    var password = '';
    for (var i = 0; i < 12; i++) {
      password += chars[random.nextInt(chars.length)];
    }
    _portalPassword.text = password;
    setState(() {});
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _portalEmail.text.trim().isEmpty) {
      await showMessage(
        context,
        title: 'Campos em falta',
        message: 'Nome e email de acesso são obrigatórios.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final result = await widget.controller.client.post(
        '/clients/${widget.clientId}/credential-objects/${widget.object['id']}/promote',
        body: {
          'name': _name.text,
          'company': _company.text,
          'email': _email.text,
          'phone': _phone.text,
          'vat': _vat.text,
          'address': _address.text,
          'hourly_rate': _hourlyRate.text,
          'notes': _notes.text,
          'portal_email': _portalEmail.text,
          'portal_password': _portalPassword.text,
        },
      );

      final data = (result['data'] as Map).cast<String, dynamic>();
      if (!mounted) return;

      await showMessage(
        context,
        title: 'Senha temporária',
        message:
            'Login: ${data['portal_user']?['email'] ?? _portalEmail.text}\nSenha: ${data['temporary_password']}',
      );

      final newClientId = data['client']?['id'] as int?;
      if (!mounted) return;
      Navigator.of(context).pop(newClientId ?? true);
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = (widget.object['project'] as Map?)?.cast<String, dynamic>();

    return _FormPage(
      title: 'Promover objeto',
      saving: _saving,
      onSave: _save,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Objeto: ${widget.object['name'] ?? '—'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            project == null
                ? 'Este objeto não tem projeto associado.'
                : 'O projeto "${project['name'] ?? '—'}" será movido para o novo cliente.',
          ),
        ),
        const SizedBox(height: 12),
        _field('Nome', _name),
        _field('Empresa', _company),
        _field('Email', _email, keyboardType: TextInputType.emailAddress),
        _field('Telefone', _phone, keyboardType: TextInputType.phone),
        _field('NIF', _vat),
        _field('Morada', _address),
        _field(
          'Valor/hora',
          _hourlyRate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        _field('Notas', _notes, maxLines: 4),
        _field(
          'Email de acesso',
          _portalEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        _field('Senha temporária', _portalPassword),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _generateTemporaryPassword,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text('Gerar senha temporária'),
          ),
        ),
      ],
    );
  }
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _projects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get(
        '/projects?per_page=50',
      );
      setState(() => _projects = result['data'] as List<dynamic>);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([int? projectId]) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ProjectFormScreen(
          controller: widget.controller,
          projectId: projectId,
        ),
      ),
    );
    _load();
  }

  Future<void> _openDetails(Map<String, dynamic> project) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ProjectDetailScreen(
          controller: widget.controller,
          project: project,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Projetos'),
        trailing: widget.controller.isClientUser
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _openForm(),
                child: const Icon(CupertinoIcons.add),
              ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                cacheExtent: 900,
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final project = _projects[index] as Map<String, dynamic>;
                  return _EntityListCard(
                    title: project['name']?.toString() ?? 'Projeto',
                    subtitle:
                        project['client']?['name']?.toString() ?? 'Sem cliente',
                    metaLines: [
                      projectStatusLabel(project['status']?.toString()),
                      money(
                        project['base_amount'] ??
                            project['quote']?['price_development'],
                      ),
                    ],
                    statusLabel: projectStatusLabel(
                      project['status']?.toString(),
                    ),
                    statusColor: projectStatusColor(
                      project['status']?.toString(),
                    ),
                    onTap: () => _openDetails(project),
                    footer: _DetailLinkButton(
                      label: 'Ver projeto',
                      onTap: () => _openDetails(project),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.controller,
    required this.project,
  });

  final AppController controller;
  final Map<String, dynamic> project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  static const _projectStatuses = <String>[
    'planeamento',
    'em_andamento',
    'aguardar_conteudos',
    'em_revisao',
    'concluido',
  ];

  bool _loading = true;
  bool _sending = false;
  String? _error;
  Map<String, dynamic>? _project;
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  int get _projectId => (_project?['id'] ?? widget.project['id']) as int? ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.controller.client.get(
        '/projects/$_projectId',
      );
      final data = (result['data'] as Map).cast<String, dynamic>();
      setState(() {
        _project =
            (data['project'] as Map?)?.cast<String, dynamic>() ??
            widget.project;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ProjectFormScreen(
          controller: widget.controller,
          projectId: _projectId,
        ),
      ),
    );
    await _load();
  }

  Future<void> _deleteProject() async {
    final confirmed = await confirmDelete(context, 'Eliminar este projeto?');
    if (!confirmed) return;

    try {
      await widget.controller.client.delete('/projects/$_projectId');
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _sendMessage({
    String type = 'message',
    String? body,
    Map<String, dynamic>? attachment,
  }) async {
    final text = (body ?? _messageController.text).trim();
    if (text.isEmpty && attachment == null) return;

    setState(() => _sending = true);
    try {
      await widget.controller.client.post(
        '/projects/$_projectId/messages',
        body: {
          'type': type,
          'body': text.isEmpty ? null : text,
          ...(attachment == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'attachment': attachment}),
        },
      );
      _messageController.clear();
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<ImageSource?> _pickImageSource() {
    return showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar imagem'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('Galeria'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Câmara'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _pickAttachmentPayload() async {
    final source = await _pickImageSource();
    if (source == null) {
      return null;
    }

    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2200,
    );
    if (file == null) {
      return null;
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      if (!mounted) return null;
      await showMessage(
        context,
        title: 'Imagem demasiado grande',
        message: 'A imagem não pode exceder 8 MB.',
      );
      return null;
    }

    final fileName = file.name.isNotEmpty
        ? file.name
        : 'prova_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final mimeType = switch (fileName.toLowerCase().split('.').last) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    return {
      'filename': fileName,
      'mime_type': mimeType,
      'content_base64': base64Encode(bytes),
    };
  }

  Future<void> _sendImageMessage({String type = 'message'}) async {
    final attachment = await _pickAttachmentPayload();
    if (attachment == null) {
      return;
    }

    await _sendMessage(type: type, attachment: attachment);
  }

  @override
  Widget build(BuildContext context) {
    final project = _project ?? widget.project;
    final quote = (project['quote'] as Map?)?.cast<String, dynamic>() ?? {};
    final baseAmount = toNumber(
      project['base_amount'] ?? quote['price_development'],
    );
    final maintenance = toNumber(quote['price_maintenance_monthly']);
    final messages = ((project['messages'] as List?) ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList()
        .reversed
        .toList();
    final latestStatusMessage = messages.lastWhere(
      (item) => item['type'] == 'status_update',
      orElse: () => <String, dynamic>{},
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(project['name']?.toString() ?? 'Projeto'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _load,
              child: const Icon(CupertinoIcons.refresh),
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(left: 10),
              onPressed: widget.controller.logout,
              child: const Icon(CupertinoIcons.square_arrow_right),
            ),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 16))
                : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    cacheExtent: 1200,
                    children: [
                      CardSection(
                        title: 'Resumo',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoLine(
                              'Cliente',
                              project['client']?['name']?.toString() ?? '—',
                            ),
                            _InfoLine(
                              'Tipo',
                              project['type']?.toString() ?? '—',
                            ),
                            _InfoLine(
                              'Estado',
                              projectStatusLabel(project['status']?.toString()),
                              valueColor: projectStatusColor(
                                project['status']?.toString(),
                              ),
                            ),
                            _InfoLine('Desenvolvimento', money(baseAmount)),
                            if (widget.controller.isClientUser) ...[
                              _InfoLine(
                                'Parcelas',
                                money(project['installments_total']),
                              ),
                              if (toNumber(project['adjudication_value']) > 0)
                                _InfoLine(
                                  'Adjudicação',
                                  money(project['adjudication_value']),
                                ),
                              _InfoLine(
                                'Em aberto',
                                money(project['remaining_amount']),
                                valueColor: const Color(0xFFB26A00),
                              ),
                            ],
                          ],
                        ),
                      ),
                      CardSection(
                        title: 'Tracking',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final status in _projectStatuses)
                                  _StatusStepChip(
                                    label: projectStatusLabel(status),
                                    active:
                                        project['status']?.toString() == status,
                                    color: projectStatusColor(status),
                                  ),
                              ],
                            ),
                            if (latestStatusMessage.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                '${latestStatusMessage['body'] ?? ''}\n${formatDateTime(latestStatusMessage['created_at'])}',
                                style: const TextStyle(
                                  color: Color(0xFF1A5A5D),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      CardSection(
                        title: 'Ações',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (quote.isNotEmpty)
                              _IconActionButton(
                                action: _EntityAction(
                                  icon: CupertinoIcons.doc_text,
                                  label: 'PDF',
                                  onTap: () => _openDocument(
                                    context,
                                    widget.controller,
                                    '/documents/quotes/${quote['id']}/pdf',
                                  ),
                                ),
                              ),
                            if (!widget.controller.isClientUser)
                              _IconActionButton(
                                action: _EntityAction(
                                  icon: CupertinoIcons.pencil,
                                  label: 'Editar',
                                  onTap: _openEdit,
                                ),
                              ),
                            if (!widget.controller.isClientUser)
                              _IconActionButton(
                                action: _EntityAction(
                                  icon: CupertinoIcons.delete,
                                  label: 'Eliminar',
                                  color: CupertinoColors.systemRed,
                                  onTap: _deleteProject,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (quote.isNotEmpty)
                        CardSection(
                          title: 'Detalhes',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((quote['technologies']?.toString() ?? '')
                                  .isNotEmpty)
                                _detailTextBlock(
                                  'Tecnologias',
                                  quote['technologies'].toString(),
                                ),
                              if ((quote['description']?.toString() ?? '')
                                  .isNotEmpty)
                                _detailTextBlock(
                                  'Descrição',
                                  _htmlToEditorText(
                                    quote['description']?.toString() ?? '',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if ((quote['development_items'] as List?)?.isNotEmpty ??
                          false)
                        CardSection(
                          title: 'Funcionalidades',
                          child: Column(
                            children: [
                              for (final raw
                                  in (quote['development_items'] as List))
                                Builder(
                                  builder: (context) {
                                    final item = (raw as Map)
                                        .cast<String, dynamic>();
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F7F8),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item['feature']?.toString() ??
                                                  '—',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${toNumber(item['hours'])}h',
                                            style: const TextStyle(
                                              color: Color(0xFF0E4D50),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Total: ${toNumber(quote['development_total_hours'])}h',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (quote.isNotEmpty)
                        CardSection(
                          title: 'Extras',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (quote['include_domain'] == true) ...[
                                _InfoLine(
                                  'Domínio 1º ano',
                                  money(quote['price_domain_first_year']),
                                ),
                                _InfoLine(
                                  'Domínio anos seguintes',
                                  money(quote['price_domain_other_years']),
                                ),
                              ],
                              if (quote['include_hosting'] == true) ...[
                                _InfoLine(
                                  'Alojamento 1º ano',
                                  money(quote['price_hosting_first_year']),
                                ),
                                _InfoLine(
                                  'Alojamento anos seguintes',
                                  money(quote['price_hosting_other_years']),
                                ),
                              ],
                              if (maintenance > 0)
                                _InfoLine(
                                  'Manutenção mensal',
                                  money(maintenance),
                                ),
                            ],
                          ),
                        ),
                      if ((quote['quote_products'] as List?)?.isNotEmpty ??
                          false)
                        CardSection(
                          title: 'Produtos / Packs',
                          child: Column(
                            children: [
                              for (final raw
                                  in (quote['quote_products'] as List))
                                Builder(
                                  builder: (context) {
                                    final item = (raw as Map)
                                        .cast<String, dynamic>();
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F7F8),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name']?.toString() ?? 'Item',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if ((item['short_description']
                                                      ?.toString() ??
                                                  '')
                                              .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                item['short_description']
                                                    .toString(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      if ((quote['terms']?.toString() ?? '').isNotEmpty)
                        CardSection(
                          title: 'Termos',
                          child: Text(
                            _htmlToEditorText(quote['terms'].toString()),
                          ),
                        ),
                      CardSection(
                        title: 'Comunicação',
                        trailing: widget.controller.isClientUser
                            ? CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _sending
                                    ? null
                                    : () => _sendImageMessage(
                                        type: 'proof_submission',
                                      ),
                                child: const Text('Submeter prova'),
                              )
                            : CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _sending
                                    ? null
                                    : () => _sendMessage(
                                        type: 'proof_request',
                                        body:
                                            'Pedido de prova: por favor partilha atualização, captura de ecrã ou vídeo deste ponto do projeto.',
                                      ),
                                child: const Text('Pedir prova'),
                              ),
                        child: Column(
                          children: [
                            if (messages.isEmpty)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Sem mensagens ainda. Usa esta área para alinhar o desenvolvimento.',
                                ),
                              ),
                            if (messages.isNotEmpty)
                              for (final message in messages)
                                _ProjectMessageBubble(message: message),
                            const SizedBox(height: 8),
                            CupertinoTextField(
                              controller: _messageController,
                              minLines: 3,
                              maxLines: 5,
                              placeholder:
                                  'Escreve aqui atualização, pedido ou resposta…',
                              padding: const EdgeInsets.all(14),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    onPressed: _sending
                                        ? null
                                        : () => _sendImageMessage(),
                                    child: const Icon(
                                      CupertinoIcons.photo_on_rectangle,
                                    ),
                                  ),
                                  CupertinoButton(
                                    color: const Color(0xFF0E4D50),
                                    borderRadius: BorderRadius.circular(14),
                                    onPressed: _sending ? null : _sendMessage,
                                    child: _sending
                                        ? const CupertinoActivityIndicator(
                                            color: CupertinoColors.white,
                                          )
                                        : const Text(
                                            'Enviar mensagem',
                                            style: TextStyle(
                                              color: CupertinoColors.white,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class QuoteDetailScreen extends StatelessWidget {
  const QuoteDetailScreen({
    super.key,
    required this.controller,
    required this.quote,
    required this.meta,
  });

  final AppController controller;
  final Map<String, dynamic> quote;
  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final base = toNumber(quote['price_development']);
    final adjudicationPercent = toNumber(quote['adjudication_percent']);
    final adjudicationValue = base * adjudicationPercent / 100;
    final installmentsByProject =
        (meta['installments_by_project'] as Map?) ?? {};
    final installments = toNumber(
      installmentsByProject[quote['project_id']?.toString()] ??
          installmentsByProject[quote['project_id']],
    );
    final remaining = (base - adjudicationValue - installments).clamp(
      0,
      double.infinity,
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(quote['project']?['name']?.toString() ?? 'Orçamento'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _openDocument(
            context,
            controller,
            '/documents/quotes/${quote['id']}/pdf',
          ),
          child: const Icon(CupertinoIcons.doc_text),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                CardSection(
                  title: 'Resumo',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoLine(
                        'Cliente',
                        quote['project']?['client']?['name'] ?? '—',
                      ),
                      _InfoLine('Base', money(base)),
                      _InfoLine('Adjudicação', money(adjudicationValue)),
                      _InfoLine('Parcelas', money(installments)),
                      _InfoLine(
                        'Em aberto',
                        money(remaining),
                        valueColor: const Color(0xFFB26A00),
                      ),
                    ],
                  ),
                ),
                if ((quote['technologies']?.toString() ?? '').isNotEmpty)
                  CardSection(
                    title: 'Tecnologias',
                    child: Text(quote['technologies'].toString()),
                  ),
                if ((quote['description']?.toString() ?? '').isNotEmpty)
                  CardSection(
                    title: 'Descrição',
                    child: Text(
                      _htmlToEditorText(quote['description'].toString()),
                    ),
                  ),
                if ((quote['development_items'] as List?)?.isNotEmpty ?? false)
                  CardSection(
                    title: 'Funcionalidades',
                    child: Column(
                      children: [
                        for (final raw in (quote['development_items'] as List))
                          Builder(
                            builder: (context) {
                              final item = (raw as Map).cast<String, dynamic>();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7F8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['feature']?.toString() ?? '—',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text('${toNumber(item['hours'])}h'),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                if ((quote['terms']?.toString() ?? '').isNotEmpty)
                  CardSection(
                    title: 'Termos',
                    child: Text(_htmlToEditorText(quote['terms'].toString())),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({
    super.key,
    required this.controller,
    this.projectId,
  });

  final AppController controller;
  final int? projectId;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<dynamic> _clients = [];
  List<dynamic> _catalog = [];
  List<dynamic> _statusOptions = [];
  int? _clientId;
  String? _selectedClientLabel;
  String _status = 'planeamento';
  String _type = 'website';
  final _name = TextEditingController();
  final _technologies = TextEditingController();
  final _description = TextEditingController();
  final _descriptionEditor = TextEditingController();
  final _priceDevelopment = TextEditingController(text: '0');
  final _terms = TextEditingController();
  final _termsEditor = TextEditingController();
  final _domainFirst = TextEditingController(text: '0');
  final _domainOther = TextEditingController(text: '0');
  final _hostingFirst = TextEditingController(text: '0');
  final _hostingOther = TextEditingController(text: '0');
  final _maintenance = TextEditingController(text: '0');
  bool _includeDomain = false;
  bool _includeHosting = false;
  bool _maintenanceEnabled = false;
  final Set<int> _selectedCatalog = {};
  List<Map<String, dynamic>> _developmentItems = [
    {'feature': 'Estrutura inicial do projeto (setup + ambiente)', 'hours': 2},
    {'feature': 'Paginas publicas (ate 4)', 'hours': 8},
  ];

  static const Map<String, String> _projectTypes = {
    'website': 'Website',
    'loja_online': 'Loja Online',
    'landing_page': 'Landing Page',
    'plugin': 'Plugin',
    'outro': 'Outro',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await widget.controller.client.get('/projects/options');
      final data = options['data'] as Map<String, dynamic>;
      _clients = data['clients'] as List<dynamic>;
      _catalog = data['catalog'] as List<dynamic>;
      _statusOptions = data['status_options'] as List<dynamic>? ?? [];
      _terms.text = data['default_terms']?.toString() ?? '';
      _termsEditor.text = _htmlToEditorText(_terms.text);
      _clientId = null;
      _selectedClientLabel = null;

      if (widget.projectId != null) {
        final projectResponse = await widget.controller.client.get(
          '/projects/${widget.projectId}?with_options=1',
        );
        final project =
            (projectResponse['data'] as Map)['project'] as Map<String, dynamic>;
        final quote = (project['quote'] as Map?)?.cast<String, dynamic>() ?? {};
        _clientId = project['client_id'] as int?;
        _name.text = project['name']?.toString() ?? '';
        _type = project['type']?.toString() ?? _type;
        _status = project['status']?.toString() ?? _status;
        _technologies.text = quote['technologies']?.toString() ?? '';
        _description.text = quote['description']?.toString() ?? '';
        _descriptionEditor.text = _htmlToEditorText(_description.text);
        _developmentItems = ((quote['development_items'] as List?) ?? [])
            .map(
              (item) => {
                'feature': (item as Map)['feature']?.toString() ?? '',
                'hours': toNumber(item['hours']).toDouble(),
              },
            )
            .toList();
        if (_developmentItems.isEmpty) {
          _developmentItems = [
            {'feature': 'Nova funcionalidade', 'hours': 1.0},
          ];
        }
        _priceDevelopment.text = quote['price_development']?.toString() ?? '0';
        _terms.text = quote['terms']?.toString() ?? _terms.text;
        _termsEditor.text = _htmlToEditorText(_terms.text);
        _includeDomain = quote['include_domain'] == true;
        _includeHosting = quote['include_hosting'] == true;
        _domainFirst.text = quote['price_domain_first_year']?.toString() ?? '0';
        _domainOther.text =
            quote['price_domain_other_years']?.toString() ?? '0';
        _hostingFirst.text =
            quote['price_hosting_first_year']?.toString() ?? '0';
        _hostingOther.text =
            quote['price_hosting_other_years']?.toString() ?? '0';
        _maintenance.text =
            quote['price_maintenance_monthly']?.toString() ?? '0';
        _maintenanceEnabled = toNumber(quote['price_maintenance_monthly']) > 0;
        for (final product in (quote['quote_products'] as List? ?? [])) {
          final productId = product['product_id'];
          if (productId is int) _selectedCatalog.add(productId);
        }
      }

      if (_clientId != null) {
        _selectedClientLabel = _clientLabelById(_clientId!);
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _clientLabelById(int id) {
    final match = _clients.cast<Map>().firstWhere(
      (client) => client['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    final name = match['name']?.toString() ?? 'Cliente';
    final company = match['company']?.toString() ?? '';
    return company.isEmpty ? name : '$name · $company';
  }

  String get _selectedTypeLabel => _projectTypes[_type] ?? _type;

  double get _developmentTotalHours => _developmentItems.fold<double>(
    0,
    (sum, item) => sum + toNumber(item['hours']).toDouble(),
  );

  Future<void> _pickClient() async {
    if (_clients.isEmpty) return;

    String? selected = _clientId?.toString();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar cliente'),
        actions: [
          SizedBox(
            height: 240,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _clients
                    .indexWhere((item) => item['id']?.toString() == selected)
                    .clamp(0, _clients.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _clients[index]['id'].toString();
              },
              children: [
                for (final client in _clients)
                  Center(
                    child: Text(
                      _formatClientLabel(
                        (client as Map).cast<String, dynamic>(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );

    if (confirmed == true && selected != null) {
      setState(() {
        _clientId = int.tryParse(selected!);
        _selectedClientLabel = _clientId == null
            ? null
            : _clientLabelById(_clientId!);
      });
    }
  }

  Future<void> _pickProjectType() async {
    final options = _projectTypes.entries.toList();
    var selected = _type;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Tipo de projeto'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: options
                    .indexWhere((item) => item.key == selected)
                    .clamp(0, options.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = options[index].key;
              },
              children: [
                for (final option in options) Center(child: Text(option.value)),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _type = selected);
    }
  }

  Future<void> _pickStatus() async {
    if (_statusOptions.isEmpty) return;
    var selected = _status;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Estado do projeto'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _statusOptions
                    .indexWhere((item) => item['value']?.toString() == selected)
                    .clamp(0, _statusOptions.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _statusOptions[index]['value'].toString();
              },
              children: [
                for (final item in _statusOptions)
                  Center(child: Text(item['label']?.toString() ?? 'Estado')),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _status = selected);
    }
  }

  void _addDevelopmentItem() {
    setState(() {
      _developmentItems = [
        ..._developmentItems,
        {'feature': '', 'hours': 1.0},
      ];
    });
  }

  void _removeDevelopmentItem(int index) {
    if (_developmentItems.length == 1) return;
    setState(() {
      _developmentItems = [..._developmentItems]..removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final developmentItems = _developmentItems
          .map<Map<String, dynamic>>(
            (item) => {
              'feature': item['feature']?.toString().trim() ?? '',
              'hours': toNumber(item['hours']).toDouble(),
            },
          )
          .where((item) => (item['feature'] as String).isNotEmpty)
          .toList();

      if (_clientId == null) {
        throw const FormatException('Seleciona um cliente.');
      }

      if (developmentItems.isEmpty) {
        throw const FormatException('Adiciona pelo menos uma funcionalidade.');
      }

      _description.text = _editorTextToHtml(_descriptionEditor.text);
      _terms.text = _editorTextToHtml(_termsEditor.text);

      final imports = _catalog
          .where((item) => _selectedCatalog.contains(item['id']))
          .map(
            (item) => {
              'product_id': item['id'],
              'type': item['type'],
              'name': item['name'],
              'slug': item['slug'],
              'short_description': item['short_description'],
              'content_html': item['content_html'],
              'price': item['price'],
              'pack_items': item['pack_items'],
              'info_fields': item['info_fields'],
            },
          )
          .toList();

      final body = {
        'client_id': _clientId,
        'name': _name.text,
        'type': _type,
        'status': _status,
        'technologies': _technologies.text,
        'description': _description.text,
        'development_items': developmentItems,
        'development_total_hours': _developmentTotalHours,
        'price_development': _priceDevelopment.text,
        'price_maintenance_monthly': _maintenanceEnabled
            ? _maintenance.text
            : null,
        'include_domain': _includeDomain,
        'include_hosting': _includeHosting,
        'price_domain_first_year': _domainFirst.text,
        'price_domain_other_years': _domainOther.text,
        'price_hosting_first_year': _hostingFirst.text,
        'price_hosting_other_years': _hostingOther.text,
        'terms': _terms.text,
        'imports': imports,
      };

      if (widget.projectId == null) {
        await widget.controller.client.post('/projects', body: body);
      } else {
        await widget.controller.client.put(
          '/projects/${widget.projectId}',
          body: body,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FormatException catch (error) {
      await showMessage(
        context,
        title: 'Dados inválidos',
        message: error.message,
      );
    } on ApiException catch (error) {
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SplashScreen();
    }
    if (_error != null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Projeto')),
        child: SafeArea(
          child: ErrorState(message: _error!, onRetry: _load),
        ),
      );
    }

    return _FormPage(
      title: widget.projectId == null ? 'Novo projeto' : 'Editar projeto',
      saving: _saving,
      onSave: _save,
      children: [
        _selectorField(
          label: 'Cliente',
          value: _selectedClientLabel ?? 'Selecionar cliente',
          onTap: _pickClient,
        ),
        const SizedBox(height: 12),
        _field('Nome', _name),
        _selectorField(
          label: 'Tipo',
          value: _selectedTypeLabel,
          onTap: _pickProjectType,
        ),
        if (widget.projectId != null) ...[
          const SizedBox(height: 12),
          _selectorField(
            label: 'Estado',
            value:
                _statusOptions
                    .cast<Map>()
                    .firstWhere(
                      (item) => item['value']?.toString() == _status,
                      orElse: () => <String, dynamic>{},
                    )['label']
                    ?.toString() ??
                _status,
            onTap: _pickStatus,
          ),
        ],
        _field('Tecnologias', _technologies),
        _richTextField('Descrição', _descriptionEditor),
        _developmentItemsField(
          items: _developmentItems,
          totalHours: _developmentTotalHours,
          onChanged: (items) => setState(() => _developmentItems = items),
          onAdd: _addDevelopmentItem,
          onRemove: _removeDevelopmentItem,
        ),
        _field('Preço desenvolvimento', _priceDevelopment),
        _richTextField('Termos', _termsEditor),
        Row(
          children: [
            const Expanded(child: Text('Incluir domínio')),
            CupertinoSwitch(
              value: _includeDomain,
              onChanged: (value) => setState(() => _includeDomain = value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Text('Incluir alojamento')),
            CupertinoSwitch(
              value: _includeHosting,
              onChanged: (value) => setState(() => _includeHosting = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_includeDomain) ...[
          _field('Domínio 1º ano', _domainFirst),
          _field('Domínio anos seguintes', _domainOther),
        ],
        if (_includeHosting) ...[
          _field('Alojamento 1º ano', _hostingFirst),
          _field('Alojamento anos seguintes', _hostingOther),
        ],
        Row(
          children: [
            const Expanded(child: Text('Incluir manutenção mensal')),
            CupertinoSwitch(
              value: _maintenanceEnabled,
              onChanged: (value) => setState(() => _maintenanceEnabled = value),
            ),
          ],
        ),
        if (_maintenanceEnabled) ...[
          const SizedBox(height: 12),
          _field('Manutenção mensal', _maintenance),
        ],
        const SizedBox(height: 8),
        const Text(
          'Produtos / Packs incluídos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final item in _catalog)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedCatalog.contains(item['id'])
                    ? const Color(0xFF0E4D50)
                    : const Color(0x33FFFFFF),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ((item['short_description']?.toString() ?? '')
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            item['short_description'].toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: _selectedCatalog.contains(item['id']),
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _selectedCatalog.add(item['id'] as int);
                      } else {
                        _selectedCatalog.remove(item['id'] as int);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class MoreModulesScreen extends StatelessWidget {
  const MoreModulesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final modules = controller.isClientUser
        ? [
            (
              'Carteira',
              CupertinoIcons.creditcard,
              ClientWalletScreen(controller: controller),
            ),
            (
              'Segurança',
              CupertinoIcons.lock_shield,
              SecurityScreen(controller: controller),
            ),
            (
              'Documentos',
              CupertinoIcons.doc_plaintext,
              InvoicesScreen(controller: controller),
            ),
          ]
        : [
            (
              'Orçamentos',
              CupertinoIcons.doc_text_search,
              QuotesScreen(controller: controller),
            ),
            (
              'Produtos / Packs',
              CupertinoIcons.cube_box,
              ProductsScreen(controller: controller),
            ),
            (
              'Documentos',
              CupertinoIcons.doc_plaintext,
              InvoicesScreen(controller: controller),
            ),
            (
              'Financeiro',
              CupertinoIcons.money_euro_circle,
              FinanceScreen(controller: controller),
            ),
            (
              'Terminal',
              CupertinoIcons.creditcard_fill,
              TapToPayScreen(controller: controller),
            ),
            (
              'Intervenções',
              CupertinoIcons.timer,
              InterventionsScreen(controller: controller),
            ),
            (
              'Carteiras',
              CupertinoIcons.creditcard,
              WalletsScreen(controller: controller),
            ),
            (
              'Empresa',
              CupertinoIcons.building_2_fill,
              CompanyScreen(controller: controller),
            ),
            (
              'Definições',
              CupertinoIcons.gear,
              SettingsScreen(controller: controller),
            ),
            (
              'Segurança',
              CupertinoIcons.lock_shield,
              SecurityScreen(controller: controller),
            ),
          ];

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Módulos'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: controller.logout,
          child: const Icon(CupertinoIcons.square_arrow_right),
        ),
      ),
      child: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(
                  context,
                ).push(CupertinoPageRoute(builder: (_) => module.$3));
              },
              child: GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        module.$2,
                        color: const Color(0xFF0E4D50),
                        size: 28,
                      ),
                    ),
                    Text(
                      module.$1,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0E3F42),
                      ),
                    ),
                    Row(
                      children: const [
                        Text(
                          'Abrir',
                          style: TextStyle(
                            color: Color(0xFF1A5A5D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.arrow_right_circle_fill,
                          size: 18,
                          color: Color(0xFF0E4D50),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final canUse = await widget.controller.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _canUseBiometrics = canUse;
      _loading = false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (_saving) return;

    if (!widget.controller.hasCachedCredentials) {
      await showMessage(
        context,
        title: 'Sem login rápido',
        message:
            'Entra pelo menos uma vez com email e password neste dispositivo antes de ativar a biometria.',
      );
      return;
    }

    if (value) {
      final authenticated = await widget.controller
          .authenticateWithBiometrics();
      if (!authenticated) {
        if (!mounted) return;
        await showMessage(
          context,
          title: 'Biometria',
          message: 'A ativação biométrica foi cancelada ou falhou.',
        );
        return;
      }
    }

    setState(() => _saving = true);
    await widget.controller.setBiometricEnabled(value);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Segurança'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 16))
                : ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(16),
                    children: [
                      CardSection(
                        title: 'Login biométrico',
                        child: !_canUseBiometrics
                            ? const Text(
                                'Este dispositivo não tem biometria disponível para a app.',
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.controller.biometricEnabled
                                        ? 'Impressão digital / Face ID ativa.'
                                        : 'Impressão digital / Face ID inativa.',
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Usar biometria para entrar mais rápido',
                                        ),
                                      ),
                                      CupertinoSwitch(
                                        value:
                                            widget.controller.biometricEnabled,
                                        onChanged: _saving
                                            ? null
                                            : _toggleBiometrics,
                                      ),
                                    ],
                                  ),
                                  if (_saving) ...[
                                    const SizedBox(height: 12),
                                    const CupertinoActivityIndicator(),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class TapToPayScreen extends StatefulWidget {
  const TapToPayScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<TapToPayScreen> createState() => _TapToPayScreenState();
}

class _TapToPayScreenState extends State<TapToPayScreen> {
  late final StripeTerminalService _terminalService;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController(
    text: 'Pagamento presencial WireDevelop',
  );
  Map<String, dynamic>? _lastPayment;

  @override
  void initState() {
    super.initState();
    _terminalService = StripeTerminalService(controller: widget.controller)
      ..addListener(_onTerminalChanged);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _terminalService.removeListener(_onTerminalChanged);
    _terminalService.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap({bool requestPermissions = false}) async {
    try {
      await _terminalService.initialize(requestPermissions: requestPermissions);
    } catch (_) {}
  }

  void _onTerminalChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int get _baseAmountCents {
    final raw = _amountController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final value = num.tryParse(raw) ?? 0;
    return (value * 100).round();
  }

  int get _grossAmountCents =>
      _terminalService.calculateGrossCents(_baseAmountCents);

  int get _surchargeAmountCents =>
      _terminalService.calculateSurchargeCents(_baseAmountCents);

  Future<void> _connect() async {
    try {
      await _terminalService.connectLocalReader();
    } catch (error) {
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Tap to Pay',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _charge() async {
    if (_baseAmountCents <= 0) {
      await showMessage(
        context,
        title: 'Valor inválido',
        message: 'Indica o valor base que queres receber.',
      );
      return;
    }

    try {
      final result = await _terminalService.processPayment(
        _baseAmountCents,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      if (!mounted) return;
      setState(
        () =>
            _lastPayment = (result['payment'] as Map?)?.cast<String, dynamic>(),
      );
      await showMessage(
        context,
        title: 'Pagamento concluído',
        message: 'O pagamento presencial foi confirmado com sucesso.',
      );
    } catch (error) {
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Erro no terminal',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _terminalService.statusMessage ?? 'Sem estado.';
    final baseAmount = _baseAmountCents / 100;
    final surchargeAmount = _surchargeAmountCents / 100;
    final grossAmount = _grossAmountCents / 100;
    final diagnostics = _terminalService.deviceDiagnostics;
    final isAndroid = Platform.isAndroid;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Terminal'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _bootstrap(requestPermissions: true),
              child: const Icon(CupertinoIcons.refresh),
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(left: 10),
              onPressed: widget.controller.logout,
              child: const Icon(CupertinoIcons.square_arrow_right),
            ),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                CardSection(
                  title: 'Estado do terminal',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status),
                      const SizedBox(height: 8),
                      Text(
                        _terminalService.supportKnown
                            ? (_terminalService.supported
                                  ? (_terminalService.isConnected
                                        ? 'Ligado ao leitor local.'
                                        : 'Tap to Pay disponível neste dispositivo.')
                                  : 'Tap to Pay indisponível neste momento.')
                            : 'Compatibilidade Tap to Pay ainda por verificar.',
                      ),
                      if (_terminalService.lastTerminalErrorCode != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Último erro Stripe: ${_terminalService.lastTerminalErrorCode?.name}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                      if (_terminalService.lastTerminalErrorMessage != null &&
                          _terminalService
                              .lastTerminalErrorMessage!
                              .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_terminalService.lastTerminalErrorMessage!),
                      ],
                      if (_terminalService.reader != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Leitor: ${_terminalService.reader?.label ?? _terminalService.reader?.deviceType?.name ?? 'Tap to Pay'}',
                        ),
                      ],
                    ],
                  ),
                ),
                CardSection(
                  title: 'Diagnóstico local',
                  child: diagnostics == null
                      ? Text(
                          isAndroid
                              ? 'A recolher diagnóstico do Android...'
                              : 'O diagnóstico detalhado deste ecrã só está disponível no Android.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoLine(
                              'Dispositivo',
                              '${diagnostics['manufacturer'] ?? '—'} ${diagnostics['model'] ?? ''}'
                                  .trim(),
                            ),
                            _InfoLine(
                              'Android',
                              '${diagnostics['androidRelease'] ?? '—'} (SDK ${diagnostics['sdkInt'] ?? '—'})',
                            ),
                            _InfoLine(
                              'App debug',
                              _boolLabel(
                                diagnostics['isDebuggableApp'] == true,
                              ),
                            ),
                            _InfoLine(
                              'Opções programador',
                              _boolLabel(
                                diagnostics['developerOptionsEnabled'] == true,
                              ),
                            ),
                            _InfoLine(
                              'ADB ativo',
                              _boolLabel(diagnostics['adbEnabled'] == true),
                            ),
                            _InfoLine(
                              'NFC presente',
                              _boolLabel(diagnostics['hasNfc'] == true),
                            ),
                            _InfoLine(
                              'NFC ativo',
                              _boolLabel(diagnostics['nfcEnabled'] == true),
                            ),
                            _InfoLine(
                              'Bluetooth LE',
                              _boolLabel(diagnostics['hasBluetoothLe'] == true),
                            ),
                            _InfoLine(
                              'Google Play Services',
                              _boolLabel(
                                diagnostics['hasGooglePlayServices'] == true,
                              ),
                            ),
                            _InfoLine(
                              'Play Store',
                              _boolLabel(
                                diagnostics['hasGooglePlayStore'] == true,
                              ),
                            ),
                            _InfoLine(
                              'Hardware keystore',
                              _boolLabel(
                                diagnostics['hasHardwareKeystore'] == true &&
                                    diagnostics['hardwareKeystoreVersion100'] ==
                                        true,
                              ),
                            ),
                            if ((diagnostics['securityPatch']?.toString() ?? '')
                                .isNotEmpty)
                              _InfoLine(
                                'Patch segurança',
                                diagnostics['securityPatch'].toString(),
                              ),
                          ],
                        ),
                ),
                CardSection(
                  title: 'Logs do terminal',
                  child: _terminalService.logs.isEmpty
                      ? const Text('Sem logs ainda.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _terminalService.logs
                              .take(12)
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    entry,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF163F41),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                CardSection(
                  title: 'Cobrança presencial',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(
                        'Valor base a receber (€)',
                        _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      _field(
                        'Descrição',
                        _descriptionController,
                        maxLength: 255,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _FinanceStatTile(
                            label: 'Base',
                            value: money(baseAmount),
                          ),
                          _FinanceStatTile(
                            label: 'Sobretaxa',
                            value: money(surchargeAmount),
                          ),
                          _FinanceStatTile(
                            label: 'Cobrar',
                            value: money(grossAmount),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sobretaxa configurada: ${_terminalService.surchargePercent.toStringAsFixed(2)}% + ${money(_terminalService.surchargeFixed)}.',
                        style: const TextStyle(
                          color: Color(0xFF163F41),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              color: const Color(0xFF0E4D50),
                              borderRadius: BorderRadius.circular(14),
                              onPressed:
                                  _terminalService.initializing ||
                                      _terminalService.discovering ||
                                      _terminalService.connecting
                                  ? null
                                  : _connect,
                              child:
                                  _terminalService.initializing ||
                                      _terminalService.discovering ||
                                      _terminalService.connecting
                                  ? const CupertinoActivityIndicator(
                                      color: CupertinoColors.white,
                                    )
                                  : Text(
                                      _terminalService.isConnected
                                          ? 'Religar terminal'
                                          : 'Ligar terminal',
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CupertinoButton(
                              color: CupertinoColors.white.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              onPressed: _terminalService.isConnected
                                  ? _terminalService.disconnect
                                  : null,
                              child: const Text(
                                'Desligar',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CupertinoButton(
                        color: const Color(0xFF163F41),
                        borderRadius: BorderRadius.circular(14),
                        onPressed:
                            _terminalService.processing ||
                                !_terminalService.supported
                            ? null
                            : _charge,
                        child: _terminalService.processing
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : const Text(
                                'Cobrar com Tap to Pay',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                if (_lastPayment != null)
                  CardSection(
                    title: 'Último pagamento',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoLine(
                          'ID interno',
                          _lastPayment?['id']?.toString() ?? '—',
                        ),
                        _InfoLine(
                          'PaymentIntent',
                          _lastPayment?['payment_intent_id']?.toString() ?? '—',
                        ),
                        _InfoLine(
                          'Estado',
                          _lastPayment?['status']?.toString() ?? '—',
                        ),
                        _InfoLine(
                          'Cobrado',
                          money(_lastPayment?['gross_amount']),
                        ),
                        _InfoLine('Taxa', money(_lastPayment?['fee_amount'])),
                        _InfoLine(
                          'Líquido',
                          money(_lastPayment?['net_amount']),
                        ),
                        _InfoLine(
                          'Cartão',
                          '${_lastPayment?['card_brand'] ?? '—'} · ${_lastPayment?['card_last4'] ?? '—'}',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _boolLabel(bool value) => value ? 'Sim' : 'Não';
}

Uri _apiUri(
  AppController controller,
  String path, {
  Map<String, String>? queryParameters,
}) {
  final baseUri = Uri.parse(controller.baseUrl);
  final basePath = baseUri.path.endsWith('/')
      ? baseUri.path.substring(0, baseUri.path.length - 1)
      : baseUri.path;
  final suffixPath = path.startsWith('/') ? path : '/$path';
  return baseUri.replace(
    path: '$basePath$suffixPath',
    queryParameters: queryParameters,
  );
}

Future<void> _openDocument(
  BuildContext context,
  AppController controller,
  String path,
) async {
  final token = controller.token;
  if (token == null || token.isEmpty) {
    await showMessage(
      context,
      title: 'Sessão expirada',
      message: 'Volta a entrar para abrir o documento.',
    );
    return;
  }

  final uri = _apiUri(
    controller,
    path,
    queryParameters: {'access_token': token},
  );

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    await showMessage(
      context,
      title: 'Não foi possível abrir',
      message: 'Não foi possível abrir o documento PDF.',
    );
  }
}

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _quotes = [];
  Map<String, dynamic> _meta = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.controller.client.get('/quotes?per_page=50');
      setState(() {
        _quotes = result['data'] as List<dynamic>? ?? [];
        _meta = (result['meta'] as Map?)?.cast<String, dynamic>() ?? {};
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> quote, Map meta) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => QuoteDetailScreen(
          controller: widget.controller,
          quote: quote,
          meta: meta.cast<String, dynamic>(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Orçamentos'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: CupertinoColors.white,
                    ),
                  )
                : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _quotes.isEmpty
                ? const EmptyState('Sem orçamentos ativos.')
                : ListView.builder(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    cacheExtent: 900,
                    itemCount: _quotes.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _QuotesSummary(meta: _meta);
                      }

                      final quote = (_quotes[index - 1] as Map)
                          .cast<String, dynamic>();
                      final base = toNumber(quote['price_development']);
                      final adjudicationPercent = toNumber(
                        quote['adjudication_percent'],
                      );
                      final adjudicationValue =
                          base * adjudicationPercent / 100;
                      final projectId = quote['project_id'];
                      final installmentsByProject =
                          (_meta['installments_by_project'] as Map?) ?? {};
                      final installments = toNumber(
                        installmentsByProject[projectId?.toString()] ??
                            installmentsByProject[projectId],
                      );
                      final remaining =
                          (base - adjudicationValue - installments).clamp(
                            0,
                            double.infinity,
                          );

                      return _EntityListCard(
                        title:
                            quote['project']?['name']?.toString() ?? 'Projeto',
                        subtitle:
                            quote['project']?['client']?['name']?.toString() ??
                            'Sem cliente',
                        metaLines: [
                          'Base: ${money(base)}',
                          'Em aberto: ${money(remaining)}',
                        ],
                        onTap: () => _openDetails(quote, _meta),
                        footer: _DetailLinkButton(
                          label: 'Ver orçamento',
                          onTap: () => _openDetails(quote, _meta),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get('/products');
      setState(() {
        _products =
            ((result['data'] as Map?)?['products'] as List<dynamic>? ?? []);
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Produtos / Packs'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _products.isEmpty
            ? const EmptyState('Sem produtos disponíveis.')
            : ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = (_products[index] as Map)
                      .cast<String, dynamic>();
                  return CardSection(
                    title: product['name']?.toString() ?? 'Produto',
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${product['type'] ?? '—'} · ${money(product['price'])}',
                          ),
                        ),
                        _DocActionButton(
                          icon: CupertinoIcons.doc_text,
                          label: 'PDF',
                          onPressed: () => _openDocument(
                            context,
                            widget.controller,
                            '/documents/products/${product['id']}/pdf',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    required this.controller,
    this.initialStatusFilter,
  });

  final AppController controller;
  final String? initialStatusFilter;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _invoices = [];
  DateTime? _issuedFrom;
  DateTime? _issuedTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String>[
        'per_page=50',
        if ((widget.initialStatusFilter ?? '').trim().isNotEmpty)
          'status=${Uri.encodeQueryComponent(widget.initialStatusFilter!.trim())}',
        if (_issuedFrom != null)
          'issued_from=${Uri.encodeQueryComponent(_dateParam(_issuedFrom!))}',
        if (_issuedTo != null)
          'issued_to=${Uri.encodeQueryComponent(_dateParam(_issuedTo!))}',
      ].join('&');
      final result = await widget.controller.client.get('/invoices?$query');
      setState(() => _invoices = result['data'] as List<dynamic>? ?? []);
      unawaited(widget.controller.refreshWidgetData());
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateParam(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  Future<DateTime?> _pickDate({
    required String title,
    DateTime? initialDate,
  }) async {
    var selected = initialDate ?? DateTime.now();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selected,
                maximumDate: DateTime.now().add(const Duration(days: 365)),
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    );

    return confirmed == true ? selected : null;
  }

  Future<void> _pickSingleDate() async {
    final selected = await _pickDate(
      title: 'Filtrar por data',
      initialDate: _issuedFrom ?? _issuedTo,
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _issuedFrom = selected;
      _issuedTo = selected;
    });
    await _load();
  }

  Future<void> _pickDateRange() async {
    final from = await _pickDate(
      title: 'Data inicial',
      initialDate: _issuedFrom,
    );
    if (from == null) {
      return;
    }

    final to = await _pickDate(
      title: 'Data final',
      initialDate: _issuedTo ?? from,
    );
    if (to == null) {
      return;
    }

    final start = from.isBefore(to) ? from : to;
    final end = from.isBefore(to) ? to : from;
    setState(() {
      _issuedFrom = start;
      _issuedTo = end;
    });
    await _load();
  }

  Future<void> _clearDateFilters() async {
    setState(() {
      _issuedFrom = null;
      _issuedTo = null;
    });
    await _load();
  }

  Future<void> _openDetails(Map<String, dynamic> invoice) async {
    final id = invoice['id'];
    if (id == null) {
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => InvoiceDetailScreen(
          controller: widget.controller,
          invoiceId: id.toString(),
          initialInvoice: invoice,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Documentos'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: _invoices.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return CardSection(
                      title: 'Filtros',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _issuedFrom == null && _issuedTo == null
                                ? 'Sem filtro de data.'
                                : _issuedFrom != null &&
                                      _issuedTo != null &&
                                      _dateParam(_issuedFrom!) ==
                                          _dateParam(_issuedTo!)
                                ? 'Data: ${formatDate(_issuedFrom)}'
                                : 'De ${formatDate(_issuedFrom)} até ${formatDate(_issuedTo)}',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DocActionButton(
                                icon: CupertinoIcons.calendar,
                                label: 'Data única',
                                onPressed: _pickSingleDate,
                              ),
                              _DocActionButton(
                                icon: CupertinoIcons.calendar_badge_plus,
                                label: 'Intervalo',
                                onPressed: _pickDateRange,
                              ),
                              _DocActionButton(
                                icon: CupertinoIcons.clear,
                                label: 'Limpar',
                                onPressed: _clearDateFilters,
                              ),
                            ],
                          ),
                          if (_invoices.isEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Sem documentos disponíveis para o filtro atual.',
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  final invoice = (_invoices[index - 1] as Map)
                      .cast<String, dynamic>();
                  final status = invoice['status']?.toString() ?? '—';
                  return _EntityListCard(
                    title: invoice['number']?.toString() ?? 'Documento',
                    subtitle:
                        '${invoice['client']?['name'] ?? '—'} · ${money(invoice['total'])}',
                    metaLines: [
                      'Estado: $status',
                      'Emissão: ${formatDate(invoice['issued_at'])}',
                    ],
                    onTap: () => _openDetails(invoice),
                    footer: _DetailLinkButton(
                      label: 'Ver detalhe',
                      onTap: () => _openDetails(invoice),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.controller,
    required this.invoiceId,
    this.initialInvoice,
  });

  final AppController controller;
  final String invoiceId;
  final Map<String, dynamic>? initialInvoice;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  Map<String, dynamic>? _invoice;
  final Set<int> _expandedInvoiceItemIds = <int>{};

  @override
  void initState() {
    super.initState();
    _invoice = widget.initialInvoice;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get(
        '/invoices/${widget.invoiceId}',
      );
      final data = ((result['data'] as Map?)?['invoice'] as Map?)
          ?.cast<String, dynamic>();
      if (data != null) {
        setState(() => _invoice = data);
      }
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _canManageInvoice => !widget.controller.isClientUser;

  Future<void> _markPaid() async {
    if (_actionLoading) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      final result = await widget.controller.client.post(
        '/invoices/${widget.invoiceId}/paid',
      );
      final invoice = ((result['data'] as Map?)?['invoice'] as Map?)
          ?.cast<String, dynamic>();
      if (invoice != null) {
        setState(() => _invoice = {...?_invoice, ...invoice});
      }
      await _load();
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Documento pago',
        message: 'A fatura foi marcada como paga.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _markPending() async {
    if (_actionLoading) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      final result = await widget.controller.client.post(
        '/invoices/${widget.invoiceId}/pending',
      );
      final invoice = ((result['data'] as Map?)?['invoice'] as Map?)
          ?.cast<String, dynamic>();
      if (invoice != null) {
        setState(() => _invoice = {...?_invoice, ...invoice});
      }
      await _load();
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Documento pendente',
        message: 'A fatura foi marcada como pendente.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _uninvoice() async {
    if (_actionLoading) {
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Desfaturar'),
        content: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Esta ação remove o documento. Queres continuar?'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desfaturar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await widget.controller.client.post(
        '/invoices/${widget.invoiceId}/uninvoice',
      );
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Documento removido',
        message: 'A fatura foi removida com sucesso.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  void _toggleInvoiceItem(Map<String, dynamic> item) {
    final id = item['id'] as int?;
    if (id == null) {
      return;
    }

    setState(() {
      if (_expandedInvoiceItemIds.contains(id)) {
        _expandedInvoiceItemIds.remove(id);
      } else {
        _expandedInvoiceItemIds.add(id);
      }
    });
  }

  String _detailValue(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _invoiceItemPackSummary(Map<String, dynamic> item) {
    final packItem = (item['source_transaction']?['pack_item'] as Map?)
        ?.cast<String, dynamic>();
    if (packItem == null) {
      return '—';
    }

    final parts = <String>[
      if (packItem['hours'] != null) '${packItem['hours']}h',
      if (packItem['pack_price'] != null) money(packItem['pack_price']),
      if (packItem['validity_months'] != null)
        '${packItem['validity_months']} meses',
    ];

    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String _invoiceItemSourceLabel(Map<String, dynamic> item) {
    switch (item['source_type']?.toString()) {
      case 'transaction':
        return 'Transação de carteira';
      case 'project':
        return 'Projeto';
      default:
        return 'Linha manual';
    }
  }

  Widget _invoiceItemDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF0C3E42).withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A5A5D)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    final title = invoice?['number']?.toString() ?? 'Documento';
    final items = (invoice?['items'] as List?)?.cast<dynamic>() ?? const [];
    final isPaid = invoice?['status']?.toString() == 'pago';
    final isClientUser = widget.controller.isClientUser;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: _loading && invoice == null
                ? const Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: CupertinoColors.white,
                    ),
                  )
                : _error != null && invoice == null
                ? ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(bottom: 18),
                    children: [
                      CardSection(
                        title: title,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _reviewLine(
                              'Cliente',
                              invoice?['client']?['name']?.toString() ?? '—',
                            ),
                            _reviewLine(
                              'Projeto',
                              invoice?['project']?['name']?.toString() ?? '—',
                            ),
                            _reviewLine(
                              'Estado',
                              invoice?['status']?.toString() ?? '—',
                            ),
                            _reviewLine(
                              'Emissão',
                              formatDate(invoice?['issued_at']),
                            ),
                            _reviewLine(
                              'Vencimento',
                              formatDate(invoice?['due_at']),
                            ),
                            _reviewLine(
                              'Pago em',
                              formatDate(invoice?['paid_at']),
                            ),
                            _reviewLine('Total', money(invoice?['total'])),
                            _reviewLine(
                              'Método',
                              invoice?['payment_method']?.toString() ?? '—',
                            ),
                            _reviewLine(
                              'Conta',
                              invoice?['payment_account']?.toString() ?? '—',
                            ),
                          ],
                        ),
                      ),
                      if (items.isNotEmpty)
                        CardSection(
                          title: 'Linhas do documento',
                          child: Column(
                            children: [
                              for (final rawItem in items)
                                Builder(
                                  builder: (context) {
                                    final item = (rawItem as Map)
                                        .cast<String, dynamic>();
                                    final itemId = item['id'] as int?;
                                    final isExpanded =
                                        itemId != null &&
                                        _expandedInvoiceItemIds.contains(
                                          itemId,
                                        );
                                    final sourceTransaction =
                                        (item['source_transaction'] as Map?)
                                            ?.cast<String, dynamic>();
                                    final intervention =
                                        (sourceTransaction?['intervention']
                                                as Map?)
                                            ?.cast<String, dynamic>();
                                    final sourceProject =
                                        (item['source_project'] as Map?)
                                            ?.cast<String, dynamic>();
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: CupertinoButton(
                                        padding: const EdgeInsets.all(12),
                                        borderRadius: BorderRadius.circular(14),
                                        color: const Color(0xFFF4F7F8),
                                        onPressed: () =>
                                            _toggleInvoiceItem(item),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item['description']
                                                                ?.toString() ??
                                                            'Linha',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Color(
                                                            0xFF0C3E42,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        isClientUser
                                                            ? 'Total: ${money(item['total'])}'
                                                            : 'Qtd: ${item['quantity'] ?? '—'} · Unitário: ${money(item['unit_price'])} · Total: ${money(item['total'])}',
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF1A5A5D,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Icon(
                                                  isExpanded
                                                      ? CupertinoIcons
                                                            .chevron_up
                                                      : CupertinoIcons
                                                            .chevron_down,
                                                  size: 18,
                                                  color: const Color(
                                                    0xFF0E4D50,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (isExpanded) ...[
                                              const SizedBox(height: 10),
                                              if (!isClientUser) ...[
                                                _invoiceItemDetailRow(
                                                  'Origem',
                                                  _invoiceItemSourceLabel(item),
                                                ),
                                                if (item['source_id'] != null)
                                                  _invoiceItemDetailRow(
                                                    'Ref.',
                                                    '#${item['source_id']}',
                                                  ),
                                                if (sourceProject != null)
                                                  _invoiceItemDetailRow(
                                                    'Projeto',
                                                    '${_detailValue(sourceProject['name'])} · ${_detailValue(sourceProject['status'])}',
                                                  ),
                                                if (sourceTransaction?['product'] !=
                                                    null)
                                                  _invoiceItemDetailRow(
                                                    'Produto',
                                                    _detailValue(
                                                      sourceTransaction?['product']?['name'],
                                                    ),
                                                  ),
                                                if (sourceTransaction?['pack_item'] !=
                                                    null)
                                                  _invoiceItemDetailRow(
                                                    'Pack',
                                                    _invoiceItemPackSummary(
                                                      item,
                                                    ),
                                                  ),
                                                if (sourceTransaction?['description'] !=
                                                        null &&
                                                    sourceTransaction!['description']
                                                            .toString() !=
                                                        item['description']
                                                            ?.toString())
                                                  _invoiceItemDetailRow(
                                                    'Movimento',
                                                    _detailValue(
                                                      sourceTransaction['description'],
                                                    ),
                                                  ),
                                              ],
                                              if (intervention != null) ...[
                                                _invoiceItemDetailRow(
                                                  'Intervenção',
                                                  _detailValue(
                                                    intervention['type'],
                                                  ),
                                                ),
                                                _invoiceItemDetailRow(
                                                  'Tempo',
                                                  signedHours(
                                                    intervention['total_seconds'],
                                                  ),
                                                ),
                                                if (!isClientUser)
                                                  _invoiceItemDetailRow(
                                                    'Valor/h',
                                                    intervention['hourly_rate'] !=
                                                            null
                                                        ? '${money(intervention['hourly_rate'])}/h'
                                                        : '—',
                                                  ),
                                                _invoiceItemDetailRow(
                                                  'Obs. início',
                                                  _detailValue(
                                                    intervention['notes'],
                                                  ),
                                                ),
                                                _invoiceItemDetailRow(
                                                  'Obs. fim',
                                                  _detailValue(
                                                    intervention['finish_notes'],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      CardSection(
                        title: 'Ações',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DocActionButton(
                              icon: CupertinoIcons.doc_text,
                              label: 'PDF',
                              onPressed: () => _openDocument(
                                context,
                                widget.controller,
                                '/documents/invoices/${widget.invoiceId}/pdf',
                              ),
                            ),
                            _DocActionButton(
                              icon: CupertinoIcons.printer,
                              label: 'Imprimir',
                              onPressed: () => _openDocument(
                                context,
                                widget.controller,
                                '/documents/invoices/${widget.invoiceId}/pdf',
                              ),
                            ),
                            if (_canManageInvoice && !isPaid)
                              _DocActionButton(
                                icon: CupertinoIcons.check_mark_circled,
                                label: _actionLoading ? 'A gravar...' : 'Pago',
                                onPressed: _markPaid,
                              ),
                            if (_canManageInvoice && isPaid)
                              _DocActionButton(
                                icon: CupertinoIcons.arrow_uturn_left_circle,
                                label: _actionLoading
                                    ? 'A gravar...'
                                    : 'Pendente',
                                onPressed: _markPending,
                              ),
                            if (_canManageInvoice && !isPaid)
                              _DocActionButton(
                                icon: CupertinoIcons.delete,
                                label: _actionLoading
                                    ? 'A gravar...'
                                    : 'Desfaturar',
                                onPressed: _uninvoice,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _sales = [];
  List<dynamic> _installments = [];
  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = <int>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get(
        '/finance?year=$_selectedYear',
      );
      final payload = (result['data'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        _sales = payload['sales'] as List<dynamic>? ?? [];
        _installments = payload['installments'] as List<dynamic>? ?? [];
        _selectedYear =
            (payload['selected_year'] as num?)?.toInt() ?? _selectedYear;
        _availableYears = ((payload['available_years'] as List?) ?? [])
            .map((item) => (item as num).toInt())
            .toList();
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFinanceYear() async {
    final years = _availableYears.isEmpty
        ? <int>[_selectedYear]
        : _availableYears;
    var selected = _selectedYear;
    final initialIndex = years.indexOf(_selectedYear);
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar ano'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 36,
              scrollController: FixedExtentScrollController(
                initialItem: initialIndex < 0 ? 0 : initialIndex,
              ),
              onSelectedItemChanged: (index) => selected = years[index],
              children: [
                for (final year in years) Center(child: Text(year.toString())),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Aplicar'),
        ),
      ),
    );

    if (confirmed == true && selected != _selectedYear) {
      setState(() => _selectedYear = selected);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _sales.fold<num>(
      0,
      (sum, item) => sum + toNumber((item as Map)['amount']),
    );
    final toInvoice = _sales
        .where(
          (item) =>
              _financeSaleNeedsInvoice((item as Map).cast<String, dynamic>()),
        )
        .fold<num>(0, (sum, item) => sum + toNumber((item as Map)['amount']));
    final paidInvoices = _sales
        .where(
          (item) => _financeSaleIsPaid((item as Map).cast<String, dynamic>()),
        )
        .fold<num>(0, (sum, item) => sum + toNumber((item as Map)['amount']));
    final pendingInvoices = _sales
        .where((item) {
          final sale = (item as Map).cast<String, dynamic>();
          return !_financeSaleIsPaid(sale) && _financeSaleHasDocument(sale);
        })
        .fold<num>(0, (sum, item) => sum + toNumber((item as Map)['amount']));
    final installmentTotal = _installments.fold<num>(
      0,
      (sum, item) => sum + toNumber((item as Map)['amount']),
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Financeiro'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                cacheExtent: 1000,
                children: [
                  CardSection(
                    title: 'Resumo',
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _pickFinanceYear,
                      child: Text(_selectedYear.toString()),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _FinanceStatTile(
                          label: 'Vendas',
                          value: money(totalSales),
                          accent: const Color(0xFF0B3E42),
                          background: const Color(0xFFEAF3F3),
                        ),
                        _FinanceStatTile(
                          label: 'A faturar',
                          value: money(toInvoice),
                          accent: const Color(0xFF1565C0),
                          background: const Color(0xFFEAF2FF),
                        ),
                        _FinanceStatTile(
                          label: 'Pago',
                          value: money(paidInvoices),
                          accent: const Color(0xFF2E7D57),
                          background: const Color(0xFFE9F6EE),
                        ),
                        _FinanceStatTile(
                          label: 'Pendente',
                          value: money(pendingInvoices),
                          accent: const Color(0xFFB26A00),
                          background: const Color(0xFFFFF3DE),
                        ),
                        _FinanceStatTile(
                          label: 'Parcelas',
                          value: money(installmentTotal),
                          accent: const Color(0xFF6A1B9A),
                          background: const Color(0xFFF5EAFE),
                        ),
                      ],
                    ),
                  ),
                  CardSection(
                    title: 'Movimentos recentes',
                    child: _sales.isEmpty
                        ? const EmptyState('Sem movimentos.')
                        : Column(
                            children: [
                              for (final raw in _sales.take(20))
                                _FinanceRow(
                                  item: (raw as Map).cast<String, dynamic>(),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class InterventionsScreen extends StatefulWidget {
  const InterventionsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<InterventionsScreen> createState() => _InterventionsScreenState();
}

class _InterventionsScreenState extends State<InterventionsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _clients = [];
  List<dynamic> _interventions = [];
  List<dynamic> _transactions = [];
  List<dynamic> _packs = [];
  List<dynamic> _types = [];
  Map<String, dynamic>? _wallet;
  String _activeTab = 'pack';
  String? _selectedClientId;
  String _type = 'Manutenção';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();
  String? _packProductId;
  String? _packItemId;
  final TextEditingController _packQuantityController = TextEditingController(
    text: '1',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _hourlyRateController.dispose();
    _packQuantityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final path = _selectedClientId == null
          ? '/interventions?tab=$_activeTab'
          : '/interventions?tab=$_activeTab&client_id=$_selectedClientId';
      final result = await widget.controller.client.get(path);
      final data = (result['data'] as Map).cast<String, dynamic>();
      final clients = data['clients'] as List<dynamic>? ?? [];
      final packs = data['packs'] as List<dynamic>? ?? [];
      final types = data['types'] as List<dynamic>? ?? [];
      final selectedClientId = data['selected_client_id']?.toString();
      final selectedTab = data['selected_tab']?.toString();
      final filteredDefaultTab =
          selectedTab == 'no-pack' || selectedTab == 'pack'
          ? selectedTab!
          : _activeTab;

      setState(() {
        _clients = clients;
        _interventions = data['interventions'] as List<dynamic>? ?? [];
        _transactions = data['transactions'] as List<dynamic>? ?? [];
        _packs = packs;
        _types = types;
        _wallet = (data['wallet'] as Map?)?.cast<String, dynamic>();
        _activeTab = filteredDefaultTab;
        _selectedClientId = selectedClientId;
        if (_type.isEmpty && types.isNotEmpty) {
          _type = types.first.toString();
        }
        if (!_types.map((item) => item.toString()).contains(_type) &&
            types.isNotEmpty) {
          _type = types.first.toString();
        }
        if (_packProductId == null && packs.isNotEmpty) {
          _packProductId = (packs.first as Map)['id'].toString();
        }
        _syncPackItemSelection();
        _syncHourlyRateFromClient();
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    return _clients
        .map((item) => (item as Map).cast<String, dynamic>())
        .where(
          (client) => _activeTab == 'pack'
              ? client['has_active_pack'] == true
              : client['has_active_pack'] != true,
        )
        .toList();
  }

  Map<String, dynamic>? get _selectedClient {
    for (final client in _clients) {
      final map = (client as Map).cast<String, dynamic>();
      if (map['id']?.toString() == _selectedClientId) {
        return map;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _packProducts =>
      _packs.map((item) => (item as Map).cast<String, dynamic>()).toList();

  List<Map<String, dynamic>> get _selectedPackItems {
    final product = _packProducts.firstWhere(
      (item) => item['id']?.toString() == _packProductId,
      orElse: () => <String, dynamic>{},
    );
    return ((product['pack_items'] as List?) ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  void _syncHourlyRateFromClient() {
    if (_activeTab == 'pack') {
      _hourlyRateController.text = '';
      return;
    }

    final rate = _selectedClient?['hourly_rate'];
    _hourlyRateController.text = rate == null ? '' : rate.toString();
  }

  void _syncPackItemSelection() {
    final items = _selectedPackItems;
    if (items.isEmpty) {
      _packItemId = null;
      return;
    }
    final exists = items.any((item) => item['id']?.toString() == _packItemId);
    if (!exists) {
      _packItemId = items.first['id']?.toString();
    }
  }

  Future<void> _selectClient() async {
    final clients = _filteredClients;
    if (clients.isEmpty) {
      await showMessage(
        context,
        title: 'Sem clientes',
        message: 'Não há clientes disponíveis neste modo.',
      );
      return;
    }

    var selected = _selectedClientId ?? clients.first['id'].toString();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar cliente'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 36,
              scrollController: FixedExtentScrollController(
                initialItem: clients
                    .indexWhere(
                      (client) => client['id']?.toString() == selected,
                    )
                    .clamp(0, clients.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = clients[index]['id'].toString();
              },
              children: [
                for (final client in clients)
                  Center(child: Text(client['name']?.toString() ?? 'Cliente')),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _selectedClientId = selected);
      _syncHourlyRateFromClient();
      await _load();
    }
  }

  Future<void> _selectType() async {
    if (_types.isEmpty) return;

    var selected = _type;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Tipo de intervenção'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 36,
              scrollController: FixedExtentScrollController(
                initialItem: _types
                    .map((item) => item.toString())
                    .toList()
                    .indexOf(selected)
                    .clamp(0, _types.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _types[index].toString();
              },
              children: [
                for (final type in _types) Center(child: Text(type.toString())),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _type = selected);
    }
  }

  Future<void> _startIntervention() async {
    if (_selectedClientId == null || _selectedClientId!.isEmpty) {
      await showMessage(
        context,
        title: 'Cliente em falta',
        message: 'Seleciona um cliente antes de iniciar a intervenção.',
      );
      return;
    }

    try {
      await widget.controller.client.post(
        '/interventions',
        body: {
          'client_id': int.parse(_selectedClientId!),
          'type': _type,
          'notes': _notesController.text.trim(),
          'is_pack': _activeTab == 'pack',
          'hourly_rate': _activeTab == 'pack'
              ? null
              : _hourlyRateController.text.trim(),
        },
      );
      _notesController.clear();
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _pauseIntervention(int id) async {
    try {
      await widget.controller.client.post('/interventions/$id/pause');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _resumeIntervention(int id) async {
    try {
      await widget.controller.client.post('/interventions/$id/resume');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _finishIntervention(Map<String, dynamic> item) async {
    final notes = TextEditingController();
    final endedAt = TextEditingController();
    final durationMinutes = TextEditingController();

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Concluir intervenção'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: notes,
              placeholder: 'Notas finais',
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: endedAt,
              placeholder: 'Hora fim YYYY-MM-DD HH:MM',
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: durationMinutes,
              placeholder: 'Duração em minutos',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.controller.client.post(
        '/interventions/${item['id']}/finish',
        body: {
          'finish_notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
          'ended_at': endedAt.text.trim().isEmpty ? null : endedAt.text.trim(),
          'duration_minutes': durationMinutes.text.trim().isEmpty
              ? null
              : int.tryParse(durationMinutes.text.trim()),
        },
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  Future<void> _buyPack() async {
    if (_selectedClientId == null ||
        _selectedClientId!.isEmpty ||
        _packProductId == null ||
        _packItemId == null) {
      return;
    }

    try {
      await widget.controller.client.post(
        '/wallets/packs',
        body: {
          'client_id': int.parse(_selectedClientId!),
          'product_id': int.parse(_packProductId!),
          'pack_item_id': int.parse(_packItemId!),
          'quantity': int.tryParse(_packQuantityController.text.trim()) ?? 1,
        },
      );
      _packQuantityController.text = '1';
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  String get _selectedPackProductLabel {
    final product = _packProducts.firstWhere(
      (item) => item['id']?.toString() == _packProductId,
      orElse: () => <String, dynamic>{},
    );
    return product['name']?.toString() ?? 'Selecionar pack';
  }

  String get _selectedPackItemLabel {
    final item = _selectedPackItems.firstWhere(
      (entry) => entry['id']?.toString() == _packItemId,
      orElse: () => <String, dynamic>{},
    );
    if (item.isEmpty) return 'Selecionar opção';
    return '${item['hours']}h · ${moneyOrDash(item['pack_price'])} · ${item['validity_months']} meses';
  }

  Future<void> _pickPackProduct() async {
    if (_packProducts.isEmpty) return;
    var selected = _packProductId ?? _packProducts.first['id'].toString();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar pack'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _packProducts
                    .indexWhere((item) => item['id']?.toString() == selected)
                    .clamp(0, _packProducts.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _packProducts[index]['id'].toString();
              },
              children: [
                for (final option in _packProducts)
                  Center(child: Text(option['name']?.toString() ?? 'Pack')),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );
    if (confirmed == true) {
      setState(() {
        _packProductId = selected;
        _syncPackItemSelection();
      });
    }
  }

  Future<void> _pickPackItem() async {
    if (_selectedPackItems.isEmpty) return;
    var selected = _packItemId ?? _selectedPackItems.first['id'].toString();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar opção'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _selectedPackItems
                    .indexWhere((item) => item['id']?.toString() == selected)
                    .clamp(0, _selectedPackItems.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _selectedPackItems[index]['id'].toString();
              },
              children: [
                for (final option in _selectedPackItems)
                  Center(
                    child: Text(
                      '${option['hours']}h · ${moneyOrDash(option['pack_price'])}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );
    if (confirmed == true) {
      setState(() => _packItemId = selected);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'running':
        return 'Em curso';
      case 'paused':
        return 'Em pausa';
      default:
        return 'Concluída';
    }
  }

  String _transactionMeta(Map<String, dynamic> item) {
    final parts = <String>[
      signedHours(item['seconds']),
      moneyOrDash(item['amount']),
      formatDate(item['transaction_at']),
    ];

    final invoice = (item['invoice'] as Map?)?.cast<String, dynamic>();
    if (invoice != null && (invoice['number']?.toString() ?? '').isNotEmpty) {
      parts.add(invoice['number'].toString());
    }

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Intervenções'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  CardSection(
                    title: 'Modo',
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: _activeTab,
                      children: const {
                        'pack': Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Com pack'),
                        ),
                        'no-pack': Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Sem pack'),
                        ),
                      },
                      onValueChanged: (value) async {
                        if (value == null) return;
                        setState(() {
                          _activeTab = value;
                          _selectedClientId = null;
                        });
                        _syncHourlyRateFromClient();
                        await _load();
                      },
                    ),
                  ),
                  CardSection(
                    title: 'Nova intervenção',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _selectClient,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _selectedClient == null
                                  ? 'Selecionar cliente'
                                  : 'Cliente: ${_selectedClient?['name'] ?? '—'}'
                                        '${(_selectedClient?['company']?.toString() ?? '').isNotEmpty ? ' · ${_selectedClient?['company']}' : ''}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _selectType,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Tipo: $_type'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _field('Notas', _notesController, maxLines: 3),
                        if (_activeTab == 'no-pack')
                          _field('Valor/hora', _hourlyRateController),
                        CupertinoButton.filled(
                          onPressed: _startIntervention,
                          child: const Text('Iniciar intervenção'),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedClientId != null)
                    CardSection(
                      title: 'Carteira do cliente',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Horas: ${signedHours(_wallet?['balance_seconds'])}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Valor: ${moneyOrDash(_wallet?['balance_amount'])}',
                          ),
                          const SizedBox(height: 10),
                          if (_activeTab == 'pack') ...[
                            _selectorField(
                              label: 'Pack',
                              value: _selectedPackProductLabel,
                              onTap: _pickPackProduct,
                            ),
                            _selectorField(
                              label: 'Opção',
                              value: _selectedPackItemLabel,
                              onTap: _pickPackItem,
                            ),
                            _field('Quantidade', _packQuantityController),
                            if (_selectedPackItems.isNotEmpty &&
                                _packItemId != null) ...[
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final selected = _selectedPackItems
                                      .firstWhere(
                                        (item) =>
                                            item['id']?.toString() ==
                                            _packItemId,
                                        orElse: () => const <String, dynamic>{},
                                      );

                                  if (selected.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F7F8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${selected['hours']}h · ${moneyOrDash(selected['pack_price'])} · ${selected['validity_months']} meses',
                                    ),
                                  );
                                },
                              ),
                            ],
                            CupertinoButton.filled(
                              onPressed: _buyPack,
                              child: const Text('Registar compra de pack'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_selectedClientId != null)
                    CardSection(
                      title: 'Transações da carteira',
                      child: _transactions.isEmpty
                          ? const Text('Sem transações registadas.')
                          : Column(
                              children: [
                                for (final raw in _transactions)
                                  Builder(
                                    builder: (context) {
                                      final item = (raw as Map)
                                          .cast<String, dynamic>();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${walletTransactionTypeLabel(item['type']?.toString() ?? '')} · ${item['description'] ?? 'Transação'}\n${_transactionMeta(item)}',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                    ),
                  CardSection(
                    title: 'Registos recentes',
                    child: _interventions.isEmpty
                        ? const Text('Sem intervenções para mostrar.')
                        : Column(
                            children: [
                              for (final raw in _interventions)
                                Builder(
                                  builder: (context) {
                                    final item = (raw as Map)
                                        .cast<String, dynamic>();
                                    final status =
                                        item['status']?.toString() ?? '';
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F7F8),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item['client']?['name'] ?? '—'} · ${item['type'] ?? 'Intervenção'}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_statusLabel(status)} · Início: ${formatDate(item['started_at'])}',
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Fim: ${formatDate(item['ended_at'])} · Tempo: ${_formatClock(item)}',
                                            ),
                                            if ((item['notes']?.toString() ??
                                                    '')
                                                .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  'Notas: ${item['notes']}',
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 10,
                                              children: [
                                                if (status == 'running')
                                                  CupertinoButton(
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () =>
                                                        _pauseIntervention(
                                                          item['id'] as int,
                                                        ),
                                                    child: const Text('Pausar'),
                                                  ),
                                                if (status == 'paused')
                                                  CupertinoButton(
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () =>
                                                        _resumeIntervention(
                                                          item['id'] as int,
                                                        ),
                                                    child: const Text(
                                                      'Retomar',
                                                    ),
                                                  ),
                                                if (status != 'completed')
                                                  CupertinoButton(
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () =>
                                                        _finishIntervention(
                                                          item,
                                                        ),
                                                    child: const Text(
                                                      'Concluir',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatClock(Map<String, dynamic> item) {
    final totalSeconds = toNumber(item['total_seconds']).toInt();
    final status = item['status']?.toString() ?? '';
    if (status == 'completed') {
      return _clockFromSeconds(totalSeconds);
    }

    final startedAt = DateTime.tryParse(item['started_at']?.toString() ?? '');
    if (startedAt == null) return '00:00:00';
    final pausedAt = DateTime.tryParse(item['paused_at']?.toString() ?? '');
    final pausedSeconds = toNumber(item['total_paused_seconds']).toInt();
    final end = status == 'paused' && pausedAt != null
        ? pausedAt
        : DateTime.now();
    final seconds = end.difference(startedAt).inSeconds - pausedSeconds;
    return _clockFromSeconds(seconds < 0 ? 0 : seconds);
  }

  String _clockFromSeconds(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({
    super.key,
    required this.controller,
    this.initialClientId,
  });

  final AppController controller;
  final String? initialClientId;

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _clients = [];
  Map<String, dynamic>? _selectedClient;
  Map<String, dynamic>? _wallet;
  List<dynamic> _transactions = [];
  List<dynamic> _packs = [];
  String? _selectedClientId;
  String? _packProductId;
  String? _packItemId;
  final TextEditingController _packQuantityController = TextEditingController(
    text: '1',
  );

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.initialClientId?.trim().isEmpty == true
        ? null
        : widget.initialClientId?.trim();
    _load();
  }

  @override
  void dispose() {
    _packQuantityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final path = _selectedClientId == null
          ? '/wallets'
          : '/wallets?client_id=$_selectedClientId';
      final result = await widget.controller.client.get(path);
      final data = (result['data'] as Map).cast<String, dynamic>();
      final clients = data['clients'] as List<dynamic>? ?? [];
      final packs = data['packs'] as List<dynamic>? ?? [];
      final selectedClientId = data['selected_client_id']?.toString();

      setState(() {
        _clients = clients;
        _selectedClient = _selectedClientId == null
            ? null
            : (data['selected_client'] as Map?)?.cast<String, dynamic>();
        _wallet = _selectedClientId == null
            ? null
            : (data['wallet'] as Map?)?.cast<String, dynamic>();
        _transactions = _selectedClientId == null
            ? []
            : data['transactions'] as List<dynamic>? ?? [];
        _packs = packs;
        _selectedClientId = _selectedClientId ?? selectedClientId;
        if (_packProductId == null && packs.isNotEmpty) {
          _packProductId = (packs.first as Map)['id'].toString();
        }
        _syncPackItemSelection();
      });
      unawaited(widget.controller.refreshWidgetData());
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _clientList =>
      _clients.map((item) => (item as Map).cast<String, dynamic>()).toList();

  List<Map<String, dynamic>> get _packProducts =>
      _packs.map((item) => (item as Map).cast<String, dynamic>()).toList();

  List<Map<String, dynamic>> get _selectedPackItems {
    final product = _packProducts.firstWhere(
      (item) => item['id']?.toString() == _packProductId,
      orElse: () => <String, dynamic>{},
    );
    return ((product['pack_items'] as List?) ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  void _syncPackItemSelection() {
    final items = _selectedPackItems;
    if (items.isEmpty) {
      _packItemId = null;
      return;
    }
    final exists = items.any((item) => item['id']?.toString() == _packItemId);
    if (!exists) {
      _packItemId = items.first['id']?.toString();
    }
  }

  Future<void> _selectClient() async {
    if (_clientList.isEmpty) return;
    var selected =
        _selectedClientId ?? _clientList.first['id']?.toString() ?? '';
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar cliente'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _clientList
                    .indexWhere((item) => item['id']?.toString() == selected)
                    .clamp(0, _clientList.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _clientList[index]['id'].toString();
              },
              children: [
                for (final client in _clientList)
                  Center(child: Text(_formatClientLabel(client))),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() {
        _selectedClientId = selected;
        _selectedClient = null;
        _wallet = null;
        _transactions = [];
      });
      await _load();
    }
  }

  String get _selectedPackProductLabel {
    final product = _packProducts.firstWhere(
      (item) => item['id']?.toString() == _packProductId,
      orElse: () => <String, dynamic>{},
    );
    return product['name']?.toString() ?? 'Selecionar pack';
  }

  String get _selectedPackItemLabel {
    final item = _selectedPackItems.firstWhere(
      (entry) => entry['id']?.toString() == _packItemId,
      orElse: () => <String, dynamic>{},
    );
    if (item.isEmpty) return 'Selecionar opção';
    return '${item['hours']}h · ${moneyOrDash(item['pack_price'])} · ${item['validity_months']} meses';
  }

  Future<void> _pickWalletPackProduct() async {
    if (_packProducts.isEmpty) return;
    var selected = _packProductId ?? _packProducts.first['id'].toString();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar pack'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _packProducts
                    .indexWhere((item) => item['id']?.toString() == selected)
                    .clamp(0, _packProducts.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _packProducts[index]['id'].toString();
              },
              children: [
                for (final option in _packProducts)
                  Center(child: Text(option['name']?.toString() ?? 'Pack')),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );
    if (confirmed == true) {
      setState(() {
        _packProductId = selected;
        _syncPackItemSelection();
      });
    }
  }

  Future<void> _pickWalletPackItem() async {
    if (_selectedPackItems.isEmpty) return;
    var selected = _packItemId ?? _selectedPackItems.first['id'].toString();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar opção'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _selectedPackItems
                    .indexWhere((item) => item['id']?.toString() == selected)
                    .clamp(0, _selectedPackItems.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _selectedPackItems[index]['id'].toString();
              },
              children: [
                for (final option in _selectedPackItems)
                  Center(
                    child: Text(
                      '${option['hours']}h · ${moneyOrDash(option['pack_price'])}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );
    if (confirmed == true) {
      setState(() => _packItemId = selected);
    }
  }

  Future<void> _buyPack() async {
    if (_selectedClientId == null ||
        _packProductId == null ||
        _packItemId == null) {
      return;
    }

    try {
      await widget.controller.client.post(
        '/wallets/packs',
        body: {
          'client_id': int.parse(_selectedClientId!),
          'product_id': int.parse(_packProductId!),
          'pack_item_id': int.parse(_packItemId!),
          'quantity': int.tryParse(_packQuantityController.text.trim()) ?? 1,
        },
      );
      _packQuantityController.text = '1';
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
  }

  String _transactionMeta(Map<String, dynamic> item) {
    final parts = <String>[
      signedHours(item['seconds']),
      moneyOrDash(item['amount']),
      formatDate(item['transaction_at']),
    ];

    final invoice = (item['invoice'] as Map?)?.cast<String, dynamic>();
    if (invoice != null && (invoice['number']?.toString() ?? '').isNotEmpty) {
      parts.add(invoice['number'].toString());
    }

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Carteiras'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                cacheExtent: 1100,
                children: [
                  CardSection(
                    title: 'Cliente',
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        onPressed: _selectClient,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _selectedClient == null
                                ? 'Selecionar cliente'
                                : _formatClientLabel(_selectedClient!),
                            style: const TextStyle(
                              color: Color(0xFF0E4D50),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedClientId == null)
                    const CardSection(
                      title: 'Carteira',
                      child: Text(
                        'Seleciona um cliente para ver saldo, packs e transações.',
                      ),
                    ),
                  if (_wallet != null)
                    CardSection(
                      title: 'Saldo',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedClient?['company']?.toString() ??
                                'Carteira selecionada',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Horas: ${signedHours(_wallet?['balance_seconds'])}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Valor: ${moneyOrDash(_wallet?['balance_amount'])}',
                          ),
                        ],
                      ),
                    ),
                  if (_wallet != null)
                    CardSection(
                      title: 'Compra de pack',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _selectorField(
                            label: 'Pack',
                            value: _selectedPackProductLabel,
                            onTap: _pickWalletPackProduct,
                          ),
                          _selectorField(
                            label: 'Opção',
                            value: _selectedPackItemLabel,
                            onTap: _pickWalletPackItem,
                          ),
                          _field('Quantidade', _packQuantityController),
                          if (_selectedPackItems.isNotEmpty &&
                              _packItemId != null) ...[
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final selected = _selectedPackItems.firstWhere(
                                  (item) =>
                                      item['id']?.toString() == _packItemId,
                                  orElse: () => const <String, dynamic>{},
                                );

                                if (selected.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F7F8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${selected['hours']}h · ${moneyOrDash(selected['pack_price'])} · ${selected['validity_months']} meses',
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 8),
                          CupertinoButton(
                            color: const Color(0xFF0E4D50),
                            borderRadius: BorderRadius.circular(14),
                            onPressed: _buyPack,
                            child: const Text(
                              'Registar compra',
                              style: TextStyle(color: CupertinoColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  CardSection(
                    title: 'Transações',
                    child: _transactions.isEmpty
                        ? const Text('Sem transações registadas.')
                        : Column(
                            children: [
                              for (final raw in _transactions)
                                Builder(
                                  builder: (context) {
                                    final item = (raw as Map)
                                        .cast<String, dynamic>();
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${walletTransactionTypeLabel(item['type']?.toString() ?? '')} · ${item['description'] ?? 'Transação'}\n${_transactionMeta(item)}',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ClientWalletScreen extends StatefulWidget {
  const ClientWalletScreen({
    super.key,
    required this.controller,
    this.paymentReturn,
  });

  final AppController controller;
  final WalletCheckoutReturn? paymentReturn;

  @override
  State<ClientWalletScreen> createState() => _ClientWalletScreenState();
}

class _ClientWalletScreenState extends State<ClientWalletScreen> {
  bool _loading = true;
  bool _paymentLoading = false;
  String? _error;
  Map<String, dynamic>? _wallet;
  List<dynamic> _transactions = [];
  List<dynamic> _interventions = [];
  List<dynamic> _packs = [];
  bool _stripeAvailable = false;
  Map<String, dynamic>? _manualPayment;
  String? _packProductId;
  String? _packItemId;
  final TextEditingController _packQuantityController = TextEditingController(
    text: '1',
  );
  bool _handledPaymentReturn = false;

  @override
  void initState() {
    super.initState();
    if (widget.paymentReturn != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_handlePaymentReturn(widget.paymentReturn!));
      });
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _packQuantityController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final result = await widget.controller.client.get('/wallet');
      final data = (result['data'] as Map).cast<String, dynamic>();
      setState(() {
        _wallet = (data['wallet'] as Map?)?.cast<String, dynamic>();
        _transactions = data['transactions'] as List<dynamic>? ?? [];
        _interventions = data['interventions'] as List<dynamic>? ?? [];
        _packs = data['packs'] as List<dynamic>? ?? [];
        _stripeAvailable = data['stripe_available'] == true;
        _manualPayment = (data['manual_payment'] as Map?)
            ?.cast<String, dynamic>();
        if (_packProductId == null && _packs.isNotEmpty) {
          _packProductId = ((_packs.first as Map)['id']).toString();
        }
        _syncPackItemSelection();
      });
      unawaited(widget.controller.refreshWidgetData());
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handlePaymentReturn(WalletCheckoutReturn paymentReturn) async {
    if (_handledPaymentReturn) {
      return;
    }

    _handledPaymentReturn = true;
    String title;
    String message;

    try {
      if (paymentReturn.isSuccess) {
        if ((paymentReturn.sessionId ?? '').isNotEmpty) {
          await widget.controller.client.post(
            '/wallet/checkout/finalize',
            body: {'session_id': paymentReturn.sessionId},
          );
        }
        title = 'Pagamento concluído';
        message = 'O pagamento foi registado e a carteira foi atualizada.';
      } else {
        await widget.controller.client.post(
          '/wallet/checkout/cancel',
          body: {
            if ((paymentReturn.token ?? '').isNotEmpty)
              'cancel_token': paymentReturn.token,
            if ((paymentReturn.sessionId ?? '').isNotEmpty)
              'session_id': paymentReturn.sessionId,
          },
        );
        title = 'Pagamento cancelado';
        message = 'O checkout foi cancelado e a carteira já foi sincronizada.';
      }
    } catch (_) {
      title = paymentReturn.isSuccess
          ? 'Pagamento recebido'
          : 'Pagamento cancelado';
      message = paymentReturn.isSuccess
          ? 'Foi pedido um novo refresh da carteira para confirmar o estado.'
          : 'Foi pedido um novo refresh da carteira para remover a operação pendente.';
    }

    await _load(showLoading: false);
    if (!mounted) {
      return;
    }

    await showMessage(context, title: title, message: message);
  }

  Map<String, dynamic>? get _walletClient =>
      (_wallet?['client'] as Map?)?.cast<String, dynamic>();

  List<Map<String, dynamic>> get _manualPaymentMethods =>
      ((_manualPayment?['methods'] as List?) ?? [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

  bool get _hasManualPaymentInfo {
    final notes = _manualPayment?['notes']?.toString().trim() ?? '';
    return notes.isNotEmpty || _manualPaymentMethods.isNotEmpty;
  }

  String _formatHours(dynamic secondsValue) {
    final seconds = secondsValue is num
        ? secondsValue.toInt()
        : int.tryParse(secondsValue?.toString() ?? '0') ?? 0;
    final sign = seconds < 0 ? '-' : '';
    final abs = seconds.abs();
    final hrs = abs ~/ 3600;
    final mins = (abs % 3600) ~/ 60;
    final secs = abs % 60;
    final base = '$sign${hrs}h ${mins.toString().padLeft(2, '0')}m';
    return secs > 0 ? '$base ${secs.toString().padLeft(2, '0')}s' : base;
  }

  dynamic _transactionDurationSeconds(Map<String, dynamic> item) {
    if (item['seconds'] != null) {
      return item['seconds'];
    }

    final intervention = (item['intervention'] as Map?)
        ?.cast<String, dynamic>();
    if (intervention != null && intervention['total_seconds'] != null) {
      return intervention['total_seconds'];
    }

    return 0;
  }

  List<Map<String, dynamic>> get _packProducts =>
      _packs.map((item) => (item as Map).cast<String, dynamic>()).toList();

  Map<String, dynamic>? get _selectedPackProduct {
    if (_packProductId == null) return null;
    final matches = _packProducts.where(
      (item) => item['id']?.toString() == _packProductId,
    );
    return matches.isEmpty ? null : matches.first;
  }

  List<Map<String, dynamic>> get _selectedPackItems {
    final product = _packProducts.firstWhere(
      (item) => item['id']?.toString() == _packProductId,
      orElse: () => <String, dynamic>{},
    );
    return ((product['pack_items'] as List?) ?? [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  void _syncPackItemSelection() {
    final items = _selectedPackItems;
    if (items.isEmpty) {
      _packItemId = null;
      return;
    }
    final exists = items.any((item) => item['id']?.toString() == _packItemId);
    if (!exists) {
      _packItemId = items.first['id']?.toString();
    }
  }

  String get _selectedPackProductLabel {
    final product = _selectedPackProduct ?? <String, dynamic>{};
    return product['name']?.toString() ?? 'Selecionar pack';
  }

  String get _selectedPackItemLabel {
    final item = _selectedPackItems.firstWhere(
      (entry) => entry['id']?.toString() == _packItemId,
      orElse: () => <String, dynamic>{},
    );
    if (item.isEmpty) return 'Selecionar opção';
    return '${item['hours']}h · ${moneyOrDash(item['pack_price'])} · ${item['validity_months']} meses';
  }

  Future<void> _openSelectedPackDocument() async {
    final product = _selectedPackProduct;
    if (product == null) return;
    await _openDocument(
      context,
      widget.controller,
      '/documents/products/${product['id']}/pdf',
    );
  }

  String _transactionStatusLabel(Map<String, dynamic> item) {
    final payment = (item['payment_metadata'] as Map?)?.cast<String, dynamic>();
    final invoice = (item['invoice'] as Map?)?.cast<String, dynamic>();
    final paymentStatus = payment?['status']?.toString();
    if (paymentStatus == 'paid') return 'Pago';
    if (paymentStatus == 'pending') return 'Pendente';
    if (paymentStatus == 'failed') return 'Falhado';
    if (invoice?['status']?.toString() == 'pago') return 'Pago';
    if (invoice?['status']?.toString() == 'pendente') return 'Pendente';
    return walletTransactionTypeLabel(item['type']?.toString() ?? '');
  }

  String _transactionSecondaryLine(Map<String, dynamic> item) {
    final packItem = (item['pack_item'] as Map?)?.cast<String, dynamic>();
    final quantity =
        int.tryParse(
          ((item['payment_metadata'] as Map?)?['quantity']?.toString() ?? '1'),
        ) ??
        1;
    final duration =
        _pendingHoursLabel(item) ??
        (item['type']?.toString() == 'purchase' && packItem?['hours'] != null
            ? '+${packItem!['hours']}h${quantity > 1 ? ' × $quantity' : ''}'
            : _formatHours(_transactionDurationSeconds(item)));
    return '$duration · ${formatDate(item['transaction_at'])}';
  }

  String? _pendingHoursLabel(Map<String, dynamic> item) {
    final payment = (item['payment_metadata'] as Map?)?.cast<String, dynamic>();
    final packItem = (item['pack_item'] as Map?)?.cast<String, dynamic>();
    if (item['payment_provider']?.toString() != 'stripe' ||
        payment?['status']?.toString() != 'pending' ||
        packItem?['hours'] == null) {
      return null;
    }

    final quantity = int.tryParse(payment?['quantity']?.toString() ?? '1') ?? 1;
    final hours = num.tryParse(packItem!['hours'].toString()) ?? 0;
    final totalHours = hours * max(quantity, 1);
    final hoursLabel = totalHours == totalHours.roundToDouble()
        ? totalHours.toInt().toString()
        : totalHours.toStringAsFixed(2);
    return 'Pendente (+${hoursLabel}h)';
  }

  int get _selectedQuantity =>
      max(1, int.tryParse(_packQuantityController.text.trim()) ?? 1);

  Map<String, dynamic>? get _selectedPackItem {
    if (_packItemId == null) return null;
    final matches = _selectedPackItems.where(
      (entry) => entry['id']?.toString() == _packItemId,
    );
    return matches.isEmpty ? null : matches.first;
  }

  num get _selectedPackTotal {
    final item = _selectedPackItem;
    if (item == null) return 0;
    return toNumber(item['pack_price']) * _selectedQuantity;
  }

  Map<String, dynamic> _checkoutPayload() {
    return {
      'product_id': int.parse(_packProductId!),
      'pack_item_id': int.parse(_packItemId!),
      'quantity': _selectedQuantity,
      'wants_invoice': false,
    };
  }

  Future<void> _openCheckoutReview() async {
    final pack = _selectedPackProduct;
    final option = _selectedPackItem;
    if (pack == null || option == null) return;

    final completed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => ClientCheckoutFlowScreen(
          controller: widget.controller,
          payload: _checkoutPayload(),
          packName: pack['name']?.toString() ?? '—',
          optionLabel:
              '${option['hours']}h · ${moneyOrDash(option['pack_price'])} · ${option['validity_months']} meses',
          quantity: _selectedQuantity,
          unitPrice: money(option['pack_price']),
          totalPrice: money(_selectedPackTotal),
          clientName: _walletClient?['name']?.toString() ?? '—',
          clientEmail: _walletClient?['email']?.toString() ?? '—',
          clientPhone: _walletClient?['phone']?.toString() ?? '—',
        ),
      ),
    );

    if (completed == true && mounted) {
      await _load();
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Pagamento concluído',
        message: 'O pagamento foi registado e a carteira foi atualizada.',
      );
    }
  }

  Future<void> _pickClientPackProduct() async {
    if (_packProducts.isEmpty) return;
    var selected = _packProductId ?? _packProducts.first['id'].toString();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar pack'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _packProducts
                    .indexWhere((item) => item['id']?.toString() == selected)
                    .clamp(0, _packProducts.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _packProducts[index]['id'].toString();
              },
              children: [
                for (final option in _packProducts)
                  Center(child: Text(option['name']?.toString() ?? 'Pack')),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );
    if (confirmed == true) {
      setState(() {
        _packProductId = selected;
        _syncPackItemSelection();
      });
    }
  }

  Future<void> _pickClientPackItem() async {
    if (_selectedPackItems.isEmpty) return;
    var selected = _packItemId ?? _selectedPackItems.first['id'].toString();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Selecionar opção'),
        actions: [
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: _selectedPackItems
                    .indexWhere((item) => item['id']?.toString() == selected)
                    .clamp(0, _selectedPackItems.length - 1),
              ),
              onSelectedItemChanged: (index) {
                selected = _selectedPackItems[index]['id'].toString();
              },
              children: [
                for (final option in _selectedPackItems)
                  Center(
                    child: Text(
                      '${option['hours']}h · ${moneyOrDash(option['pack_price'])}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        message: CupertinoButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Selecionar'),
        ),
      ),
    );
    if (confirmed == true) {
      setState(() => _packItemId = selected);
    }
  }

  Future<void> _openCheckout() async {
    if (_packProductId == null || _packItemId == null || _paymentLoading) {
      return;
    }

    if (!_stripeAvailable) {
      return;
    }

    setState(() => _paymentLoading = true);
    try {
      await _openCheckoutReview();
    } on ApiException catch (error) {
      if (mounted) {
        await showMessage(context, title: 'Erro', message: error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _paymentLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Carteira'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _load,
              child: const Icon(CupertinoIcons.refresh),
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(left: 10),
              onPressed: widget.controller.logout,
              child: const Icon(CupertinoIcons.square_arrow_right),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                cacheExtent: 1100,
                children: [
                  CardSection(
                    title: 'Saldo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_walletClient?['name']?.toString() ?? 'Cliente'),
                        const SizedBox(height: 6),
                        Text(
                          'Tempo em carteira: ${_formatHours(_wallet?['balance_seconds'])}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Valor registado: ${moneyOrDash(_wallet?['balance_amount'])}',
                        ),
                      ],
                    ),
                  ),
                  if (_packs.isNotEmpty)
                    CardSection(
                      title: 'Comprar manutenção',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _selectorField(
                            label: 'Pack',
                            value: _selectedPackProductLabel,
                            onTap: _pickClientPackProduct,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _selectedPackProduct == null
                                  ? null
                                  : _openSelectedPackDocument,
                              child: const Text(
                                'Documento explicativo',
                                style: TextStyle(
                                  color: Color(0xFF0E4D50),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _selectorField(
                            label: 'Opção',
                            value: _selectedPackItemLabel,
                            onTap: _pickClientPackItem,
                          ),
                          _field(
                            'Quantidade',
                            _packQuantityController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_hasManualPaymentInfo) ...[
                            const Text(
                              'Se preferires, também podes optar por pagamento manual falando com a WireDevelop.',
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (!_stripeAvailable) ...[
                            const Text(
                              'O checkout Stripe está indisponível neste servidor neste momento.',
                            ),
                            const SizedBox(height: 10),
                          ],
                          CupertinoButton(
                            color: const Color(0xFF0E4D50),
                            borderRadius: BorderRadius.circular(14),
                            onPressed: _paymentLoading || !_stripeAvailable
                                ? null
                                : _openCheckout,
                            child: _paymentLoading
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                  )
                                : Text(
                                    !_stripeAvailable
                                        ? 'STRIPE INDISPONÍVEL'
                                        : 'AVANÇAR',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  CardSection(
                    title: 'Intervenções',
                    child: _interventions.isEmpty
                        ? const Text('Sem intervenções registadas.')
                        : Column(
                            children: [
                              for (final raw in _interventions)
                                Builder(
                                  builder: (context) {
                                    final item = (raw as Map)
                                        .cast<String, dynamic>();
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${item['type'] ?? 'Intervenção'} · ${item['status'] ?? '—'}\n${_formatHours(item['total_seconds'])} · ${formatDate(item['started_at'])}',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                  ),
                  CardSection(
                    title: 'Compras / Transações',
                    child: _transactions.isEmpty
                        ? const Text('Sem transações registadas.')
                        : Column(
                            children: [
                              for (final raw in _transactions)
                                Builder(
                                  builder: (context) {
                                    final item = (raw as Map)
                                        .cast<String, dynamic>();
                                    final invoice = (item['invoice'] as Map?)
                                        ?.cast<String, dynamic>();
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '#${item['id']} · ${item['description'] ?? 'Transação'} · ${moneyOrDash(item['amount'])}\n${_transactionStatusLabel(item)}${invoice?['number'] != null ? ' · ${invoice!['number']}' : ''}\n${_transactionSecondaryLine(item)}',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ClientCheckoutFlowScreen extends StatefulWidget {
  const ClientCheckoutFlowScreen({
    super.key,
    required this.controller,
    required this.payload,
    required this.packName,
    required this.optionLabel,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
  });

  final AppController controller;
  final Map<String, dynamic> payload;
  final String packName;
  final String optionLabel;
  final int quantity;
  final String unitPrice;
  final String totalPrice;
  final String clientName;
  final String clientEmail;
  final String clientPhone;

  @override
  State<ClientCheckoutFlowScreen> createState() =>
      _ClientCheckoutFlowScreenState();
}

class _ClientCheckoutFlowScreenState extends State<ClientCheckoutFlowScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _paying = false;
  bool _completed = false;
  bool _cancelled = false;
  bool _checkoutOpened = false;
  String? _error;
  Map<String, dynamic>? _checkout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareCheckout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_completed && !_cancelled) {
      unawaited(_cancelCheckout());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _checkoutOpened && !_completed) {
      unawaited(_refreshCheckoutStatus());
    }
  }

  Future<void> _prepareCheckout() async {
    try {
      final result = await widget.controller.client.post(
        '/wallet/checkout',
        body: widget.payload,
      );
      final data = (result['data'] as Map).cast<String, dynamic>();
      setState(() {
        _checkout = data;
      });
    } on ApiException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Não foi possível preparar o pagamento.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String get _checkoutSessionId =>
      _checkout?['checkout_session_id']?.toString() ?? '';

  Future<void> _cancelCheckout() async {
    final cancelToken = _checkout?['cancel_token']?.toString() ?? '';
    final sessionId = _checkoutSessionId;
    if (_cancelled || (cancelToken.isEmpty && sessionId.isEmpty)) {
      return;
    }

    _cancelled = true;
    try {
      await widget.controller.client.post(
        '/wallet/checkout/cancel',
        body: {
          if (cancelToken.isNotEmpty) 'cancel_token': cancelToken,
          if (sessionId.isNotEmpty) 'session_id': sessionId,
        },
      );
    } catch (_) {}
  }

  Future<void> _refreshCheckoutStatus() async {
    final sessionId = _checkoutSessionId;
    if (sessionId.isEmpty || _paying) {
      return;
    }

    try {
      final result = await widget.controller.client.post(
        '/wallet/checkout/finalize',
        body: {'session_id': sessionId},
      );
      final data = (result['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final status = data['status']?.toString() ?? 'missing';
      if (status == 'paid') {
        _completed = true;
        _cancelled = true;
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (_) {}
  }

  Future<void> _pay() async {
    final checkoutUrl = _checkout?['checkout_url']?.toString() ?? '';
    if (checkoutUrl.isEmpty || _paying) {
      return;
    }

    setState(() => _paying = true);
    try {
      final opened = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        if (!mounted) return;
        await showMessage(
          context,
          title: 'Erro',
          message: 'Não foi possível abrir o checkout Stripe.',
        );
        return;
      }

      _checkoutOpened = true;
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Checkout aberto',
        message:
            'O checkout Stripe foi aberto no navegador. Depois de concluir ou cancelar, volte à app para atualizar o estado.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } catch (_) {
      await _cancelCheckout();
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Erro',
        message: 'Não foi possível iniciar o pagamento Stripe.',
      );
    } finally {
      if (mounted) {
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Resumo')),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 16))
                : _error != null
                ? ErrorState(
                    message: _error!,
                    onRetry: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _prepareCheckout();
                    },
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(16),
                    children: [
                      CardSection(
                        title: 'Resumo da compra',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _reviewLine('Pack', widget.packName),
                            _reviewLine('Opção', widget.optionLabel),
                            _reviewLine(
                              'Quantidade',
                              widget.quantity.toString(),
                            ),
                            _reviewLine('Preço unitário', widget.unitPrice),
                            _reviewLine('Total', widget.totalPrice),
                          ],
                        ),
                      ),
                      CardSection(
                        title: 'Dados da conta',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _reviewLine('Nome', widget.clientName),
                            _reviewLine('Email', widget.clientEmail),
                            _reviewLine('Telefone', widget.clientPhone),
                          ],
                        ),
                      ),
                      CardSection(
                        title: 'Métodos de pagamento',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'O pagamento será concluído no checkout Stripe externo. A escolha do método e a recolha do NIF, quando preenchido, ficam registadas no CRM.',
                            ),
                            if (_checkoutOpened) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'Se já terminaste no navegador, volta à app e carrega abaixo para verificar o estado.',
                              ),
                              const SizedBox(height: 10),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _refreshCheckoutStatus,
                                child: const Text(
                                  'Atualizar estado do pagamento',
                                  style: TextStyle(
                                    color: Color(0xFF0E4D50),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoButton(
                        color: const Color(0xFF0E4D50),
                        borderRadius: BorderRadius.circular(14),
                        onPressed: _paying ? null : _pay,
                        child: _paying
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : const Text(
                                'PAGAR',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _reviewLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 6, child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
}

class CompanyScreen extends _CompanyLikeScreen {
  const CompanyScreen({required super.controller})
    : super(title: 'Empresa', endpoint: '/company', savePath: '/company');
}

class SettingsScreen extends _CompanyLikeScreen {
  const SettingsScreen({required super.controller})
    : super(
        title: 'Definições',
        endpoint: '/settings',
        savePath: '/settings/sales-goal',
        settingsFields: true,
      );
}

class _QuotesSummary extends StatelessWidget {
  const _QuotesSummary({required this.meta});

  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final pipeline = toNumber(meta['pipeline_total']);
    final adjudications = toNumber(meta['adjudications_total']);
    final installments = toNumber(meta['installments_total']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: GlassPanel(
              enableBlur: false,
              radius: 16,
              child: _summaryBlock(
                'Dinheiro em cima da mesa',
                money(pipeline),
                'Projetos ativos (exclui concluídos e cancelados).',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassPanel(
              enableBlur: false,
              radius: 16,
              child: _summaryBlock(
                'Adjudicações / Parcelas',
                money(adjudications + installments),
                'Adjudicações: ${money(adjudications)} · Parcelas: ${money(installments)}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBlock(String title, String value, String caption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B3E42),
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(caption, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DocActionButton extends StatelessWidget {
  const _DocActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: CupertinoColors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0E4D50)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0E4D50),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntityAction {
  const _EntityAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF0E4D50),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
}

class _EntityListCard extends StatelessWidget {
  const _EntityListCard({
    required this.title,
    required this.subtitle,
    required this.metaLines,
    required this.onTap,
    this.statusLabel,
    this.statusColor,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<String> metaLines;
  final VoidCallback onTap;
  final String? statusLabel;
  final Color? statusColor;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E3F42),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF1A5A5D),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final line in metaLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              line,
                              style: const TextStyle(
                                color: Color(0xFF113B3D),
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (statusLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (statusColor ?? const Color(0xFF0E4D50))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel!,
                            style: TextStyle(
                              color: statusColor ?? const Color(0xFF0E4D50),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLinkButton extends StatelessWidget {
  const _DetailLinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0E4D50),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            CupertinoIcons.arrow_right_circle_fill,
            size: 18,
            color: Color(0xFF0E4D50),
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({required this.action});

  final _EntityAction action;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: CupertinoColors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      onPressed: action.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, size: 15, color: action.color),
          const SizedBox(width: 6),
          Text(
            action.label,
            style: TextStyle(
              color: action.color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5A7778),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF103537),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStepChip extends StatelessWidget {
  const _StatusStepChip({
    required this.label,
    required this.active,
    required this.color,
  });

  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.16) : const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.38)
              : const Color(0x22FFFFFF),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? color : const Color(0xFF1A5A5D),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ProjectMessageBubble extends StatelessWidget {
  const _ProjectMessageBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final type = message['type']?.toString() ?? 'message';
    final isMine = message['is_current_user'] == true;
    final attachment = ((message['meta'] as Map?)?['attachment'] as Map?)
        ?.cast<String, dynamic>();
    final attachmentUrl = attachment?['url']?.toString();
    final accent = switch (type) {
      'proof_request' => const Color(0xFFB26A00),
      'proof_submission' => const Color(0xFF6A1B9A),
      'status_update' => const Color(0xFF1565C0),
      _ => const Color(0xFF0E4D50),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine
            ? const Color(0xFFF4F7F8)
            : CupertinoColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message['sender_name']?.toString() ?? 'Utilizador',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  switch (type) {
                    'proof_request' => 'Pedido de prova',
                    'proof_submission' => 'Prova',
                    'status_update' => 'Estado',
                    _ => 'Mensagem',
                  },
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if ((message['body']?.toString() ?? '').trim().isNotEmpty)
            Text(message['body']?.toString() ?? '—'),
          if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
            if ((message['body']?.toString() ?? '').trim().isNotEmpty)
              const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                attachmentUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              attachment?['filename']?.toString() ?? 'Imagem anexada',
              style: const TextStyle(
                color: Color(0xFF5A7778),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            formatDateTime(message['created_at']),
            style: const TextStyle(
              color: Color(0xFF5A7778),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _detailTextBlock(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5A7778),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(value),
      ],
    ),
  );
}

class _FinanceStatTile extends StatelessWidget {
  const _FinanceStatTile({
    required this.label,
    required this.value,
    this.accent = const Color(0xFF0C3E42),
    this.background = const Color(0xFFF4F7F8),
  });

  final String label;
  final String value;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: accent.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

bool _financeSaleIsPaid(Map<String, dynamic> item) {
  if (item['invoice_status']?.toString() == 'pago') {
    return true;
  }

  return item['billing']?['status']?.toString() == 'paid';
}

bool _financeSaleHasDocument(Map<String, dynamic> item) {
  return item['invoice_id'] != null || item['invoiced'] == true;
}

bool _financeSaleNeedsInvoice(Map<String, dynamic> item) {
  return item['to_invoice'] == true && !_financeSaleHasDocument(item);
}

String _financeSaleStatus(Map<String, dynamic> item) {
  if (_financeSaleIsPaid(item)) {
    return 'Pago';
  }
  if (_financeSaleHasDocument(item)) {
    return 'Pendente';
  }
  if (_financeSaleNeedsInvoice(item)) {
    return 'A faturar';
  }
  return 'Sem documento';
}

Color _financeSaleStatusColor(Map<String, dynamic> item) {
  if (_financeSaleIsPaid(item)) {
    return const Color(0xFF2E7D57);
  }
  if (_financeSaleHasDocument(item)) {
    return const Color(0xFFB26A00);
  }
  if (_financeSaleNeedsInvoice(item)) {
    return const Color(0xFF1565C0);
  }
  return const Color(0xFF6B7F80);
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = _financeSaleStatus(item);
    final statusColor = _financeSaleStatusColor(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        enableBlur: false,
        radius: 16,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['description']?.toString() ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item['client'] ?? '—'} · ${item['type'] ?? '—'} · ${formatDate(item['date'])}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(item['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D4B4F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyLikeScreen extends StatefulWidget {
  const _CompanyLikeScreen({
    required this.controller,
    required this.title,
    required this.endpoint,
    required this.savePath,
    this.singleNumberField = false,
    this.settingsFields = false,
  });

  final AppController controller;
  final String title;
  final String endpoint;
  final String savePath;
  final bool singleNumberField;
  final bool settingsFields;

  @override
  State<_CompanyLikeScreen> createState() => _CompanyLikeScreenState();
}

class _CompanyLikeScreenState extends State<_CompanyLikeScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _data = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.client.get(widget.endpoint);
      final payload = (result['data'] as Map).cast<String, dynamic>();
      _data = widget.settingsFields
          ? {
              'sales_goal_year': payload['sales_goal']?.toString() ?? '',
              'terminal_surcharge_percent':
                  payload['terminal_surcharge_percent']?.toString() ?? '0',
              'terminal_surcharge_fixed':
                  payload['terminal_surcharge_fixed']?.toString() ?? '0',
            }
          : widget.singleNumberField
          ? {'sales_goal_year': payload['sales_goal']?.toString() ?? ''}
          : (payload['company'] as Map?)?.cast<String, dynamic>() ?? {};

      for (final entry in _data.entries) {
        _controllers[entry.key] = TextEditingController(
          text: entry.value?.toString() ?? '',
        );
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = {
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      };
      await widget.controller.client.post(widget.savePath, body: body);
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Guardado',
        message: 'Dados atualizados com sucesso.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashScreen();
    if (_error != null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
        child: SafeArea(
          child: ErrorState(message: _error!, onRetry: _load),
        ),
      );
    }

    return _FormPage(
      title: widget.title,
      saving: _saving,
      onSave: _save,
      children: [
        for (final entry in _controllers.entries)
          _field(
            _labelForField(entry.key),
            entry.value,
            keyboardType: _isNumericField(entry.key)
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
          ),
      ],
    );
  }

  String _labelForField(String key) {
    if (widget.settingsFields) {
      switch (key) {
        case 'sales_goal_year':
          return 'Meta anual (€)';
        case 'terminal_surcharge_percent':
          return 'Sobretaxa terminal (%)';
        case 'terminal_surcharge_fixed':
          return 'Sobretaxa terminal fixa (€)';
      }
    }

    return key;
  }

  bool _isNumericField(String key) {
    return widget.settingsFields ||
        (widget.singleNumberField && key == 'sales_goal_year');
  }
}

class _FormPage extends StatelessWidget {
  const _FormPage({
    required this.title,
    required this.saving,
    required this.onSave,
    required this.children,
  });

  final String title;
  final bool saving;
  final Future<void> Function() onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: saving ? null : onSave,
          child: saving
              ? const CupertinoActivityIndicator()
              : const Text('Guardar'),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                CardSection(
                  title: title,
                  child: Column(children: children),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _field(
  String label,
  TextEditingController controller, {
  int maxLines = 1,
  bool enabled = true,
  String? placeholder,
  TextInputType keyboardType = TextInputType.text,
  TextCapitalization textCapitalization = TextCapitalization.none,
  List<TextInputFormatter>? inputFormatters,
  int? maxLength,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          placeholder: placeholder,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x220E4D50)),
          ),
          style: const TextStyle(color: Color(0xFF103537)),
        ),
      ],
    ),
  );
}

Widget _selectorField({
  required String label,
  required String value,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x220E4D50)),
          ),
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onPressed: onTap,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(color: Color(0xFF103537)),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 18,
                  color: Color(0xFF0E4D50),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _richTextField(String label, TextEditingController controller) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x220E4D50)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _editorActionButton(
                    label: 'Título',
                    onTap: () => _prefixSelection(controller, '# '),
                  ),
                  _editorActionButton(
                    label: 'Lista',
                    onTap: () => _prefixSelection(controller, '- '),
                  ),
                  _editorActionButton(
                    label: 'Negrito',
                    onTap: () => _wrapSelection(controller, '**', '**'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                maxLines: 8,
                minLines: 6,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                style: const TextStyle(color: Color(0xFF103537)),
                placeholder:
                    '# Título\nTexto normal\n- Item 1\n- Item 2\n\nUsa a barra acima para formatar.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _editorActionButton({
  required String label,
  required VoidCallback onTap,
}) {
  return CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    color: const Color(0xFF0E4D50),
    borderRadius: BorderRadius.circular(12),
    onPressed: onTap,
    child: Text(
      label,
      style: const TextStyle(color: CupertinoColors.white, fontSize: 12),
    ),
  );
}

Widget _developmentItemsField({
  required List<Map<String, dynamic>> items,
  required double totalHours,
  required ValueChanged<List<Map<String, dynamic>>> onChanged,
  required VoidCallback onAdd,
  required void Function(int index) onRemove,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Funcionalidades',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onAdd,
              child: const Text('Adicionar linha'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x220E4D50)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Funcionalidade',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  SizedBox(
                    width: 86,
                    child: Text(
                      'Horas',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  SizedBox(width: 32),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DevelopmentItemRow(
                    index: i,
                    item: items[i],
                    canRemove: items.length > 1,
                    onChanged: (feature, hours) {
                      final next = [...items];
                      next[i] = {'feature': feature, 'hours': hours};
                      onChanged(next);
                    },
                    onRemove: () => onRemove(i),
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total estimado de horas: ${NumberFormat.decimalPattern('pt_PT').format(totalHours)}h',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E4D50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _prefixSelection(TextEditingController controller, String prefix) {
  final text = controller.text;
  final selection = controller.selection;
  final start = selection.start < 0 ? text.length : selection.start;
  final end = selection.end < 0 ? text.length : selection.end;
  final selectedText = text.substring(start, end);
  final replacement = selectedText.isEmpty ? prefix : '$prefix$selectedText';
  controller.value = controller.value.copyWith(
    text: text.replaceRange(start, end, replacement),
    selection: TextSelection.collapsed(offset: start + replacement.length),
  );
}

void _wrapSelection(
  TextEditingController controller,
  String before,
  String after,
) {
  final text = controller.text;
  final selection = controller.selection;
  final start = selection.start < 0 ? text.length : selection.start;
  final end = selection.end < 0 ? text.length : selection.end;
  final selectedText = text.substring(start, end);
  final replacement = '$before$selectedText$after';
  controller.value = controller.value.copyWith(
    text: text.replaceRange(start, end, replacement),
    selection: TextSelection.collapsed(offset: start + replacement.length),
  );
}

String _formatClientLabel(Map<String, dynamic> client) {
  final name = client['name']?.toString() ?? 'Cliente';
  final company = client['company']?.toString() ?? '';
  return company.isEmpty ? name : '$name · $company';
}

String _htmlToEditorText(String html) {
  var output = html;
  output = output.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  output = output.replaceAllMapped(
    RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', caseSensitive: false, dotAll: true),
    (match) => '# ${match.group(1)?.trim() ?? ''}\n\n',
  );
  output = output.replaceAllMapped(
    RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
    (match) => '- ${match.group(1)?.trim() ?? ''}\n',
  );
  output = output.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
  output = output.replaceAll(RegExp(r'<[^>]+>'), '');
  output = output
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return output.trim();
}

String _editorTextToHtml(String text) {
  final lines = text.trim().split('\n');
  final buffer = StringBuffer();
  var inList = false;

  String escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String inlineFormat(String value) => value.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (match) => '<strong>${match.group(1) ?? ''}</strong>',
  );

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      if (inList) {
        buffer.write('</ul>');
        inList = false;
      }
      continue;
    }

    if (line.startsWith('# ')) {
      if (inList) {
        buffer.write('</ul>');
        inList = false;
      }
      buffer.write(
        '<h3>${inlineFormat(escape(line.substring(2).trim()))}</h3>',
      );
      continue;
    }

    if (line.startsWith('- ') || line.startsWith('• ')) {
      if (!inList) {
        buffer.write('<ul>');
        inList = true;
      }
      buffer.write(
        '<li>${inlineFormat(escape(line.substring(2).trim()))}</li>',
      );
      continue;
    }

    if (inList) {
      buffer.write('</ul>');
      inList = false;
    }

    buffer.write('<p>${inlineFormat(escape(line.trim()))}</p>');
  }

  if (inList) {
    buffer.write('</ul>');
  }

  return buffer.toString();
}

class _DevelopmentItemRow extends StatefulWidget {
  const _DevelopmentItemRow({
    required this.index,
    required this.item,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final Map<String, dynamic> item;
  final bool canRemove;
  final void Function(String feature, num hours) onChanged;
  final VoidCallback onRemove;

  @override
  State<_DevelopmentItemRow> createState() => _DevelopmentItemRowState();
}

class _DevelopmentItemRowState extends State<_DevelopmentItemRow> {
  late final TextEditingController _featureController;
  late final TextEditingController _hoursController;

  @override
  void initState() {
    super.initState();
    _featureController = TextEditingController(
      text: widget.item['feature']?.toString() ?? '',
    );
    _hoursController = TextEditingController(
      text: toNumber(widget.item['hours']).toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _DevelopmentItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final feature = widget.item['feature']?.toString() ?? '';
    final hours = toNumber(widget.item['hours']).toString();
    if (_featureController.text != feature) {
      _featureController.value = TextEditingValue(
        text: feature,
        selection: TextSelection.collapsed(offset: feature.length),
      );
    }
    if (_hoursController.text != hours) {
      _hoursController.value = TextEditingValue(
        text: hours,
        selection: TextSelection.collapsed(offset: hours.length),
      );
    }
  }

  @override
  void dispose() {
    _featureController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CupertinoTextField(
            controller: _featureController,
            onChanged: (value) =>
                widget.onChanged(value, toNumber(widget.item['hours'])),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 86,
          child: CupertinoTextField(
            controller: _hoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => widget.onChanged(
              _featureController.text,
              num.tryParse(value.replaceAll(',', '.')) ?? 0,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.only(top: 6),
          onPressed: widget.canRemove ? widget.onRemove : null,
          child: const Icon(
            CupertinoIcons.delete,
            size: 18,
            color: CupertinoColors.systemRed,
          ),
        ),
      ],
    );
  }
}

Future<bool> _prompt(
  BuildContext context,
  String title,
  TextEditingController controller,
) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(controller: controller),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF1B5A5D).withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0C3E42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleList extends StatelessWidget {
  const _SimpleList({
    required this.items,
    required this.titleKey,
    required this.subtitleBuilder,
    this.onItemTap,
  });

  final List<dynamic> items;
  final String titleKey;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  final Future<void> Function(Map<String, dynamic>)? onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState('Sem registos.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final raw in items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: GlassPanel(
                padding: const EdgeInsets.all(12),
                radius: 16,
                enableBlur: false,
                child: Builder(
                  builder: (context) {
                    final item = (raw as Map).cast<String, dynamic>();
                    final content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item[titleKey]?.toString() ?? '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C3E42),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitleBuilder(item),
                          style: const TextStyle(color: Color(0xFF1A5A5D)),
                        ),
                      ],
                    );

                    if (onItemTap == null) {
                      return content;
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onItemTap!(item),
                      child: content,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
