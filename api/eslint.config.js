// ESLint 9 flat config. The older .eslintrc format and the --ext flag were both
// removed in v9; file selection lives in the `files` patterns below instead.
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['dist/**', 'node_modules/**'],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
    },
    rules: {
      // The AGPL boundary is enforced by scripts/check_agpl_boundary.sh, not here.
      // These rules cover the standards in CLAUDE.md: strict types, no `any`.
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/explicit-function-return-type': 'error',
      'no-console': ['error', { allow: ['warn', 'error'] }],
    },
  },
);
