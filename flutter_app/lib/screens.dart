import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _submit();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.controller.loginWithCachedCredentials();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 18))
            : _error != null
            ? ErrorState(message: _error!, onRetry: _submit)
            : const SizedBox.shrink(),
      ),
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
        activeColor: kBrandColor,
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
        middle: const Text('Dashboard'),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Text(
                      'Bem-vindo, $userName',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client['company']?.toString() ?? 'Sem empresa'),
                        const SizedBox(height: 6),
                        Text(client['email']?.toString() ?? 'Sem email'),
                        const SizedBox(height: 12),
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

class QuotesScreen extends _JsonModuleScreen {
  QuotesScreen({required super.controller})
    : super(
        title: 'Orçamentos',
        endpoint: '/quotes?per_page=30',
        itemBuilder: (item) =>
            '${item['project']?['name'] ?? 'Projeto'} · ${money(item['price_development'])}',
      );
}

class ProductsScreen extends _JsonModuleScreen {
  ProductsScreen({required super.controller})
    : super(
        title: 'Produtos / Packs',
        endpoint: '/products',
        rootListKey: 'products',
        itemBuilder: (item) => '${item['name']} · ${item['type']}',
      );
}

class InvoicesScreen extends _JsonModuleScreen {
  InvoicesScreen({required super.controller})
    : super(
        title: 'Faturas',
        endpoint: '/invoices?per_page=30',
        itemBuilder: (item) => '${item['number']} · ${money(item['total'])}',
      );
}

class FinanceScreen extends _JsonModuleScreen {
  FinanceScreen({required super.controller})
    : super(
        title: 'Financeiro',
        endpoint: '/finance',
        rootListKey: 'sales',
        itemBuilder: (item) => '${item['client']} · ${item['description']}',
      );
}

class InterventionsScreen extends _JsonModuleScreen {
  InterventionsScreen({required super.controller})
    : super(
        title: 'Intervenções',
        endpoint: '/interventions',
        rootListKey: 'interventions',
        itemBuilder: (item) =>
            '${item['client']?['name'] ?? '—'} · ${item['type']}',
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
  });

  final AppController controller;
  final String title;
  final String endpoint;
  final String? rootListKey;
  final String Function(Map<String, dynamic> item) itemBuilder;

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
            : ListView(
                children: [
                  for (final raw in _items)
                    CardSection(
                      title: widget.itemBuilder(
                        (raw as Map).cast<String, dynamic>(),
                      ),
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(raw),
                        style: const TextStyle(fontSize: 12),
                      ),
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
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
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
      children: [
        for (final raw in items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Builder(
              builder: (context) {
                final item = (raw as Map).cast<String, dynamic>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item[titleKey]?.toString() ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitleBuilder(item)),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
