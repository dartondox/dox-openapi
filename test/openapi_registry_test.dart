import 'package:dox_openapi/dox_openapi.dart';
import 'package:test/test.dart';

const OpenApiRegistry registry = OpenApiRegistry(
  operations: <OpenApiOperation>[
    OpenApiOperation(
      controller: 'BlogController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
    ),
    OpenApiOperation(
      controller: 'UserController',
      method: 'index',
      argumentTypes: <String>['DoxRequest'],
    ),
    OpenApiOperation(
      controller: 'UserController',
      method: 'show',
      argumentTypes: <String>['DoxRequest', 'String'],
    ),
  ],
  routes: <OpenApiRouteBinding>[
    OpenApiRouteBinding('GET', 'blogs', 'BlogController.index'),
    OpenApiRouteBinding('GET', '/users', 'UserController.index'),
    OpenApiRouteBinding('GET', null, 'UserController.index'),
  ],
);

List<String> request = <String>['DoxRequest'];

void main() {
  group('OpenApiRegistry |', () {
    test('a colon in a route path is not a param', () {
      const OpenApiRegistry colon = OpenApiRegistry(
        operations: <OpenApiOperation>[
          OpenApiOperation(
            controller: 'ParamController',
            method: 'run',
            argumentTypes: <String>['DoxRequest'],
          ),
          OpenApiOperation(
            controller: 'SearchController',
            method: 'run',
            argumentTypes: <String>['DoxRequest'],
          ),
        ],
        routes: <OpenApiRouteBinding>[
          OpenApiRouteBinding('GET', '/books{search}', 'ParamController.run'),
          OpenApiRouteBinding('GET', '/books:search', 'SearchController.run'),
        ],
      );
      expect(
        colon.find('GET', '/books:search', 'run', request)?.id,
        'SearchController.run',
      );
      expect(
        colon.find('GET', '/books{search}', 'run', request)?.id,
        'ParamController.run',
      );
    });

    test('a route call with the same path end wins', () {
      expect(
        registry.find('GET', '/api/blogs', 'index', request)?.id,
        'BlogController.index',
      );
      expect(
        registry.find('get', '/api/v1/users/', 'index', request)?.id,
        'UserController.index',
      );
    });

    test('a route call without a plain path matches any path', () {
      expect(
        registry.find('GET', '/people', 'index', request)?.id,
        'UserController.index',
      );
    });

    test('else one method with the same name and types', () {
      expect(
        registry.find('GET', '/x/{id}', 'show', <String>[
          'DoxRequest',
          'String',
        ])?.id,
        'UserController.show',
      );
      expect(
        registry.find('GET', '/x/{id}', 'show', <String>['DoxRequest']),
        isNull,
      );
    });

    test('two methods with the same name and no route call: none', () {
      expect(registry.find('POST', '/blogs', 'index', request), isNull);
    });

    test('two controllers with the same method name never mix', () {
      // `/login` ends both live paths. Without the controller, the docs
      // of WebAuthController.login went to POST /api/auth/login.
      const OpenApiRegistry logins = OpenApiRegistry(
        operations: <OpenApiOperation>[
          OpenApiOperation(
            controller: 'AuthController',
            method: 'login',
            argumentTypes: <String>['DoxRequest'],
          ),
          OpenApiOperation(
            controller: 'WebAuthController',
            method: 'login',
            argumentTypes: <String>['DoxRequest'],
          ),
        ],
        routes: <OpenApiRouteBinding>[
          OpenApiRouteBinding('POST', 'api/login', 'AuthController.login'),
          OpenApiRouteBinding('POST', '/login', 'WebAuthController.login'),
        ],
      );
      expect(
        logins
            .find(
              'POST',
              '/api/auth/login',
              'login',
              request,
              controller: 'AuthController',
            )
            ?.id,
        'AuthController.login',
      );
      expect(
        logins
            .find(
              'POST',
              '/web-auth/login',
              'login',
              request,
              controller: 'WebAuthController',
            )
            ?.id,
        'WebAuthController.login',
      );
    });
    test('two controllers with the same method name pick the right op', () {
      const OpenApiRegistry shows = OpenApiRegistry(
        operations: <OpenApiOperation>[
          OpenApiOperation(controller: 'PostController', method: 'show'),
          OpenApiOperation(controller: 'TagController', method: 'show'),
        ],
        routes: <OpenApiRouteBinding>[
          OpenApiRouteBinding('GET', '/posts/{id}', 'PostController.show'),
          OpenApiRouteBinding('GET', '/tags/{id}', 'TagController.show'),
        ],
      );
      expect(
        shows.find('GET', '/posts/{id}', 'show', <String>[])?.id,
        'PostController.show',
      );
      expect(
        shows.find('GET', '/tags/{id}', 'show', <String>[])?.id,
        'TagController.show',
      );
      expect(shows.find('POST', '/tags/{id}', 'show', <String>[]), isNull);
    });

    test('the longest matching path end wins, the first on a tie', () {
      const OpenApiRegistry nested = OpenApiRegistry(
        operations: <OpenApiOperation>[
          OpenApiOperation(controller: 'A', method: 'list'),
          OpenApiOperation(controller: 'B', method: 'list'),
          OpenApiOperation(controller: 'C', method: 'list'),
        ],
        routes: <OpenApiRouteBinding>[
          OpenApiRouteBinding('GET', 'items', 'A.list'),
          OpenApiRouteBinding('GET', 'admin/items', 'B.list'),
          OpenApiRouteBinding('GET', 'admin/items', 'C.list'),
        ],
      );
      expect(
        nested.find('GET', '/api/admin/items', 'list', <String>[])?.id,
        'B.list',
      );
      expect(
        nested.find('GET', '/api/items', 'list', <String>[])?.id,
        'A.list',
      );
    });

    test('a function name with a dot still matches the operation end', () {
      const OpenApiRegistry dotted = OpenApiRegistry(
        operations: <OpenApiOperation>[
          OpenApiOperation(controller: 'A.b', method: 'show'),
        ],
        routes: <OpenApiRouteBinding>[
          OpenApiRouteBinding('GET', '/x', 'A.b.show'),
        ],
      );
      expect(dotted.find('GET', '/x', 'b.show', <String>[])?.id, 'A.b.show');
      expect(dotted.find('GET', '/x', 'show', <String>[])?.id, 'A.b.show');
    });

    test('the same registry gives the same answer each time', () {
      for (int i = 0; i < 3; i++) {
        expect(
          registry.find('GET', '/api/blogs', 'index', request)?.id,
          'BlogController.index',
        );
        expect(registry.find('POST', '/blogs', 'index', request), isNull);
      }
    });

    test('a big registry still matches each route', () {
      List<OpenApiOperation> operations = <OpenApiOperation>[];
      List<OpenApiRouteBinding> routes = <OpenApiRouteBinding>[];
      for (int i = 0; i < 2000; i++) {
        operations.add(OpenApiOperation(controller: 'C$i', method: 'show'));
        operations.add(OpenApiOperation(controller: 'C$i', method: 'm$i'));
        routes.add(OpenApiRouteBinding('GET', '/r$i/{id}', 'C$i.show'));
        routes.add(OpenApiRouteBinding('POST', '/r$i', 'C$i.m$i'));
      }
      OpenApiRegistry big = OpenApiRegistry(
        operations: operations,
        routes: routes,
      );
      for (int i = 0; i < 2000; i++) {
        expect(
          big.find('GET', '/api/r$i/{id}', 'show', <String>[])?.id,
          'C$i.show',
        );
        expect(big.find('POST', '/r$i', 'm$i', <String>[])?.id, 'C$i.m$i');
      }
      // No route call for this path end, and many `show` methods: none.
      expect(big.find('GET', '/nope', 'show', <String>[]), isNull);
    });
  });
}
