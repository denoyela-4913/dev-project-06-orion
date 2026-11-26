// Réponse « collection » de Spring Data REST (format HAL): la liste est sous `_embedded.<nom de la ressource>`.
export interface HalCollection<Name extends string, Item> {
  _embedded: Record<Name, Item[]>
}
