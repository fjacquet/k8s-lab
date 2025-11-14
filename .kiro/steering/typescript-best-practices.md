---
inclusion: fileMatch
fileMatchPattern: ['**/*.ts', '**/*.tsx', '**/tsconfig.json']
---

## TypeScript Configuration

- Enable strict mode in `tsconfig.json`: `"strict": true`
- Enable `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`
- Use `noUncheckedIndexedAccess` for safer array/object access
- Configure path aliases for cleaner imports

## Naming Conventions

- **PascalCase**: Classes, interfaces, type aliases, enums (`UserProfile`, `ApiResponse`)
- **camelCase**: Variables, functions, methods, parameters (`userName`, `fetchData`)
- **UPPER_SNAKE_CASE**: Global constants, enum values (`MAX_RETRIES`, `API_BASE_URL`)
- **Prefix interfaces with 'I' only when necessary** to distinguish from classes

## Type Safety Rules

- **Always declare explicit return types** for functions and methods
- **Never use `any`** - use `unknown` for truly unknown types, then narrow with type guards
- **Prefer `interface` over `type`** for object shapes (better error messages, declaration merging)
- **Use `type` for unions, intersections, and mapped types**
- **Leverage generics** for reusable, type-safe components and functions
- **Use discriminated unions** for complex state management

## Modern TypeScript Patterns

- Use **optional chaining** (`?.`) to safely access nested properties
- Use **nullish coalescing** (`??`) instead of `||` for default values
- Use **template literal types** for string validation
- Use **const assertions** (`as const`) for literal types
- Use **satisfies operator** to validate types without widening

## Error Handling

- Create **custom error classes** extending `Error` with specific properties
- Use **Result/Either patterns** for expected errors (avoid throwing)
- Type error objects explicitly: `catch (error: unknown)`
- Use **type guards** to narrow error types before handling

## Import/Export Standards

- **Prefer named exports** over default exports (better refactoring, tree-shaking)
- **Group imports** in this order:
  1. External libraries (React, lodash, etc.)
  2. Internal modules (utils, components, types)
  3. Relative imports (./components, ../utils)
- **Use absolute imports** with path aliases (`@/components` vs `../../components`)
- **Export types separately** when needed: `export type { User, ApiResponse }`

## Code Organization

- **Colocate types** with their usage when specific to one module
- **Create shared types** in dedicated `types/` directory for cross-module usage
- **Use barrel exports** (`index.ts`) sparingly - only for public APIs
- **Separate business logic** from framework code (React, Express, etc.)

## Testing Considerations

- Write tests for all public functions and exported utilities
- Use type assertions in tests: `expect<Type>(value).toBe(...)`
- Mock external dependencies with proper typing
- Run tests silently in automated contexts: `npm test -- --silent`
