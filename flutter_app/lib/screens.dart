import 'dart:convert';

import 'package:flutter/cupertino.dart';
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
      await _askToEnableBiometrics();
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

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
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
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            label: 'Clientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.folder),
            label: 'Projetos',
          ),
          BottomNavigationBarItem(
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
                return ClientsScreen(controller: controller);
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
                            _StatChip(
                              label: 'Faturação paga',
                              value: money(_payload?['stats']?['paid_amount']),
                            ),
                          ],
                        ),
                      ),
                      CardSection(
                        title: 'Últimas faturas',
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
        trailing: CupertinoButton(
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
                    trailing: CupertinoButton(
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
    };

    try {
      if (widget.client == null) {
        await widget.controller.client.post('/clients', body: body);
      } else {
        await widget.controller.client.put(
          '/clients/${widget.client!['id']}',
          body: body,
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

  @override
  Widget build(BuildContext context) {
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
        trailing: CupertinoButton(
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
                    trailing: CupertinoButton(
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
                        Text(money(project['quote']?['price_development'])),
                        const SizedBox(height: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _delete(project['id'] as int),
                          child: const Text(
                            'Eliminar',
                            style: TextStyle(color: CupertinoColors.systemRed),
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
    final modules = [
      ('Orçamentos', QuotesScreen(controller: controller)),
      ('Produtos / Packs', ProductsScreen(controller: controller)),
      ('Faturas', InvoicesScreen(controller: controller)),
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
        middle: const Text('Faturas'),
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
            ? const EmptyState('Sem faturas disponíveis.')
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
                    title: invoice['number']?.toString() ?? 'Fatura',
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

class InterventionsScreen extends _JsonModuleScreen {
  InterventionsScreen({required super.controller})
    : super(
        title: 'Intervenções',
        endpoint: '/interventions',
        rootListKey: 'interventions',
        itemBuilder: (item) =>
            '${item['client']?['name'] ?? '—'} · ${item['type']}',
        subtitleBuilder: (item) =>
            'Início: ${formatDate(item['started_at'])} · Fim: ${formatDate(item['ended_at'])}',
      );
}

class WalletsScreen extends _JsonModuleScreen {
  WalletsScreen({required super.controller})
    : super(
        title: 'Carteiras',
        endpoint: '/wallets',
        rootListKey: 'transactions',
        itemBuilder: (item) =>
            '${item['description'] ?? 'Transação'} · ${money(item['amount'])}',
        subtitleBuilder: (item) =>
            '${item['type'] ?? '—'} · ${formatDate(item['transaction_at'])}',
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
        singleNumberField: true,
      );
}

class _JsonModuleScreen extends StatefulWidget {
  const _JsonModuleScreen({
    required this.controller,
    required this.title,
    required this.endpoint,
    required this.itemBuilder,
    this.rootListKey,
    this.subtitleBuilder,
  });

  final AppController controller;
  final String title;
  final String endpoint;
  final String? rootListKey;
  final String Function(Map<String, dynamic> item) itemBuilder;
  final String Function(Map<String, dynamic> item)? subtitleBuilder;

  @override
  State<_JsonModuleScreen> createState() => _JsonModuleScreenState();
}

class _JsonModuleScreenState extends State<_JsonModuleScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

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
      final source = widget.rootListKey == null
          ? result['data']
          : (result['data'] as Map<String, dynamic>)[widget.rootListKey];
      setState(() => _items = source as List<dynamic>? ?? []);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _items.isEmpty
            ? const EmptyState('Sem dados disponíveis.')
            : ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = (_items[index] as Map).cast<String, dynamic>();
                  final subtitle =
                      widget.subtitleBuilder?.call(item) ??
                      item.entries
                          .where(
                            (entry) =>
                                entry.key != 'id' &&
                                entry.value != null &&
                                entry.value.toString().isNotEmpty,
                          )
                          .take(3)
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join(' · ');
                  return CardSection(
                    title: widget.itemBuilder(item),
                    child: Text(
                      subtitle.isEmpty ? 'Sem detalhes.' : subtitle,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                },
              ),
      ),
    );
  }
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
