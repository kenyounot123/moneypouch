import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "heading", "income", "spent", "net", "column" ]

  connect() {
    this.resting = {
      column: this.columnTargets.find(column => column.hasAttribute("data-active")),
      chartHeadingParam: this.headingTarget.textContent,
      chartSpentParam: this.spentTarget.textContent,
      chartIncomeParam: this.hasIncomeTarget ? this.incomeTarget.textContent : "",
      chartNetParam: this.hasNetTarget ? this.netTarget.textContent : ""
    }
  }

  show({ currentTarget }) {
    this.#read(currentTarget.dataset, currentTarget)
  }

  clear() {
    this.#read(this.resting, this.resting.column)
  }

  #read({ chartHeadingParam, chartSpentParam, chartIncomeParam, chartNetParam }, column) {
    this.headingTarget.textContent = chartHeadingParam
    this.spentTarget.textContent = chartSpentParam
    if (this.hasIncomeTarget) this.incomeTarget.textContent = chartIncomeParam
    if (this.hasNetTarget) this.netTarget.textContent = chartNetParam

    this.columnTargets.forEach(target => target.toggleAttribute("data-active", target == column))
  }
}
