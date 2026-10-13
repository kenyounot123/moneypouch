import { BaseRuleVisitor, ParserRule, getAttributes, getAttributeName } from "@herb-tools/linter"

const OFF_SYSTEM = /^(?:font-pixel|tracking-.+|(?:text|leading)-\[\d.*\])$/
const RUBY_CLASS_OPTION = /\bclass:\s*(["'])(.*?)\1/g

class TypographyVisitor extends BaseRuleVisitor {
  constructor(ruleName, context, source) {
    super(ruleName, context)
    this.lines = source.split("\n")
  }

  visitHTMLOpenTagNode(node) {
    this.checkClassAttribute(node)
    super.visitHTMLOpenTagNode(node)
  }

  // link_to and tag.* parse into elements whose open tag is ERB.
  visitERBOpenTagNode(node) {
    this.checkClassAttribute(node)
    super.visitERBOpenTagNode(node)
  }

  // button_to and form builder calls stay Ruby, so read their class: option from the code.
  visitERBContentNode(node) {
    const code = node.content?.value ?? ""
    for (const match of code.matchAll(RUBY_CLASS_OPTION)) {
      this.checkClasses(match[2], this.locationIn(node.content.location, code, match))
    }
    super.visitERBContentNode(node)
  }

  checkClassAttribute(node) {
    const attribute = getAttributes(node).find((attribute) => getAttributeName(attribute) === "class")
    if (attribute?.value) {
      this.checkClasses(this.sourceAt(attribute.value.location), attribute.location)
    }
  }

  checkClasses(classes, location) {
    for (const token of classes.split(/[\s"']+/)) {
      if (OFF_SYSTEM.test(token)) {
        this.addOffense(`Replace \`${token}\` with a type role (text-display, text-title, text-heading, text-button, text-button-sm) or a size from the scale (text-xs to text-lg). Roles live in app/assets/tailwind/application.css.`, location)
      }
    }
  }

  locationIn(codeLocation, code, match) {
    const before = code.slice(0, match.index).split("\n")
    const line = codeLocation.start.line + before.length - 1
    const column = (before.length === 1 ? codeLocation.start.column : 0) + before.at(-1).length
    return { start: { line, column }, end: { line, column: column + match[0].length } }
  }

  sourceAt({ start, end }) {
    const lines = this.lines.slice(start.line - 1, end.line)
    lines[lines.length - 1] = lines[lines.length - 1].slice(0, end.column)
    lines[0] = lines[0].slice(start.column)
    return lines.join("\n")
  }
}

export default class TypographyRule extends ParserRule {
  static ruleName = "typography"

  get parserOptions() {
    return { action_view_helpers: true }
  }

  check(result, context) {
    const visitor = new TypographyVisitor(this.ruleName, context, result.source)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
