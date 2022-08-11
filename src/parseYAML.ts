import { parse } from "yaml"

export function parseYAML(input: string): any {
  try {
    const parsed = parse(input, {
      merge: true,
    })
    return parsed
  } catch (_) {
    return {}
  }
}
