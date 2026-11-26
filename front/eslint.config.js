// Lint du front (job `lint` de la CI, `npm run lint`).
// Socles recommandés d'ESLint, typescript-eslint et angular-eslint (TypeScript et templates, accessibilité
// comprise), plus les règles qui ont besoin des types : une promesse ni attendue ni traitée est une erreur
// (défaut déjà corrigé dans les composants, cf. docs/BACKLOG.md).
const eslint = require('@eslint/js');
const { defineConfig } = require('eslint/config');
const tseslint = require('typescript-eslint');
const angular = require('angular-eslint');

module.exports = defineConfig([
  { ignores: ['dist/**', 'coverage/**', '.angular/**'] },
  {
    files: ['src/**/*.ts'],
    extends: [
      eslint.configs.recommended,
      tseslint.configs.recommended,
      angular.configs.tsRecommended,
    ],
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: __dirname },
    },
    processor: angular.processInlineTemplates,
    rules: {
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      // Désactivée : les composants modifient leur état après des promesses et comptent sur la détection de
      // changement par défaut (zone.js). Passer en OnPush sans revoir cet état figerait l'affichage ; c'est un
      // chantier à part (cf. docs/BACKLOG.md).
      '@angular-eslint/prefer-on-push-component-change-detection': 'off',
    },
  },
  {
    files: ['src/**/*.html'],
    extends: [angular.configs.templateRecommended, angular.configs.templateAccessibility],
  },
]);
