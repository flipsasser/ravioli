export class KeyMissingError extends Error {}
Object.defineProperty(KeyMissingError.prototype, "name", {
  value: KeyMissingError.name,
})

export class ParseError extends Error {}
Object.defineProperty(ParseError.prototype, "name", {
  value: ParseError.name,
})

// export function warn(message, error?: Error, strict?: boolean) {
//   console.warn(message, error)

//   if (strict) {
//     throw error
//   }
// }
