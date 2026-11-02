import { Controller } from "@hotwired/stimulus"

// The readout names one column and its amount. It rests on what the page first drew and follows the pointer.
export default class extends Controller {
  static targets = [ "heading", "amount", "detail", "column" ]

  connect() {
    this.resting = {
      column: this.columnTargets.find(column => column.hasAttribute("data-active")),
      chartHeadingParam: this.headingTarget.textContent,
      chartAmountParam: this.amountTarget.textContent,
      chartDetailParam: this.hasDetailTarget ? this.detailTarget.textContent : "",
      chartToneParam: this.amountTarget.dataset.tone
    }
  }

  show({ currentTarget }) {
    this.#read(currentTarget.dataset, currentTarget)
  }

  clear() {
    this.#read(this.resting, this.resting.column)
  }

  #read({ chartHeadingParam, chartAmountParam, chartDetailParam, chartToneParam }, column) {
    this.headingTarget.textContent = chartHeadingParam
    this.amountTarget.textContent = chartAmountParam
    this.amountTarget.dataset.tone = chartToneParam
    if (this.hasDetailTarget) this.detailTarget.textContent = chartDetailParam

    this.columnTargets.forEach(target => target.toggleAttribute("data-active", target == column))
  }
}
