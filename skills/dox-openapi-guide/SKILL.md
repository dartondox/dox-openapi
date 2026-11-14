---
name: dox-openapi-guide
description: Use when you turn on or change API docs in a Dox (Dart) app, open /docs, tune the generated OpenAPI 3.1 document with annotations (@Summary, @Response, @Security, @ApiIgnore), write openapi.json files, or build a document by hand with dox_openapi.
---

# dox_openapi guide

`dox_openapi` makes an OpenAPI 3.1 document (JSON and YAML) and serves a Scalar or Swagger UI page.
In a Dox app you write almost no docs code. `dox_builder` reads your routes, DTOs and controllers, and `dox_core` serves the pages.
For routes, controllers and DTO basics, see the dox-core-guide skill.

## Install

A Dox app already has it through `dox_core`. Add no package.
For use outside Dox only: `dart pub add dox_openapi`.

## Turn it on in a Dox app

1. Run the builder. It writes `lib/generated/openapi.g.dart`.

```bash
dart run build_runner build --delete-conflicting-outputs   # or: dox build_runner:build
```

Run it again after you change routes, controllers, DTOs or models. `dox build_runner:watch` does it while you work.

2. Make the config in `lib/config/openapi.dart`:

```dart
import 'package:dox_core/dox_core.dart';
import 'package:my_app/generated/openapi.g.dart';

OpenApiConfig openApi = OpenApiConfig(
  info: Info(title: 'Blog API', version: '1.0.0'),
  registry: openApiRegistry,
);
```

3. Pass it to `AppConfig` in `lib/config/app.dart`:

```dart
AppConfig appConfig = AppConfig(
  openApi: openApi,
  // ...
);
```

4. Start the app and open `http://localhost:3000/docs`.

Routes: `GET /docs` (the page), `GET /openapi.json`, `GET /openapi.yaml`.
The document is built on the first request, then kept.

## OpenApiConfig options

| Option | Default | What it does |
| --- | --- | --- |
| `enabled` | `null` | `true` or `false` forces the routes on or off. `null`: on only when `APP_ENV` is `development` or `local` |
| `info` | `Info(title: 'Dox API', version: '1.0.0')` | title and version |
| `servers` | `[]` | base URLs, like `[Server('https://api.my.app')]` |
| `registry` | empty | `openApiRegistry` from the generated file |
| `securitySchemes`, `securityByMiddleware` | `{}` | login schemes by hand |
| `ui` | `DocsUi.scalar` | `DocsUi.scalar` or `DocsUi.swagger` |
| `scalar` | `ScalarOptions()` | `theme`, `darkMode`, `showDownloadButton`, `proxyUrl` |
| `pageTitle` | `info.title` | title of the `/docs` page |
| `include` | `[]` (all) | only these paths, like `['/api/*']` |
| `exclude` | `[]` | leave these paths out, like `['/api/internal/*']` |

```dart
OpenApiConfig(
  registry: openApiRegistry,
  ui: DocsUi.swagger,
  scalar: ScalarOptions(theme: ScalarTheme.purple, darkMode: true),
  exclude: <String>['/api/internal/*'],
);
```

## Describe a route

Put annotations on a controller method. They come from `dox_core`.

```dart
class BlogController {
  @Summary('Get one blog')
  @Description('Deleted blogs are not found.')
  @Tags(<String>['Blogs'])
  Future<Blog?> show(DoxRequest req, String id) async {
    return Blog().find(id);
  }

  @Summary('Create a blog')
  @Response(201, Blog, description: 'The new blog')
  Future<DoxResponse> store(CreateBlog body) async { ... }
}
```

Another example:

```dart
@Summary('Log in')
@Description('Gives a bearer token for the Authorization header.')
@Tags(<String>['Auth'])
@Request(LoginUser)
@Response(200, LoginResult)
@Response(401, null, description: 'Wrong email or password')
Future<dynamic> login(DoxRequest req) async { ... }
```

| Annotation | Effect |
| --- | --- |
| `@Summary`, `@Description` | short title and longer text. Default: the `///` comment |
| `@Tags([...])` | groups, on a method or a class |
| `@Request(T)`, `@Body(T)`, `@Query(T)` | the request class |
| `@Response(status, Type, description: '')` | one answer. Add more for more codes |
| `@ApiDeprecated()` | marks the route deprecated |
| `@ApiIgnore()` | hides a method or a whole class |
| `@DoxController(tag: 'Users')` | for a class the builder can not see in a `Route.get(...)` call |

Use `@Response` when the method returns `DoxResponse` or `dynamic`. The builder can not see the body then.
The `Type` can be a model, `List<User>`, a `@Dto` or a basic type.

## What the builder finds on its own (and `///` comments)

Annotations are optional. A normal controller already gets docs. The builder fills in the rest.

```dart
class BlogController {
  Future<Blog?> show(DoxRequest req, String id) async {
    return Blog().find(id);
  }

  Future<Blog> store(CreateBlog body) async { ... }
}
```

| Docs part | Source |
| --- | --- |
| path, method | the live route table |
| path param types | controller arguments after the first one (`int id` gives `integer`) |
| tags | class name without `Controller` |
| operationId | `Class.method` |
| summary | `@Summary`. Else the first line of the `///` comment |
| description | `@Description`. Else the rest of the `///` comment |
| request | `@Body(T)`, `@Query(T)` or `@Request(T)`; else an argument of a `@Dto` type; else a `req.validate<T>()` call |
| 200 answer | the return type (`Future<T>` counts as `T`) |
| `401`, `403` | auth middleware, `Can`, `GuestMiddleware`, `ValidateSignature`, `req.authorize(...)`, `Gate.authorize(...)` |
| `404` | the path has a `{param}` |
| `422` | a request class, `req.validate<T>()` or `req.validateSchema(...)` |
| `500` | every route |

For `POST`, `PUT` and `PATCH` the request is the JSON body. For other methods each field is a query param.
`@Dto(source: Source.query)` or `Source.body` picks the place by hand.
A route with `{id?}` gives two paths, `/blog/{id}` and `/blog`.

A `///` comment on a method also works for the summary and the description. The first line is the summary. The rest is the description. When a method has both, the annotation wins.

```dart
/// Get one blog
///
/// Deleted blogs are not found.
Future<Blog?> show(DoxRequest req, String id) async { ... }
```

## Login schemes

Put `@Security` above a middleware class. Every route with it gets the scheme.

```dart
@Security.bearer(format: 'API key')
class ApiKeyAuthMiddleware implements IDoxMiddleware { ... }

@Security.apiKey(header: 'X-API-Key')
class HeaderKeyMiddleware implements IDoxMiddleware { ... }
```

A middleware without `@Security` whose class name ends with `AuthMiddleware` gets `bearerAuth` (bearer, no format).
To use a key in a query or a cookie, set `securitySchemes` and `securityByMiddleware` in `OpenApiConfig`. The config wins over `@Security`.

```dart
OpenApiConfig(
  registry: openApiRegistry,
  securitySchemes: <String, SecurityScheme>{
    'apiKey': SecurityScheme.apiKey(name: 'X-API-Key'),
  },
  securityByMiddleware: <String, List<Map<String, List<String>>>>{
    'ApiKeyMiddleware': <Map<String, List<String>>>[
      <String, List<String>>{'apiKey': <String>[]},
    ],
  },
);
```

## Write the files

```bash
dox openapi:generate              # storage/openapi/openapi.json and openapi.yaml
dox openapi:generate docs/api     # another folder
```

It runs `bin/openapi.dart` of your app. A new app has no such file. Make it:

```dart
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/app.dart';

Future<void> main(List<String> args) async {
  Dox().initialize(appConfig);
  await Dox().writeOpenApi(args.isEmpty ? 'storage/openapi' : args.first);
  exit(0);
}
```

## Without Dox

```dart
import 'package:dox_openapi/dox_openapi.dart';

ApiDoc docs = ApiDoc();
Map<String, dynamic> user = docs.schema('User', userSchema); // returns a $ref

docs.route('GET', '/users/{id}',
    summary: 'Get one user',
    tags: <String>['users'],
    params: <String, Object>{'id': <String, dynamic>{'type': 'integer'}},
    responses: <int, ResponseDoc>{
      200: ResponseDoc(schema: user, description: 'The user'),
      404: const ResponseDoc(description: 'Not found'),
    },
    namedResponses: <String, ResponseDoc>{ // text keys: default, 2XX
      'default': const ResponseDoc(description: 'Any other error'),
    });

OpenApi api = OpenApi(
  info: const Info(title: 'My API', version: '1.0.0'),
  servers: const <Server>[Server('http://localhost:3000')],
  securitySchemes: <String, SecurityScheme>{'bearerAuth': SecurityScheme.bearer()},
  docs: docs,
);

api.toJson();                             // Map
api.toYaml();                             // YAML text
await api.writeFiles('storage/openapi');  // openapi.json + openapi.yaml

OpenApiServer server = OpenApiServer(api); // ui: DocsUi.swagger for Swagger
OpenApiResponse? page = server.handle('/docs'); // also /openapi.json, /openapi.yaml
```

- A schema can be a JSON Schema `Map`, a `dox_validation` schema, or any object with `toJsonSchema()`.
- `DoxRouteAdapter().addTo(docs, routes)` adds a basic entry for each route you did not describe.
- `OpenApiServer.handle` returns `null` for other paths. Send `page.body` with the header `Content-Type: page.contentType`.

## Gotchas

- If `APP_ENV` is not set, Dox treats the app as production. `/docs` is off. Set `APP_ENV=development` in `.env` and in CI, or set `enabled: true`.
- The docs are stale until you run the builder again. A new route with no docs usually means the builder did not run.
- Two controllers can have a method with the same name, like `index`. Name the class in the route, like `(LinkController c) => c.index`, so the right docs match.
- Inline closure routes still get a basic entry, with no types.
- The Scalar page loads from the jsDelivr CDN. It needs internet in the browser.
- `/docs` has no login. Do not turn it on in production without a reason.
- OpenAPI path params are always required. That is why `{id?}` makes two paths.
