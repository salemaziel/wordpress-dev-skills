```markdown
# wordpress-dev-skills Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches best practices for developing TypeScript-based WordPress utilities and modules, as exemplified by the `wordpress-dev-skills` repository. It covers coding conventions, commit patterns, file organization, and testing approaches to ensure consistency and maintainability in WordPress development workflows.

## Coding Conventions

### File Naming
- Use **camelCase** for file names.
  - Example: `userProfile.ts`, `postUtils.ts`

### Import Style
- Use **relative imports** for internal modules.
  - Example:
    ```typescript
    import { getUserData } from './userProfile';
    ```

### Export Style
- Use **named exports** for all modules.
  - Example:
    ```typescript
    // In postUtils.ts
    export function getPostTitle(postId: number): string {
      // ...
    }
    ```

### Commit Messages
- Follow the **Conventional Commits** format.
- Use the `feat` prefix for new features.
  - Example:
    ```
    feat: add function to fetch user meta by ID
    ```

## Workflows

### Feature Development
**Trigger:** When adding a new feature or utility function  
**Command:** `/feature-development`

1. Create a new TypeScript file using camelCase naming.
2. Implement the feature using named exports.
3. Use relative imports for dependencies.
4. Write a corresponding test file named `*.test.ts`.
5. Commit changes using the `feat:` prefix and a concise description.

### Code Importing
**Trigger:** When importing code from another module  
**Command:** `/import-module`

1. Use a relative path to import the required function or constant.
2. Import only what you need using named imports.
   - Example:
     ```typescript
     import { getPostTitle } from './postUtils';
     ```

### Testing
**Trigger:** When verifying code correctness  
**Command:** `/run-tests`

1. Create or update a test file matching the `*.test.ts` pattern.
2. Write tests for all exported functions.
3. Run the test suite using your preferred TypeScript-compatible test runner.

## Testing Patterns

- Test files are named using the pattern `*.test.ts`.
- Each exported function should have corresponding tests.
- The testing framework is not specified; use a TypeScript-compatible runner (e.g., Jest, Mocha).
- Example test file:
  ```typescript
  // userProfile.test.ts
  import { getUserData } from './userProfile';

  describe('getUserData', () => {
    it('returns user data for a valid ID', () => {
      expect(getUserData(1)).toEqual({ id: 1, name: 'Alice' });
    });
  });
  ```

## Commands
| Command               | Purpose                                    |
|-----------------------|--------------------------------------------|
| /feature-development  | Start a new feature or utility module      |
| /import-module        | Import a function or constant from a module|
| /run-tests            | Run the test suite                         |
```