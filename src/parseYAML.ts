import { parse } from "yaml"

export function parseYAML(input: string): any {
  return parse(input, {
    merge: true,
  })
}
