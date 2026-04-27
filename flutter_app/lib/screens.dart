import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controller.dart';
import 'services/api_client.dart';
import 'widgets/ui.dart';

String formatDate(dynamic value) {
  if (value == null || value.toString().isEmpty) return '—';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
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
    _emailController.text = widget.controller.apiEmail;
    _passwordController.text = widget.controller.apiPassword;
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
            'Pode ativar impressão digital ou Face ID para entrar mais rápido.',
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
      await widget.controller.setBiometricEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canQuickLogin =
        widget.controller.biometricEnabled && _canUseBiometrics;

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
      await widget.controller.setBiometricEnabled(false);
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

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final isClientUser = controller.isClientUser;
    return CupertinoTabScaffold(
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
          builder: (context) {
            switch (index) {
              case 0:
                return DashboardScreen(controller: controller);
              case 1:
                return isClientUser
                    ? ObjectsScreen(controller: controller)
                    : ClientsScreen(controller: controller);
              case 2:
                return ProjectsScreen(controller: controller);
              default:
                return MoreModulesScreen(controller: controller);
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
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
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
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _load,
          child: const Icon(
            CupertinoIcons.refresh,
            color: CupertinoColors.white,
          ),
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
                              label: 'Clientes',
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
                          ),
                        ),
                      CardSection(
                        title: 'Últimos documentos',
                        child: _SimpleList(
                          items: (_payload?['recent_invoices'] as List? ?? []),
                          titleKey: 'number',
                          subtitleBuilder: (item) =>
                              '${item['client']?['name'] ?? '—'} · ${money(item['total'])}',
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
                                                  child: const Text('Copiar'),
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

  Future<void> _delete(Map<String, dynamic> client) async {
    final confirmed = await confirmDelete(
      context,
      'Eliminar ${client['name']}?',
    );
    if (!confirmed) return;

    try {
      await widget.controller.client.delete('/clients/${client['id']}');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
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
                itemCount: _clients.length,
                itemBuilder: (context, index) {
                  final client = _clients[index] as Map<String, dynamic>;
                  return CardSection(
                    title: client['name']?.toString() ?? 'Cliente',
                    trailing: widget.controller.isClientUser
                        ? null
                        : CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _openForm(client),
                            child: const Text('Editar'),
                          ),
                    child: Wrap(
                      runSpacing: 8,
                      children: [
                        Text(client['company']?.toString() ?? 'Sem empresa'),
                        Text(client['email']?.toString() ?? 'Sem email'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _openDetails(client),
                                child: const Text('Detalhes'),
                              ),
                            ),
                            if (!widget.controller.isClientUser)
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _delete(client),
                                  child: const Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      color: CupertinoColors.systemRed,
                                    ),
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
                                  const SizedBox(height: 8),
                                  for (final credential
                                      in (object['credentials'] as List? ?? []))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '${credential['label']} · ${credential['username'] ?? '—'}',
                                      ),
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

  Future<void> _delete(int projectId) async {
    final confirmed = await confirmDelete(context, 'Eliminar este projeto?');
    if (!confirmed) return;
    try {
      await widget.controller.client.delete('/projects/$projectId');
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showMessage(context, title: 'Erro', message: error.message);
    }
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
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final project = _projects[index] as Map<String, dynamic>;
                  return CardSection(
                    title: project['name']?.toString() ?? 'Projeto',
                    trailing: widget.controller.isClientUser
                        ? null
                        : CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _openForm(project['id'] as int),
                            child: const Text('Editar'),
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project['client']?['name']?.toString() ?? '—'),
                        const SizedBox(height: 6),
                        Text(project['status']?.toString() ?? '—'),
                        const SizedBox(height: 6),
                        Text(
                          money(
                            project['base_amount'] ??
                                project['quote']?['price_development'],
                          ),
                        ),
                        if (widget.controller.isClientUser) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Parcelas: ${money(project['installments_total'])}',
                          ),
                          if (toNumber(project['adjudication_value']) > 0)
                            Text(
                              'Adjudicação: ${money(project['adjudication_value'])}',
                            ),
                          Text(
                            'Em aberto: ${money(project['remaining_amount'])}',
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (!widget.controller.isClientUser)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _delete(project['id'] as int),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(
                                color: CupertinoColors.systemRed,
                              ),
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
  int? _clientId;
  String _status = 'planeamento';
  String _type = 'website';
  final _name = TextEditingController();
  final _typeController = TextEditingController(text: 'website');
  final _technologies = TextEditingController();
  final _description = TextEditingController();
  final _developmentJson = TextEditingController(
    text: '[{"feature":"Homepage","hours":8}]',
  );
  final _priceDevelopment = TextEditingController(text: '0');
  final _terms = TextEditingController();
  final _domainFirst = TextEditingController(text: '0');
  final _domainOther = TextEditingController(text: '0');
  final _hostingFirst = TextEditingController(text: '0');
  final _hostingOther = TextEditingController(text: '0');
  final _maintenance = TextEditingController(text: '0');
  bool _includeDomain = false;
  bool _includeHosting = false;
  final Set<int> _selectedCatalog = {};

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
      _terms.text = data['default_terms']?.toString() ?? '';
      _clientId = _clients.isNotEmpty ? _clients.first['id'] as int : null;

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
        _typeController.text = _type;
        _status = project['status']?.toString() ?? _status;
        _technologies.text = quote['technologies']?.toString() ?? '';
        _description.text = quote['description']?.toString() ?? '';
        _developmentJson.text = jsonEncode(quote['development_items'] ?? []);
        _priceDevelopment.text = quote['price_development']?.toString() ?? '0';
        _terms.text = quote['terms']?.toString() ?? _terms.text;
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
        for (final product in (quote['quote_products'] as List? ?? [])) {
          final productId = product['product_id'];
          if (productId is int) _selectedCatalog.add(productId);
        }
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final developmentItems =
          jsonDecode(_developmentJson.text) as List<dynamic>;
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
        'development_total_hours': developmentItems.fold<num>(
          0,
          (sum, item) => sum + (num.tryParse(item['hours'].toString()) ?? 0),
        ),
        'price_development': _priceDevelopment.text,
        'price_maintenance_monthly': _maintenance.text,
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
    } on FormatException {
      await showMessage(
        context,
        title: 'JSON inválido',
        message: 'O campo de funcionalidades deve conter JSON válido.',
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
        CupertinoSlidingSegmentedControl<int>(
          groupValue: _clientId,
          children: {
            for (final client in _clients.take(3))
              client['id'] as int: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(client['name'].toString()),
              ),
          },
          onValueChanged: (value) => setState(() => _clientId = value),
        ),
        const SizedBox(height: 12),
        _field('Nome', _name),
        _field('Tipo', _typeController, enabled: false),
        _field('Tecnologias', _technologies),
        _field('Descrição', _description, maxLines: 5),
        _field('Funcionalidades JSON', _developmentJson, maxLines: 7),
        _field('Preço desenvolvimento', _priceDevelopment),
        _field('Termos', _terms, maxLines: 6),
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
        _field('Domínio 1º ano', _domainFirst),
        _field('Domínio anos seguintes', _domainOther),
        _field('Alojamento 1º ano', _hostingFirst),
        _field('Alojamento anos seguintes', _hostingOther),
        _field('Manutenção mensal', _maintenance),
        const SizedBox(height: 8),
        const Text(
          'Produtos / Packs incluídos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final item in _catalog.take(8))
          Row(
            children: [
              Expanded(child: Text(item['name'].toString())),
              CupertinoSwitch(
                value: _selectedCatalog.contains(item['id']),
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _selectedCatalog.add(item['id'] as int);
                    } else {
                      _selectedCatalog.remove(item['id']);
                    }
                  });
                },
              ),
            ],
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
            ('Carteira', ClientWalletScreen(controller: controller)),
            ('Documentos', InvoicesScreen(controller: controller)),
          ]
        : [
            ('Orçamentos', QuotesScreen(controller: controller)),
            ('Produtos / Packs', ProductsScreen(controller: controller)),
            ('Documentos', InvoicesScreen(controller: controller)),
            ('Financeiro', FinanceScreen(controller: controller)),
            ('Intervenções', InterventionsScreen(controller: controller)),
            ('Carteiras', WalletsScreen(controller: controller)),
            ('Empresa', CompanyScreen(controller: controller)),
            ('Definições', SettingsScreen(controller: controller)),
          ];

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Módulos'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: controller.logout,
          child: const Text('Logout'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            for (final module in modules)
              CardSection(
                title: module.$1,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).push(CupertinoPageRoute(builder: (_) => module.$2));
                  },
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Abrir módulo'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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

                      return CardSection(
                        title:
                            quote['project']?['name']?.toString() ?? 'Projeto',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quote['project']?['client']?['name']
                                      ?.toString() ??
                                  'Sem cliente',
                              style: const TextStyle(color: Color(0xFF1A5A5D)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                Text('Base: ${money(base)}'),
                                Text(
                                  'Adjudicação: ${money(adjudicationValue)}',
                                ),
                                Text('Parcelas: ${money(installments)}'),
                                Text('Em aberto: ${money(remaining)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _DocActionButton(
                                  icon: CupertinoIcons.doc_text,
                                  label: 'PDF',
                                  onPressed: () => _openDocument(
                                    context,
                                    widget.controller,
                                    '/documents/quotes/${quote['id']}/pdf',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _DocActionButton(
                                  icon: CupertinoIcons.printer,
                                  label: 'Imprimir',
                                  onPressed: () => _openDocument(
                                    context,
                                    widget.controller,
                                    '/documents/quotes/${quote['id']}/pdf',
                                  ),
                                ),
                              ],
                            ),
                          ],
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
  const InvoicesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _invoices = [];

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
        '/invoices?per_page=50',
      );
      setState(() => _invoices = result['data'] as List<dynamic>? ?? []);
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
            : _invoices.isEmpty
            ? const EmptyState('Sem documentos disponíveis.')
            : ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: _invoices.length,
                itemBuilder: (context, index) {
                  final invoice = (_invoices[index] as Map)
                      .cast<String, dynamic>();
                  final status = invoice['status']?.toString() ?? '—';
                  return CardSection(
                    title: invoice['number']?.toString() ?? 'Documento',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${invoice['client']?['name'] ?? '—'} · ${money(invoice['total'])}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estado: $status · Emissão: ${formatDate(invoice['issued_at'])}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _DocActionButton(
                              icon: CupertinoIcons.doc_text,
                              label: 'PDF',
                              onPressed: () => _openDocument(
                                context,
                                widget.controller,
                                '/documents/invoices/${invoice['id']}/pdf',
                              ),
                            ),
                            const SizedBox(width: 8),
                            _DocActionButton(
                              icon: CupertinoIcons.printer,
                              label: 'Imprimir',
                              onPressed: () => _openDocument(
                                context,
                                widget.controller,
                                '/documents/invoices/${invoice['id']}/pdf',
                              ),
                            ),
                          ],
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

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _sales = [];
  List<dynamic> _installments = [];
  List<dynamic> _invoices = [];

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
      final result = await widget.controller.client.get('/finance');
      final payload = (result['data'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        _sales = payload['sales'] as List<dynamic>? ?? [];
        _installments = payload['installments'] as List<dynamic>? ?? [];
        _invoices = payload['invoices'] as List<dynamic>? ?? [];
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _sales.fold<num>(
      0,
      (sum, item) => sum + toNumber((item as Map)['amount']),
    );
    final toInvoice = _sales
        .where((item) => (item as Map)['to_invoice'] == true)
        .fold<num>(0, (sum, item) => sum + toNumber((item as Map)['amount']));
    final paidInvoices = _invoices
        .where((item) => (item as Map)['status'] == 'pago')
        .fold<num>(0, (sum, item) => sum + toNumber((item as Map)['total']));
    final pendingInvoices = _invoices
        .where((item) => (item as Map)['status'] != 'pago')
        .fold<num>(0, (sum, item) => sum + toNumber((item as Map)['total']));
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
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _FinanceStatTile(
                          label: 'Vendas',
                          value: money(totalSales),
                        ),
                        _FinanceStatTile(
                          label: 'A faturar',
                          value: money(toInvoice),
                        ),
                        _FinanceStatTile(
                          label: 'Pago',
                          value: money(paidInvoices),
                        ),
                        _FinanceStatTile(
                          label: 'Pendente',
                          value: money(pendingInvoices),
                        ),
                        _FinanceStatTile(
                          label: 'Parcelas',
                          value: money(installmentTotal),
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
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _packProducts.isEmpty
                                  ? null
                                  : () async {
                                      final options = _packProducts;
                                      String selected =
                                          _packProductId ??
                                          options.first['id'].toString();
                                      final confirmed = await showCupertinoDialog<bool>(
                                        context: context,
                                        builder: (context) => CupertinoAlertDialog(
                                          title: const Text('Selecionar pack'),
                                          content: SizedBox(
                                            height: 180,
                                            child: CupertinoPicker(
                                              itemExtent: 36,
                                              scrollController:
                                                  FixedExtentScrollController(
                                                    initialItem: options
                                                        .indexWhere(
                                                          (item) =>
                                                              item['id']
                                                                  ?.toString() ==
                                                              selected,
                                                        )
                                                        .clamp(
                                                          0,
                                                          options.length - 1,
                                                        ),
                                                  ),
                                              onSelectedItemChanged: (index) {
                                                selected = options[index]['id']
                                                    .toString();
                                              },
                                              children: [
                                                for (final option in options)
                                                  Center(
                                                    child: Text(
                                                      option['name']
                                                              ?.toString() ??
                                                          'Pack',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            CupertinoDialogAction(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: const Text('Cancelar'),
                                            ),
                                            CupertinoDialogAction(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              child: const Text('Selecionar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        setState(() {
                                          _packProductId = selected;
                                          _syncPackItemSelection();
                                        });
                                      }
                                    },
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _packProducts
                                          .firstWhere(
                                            (item) =>
                                                item['id']?.toString() ==
                                                _packProductId,
                                            orElse: () =>
                                                const <String, dynamic>{},
                                          )['name']
                                          ?.toString() ??
                                      'Selecionar pack',
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _selectedPackItems.isEmpty
                                  ? null
                                  : () async {
                                      final options = _selectedPackItems;
                                      String selected =
                                          _packItemId ??
                                          options.first['id'].toString();
                                      final confirmed = await showCupertinoDialog<bool>(
                                        context: context,
                                        builder: (context) => CupertinoAlertDialog(
                                          title: const Text('Selecionar opção'),
                                          content: SizedBox(
                                            height: 180,
                                            child: CupertinoPicker(
                                              itemExtent: 36,
                                              scrollController:
                                                  FixedExtentScrollController(
                                                    initialItem: options
                                                        .indexWhere(
                                                          (item) =>
                                                              item['id']
                                                                  ?.toString() ==
                                                              selected,
                                                        )
                                                        .clamp(
                                                          0,
                                                          options.length - 1,
                                                        ),
                                                  ),
                                              onSelectedItemChanged: (index) {
                                                selected = options[index]['id']
                                                    .toString();
                                              },
                                              children: [
                                                for (final option in options)
                                                  Center(
                                                    child: Text(
                                                      '${option['hours']}h · ${money(option['pack_price'])}',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            CupertinoDialogAction(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: const Text('Cancelar'),
                                            ),
                                            CupertinoDialogAction(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              child: const Text('Selecionar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        setState(() => _packItemId = selected);
                                      }
                                    },
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _selectedPackItems
                                              .firstWhere(
                                                (item) =>
                                                    item['id']?.toString() ==
                                                    _packItemId,
                                                orElse: () =>
                                                    const <String, dynamic>{},
                                              )['hours']
                                              ?.toString() !=
                                          null
                                      ? '${_selectedPackItems.firstWhere((item) => item['id']?.toString() == _packItemId, orElse: () => const <String, dynamic>{})['hours']}h'
                                      : 'Selecionar opção',
                                ),
                              ),
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
  const WalletsScreen({super.key, required this.controller});

  final AppController controller;

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
        _selectedClient = (data['selected_client'] as Map?)
            ?.cast<String, dynamic>();
        _wallet = (data['wallet'] as Map?)?.cast<String, dynamic>();
        _transactions = data['transactions'] as List<dynamic>? ?? [];
        _packs = packs;
        _selectedClientId = selectedClientId;
        if (_packProductId == null && packs.isNotEmpty) {
          _packProductId = (packs.first as Map)['id'].toString();
        }
        _syncPackItemSelection();
      });
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Selecionar cliente'),
        content: SizedBox(
          height: 180,
          child: CupertinoPicker(
            itemExtent: 36,
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
                Center(child: Text(client['name']?.toString() ?? 'Cliente')),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Selecionar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _selectedClientId = selected);
      await _load();
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
                children: [
                  CardSection(
                    title: 'Cliente',
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _selectClient,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _selectedClient?['name']?.toString() ??
                              'Selecionar cliente',
                        ),
                      ),
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
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _packProducts.isEmpty
                                ? null
                                : () async {
                                    var selected =
                                        _packProductId ??
                                        _packProducts.first['id'].toString();
                                    final confirmed = await showCupertinoDialog<bool>(
                                      context: context,
                                      builder: (context) => CupertinoAlertDialog(
                                        title: const Text('Selecionar pack'),
                                        content: SizedBox(
                                          height: 180,
                                          child: CupertinoPicker(
                                            itemExtent: 36,
                                            scrollController:
                                                FixedExtentScrollController(
                                                  initialItem: _packProducts
                                                      .indexWhere(
                                                        (item) =>
                                                            item['id']
                                                                ?.toString() ==
                                                            selected,
                                                      )
                                                      .clamp(
                                                        0,
                                                        _packProducts.length -
                                                            1,
                                                      ),
                                                ),
                                            onSelectedItemChanged: (index) {
                                              selected =
                                                  _packProducts[index]['id']
                                                      .toString();
                                            },
                                            children: [
                                              for (final option
                                                  in _packProducts)
                                                Center(
                                                  child: Text(
                                                    option['name']
                                                            ?.toString() ??
                                                        'Pack',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          CupertinoDialogAction(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          CupertinoDialogAction(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Selecionar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      setState(() {
                                        _packProductId = selected;
                                        _syncPackItemSelection();
                                      });
                                    }
                                  },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _packProducts
                                        .firstWhere(
                                          (item) =>
                                              item['id']?.toString() ==
                                              _packProductId,
                                          orElse: () =>
                                              const <String, dynamic>{},
                                        )['name']
                                        ?.toString() ??
                                    'Selecionar pack',
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _selectedPackItems.isEmpty
                                ? null
                                : () async {
                                    var selected =
                                        _packItemId ??
                                        _selectedPackItems.first['id']
                                            .toString();
                                    final confirmed = await showCupertinoDialog<bool>(
                                      context: context,
                                      builder: (context) => CupertinoAlertDialog(
                                        title: const Text('Selecionar opção'),
                                        content: SizedBox(
                                          height: 180,
                                          child: CupertinoPicker(
                                            itemExtent: 36,
                                            scrollController:
                                                FixedExtentScrollController(
                                                  initialItem: _selectedPackItems
                                                      .indexWhere(
                                                        (item) =>
                                                            item['id']
                                                                ?.toString() ==
                                                            selected,
                                                      )
                                                      .clamp(
                                                        0,
                                                        _selectedPackItems
                                                                .length -
                                                            1,
                                                      ),
                                                ),
                                            onSelectedItemChanged: (index) {
                                              selected =
                                                  _selectedPackItems[index]['id']
                                                      .toString();
                                            },
                                            children: [
                                              for (final option
                                                  in _selectedPackItems)
                                                Center(
                                                  child: Text(
                                                    '${option['hours']}h · ${money(option['pack_price'])}',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          CupertinoDialogAction(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          CupertinoDialogAction(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Selecionar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      setState(() => _packItemId = selected);
                                    }
                                  },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _selectedPackItems
                                            .firstWhere(
                                              (item) =>
                                                  item['id']?.toString() ==
                                                  _packItemId,
                                              orElse: () =>
                                                  const <String, dynamic>{},
                                            )['hours']
                                            ?.toString() !=
                                        null
                                    ? '${_selectedPackItems.firstWhere((item) => item['id']?.toString() == _packItemId, orElse: () => const <String, dynamic>{})['hours']}h'
                                    : 'Selecionar opção',
                              ),
                            ),
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
                          CupertinoButton.filled(
                            onPressed: _buyPack,
                            child: const Text('Registar compra'),
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
  const ClientWalletScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ClientWalletScreen> createState() => _ClientWalletScreenState();
}

class _ClientWalletScreenState extends State<ClientWalletScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _wallet;
  List<dynamic> _transactions = [];
  List<dynamic> _interventions = [];

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
      final result = await widget.controller.client.get('/wallet');
      final data = (result['data'] as Map).cast<String, dynamic>();
      setState(() {
        _wallet = (data['wallet'] as Map?)?.cast<String, dynamic>();
        _transactions = data['transactions'] as List<dynamic>? ?? [];
        _interventions = data['interventions'] as List<dynamic>? ?? [];
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Carteira'),
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
                children: [
                  CardSection(
                    title: 'Saldo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _wallet?['client']?['name']?.toString() ?? 'Cliente',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tempo em carteira: ${_formatHours(_wallet?['balance_seconds'])}',
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
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${item['description'] ?? 'Transação'} · ${moneyOrDash(item['amount'])}\n${_formatHours(item['seconds'])} · ${formatDate(item['transaction_at'])}',
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
        singleNumberField: true,
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

class _FinanceStatTile extends StatelessWidget {
  const _FinanceStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      enableBlur: false,
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0C3E42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = item['to_invoice'] == true ? 'A faturar' : 'OK';
    final statusColor = item['to_invoice'] == true
        ? CupertinoColors.systemOrange
        : const Color(0xFF2E7D57);
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
  });

  final AppController controller;
  final String title;
  final String endpoint;
  final String savePath;
  final bool singleNumberField;

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
      _data = widget.singleNumberField
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
          _field(entry.key, entry.value),
      ],
    );
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
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CardSection(
              title: title,
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _field(
  String label,
  TextEditingController controller, {
  int maxLines = 1,
  bool enabled = true,
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
          padding: const EdgeInsets.all(14),
        ),
      ],
    ),
  );
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
  });

  final List<dynamic> items;
  final String titleKey;
  final String Function(Map<String, dynamic>) subtitleBuilder;

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
                    return Column(
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
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
