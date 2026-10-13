import { BaseRuleVisitor, ParserRule, getAttributes, getAttributeName, locationFromContentOffset } from "@herb-tools/linter"

const COLOR_PROPERTY = String.raw`(?:color|background(?:-color)?|[\w-]+-color|fill|stroke)`
const BRACKETED_COLOR = new RegExp(String.raw`-\[(?:color:)?(?:#|(?:rgba?|hsla?|oklch|oklab|lab|lch|hwb|color-mix|color)\()|^(?:[\w-]+:)*\[${COLOR_PROPERTY}:`, "i")
const PRIMITIVE = /--(?:(?:slate|gold|green|red)-\d+|white)\b/
const STYLE_COLOR = new RegExp(String.raw`(?:^|;)\s*${COLOR_PROPERTY}\s*:`, "i")
const RUBY_OPTION = /\b(class|style):\s*/g

class ColorsVisitor extends BaseRuleVisitor {
  constructor(ruleName, context, source) {
    super(ruleName, context)
    this.lines = source.split("\n")
  }

  visitHTMLOpenTagNode(node) {
    this.checkAttributes(node)
    super.visitHTMLOpenTagNode(node)
  }

  // link_to and tag.* parse into elements whose open tag is ERB.
  visitERBOpenTagNode(node) {
    this.checkAttributes(node)
    super.visitERBOpenTagNode(node)
  }

  // button_to and form builder calls stay Ruby, so read their class: and style: options from the code.
  visitERBContentNode(node) {
    const code = node.content?.value ?? ""
    const { line, column } = node.content?.location.start ?? {}
    for (const match of code.matchAll(RUBY_OPTION)) {
      for (const string of this.optionValueStrings(code, match.index + match[0].length)) {
        const location = locationFromContentOffset(line, column, code, string.index)
        if (match[1] === "class") {
          this.checkClasses(string.value, location)
        } else {
          this.checkStyle(string.value, location)
        }
      }
    }
    super.visitERBContentNode(node)
  }

  checkAttributes(node) {
    for (const attribute of getAttributes(node)) {
      const name = getAttributeName(attribute)
      if (attribute.value && name === "class") {
        this.checkClasses(this.sourceAt(attribute.value.location), attribute.location)
      } else if (attribute.value && name === "style") {
        this.checkStyle(this.sourceAt(attribute.value.location).replace(/^["']|["']$/g, ""), attribute.location)
      }
    }
  }

  checkClasses(classes, location) {
    for (const token of classes.split(/[\s"']+/)) {
      if (BRACKETED_COLOR.test(token)) {
        this.addOffense(`Replace \`${token}\` with a semantic color utility such as bg-level-2, text-secondary, border-primary, or ring-focus. Tokens live in app/assets/tailwind/application.css.`, location)
      } else if (PRIMITIVE.test(token)) {
        this.addOffense(`Replace \`${token}\` with a semantic token. Raw primitives like --slate-* only feed the tokens in app/assets/tailwind/application.css.`, location)
      }
    }
  }

  checkStyle(style, location) {
    if (STYLE_COLOR.test(style)) {
      this.addOffense(`Move the color in \`style="${style.trim()}"\` to a semantic color utility such as bg-level-2 or text-secondary. Tokens live in app/assets/tailwind/application.css.`, location)
    }
  }

  optionValueStrings(code, start) {
    const strings = []
    const array = code[start] === "["
    let index = array ? start + 1 : start
    while (index < code.length) {
      const char = code[index]
      if (char === `"` || char === "'") {
        const end = code.indexOf(char, index + 1)
        if (end === -1) {
          break
        }
        strings.push({ value: code.slice(index + 1, end), index })
        if (!array) {
          break
        }
        index = end + 1
      } else if (!array || char === "]") {
        break
      } else {
        index++
      }
    }
    return strings
  }

  sourceAt({ start, end }) {
    const lines = this.lines.slice(start.line - 1, end.line)
    lines[lines.length - 1] = lines[lines.length - 1].slice(0, end.column)
    lines[0] = lines[0].slice(start.column)
    return lines.join("\n")
  }
}

export default class ColorsRule extends ParserRule {
  static ruleName = "colors"

  get parserOptions() {
    return { action_view_helpers: true }
  }

  check(result, context) {
    const visitor = new ColorsVisitor(this.ruleName, context, result.source)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
