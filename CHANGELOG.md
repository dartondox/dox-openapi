## 3.1.0

- Fix: an optional route param `{id?}` showed as a required param, so the route without the id was missing from the document. Now `/blog/{id?}` gives two paths: `/blog/{id}` and `/blog`. OpenAPI path params must always be required, so this is the only correct way to show it. An optional param in the middle works too: `/a/{x?}/b` gives `/a/{x}/b` and `/a/b`. Optional params next to each other are dropped from the right, the same way the Dox router matches them. A route that is documented on the shorter path itself still wins.
- The shorter path of an optional route now has its own summary and operation id. Before, `/greet` showed the summary `GET /greet/{name}` and the long id `getGreetByNameWithoutName`. Now it shows `GET /greet` and `getGreet`. This only happens when the summary and id were made from the path. A custom summary stays, and a custom id still gets a `Without<Name>` ending. Operation ids of routes without optional params do not change.
- New: `paramResponses` on `RouteDoc`. These are answers that only happen when the path has a param, like `404` when no record has the id. The shorter path of an optional route leaves them out when it has no params left.
- New: `DoxRouteAdapter` puts the `body` of a GET or DELETE route in the query string, like dox_core does. Before, it became a request body, so the query params were missing from the docs. A schema without properties stays a body.
- New: `namedResponses` on `RouteDoc` and `ApiDoc.route`. It takes responses with a text key, like `default` or `2XX`. The `responses` map still uses `int` keys and works as before.

## 3.0.0

- The first stable release.
- The package now lives in its own repo: [dartondox/dox-openapi](https://github.com/dartondox/dox-openapi). Nothing changes for users: same package name, same API.

## 3.0.0-rc.1

- Version bump only, to match the other packages.

## 3.0.0-alpha.17

- Version bump only, to match the other packages.

## 3.0.0-alpha.16

- Version bump only, to match the other packages.

## 3.0.0-alpha.15

- Version bump only, to match the other packages.

## 3.0.0-alpha.14

- New: `OpenApiSecurity` and `OpenApiRegistry.security`: login schemes by middleware class name, from `@Security`.

## 3.0.0-alpha.13

- Version bump only, to match the other packages.

## 3.0.0-alpha.12

- Fix: two controllers with the same method name (like `login`) could swap their docs. `OpenApiRegistry.find` now takes `controller:`. When the route knows its controller class, only methods of that class match.

## 3.0.0-alpha.11

- Version bump only, to match the other packages.

## 3.0.0-alpha.10

- Version bump only, to match the other packages.

## 3.0.0-alpha.9

- Version bump only, to match the other packages.

## 3.0.0-alpha.8

- Version bump only, to match the other packages.

## 3.0.0-alpha.7

- The `/docs` page loads its CDN files with an `integrity` hash, so the browser refuses a changed file.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- Version bump only, to match the other packages.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- A request body with a file field (`format: binary`, also in a list) uses `multipart/form-data` instead of `application/json`, so the `/docs` page can send files. `RouteDoc(bodyMediaType:)` sets it by hand.
- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- `DoxRouteAdapter` reads `preMiddleware` and `body` from a route when it has them.
- A Dox catch-all param `{path*}` and an optional param `{id?}` become `{path}` and `{id}` in the document.
- `OpenApiOperation.formRequest` is removed (form requests are gone).
- New `OpenApiRegistry`, `OpenApiOperation` and `OpenApiRouteBinding`: the docs that `dox_builder` finds in the code. `OpenApiRegistry.find()` matches them to a live route.
- `RouteDoc` and `ApiDoc.route()` take `deprecated`.
- `OpenApiServer` builds and encodes the document once, on the first call, and keeps it. Make a new `OpenApiServer` after you change the `OpenApi`.
- `OpenApi.yamlEmitter` is now a public field.
- `/docs` uses Scalar (`@scalar/api-reference` 1.75.1) by default. `OpenApiServer(ui: DocsUi.swagger)` gives Swagger UI. `ScalarOptions` sets the theme, dark mode, download button and proxy (off by default). The title and the config are escaped.
- Swagger UI updated to 5.34.0.

## 3.0.0-alpha.1

- First release.
- Build an OpenAPI 3.1 document with `OpenApi` and `ApiDoc`.
- Add undocumented Dox routes with `DoxRouteAdapter`.
- Output as JSON and YAML, write files, serve `/openapi.json`, `/openapi.yaml` and `/docs`.
