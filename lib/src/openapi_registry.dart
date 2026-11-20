import 'route_doc.dart';

/// Docs of one controller method, made at build time by `dox_builder`.
///
/// The generated `lib/generated/openapi.g.dart` holds a list of these. They are
/// matched to the live routes by the method name, see [OpenApiRegistry].
class OpenApiOperation {
  /// Class name, for example `BlogController`.
  final String controller;

  /// Method name, for example `index`.
  final String method;

  /// Argument types, for example `['DoxRequest', 'String']`.
  /// Used to tell two methods with the same name apart.
  final List<String> argumentTypes;

  /// Short title.
  final String? summary;

  /// Longer text.
  final String? description;

  /// Tags to group the route.
  final List<String> tags;

  /// True when the route is deprecated.
  final bool deprecated;

  /// True for `@ApiIgnore()`: the route is left out of the document.
  final bool ignore;

  /// Schemas of the path params, in order. They match the route params
  /// by position: the first one is for the first `{param}`.
  final List<Map<String, dynamic>> params;

  /// The request schema: a JSON Schema map (often a `$ref` to a `@Dto`
  /// class) or an object with `toJsonSchema()`.
  final Object? schema;

  /// `body` or `query`. Null means body for POST, PUT and PATCH,
  /// and query for the other methods.
  final String? requestIn;

  /// Responses by status code, from the return type and `@Response`.
  final Map<int, ResponseDoc> responses;

  /// Creates the docs of one controller method.
  const OpenApiOperation({
    required this.controller,
    required this.method,
    this.argumentTypes = const <String>[],
    this.summary,
    this.description,
    this.tags = const <String>[],
    this.deprecated = false,
    this.ignore = false,
    this.params = const <Map<String, dynamic>>[],
    this.schema,
    this.requestIn,
    this.responses = const <int, ResponseDoc>{},
  });

  /// `Class.method`, used as the operation id.
  String get id {
    return '$controller.$method';
  }
}

/// A `Route.get('path', controller.method)` call the builder found.
/// It tells which class a route handler belongs to.
class OpenApiRouteBinding {
  /// HTTP method in upper case, for example `GET`.
  final String method;

  /// The full path: the router prefix, the `Route.group` prefixes and
  /// the path of the route call. Null when one part is not a plain string.
  final String? path;

  /// The operation id, `Class.method`.
  final String operation;

  /// Creates a binding.
  const OpenApiRouteBinding(this.method, this.path, this.operation);
}

/// A login scheme from `@Security` on a middleware class.
class OpenApiSecurity {
  /// Name under `components/securitySchemes`, like `apiKeyAuth`.
  final String name;

  /// The OpenAPI security scheme object.
  final Map<String, dynamic> scheme;

  /// Creates a login scheme.
  const OpenApiSecurity(this.name, this.scheme);
}

/// Everything `dox_builder` found in the app: controller methods,
/// route calls, model schemas and login schemes. The generated file
/// makes one.
class OpenApiRegistry {
  /// Docs of the controller methods.
  final List<OpenApiOperation> operations;

  /// Route calls found in the code.
  final List<OpenApiRouteBinding> routes;

  /// Named schemas (models), placed under `components/schemas`.
  final Map<String, Map<String, dynamic>> schemas;

  /// Login schemes by middleware class name, from `@Security`.
  final Map<String, OpenApiSecurity> security;

  /// Creates a registry. The default is empty.
  const OpenApiRegistry({
    this.operations = const <OpenApiOperation>[],
    this.routes = const <OpenApiRouteBinding>[],
    this.schemas = const <String, Map<String, dynamic>>{},
    this.security = const <String, OpenApiSecurity>{},
  });

  /// Finds the docs for one live route.
  ///
  /// [functionName] and [argumentTypes] come from the route handler.
  /// [controller] is the class name of the handler, when the route knows
  /// it (`(C c) => c.index` or `Route.get<C>`). Then only methods of that
  /// class match, so two controllers with the same method name never mix.
  ///
  /// A route call with the same HTTP method, a path that ends the same
  /// way and the same method name wins. Else a single method with the
  /// same name and argument types wins. Else it returns null.
  OpenApiOperation? find(
    String httpMethod,
    String path,
    String functionName,
    List<String> argumentTypes, {
    String? controller,
  }) {
    _RegistryIndex index = _index();
    String method = httpMethod.toUpperCase();
    // A route path comes from Dox, where a `:` is not a param.
    String openApiPath = PathConverter.path(path, colonParams: false);
    OpenApiRouteBinding? best;
    int bestLength = 0;
    for (_IndexedBinding entry in index.bindingsFor(method, functionName)) {
      OpenApiRouteBinding binding = entry.binding;
      if (!_sameName(binding, functionName, controller)) continue;
      String? bindingPath = entry.path;
      if (bindingPath != null && !_endsWith(openApiPath, bindingPath)) {
        continue;
      }
      int length = bindingPath?.length ?? 0;
      if (best == null || length > bestLength) {
        best = binding;
        bestLength = length;
      }
    }
    if (best != null) {
      OpenApiOperation? op = index.byId[best.operation];
      if (op != null) return op;
    }
    OpenApiOperation? found;
    for (OpenApiOperation op in index.operationsNamed(functionName)) {
      if (!_sameTypes(op, argumentTypes)) continue;
      if (controller != null && op.controller != controller) continue;
      if (found != null) return null;
      found = op;
    }
    return found;
  }

  /// Gets the lookup index, and builds it on the first call.
  _RegistryIndex _index() {
    _RegistryIndex? index = _indexes[this];
    if (index == null) {
      index = _RegistryIndex(operations, routes);
      _indexes[this] = index;
    }
    return index;
  }

  bool _sameName(
    OpenApiRouteBinding binding,
    String functionName,
    String? controller,
  ) {
    if (controller != null) {
      return binding.operation == '$controller.$functionName';
    }
    return binding.operation.endsWith('.$functionName');
  }

  bool _endsWith(String path, String suffix) {
    return suffix == '/'
        ? path == '/'
        : path == suffix || path.endsWith(suffix);
  }

  bool _sameTypes(OpenApiOperation op, List<String> types) {
    if (op.argumentTypes.length != types.length) return false;
    for (int i = 0; i < types.length; i++) {
      if (op.argumentTypes[i] != types[i]) return false;
    }
    return true;
  }
}

/// One lookup index per registry. A registry is a const class, so the
/// index is kept here and not in a field.
final Expando<_RegistryIndex> _indexes = Expando<_RegistryIndex>(
  'OpenApiRegistry index',
);

/// A route call with its path already turned into an OpenAPI path.
class _IndexedBinding {
  final OpenApiRouteBinding binding;

  /// [OpenApiRouteBinding.path] after `PathConverter.path`. Null stays null.
  final String? path;

  _IndexedBinding(this.binding, this.path);
}

/// Lookup tables for [OpenApiRegistry.find], built once per registry.
///
/// Before, `find` looped over every route call and every operation for each
/// live route. With many routes, building the docs took seconds.
///
/// The index keeps the list order, so `find` gives the same answer as before.
/// It is built from the lists as they are on the first `find` call.
class _RegistryIndex {
  /// Route calls by HTTP method, then by the name after the last `.` of
  /// [OpenApiRouteBinding.operation]. Route calls without a `.` are left
  /// out: they can never match.
  final Map<String, Map<String, List<_IndexedBinding>>> _byName =
      <String, Map<String, List<_IndexedBinding>>>{};

  /// All route calls by HTTP method. Used when the function name has a `.`.
  final Map<String, List<_IndexedBinding>> _byMethod =
      <String, List<_IndexedBinding>>{};

  /// Operations by id. The first one wins when two share an id.
  final Map<String, OpenApiOperation> byId = <String, OpenApiOperation>{};

  /// Operations by method name.
  final Map<String, List<OpenApiOperation>> _operationsByName =
      <String, List<OpenApiOperation>>{};

  _RegistryIndex(
    List<OpenApiOperation> operations,
    List<OpenApiRouteBinding> routes,
  ) {
    for (OpenApiRouteBinding binding in routes) {
      String? raw = binding.path;
      _IndexedBinding entry = _IndexedBinding(
        binding,
        raw == null ? null : PathConverter.path(raw, colonParams: false),
      );
      _byMethod.putIfAbsent(binding.method, _newBindingList).add(entry);
      int dot = binding.operation.lastIndexOf('.');
      if (dot < 0) continue;
      String name = binding.operation.substring(dot + 1);
      _byName
          .putIfAbsent(binding.method, _newBindingMap)
          .putIfAbsent(name, _newBindingList)
          .add(entry);
    }
    for (OpenApiOperation op in operations) {
      String id = op.id;
      if (!byId.containsKey(id)) byId[id] = op;
      _operationsByName.putIfAbsent(op.method, _newOperationList).add(op);
    }
  }

  /// Route calls that may match [functionName] for [method], in list order.
  ///
  /// A name without a `.` can only end an operation after its last `.`, so
  /// the group by name is enough. A name with a `.`, like `b.show`, can
  /// match `A.b.show`, so then all route calls of the method are checked.
  List<_IndexedBinding> bindingsFor(String method, String functionName) {
    if (functionName.contains('.')) {
      return _byMethod[method] ?? const <_IndexedBinding>[];
    }
    return _byName[method]?[functionName] ?? const <_IndexedBinding>[];
  }

  /// Operations with the method name [name], in list order.
  List<OpenApiOperation> operationsNamed(String name) {
    return _operationsByName[name] ?? const <OpenApiOperation>[];
  }

  static List<_IndexedBinding> _newBindingList() {
    return <_IndexedBinding>[];
  }

  static Map<String, List<_IndexedBinding>> _newBindingMap() {
    return <String, List<_IndexedBinding>>{};
  }

  static List<OpenApiOperation> _newOperationList() {
    return <OpenApiOperation>[];
  }
}
