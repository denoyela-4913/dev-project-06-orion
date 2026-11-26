// Chargé avant chaque fichier de test (angular.json, cible `test`).
// Jasmine retirait les espions après chaque test. Vitest remet leurs appels à zéro mais les laisse en place:
// sans ceci, la fausse implémentation posée par un test s'appliquerait encore aux suivants.
afterEach(() => {
  vi.restoreAllMocks();
});
