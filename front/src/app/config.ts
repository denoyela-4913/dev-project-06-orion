declare global {
  interface Window {
    // Défini par /config.js, chargé par index.html avant l'application.
    MICROCRM_CONFIG?: { apiBaseUrl?: string }
  }
}

const DEFAULT_API_BASE_URL = "http://localhost:8080"

// Une valeur absente ou vide garde l'adresse du back lancé en local.
export const resolveApiBaseUrl = (config: Window['MICROCRM_CONFIG']): string =>
  config?.apiBaseUrl || DEFAULT_API_BASE_URL

export const API_BASE_URL = resolveApiBaseUrl(window.MICROCRM_CONFIG)
